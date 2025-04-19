//
//  TypeDeclarationSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 18.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Type Declarations")
struct TypeDeclarationSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    struct DeclarationKindTest {
        let keyword: String
        let name: String
        let expectedKind: SymbolDefinitionKind
    }

    static let kinds: [DeclarationKindTest] = [
        .init(keyword: "struct", name: "MyType", expectedKind: .struct),
        .init(keyword: "class", name: "MyClass", expectedKind: .class),
        .init(keyword: "enum", name: "MyEnum", expectedKind: .enum),
        .init(keyword: "protocol", name: "MyProtocol", expectedKind: .protocol),
        .init(keyword: "actor", name: "MyActor", expectedKind: .actor)
    ]

    static let genericKinds = kinds.filter { $0.expectedKind != .protocol }

    // MARK: - Tests

    @Test(
        "Simple type declaration.",
        .tags(.symbolKind.definition),
        arguments: kinds
    )
    func testSimpleDeclaration(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Type declaration with single protocol conformance.",
        .tags(.symbolKind.definition),
        arguments: kinds
    )
    func testSingleProtocolConformance(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name): Codable {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: offset + 4),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Type declaration with multiple protocol conformances.",
        .tags(.symbolKind.definition),
        arguments: kinds
    )
    func testMultipleProtocolConformances(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name): Hashable, Identifiable {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: offset + 4),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Identifiable",
            fullyQualifiedName: "Identifiable",
            kind: .usage,
            location: .init(line: 1, column: offset + 14),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test(
        "Generic type declaration with a single constraint.",
        .tags(.symbolKind.definition, .syntaxFeature.generic, .syntaxFeature.constraint),
        arguments: genericKinds
    )
    func testGenericConstraint(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name)<T: Codable> {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: offset + 6),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic type declaration with multiple constraints.",
        .tags(.symbolKind.definition, .syntaxFeature.generic, .syntaxFeature.constraint),
        arguments: genericKinds
    )
    func testMultipleGenericConstraints(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name)<T: Codable, U: Hashable> {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: offset + 6),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: offset + 18),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test(
        "Generic type declaration with compound constraint.",
        .tags(.symbolKind.definition, .syntaxFeature.generic, .syntaxFeature.compoundConstraint),
        arguments: genericKinds
    )
    func testCompoundGenericConstraint(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name)<T: Codable & Sendable> {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: offset + 6),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Sendable",
            fullyQualifiedName: "Sendable",
            kind: .usage,
            location: .init(line: 1, column: offset + 16),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test(
        "Generic type declaration with a where clause.",
        .tags(
            .symbolKind.definition,
            .syntaxFeature.generic,
            .syntaxFeature.constraint,
            .syntaxFeature.whereClause
        ),
        arguments: genericKinds
    )
    func testWhereClause(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name)<T> where T: Equatable {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Equatable",
            fullyQualifiedName: "Equatable",
            kind: .usage,
            location: .init(line: 1, column: offset + 15),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic type declaration with compound where clause.",
        .tags(
            .symbolKind.definition,
            .syntaxFeature.generic,
            .syntaxFeature.compoundConstraint,
            .syntaxFeature.whereClause
        ),
        arguments: genericKinds
    )
    func testCompoundWhereClause(kind: DeclarationKindTest) {
        let sut = visitor()
        let node = node("\(kind.keyword) \(kind.name)<T> where T: Equatable & Identifiable {}")
        let result = sut.parseSymbols(node: node, fileName: "")
        let offset = kind.name.count + kind.keyword.count

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: kind.name,
            fullyQualifiedName: kind.name,
            kind: .definition(kind.expectedKind),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Equatable",
            fullyQualifiedName: "Equatable",
            kind: .usage,
            location: .init(line: 1, column: offset + 15),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Identifiable",
            fullyQualifiedName: "Identifiable",
            kind: .usage,
            location: .init(line: 1, column: offset + 27),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
}
