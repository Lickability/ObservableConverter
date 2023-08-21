//
//  ObservableObjectRecorder.swift
//
//
//  Created by Brian Capps on 8/21/23.
//

import Foundation
import SwiftSyntax

/// A `SyntaxVisitor` that records classes names that are known to be `ObservableObject` classes based on their usage.
/// This allows us to convert classes even if their inhereitence of `ObservableObject` is indirect.
final class ObservableObjectRecorder: SyntaxVisitor {
    private(set) var observableObjectClassNames: Set<String> = []
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let possibleObservableObjectTypes: [String] = node.memberBlock.members.compactMap { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return nil }
            
            let isObservableVariable = variable.attributes.contains { attribute in
                guard let simpleTypeID = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self) else { return false }
                return ["StateObject", "EnvironmentObject", "ObservedObject"].contains(simpleTypeID.name.text)
            }
            
            guard isObservableVariable else { return nil }
            
            let typeNames = variable.bindings.compactMap { binding in
                // If declared as @EnvironmentObject private var property: TypeName
                if let typeAnnotation = binding.typeAnnotation,
                    let identifier = typeAnnotation.type.as(IdentifierTypeSyntax.self) {
                    return identifier.name.text
                    
                // Else if declared as @StateObject private var property = TypeName()
                } else if let initialiazer = binding.initializer,
                            let functionCall = initialiazer.value.as(FunctionCallExprSyntax.self),
                          let identifier = functionCall.calledExpression.as(DeclReferenceExprSyntax.self) {
                    return identifier.baseName.text
                }
                
                return nil
            }
            
            return typeNames.first
        }
        
        guard !possibleObservableObjectTypes.isEmpty else { return .skipChildren }
        
        let genericTypeNames = node.genericParameterClause?.parameters.map { genericParameter in
            return genericParameter.name.text
        } ?? []
        
        possibleObservableObjectTypes.forEach { possibleTypeName in
            if genericTypeNames.contains(possibleTypeName) {
                // TODO: handle going up the tree to find the type being passed
            } else {
                observableObjectClassNames.insert(possibleTypeName)
            }
        }
        
        return .skipChildren
    }
}
