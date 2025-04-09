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

final class SyntaxSymbolsVisitor: SyntaxVisitor {

    // MARK: Properties

    private static let swiftBuiltInTypes: Set<String> = [
        "Bool", "String", "Int", "Double", "Float", "Any", "Never", "Optional", "Void"
    ]

    private let options: SwiftSymbolsAnalyzerOptions

    private(set) var symbolOccurrences: Set<SyntaxSymbolOccurrence> = []
    private(set) var imports: Set<String> = []

    private var fileURL: URL
    private let sourceLocationConverter: SourceLocationConverter
    private var scopeStack: [String] = []
    private var genericTypeParameters: Set<String> = []

    // MARK: Initialization

    init(
        fileURL: URL,
        options: SwiftSymbolsAnalyzerOptions,
        sourceLocationConverter: SourceLocationConverter
    ) {
        self.fileURL = fileURL
        self.options = options
        self.sourceLocationConverter = sourceLocationConverter
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: Recording Occurrences and Scope Helpers

    private func recordOccurrence(
        name: String,
        kind: SymbolOccurrenceKind,
        location: SyntaxSymbolLocation,
        fullyQualifiedName: String? = nil
    ) {
        guard !Self.swiftBuiltInTypes.contains(name) else {
            return
        }

        if kind.isDefinition && !options.contains(.includeDefinitions) ||
            kind.isUsage && !options.contains(.includeUsages) {
            return
        }

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
        }
    }

    private func resetGenericParameters() {
        genericTypeParameters.removeAll()
    }

    private func shouldRecordSymbol(_ name: String) -> Bool {
        guard let first = name.first, first.isUppercase else { return false }
        return !genericTypeParameters.contains(name)
    }

    // MARK: - Visitor

    // MARK: Import Declarations

    override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        if let firstPath = node.path.first?.name.text {
            imports.insert(firstPath)
        }
        return .visitChildren
    }

    // MARK: - Variable Declarations and Property Wrappers

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let typeAnnotation = binding.typeAnnotation {
                collectTypeNames(from: typeAnnotation.type)
            }
            if let initializer = binding.initializer?.value {
                processExpressionForTypes(initializer)
            }
        }
        processAttributes(node.attributes)
        return .visitChildren
    }

    // MARK: Type Expressions

    override func visit(_ node: TypeExprSyntax) -> SyntaxVisitorContinueKind {
        collectTypeNames(from: node.type)
        return .visitChildren
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        if let signature = node.signature {
            if case let .parameterClause(parameterClause) = signature.parameterClause {
                for param in parameterClause.parameters {
                    if let typeAnnotation = param.type {
                        collectTypeNames(from: typeAnnotation)
                    }
                }
            }
            if let returnClause = signature.returnClause {
                collectTypeNames(from: returnClause.type)
            }
        }
        return .visitChildren
    }

    // MARK: Inheritance

    override func visit(_ node: InheritedTypeSyntax) -> SyntaxVisitorContinueKind {
        collectTypeNames(from: node.type)
        return .visitChildren
    }

    // MARK: Initializer and Function Signatures

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = "init"
        scopeStack.append(name)
        collectGenericParameters(from: node.genericParameterClause)

        for param in node.signature.parameterClause.parameters {
            collectTypeNames(from: param.type)
        }
        return .visitChildren
    }

    override func visitPost(_ node: InitializerDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(uniqueFunctionIdentifier(node))
        collectGenericParameters(from: node.genericParameterClause)

        if let returnType = node.signature.returnClause?.type {
            collectTypeNames(from: returnType)
        }
        for param in node.signature.parameterClause.parameters {
            collectTypeNames(from: param.type)
        }
        return .visitChildren
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
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

    // MARK: - Function Calls

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        processExpressionForTypes(node.calledExpression)
        return .visitChildren
    }

    // MARK: Member Types (Qualified Type Names)

    override func visit(_ node: MemberTypeSyntax) -> SyntaxVisitorContinueKind {
        // Check if the base of the member type is an imported module.
        if let baseIdentifier = node.baseType.as(IdentifierTypeSyntax.self),
           imports.contains(baseIdentifier.name.text) {
            // Construct the fully qualified name using the module and the member.
            let fqn = "\(baseIdentifier.name.text).\(node.name.text)"

            // Record the external usage with its fully qualified name.
            recordOccurrence(
                name: node.name.text,
                kind: .usage,
                location: location(from: Syntax(node)),
                fullyQualifiedName: fqn
            )
        } else {
            // For unqualified member types, record normally.
            recordOccurrence(
                name: node.name.text,
                kind: .usage,
                location: location(from: Syntax(node)),
                fullyQualifiedName: fullyQualifiedName(for: node.name.text)
            )

            // Also, process the base type recursively.
            collectTypeNames(from: node.baseType)
        }
        return .visitChildren
    }

    // MARK: Subscript

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        for param in node.parameterClause.parameters {
            collectTypeNames(from: param.type)
        }
        collectTypeNames(from: node.returnClause.type)
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
        scopeStack.append(node.name.text)
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            collectTypeNames(from: inheritance.type)
        }
        return .visitChildren
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
        scopeStack.append(node.name.text)
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            collectTypeNames(from: inheritance.type)
        }
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
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
        scopeStack.append(node.name.text)
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            collectTypeNames(from: inheritance.type)
        }
        return .visitChildren
    }

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            if let paramClause = element.parameterClause {
                for param in paramClause.parameters {
                    collectTypeNames(from: param.type)
                }
            }
        }
        return .visitChildren
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
        collectTypeNames(from: node.initializer.value)
        return .visitChildren
    }

    override func visitPost(_ node: TypeAliasDeclSyntax) {
        resetGenericParameters()
    }

    // MARK: Protocol

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        recordOccurrence(
            name: node.name.text,
            kind: .definition(.protocol),
            location: location(from: Syntax(node)),
            fullyQualifiedName: fullyQualifiedName(for: node.name.text)
        )
        scopeStack.append(node.name.text)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            collectTypeNames(from: inheritance.type)
        }
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
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
        scopeStack.append(node.name.text)
        collectGenericParameters(from: node.genericParameterClause)
        for inheritance in node.inheritanceClause?.inheritedTypes ?? [] {
            collectTypeNames(from: inheritance.type)
        }
        return .visitChildren
    }

    override func visitPost(_ node: ActorDeclSyntax) {
        _ = scopeStack.popLast()
        resetGenericParameters()
    }

    // MARK: - Helpers

    /// Recursively collects type names from a given type syntax node.
    private func collectTypeNames(from typeSyntax: TypeSyntax) {

        if let identifier = typeSyntax.as(IdentifierTypeSyntax.self) {
            // If the type is a simple identifier (AVAsset or Set)
            let name = identifier.name.text

            // Only record if the name starts with an uppercase letter and isn’t a generic parameter.
            if shouldRecordSymbol(name) {
                recordOccurrence(
                    name: name,
                    kind: .usage,
                    location: location(from: Syntax(identifier)),
                    fullyQualifiedName: fullyQualifiedName(for: name)
                )
            }

            // If there are generic arguments (Set<AnyCancellable>), recursively process each argument.
            if let genericArgs = identifier.genericArgumentClause {
                for arg in genericArgs.arguments {
                    collectTypeNames(from: arg.argument)
                }
            }

        } else if let member = typeSyntax.as(MemberTypeSyntax.self) {
            // If the type is a member type (qualified name) like "Module.TypeName".
            // Record the right-hand name as the type.
            if let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
               imports.contains(baseIdentifier.name.text) {
                let fqn = "\(baseIdentifier.name.text).\(member.name.text)"
                recordOccurrence(
                    name: member.name.text,
                    kind: .usage,
                    location: location(from: Syntax(member)),
                    fullyQualifiedName: fqn
                )
            } else {
                // Otherwise, process as before.
                recordOccurrence(
                    name: member.name.text,
                    kind: .usage,
                    location: location(from: Syntax(member)),
                    fullyQualifiedName: fullyQualifiedName(for: member.name.text)
                )
                collectTypeNames(from: member.baseType)
            }

        } else if let optional = typeSyntax.as(OptionalTypeSyntax.self) {
            // For an optional type, process the wrapped type.
            collectTypeNames(from: optional.wrappedType)

        } else if let array = typeSyntax.as(ArrayTypeSyntax.self) {
            // For an array, process the element type.
            collectTypeNames(from: array.element)

        } else if let dictionary = typeSyntax.as(DictionaryTypeSyntax.self) {
            // For a dictionary, process both key and value types.
            collectTypeNames(from: dictionary.key)
            collectTypeNames(from: dictionary.value)

        } else if let tuple = typeSyntax.as(TupleTypeSyntax.self) {
            // For a tuple type, process each element's type.
            for element in tuple.elements {
                collectTypeNames(from: element.type)
            }
        }
    }

    /// Processes an expression syntax node to extract type names.
    private func processExpressionForTypes(_ expr: ExprSyntax) {

        if let call = expr.as(FunctionCallExprSyntax.self) {
            // If the expression is a function call.
            // Recursively process the called expression.

            processExpressionForTypes(call.calledExpression)

            // Retrieve the full text of the call. This text contains the generic arguments.
            let callText = call.description
            // We use the location for the call as the location for any generic argument occurrences.
            let callLocation = location(from: Syntax(call))

            // Check if there is a trailing closure.
            if let braceIndex = callText.firstIndex(of: "{"),
               let genericIndex = callText.firstIndex(of: "<"),
               braceIndex < genericIndex {
                return
            }

            // Look for the generic argument clause delimiters in the call text.
            if let genericStart = callText.firstIndex(of: "<"),
               let genericEnd = callText.firstIndex(of: ">") {

                let genericSubstring = callText[callText.index(after: genericStart)..<genericEnd]
                let genericArgs = genericSubstring.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                for arg in genericArgs where shouldRecordSymbol(arg) {
                    recordOccurrence(
                        name: arg,
                        kind: .usage,
                        location: callLocation,
                        fullyQualifiedName: fullyQualifiedName(for: arg)
                    )
                }
            }

        } else if let typeExpr = expr.as(TypeExprSyntax.self) {
            // If the expression is a type expression (explicitly cast or referenced as a type).
            collectTypeNames(from: typeExpr.type)

        } else if let identifier = expr.as(DeclReferenceExprSyntax.self) {
            // If the expression is a simple identifier reference (a bare type name)
            let name = identifier.baseName.text
            if shouldRecordSymbol(name) {
                recordOccurrence(
                    name: name,
                    kind: .usage,
                    location: location(from: Syntax(identifier)),
                    fullyQualifiedName: fullyQualifiedName(for: name)
                )
            }

        } else if let member = expr.as(MemberAccessExprSyntax.self) {
            // If the member access has a base, check if it is an imported module.

            if let base = member.base,
               let baseID = base.as(DeclReferenceExprSyntax.self),
               imports.contains(baseID.baseName.text) {
                // If so, construct the fully qualified name using the module and member.
                let fqn = "\(baseID.baseName.text).\(member.declName.baseName.text)"
                recordOccurrence(
                    name: member.declName.baseName.text,
                    kind: .usage,
                    location: location(from: Syntax(member)),
                    fullyQualifiedName: fqn
                )
            } else {
                let name = member.declName.baseName.text
                if shouldRecordSymbol(name) {
                    recordOccurrence(
                        name: name,
                        kind: .usage,
                        location: location(from: Syntax(member)),
                        fullyQualifiedName: fullyQualifiedName(for: name)
                    )
                }
            }
        }

    }

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
                        fullyQualifiedName: fullyQualifiedName(for: name)
                    )
                }
            }
        }
    }
}
