//
//  SyntaxSymbolsVisitor.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 21.03.2025.
//

import Common
import Foundation
import SwiftParser
import SwiftSyntax

struct SyntaxVisitorResult {
    let symbolOccurrences: Set<SyntaxSymbolOccurrence>
    let imports: Set<String>
}

final class SyntaxSymbolsVisitor: SyntaxVisitor {

    // MARK: Properties

    private var sourceLocationConverter: SourceLocationConverter!

    private var symbolOccurrences: Set<SyntaxSymbolOccurrence> = []
    private var imports: Set<String> = []

    private var scopeStack: [String] = []
    private var genericTypeParameters: Set<String> = []

    private var localVariablesStack: [String] = []
    private var currentScopeVariables: Set<String> = []

    // MARK: Initialization

    init() {
        super.init(viewMode: .fixedUp)
    }

    func parseSymbols(node: some SyntaxProtocol, fileName: String) -> SyntaxVisitorResult {
        reset()
        sourceLocationConverter = SourceLocationConverter(
            fileName: fileName,
            tree: node
        )
        walk(node)
        return SyntaxVisitorResult(
            symbolOccurrences: symbolOccurrences,
            imports: imports
        )
    }

    private func reset() {
        symbolOccurrences.removeAll()
        imports.removeAll()
        scopeStack.removeAll()
        genericTypeParameters.removeAll()
    }

    // MARK: Recording Occurrences and Scope Helpers

    private func recordOccurrence(
        name: String,
        kind: SymbolOccurrenceKind,
        location: SyntaxSymbolLocation,
        fullyQualifiedName: String? = nil
    ) {
        let occurrence = SyntaxSymbolOccurrence(
            symbolName: name,
            fullyQualifiedName: fullyQualifiedName,
            kind: kind,
            location: location,
            scopeChain: scopeStack
        )
        symbolOccurrences.insert(occurrence)
    }

    private func fullyQualifiedName(for name: String) -> String {
        (scopeStack + [name]).joined(separator: ".")
    }

    private func location(from node: Syntax) -> SyntaxSymbolLocation {
        let loc = sourceLocationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        return SyntaxSymbolLocation(line: loc.line, column: loc.column)
    }

    private func collectGenericParameters(from clause: GenericParameterClauseSyntax?) {
        guard let clause else { return }
        for param in clause.parameters {
            genericTypeParameters.insert(param.name.text)
            if let inheritedType = param.inheritedType {
                walk(inheritedType)
            }
        }
    }

    private func resetGenericParameters() {
        genericTypeParameters.removeAll()
    }

    private func shouldRecordSymbol(_ name: String) -> Bool {
        return !genericTypeParameters.contains(name) && !localVariablesStack.contains(name)
    }

    // MARK: - Visitor

    // MARK: Import Declarations

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        imports.insert(node.path.description)
        return .visitChildren
    }

    // MARK: - Variable Declarations and Property Wrappers

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let pattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                let variableName = pattern.identifier.text
                currentScopeVariables.insert(variableName)
                localVariablesStack.append(variableName)
            }
            if let initializer = binding.initializer {
                walk(initializer)
            }
            if let annotation = binding.typeAnnotation {
                walk(annotation)
            }
        }

        processAttributes(node.attributes)
        return .skipChildren
    }

    override func visitPost(_ node: CodeBlockSyntax) {
        currentScopeVariables.forEach { _ in
            localVariablesStack.removeLast()
        }
        currentScopeVariables.removeAll()
    }

    // MARK: Initializer and Function Signatures

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        collectGenericParameters(from: node.genericParameterClause)
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        for param in node.signature.parameterClause.parameters {
            walk(param.type)
        }
        if let throwsClause = node.signature.effectSpecifiers?.throwsClause {
            if let throwingType = throwsClause.type {
                walk(throwingType)
            }
        }

        scopeStack.append("init")
        if let codeBlock = node.body {
            walk(codeBlock)
        }
        return .skipChildren
    }

    override func visitPost(_ node: InitializerDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        collectGenericParameters(from: node.genericParameterClause)
        if let returnType = node.signature.returnClause?.type {
            walk(returnType)
        }
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        for param in node.signature.parameterClause.parameters {
            walk(param.type)
        }
        if let throwsClause = node.signature.effectSpecifiers?.throwsClause {
            if let throwingType = throwsClause.type {
                walk(throwingType)
            }
        }

        scopeStack.append(uniqueFunctionIdentifier(node))
        if let codeBlock = node.body {
            walk(codeBlock)
        }
        return .skipChildren
    }

    private func uniqueFunctionIdentifier(_ node: FunctionDeclSyntax) -> String {
        let name = node.name.text
        let parameterLabels = node.signature.parameterClause.parameters.map { param in
            let label = param.firstName.text
            return label == "_" ? "" : "\(label):"
        }.joined()
        let returnType = node.signature.returnClause?.type.description.trimmingCharacters(in: .whitespaces) ?? "Void"
        return "\(name)(\(parameterLabels)):\(returnType)"
    }

    // MARK: Subscript

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        for param in node.parameterClause.parameters {
            walk(param.type)
        }
        walk(node.returnClause.type)
        return .visitChildren
    }

    // MARK: - Declarations

    // MARK: Struct

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.struct),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            walk(inheritance.type)
        }
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        scopeStack.append(node.name.text)
        walk(node.memberBlock)
        return .skipChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    // MARK: Class

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.class),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            walk(inheritance.type)
        }
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        scopeStack.append(node.name.text)
        walk(node.memberBlock)
        return .skipChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    // MARK: Actor

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.actor),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            walk(inheritance.type)
        }
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        scopeStack.append(node.name.text)
        walk(node.memberBlock)
        return .skipChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    // MARK: Enum

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.enum),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            walk(inheritance.type)
        }
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        scopeStack.append(node.name.text)
        walk(node.memberBlock)
        return .skipChildren
    }

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            if let paramClause = element.parameterClause {
                for param in paramClause.parameters {
                    walk(param.type)
                }
            }
        }
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    // MARK: Typealias

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.typealias),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        collectGenericParameters(from: node.genericParameterClause)
        walk(node.initializer.value)
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        return .skipChildren
    }

    override func visitPost(_ node: TypeAliasDeclSyntax) {
        resetGenericParameters()
    }

    // MARK: Associated Type

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.associatedType),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        if let initializer = node.initializer?.value {
            walk(initializer)
        }
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            walk(inheritance.type)
        }
        if let whereClause = node.genericWhereClause {
            processGenericWhereClause(whereClause)
        }
        return .skipChildren
    }

    // MARK: Protocol

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.protocol),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            walk(inheritance.type)
        }
        scopeStack.append(node.name.text)
        walk(node.memberBlock)
        return .skipChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    // MARK: - Type Syntax

    // Example: Int, String, User
    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if shouldRecordSymbol(name) {
            recordOccurrence(
                name: name,
                kind: .usage,
                location: location(from: Syntax(node)),
                fullyQualifiedName: name
            )
        }
        return .visitChildren
    }

    // Example: Module.TypeName, Container.Entry
    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        let qualifiedName = node.description.trimmingCharacters(in: .whitespaces)
        recordOccurrence(
            name: node.name.text,
            kind: .usage,
            location: location(from: Syntax(node)),
            fullyQualifiedName: qualifiedName
        )
        return .skipChildren
    }

    // MARK: - Expression Syntax

    // Example: Result<String, Error>.success(...)
    override func visit(_ node: GenericSpecializationExprSyntax) -> SyntaxVisitorContinueKind {
        walk(node.expression)

        for argument in node.genericArgumentClause.arguments {
            if case let .type(type) = argument.argument {
                walk(type)
            }
        }

        return .skipChildren
    }

    // Example: User()
    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if shouldRecordSymbol(name) {
            recordOccurrence(
                name: name,
                kind: .usage,
                location: location(from: Syntax(node)),
                fullyQualifiedName: name
            )
        }
        return .skipChildren
    }

    // Example: Foundation.Date.now or Container.Entry()
    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.base?.as(DeclReferenceExprSyntax.self),
           imports.contains(base.baseName.text) {
            let fqn = "\(base.baseName.text).\(node.declName.baseName.text)"
            recordOccurrence(
                name: node.declName.baseName.text,
                kind: .usage,
                location: location(from: Syntax(node)),
                fullyQualifiedName: fqn
            )
            return .skipChildren
        }

        if let base = node.base {
            walk(base)
        }

        return .skipChildren
    }

    // Example: \User.name
    override func visit(_ node: KeyPathExprSyntax) -> SyntaxVisitorContinueKind {
        if let root = node.root {
            walk(root)
        }
        return .skipChildren
    }

    // MARK: - Helpers

    /// Processes property wrapper attributes and collects their type names.
    private func processAttributes(_ attributes: AttributeListSyntax?) {
        guard let attributes else { return }

        for attribute in attributes {
            if let attr = attribute.as(AttributeSyntax.self),
               let wrapperName = attr.attributeName.as(IdentifierTypeSyntax.self) {
                let name = wrapperName.name.text
                if shouldRecordSymbol(name) {
                    recordOccurrence(
                        name: name,
                        kind: .usage,
                        location: location(from: Syntax(attribute)),
                        fullyQualifiedName: name
                    )
                }
            }
        }
    }

    private func processGenericWhereClause(_ clause: GenericWhereClauseSyntax) {
        for requirement in clause.requirements {
            switch requirement.requirement {
            case let .conformanceRequirement(syntax):
                walk(syntax.rightType)

            case .sameTypeRequirement:
                break

            case .layoutRequirement:
                break
            }
        }
    }
}
