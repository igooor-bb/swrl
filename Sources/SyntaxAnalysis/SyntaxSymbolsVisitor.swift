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

struct LocalVariableOccurrence: Hashable {
    let name: String
    let scopeChain: [String]
}

final class SyntaxSymbolsVisitor: SyntaxVisitor {

    // MARK: Properties

    private var sourceLocationConverter: SourceLocationConverter!

    private var symbolOccurrences: Set<SyntaxSymbolOccurrence> = []
    private var imports: Set<String> = []

    private var scopeStack: [String] = []
    private var genericTypeParameters: Set<String> = []

    private var localVariables: Set<LocalVariableOccurrence> = []
    private var isInsideCatchClause = false

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
        localVariables.removeAll()
        isInsideCatchClause = false
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
        guard !name.isEmpty else {
            return false
        }

        let isGenericParameter = genericTypeParameters.contains(name)
        let isSynthesizedVariable = isInsideCatchClause && name == "error"

        // TODO: Resolve function symbols
        let isFunction = name[name.startIndex].isLowercase

        let isLocalVariable = {
            let foundLocalVariable = localVariables.first { occ in
                occ.name == name && occ.scopeChain.isPrefix(to: scopeStack)
            }
            return foundLocalVariable != nil
        }()

        return !isGenericParameter && !isLocalVariable && !isSynthesizedVariable && !isFunction
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
                let occurrence = LocalVariableOccurrence(
                    name: variableName,
                    scopeChain: scopeStack
                )
                localVariables.insert(occurrence)
            }
            if let initializer = binding.initializer {
                walk(initializer)
            }
            if let annotation = binding.typeAnnotation {
                walk(annotation)
            }
        }

        walk(node.attributes)
        return .skipChildren
    }

    // MARK: Initializer and Function Signatures

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let scopeName = "init"

        collectGenericParameters(from: node.genericParameterClause)
        if let whereClause = node.genericWhereClause {
            walk(whereClause)
        }
        for param in node.signature.parameterClause.parameters {
            let paramName = param.secondName ?? param.firstName
            let occurrence = LocalVariableOccurrence(
                name: paramName.text,
                scopeChain: scopeStack + [scopeName]
            )
            localVariables.insert(occurrence)
            walk(param.type)
        }
        if let throwsClause = node.signature.effectSpecifiers?.throwsClause {
            if let throwingType = throwsClause.type {
                walk(throwingType)
            }
        }

        scopeStack.append(scopeName)
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
        let scopeName = uniqueFunctionIdentifier(node)

        collectGenericParameters(from: node.genericParameterClause)
        if let returnType = node.signature.returnClause?.type {
            walk(returnType)
        }
        if let whereClause = node.genericWhereClause {
            walk(whereClause)
        }
        for param in node.signature.parameterClause.parameters {
            let paramName = param.secondName ?? param.firstName
            let occurrence = LocalVariableOccurrence(
                name: paramName.text,
                scopeChain: scopeStack + [scopeName]
            )
            localVariables.insert(occurrence)
            walk(param.type)
        }
        if let throwsClause = node.signature.effectSpecifiers?.throwsClause {
            if let throwingType = throwsClause.type {
                walk(throwingType)
            }
        }

        scopeStack.append(scopeName)
        if let codeBlock = node.body {
            walk(codeBlock)
        }
        return .skipChildren
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        isInsideCatchClause = true
        return .visitChildren
    }

    override func visitPost(_ node: CatchClauseSyntax) {
        isInsideCatchClause = false
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
            walk(whereClause)
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
            walk(whereClause)
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
            walk(whereClause)
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
            walk(whereClause)
        }
        scopeStack.append(node.name.text)
        walk(node.memberBlock)
        return .skipChildren
    }

    // MARK: Extension

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let typeSyntax = node.extendedType.as(IdentifierTypeSyntax.self) {
            let extendedTypeName = typeSyntax.name.text
            scopeStack.append(extendedTypeName)
        }
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        _ = scopeStack.popLast()
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
            walk(whereClause)
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
            walk(whereClause)
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
        let name = node.name.text
        if shouldRecordSymbol(name) {
            recordOccurrence(
                name: name,
                kind: .usage,
                location: location(from: Syntax(node)),
                fullyQualifiedName: qualifiedName
            )
        }
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
        guard case .identifier = node.baseName.tokenKind else {
            return .skipChildren
        }

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

    override func visit(_ node: GenericWhereClauseSyntax) -> SyntaxVisitorContinueKind {
        for requirement in node.requirements {
            switch requirement.requirement {
            case let .conformanceRequirement(syntax):
                walk(syntax.rightType)

            case .sameTypeRequirement:
                break

            case .layoutRequirement:
                break
            }
        }
        return .skipChildren
    }

    /// Processes property wrapper attributes and collects their type names.
    override func visit(_ node: AttributeListSyntax) -> SyntaxVisitorContinueKind {
        for attribute in node {
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

        return .skipChildren
    }
}
