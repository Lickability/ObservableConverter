import Foundation
import SwiftSyntax
import SwiftParser
import ArgumentParser

// TODO: Tests

@main
struct ObservableConverterCommand: ParsableCommand {
    @Argument(help: "A list of file paths to convert those files to use @Observable.")
    var filePaths: [String]
    
    func run() throws {
        try filePaths.forEach { filePath in
            let fileURL = URL(fileURLWithPath: filePath)
            let updatedTempFileURL = fileURL.appendingPathExtension("temp")

            let sourceFileContents = try String(contentsOf: fileURL, encoding: .utf8)
            let sourceFileSyntax = Parser.parse(source: sourceFileContents)
            
            let recorder = ObservableObjectRecorder(viewMode: .all)
            recorder.walk(sourceFileSyntax)
            let observableConverted = ObservableConverterRewriter(knownClassNames: recorder.observableObjectClassNames).visit(sourceFileSyntax)

            try "".write(to: updatedTempFileURL, atomically: true, encoding: .utf8)
            let fileHandle = try FileHandle(forWritingTo: updatedTempFileURL)
            var fileWriter = FileHandlerOutputStream(fileHandle: fileHandle)
            observableConverted.write(to: &fileWriter)
            fileHandle.closeFile()

            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: updatedTempFileURL)
        }
    }
}

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
                print("BOC: Generic found for type name: \(possibleTypeName)")
            } else {
                observableObjectClassNames.insert(possibleTypeName)
            }
        }
        
        return .skipChildren
    }
}

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

        return DeclSyntax(newNode)
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
        
        return DeclSyntax(newNode)
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
        
        return newNode
    }
    
    override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
        // Handles view modifier calls to `.environmentObject()` by converting to the new `.environment()`
        guard node.declName.baseName.text == "environmentObject" else { return super.visit(node) }
        
        var newNode = node
        newNode.declName.baseName = .stringSegment("environment")
        return ExprSyntax(newNode)
    }
}

struct FileHandlerOutputStream: TextOutputStream {
    let fileHandle: FileHandle

    mutating func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            print("Write error")
        }
    }
}
