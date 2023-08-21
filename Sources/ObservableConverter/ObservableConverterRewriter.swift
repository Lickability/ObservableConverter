//
//  ObservableConverterRewriter.swift
//
//
//  Created by Brian Capps on 8/21/23.
//

import Foundation
import SwiftSyntax

/// A `SyntaxRewriter` that converts known usage of `ObservableObject` APIs to newer `@Observable` ones.
final class ObservableConverterRewriter: SyntaxRewriter {
    private let knownClassNames: Set<String>
    
    init(knownClassNames: Set<String>) {
        self.knownClassNames = knownClassNames
    }
    
    override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        var newNode = node
        guard let inheritanceClause = node.inheritanceClause else { return super.visit(node) }
        
        // Detect ObservableObject inheritance
        let inheretedTypeCollection = inheritanceClause.inheritedTypes
        
        let filteredTypes = inheretedTypeCollection.filter { inheretedType in
            guard let simpleTypeID = inheretedType.type.as(IdentifierTypeSyntax.self) else { return true }
            return simpleTypeID.name.text != "ObservableObject"
        }

        let isObservableObject = filteredTypes.count < inheretedTypeCollection.count || knownClassNames.contains(node.name.text)
        guard isObservableObject else { return super.visit(node) }

        // Add @Observable, preserving leading whitespace from either the leading modifiers or class
        let classLeadingTrivia = node.modifiers.first?.leadingTrivia ?? node.classKeyword.leadingTrivia
        
        if !node.modifiers.isEmpty {
            newNode.modifiers[node.modifiers.startIndex].leadingTrivia = .spaces(0)
        } else {
            newNode.classKeyword.leadingTrivia = .spaces(0)
        }
        
        let observableIdentifier = IdentifierTypeSyntax(name: .stringSegment("Observable"))
        var observableAttribute = AttributeSyntax(attributeName: observableIdentifier)
        observableAttribute.atSign = .atSignToken()
        observableAttribute.leadingTrivia = classLeadingTrivia
        observableAttribute.trailingTrivia = .newline
        newNode.attributes.append(AttributeListSyntax.Element(observableAttribute))

        // Remove ObservableObject inheritance
        newNode.inheritanceClause?.inheritedTypes = filteredTypes
        
        if filteredTypes.isEmpty {
            newNode.inheritanceClause?.colon.tokenKind = .stringSegment("")
        }
        
        // Loop over properties for an observable object and replace @Published annotations with nothing
        let newMembers = newNode.memberBlock.members.map { member in
            var newMember = member
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return member }
            
            let newAttributes = variable.attributes.map { attribute in
                guard let customAttribute = attribute.as(AttributeSyntax.self) else { return attribute }
                guard let simpleTypeID = customAttribute.attributeName.as(IdentifierTypeSyntax.self) else { return attribute }
                guard simpleTypeID.name.text == "Published" else { return attribute }
                
                var newAttribute = customAttribute
                var newSimpleTypeID = simpleTypeID
                newSimpleTypeID.name.tokenKind = .stringSegment("")
                newAttribute.attributeName = TypeSyntax(newSimpleTypeID)
                newAttribute.atSign.tokenKind = .stringSegment("")
                newAttribute.trailingTrivia = .spaces(0)
                return AttributeListSyntax.Element(newAttribute)
            }
            
            var newVariable = variable
            newVariable.attributes = AttributeListSyntax(newAttributes)
            newMember.decl = DeclSyntax(newVariable)
            
            return newMember
        }
        
        newNode.memberBlock.members = MemberBlockItemListSyntax(newMembers)

        return super.visit(newNode)
    }
    
    // Search for and update @EnvironmentObject to @Environment
    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        let typeBindingIndex = node.bindings.firstIndex { patternBinding in
            patternBinding.typeAnnotation?.type.as(IdentifierTypeSyntax.self) != nil
        }
                
        guard let typeBindingIndex else { return super.visit(node) }
        guard let variableTypeName = node.bindings[typeBindingIndex].typeAnnotation?.type.as(IdentifierTypeSyntax.self)?.name.text else { return super.visit(node) }

        let environmentObjectAttributeIndex = node.attributes.firstIndex { attribute in
            guard let customAttribute = attribute.as(AttributeSyntax.self) else { return false }
            guard let simpleTypeID = customAttribute.attributeName.as(IdentifierTypeSyntax.self) else { return false }
            return simpleTypeID.name.text == "EnvironmentObject"
        }
        
        guard let environmentObjectAttributeIndex else { return super.visit(node) }
        
        let environmentObjectAttribute = node.attributes[environmentObjectAttributeIndex]
        guard let customAttribute = environmentObjectAttribute.as(AttributeSyntax.self) else { return super.visit(node) }
        guard let simpleTypeID = customAttribute.attributeName.as(IdentifierTypeSyntax.self) else { return super.visit(node) }

        var newNode = node
        
        // Remove the trailing type annotation, as it's no longer necessary
        newNode.bindings[typeBindingIndex].typeAnnotation?.colon.tokenKind = .stringSegment("")
        newNode.bindings[typeBindingIndex].typeAnnotation?.type = TypeSyntax(IdentifierTypeSyntax(name: .stringSegment("")))

        // Update the attribute to Environment with the specified type anontation here instead
        var newAttribute = customAttribute
        var newSimpleTypeID = simpleTypeID
        newSimpleTypeID.name.tokenKind = .stringSegment("Environment")
        newSimpleTypeID.trailingTrivia = .spaces(0)
        
        newAttribute.attributeName = TypeSyntax(newSimpleTypeID)
        newAttribute.leftParen = TokenSyntax(.leftParen, presence: .present)
        newAttribute.rightParen = TokenSyntax(.rightParen, presence: .present)
        newAttribute.trailingTrivia = .space
        
        let typeIdentifier = DeclReferenceExprSyntax(baseName: .stringSegment(variableTypeName))
        let member = MemberAccessExprSyntax(base: typeIdentifier, period: .periodToken(), name: .stringSegment("self"))
        let labeledExpressions = LabeledExprListSyntax(arrayLiteral: LabeledExprSyntax(expression: member))
        newAttribute.arguments = AttributeSyntax.Arguments(labeledExpressions)
        newNode.attributes[environmentObjectAttributeIndex] = AttributeListSyntax.Element(newAttribute)
        
        return super.visit(newNode)
    }
    
    override func visit(_ node: FunctionCallExprSyntax) -> ExprSyntax {
        guard var simpleTypeID = node.calledExpression.as(DeclReferenceExprSyntax.self) else { return super.visit(node) }
        guard simpleTypeID.baseName.text == "StateObject" else { return super.visit(node) }
        
        let wrappedValueIndex = node.arguments.firstIndex { argument in
            argument.label?.text == "wrappedValue"
        }
        
        guard let wrappedValueIndex else { return super.visit(node) }
        
        simpleTypeID.baseName.tokenKind = .stringSegment("State")

        var newNode = node
        newNode.calledExpression = ExprSyntax(simpleTypeID)
        newNode.arguments[wrappedValueIndex].label?.tokenKind = .stringSegment("initialValue")
        
        return super.visit(newNode)
    }
    
    override func visit(_ node: AttributeSyntax) -> AttributeSyntax {
        guard let simpleTypeID = node.attributeName.as(IdentifierTypeSyntax.self) else { return super.visit(node) }
        
        var newNode = node
        var newSimpleTypeID = simpleTypeID

        if simpleTypeID.name.text == "StateObject" {
            newSimpleTypeID.name.tokenKind = .stringSegment("State")
            newNode.attributeName = TypeSyntax(newSimpleTypeID)
        } else if simpleTypeID.name.text == "ObservedObject" {
            newSimpleTypeID.name.tokenKind = .stringSegment("")
            newNode.attributeName = TypeSyntax(newSimpleTypeID)
            newNode.atSign.tokenKind = .stringSegment("")
            newNode.trailingTrivia = .spaces(0)
        }
        
        return super.visit(newNode)
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
        // Handles view modifier calls to `.environmentObject()` by converting to the new `.environment()`
        guard node.declName.baseName.text == "environmentObject" else { return super.visit(node) }
        
        var newNode = node
        newNode.declName.baseName = .stringSegment("environment")
        return super.visit(newNode)
    }
}
