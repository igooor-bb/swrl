//
//  InitializerSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 18.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Initializers")
struct InitializerSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test("Initializer with a single parameter.")
    func testInitializerWithSingleParameter() {
        let sut = visitor()
        let node = node("init(name: String) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test("Initializer with multiple parameters.")
    func testInitializerWithMultipleParameters() {
        let sut = visitor()
        let node = node("init(id: UUID, count: Int) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "UUID",
            fullyQualifiedName: "UUID",
            kind: .usage,
            location: .init(line: 1, column: 10),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 1, column: 23),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Failable initializer with a parameter.")
    func testFailableInitializer() {
        let sut = visitor()
        let node = node("init?(data: Data) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Data",
            fullyQualifiedName: "Data",
            kind: .usage,
            location: .init(line: 1, column: 13),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test("Throwing initializer with a parameter.")
    func testThrowingInitializer() {
        let sut = visitor()
        let node = node("init(file: URL) throws(CustomError) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "URL",
            fullyQualifiedName: "URL",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "CustomError",
            fullyQualifiedName: "CustomError",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Initializer with a closure parameter.")
    func testInitializerWithClosureParameter() {
        let sut = visitor()
        let node = node("init(completion: () -> Void)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test("Initializer with array and dictionary parameters.")
    func testInitializerWithArrayAndDictionaryTypes() {
        let sut = visitor()
        let node = node("init(list: [Item], mapping: [Key: Value]) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Item",
            fullyQualifiedName: "Item",
            kind: .usage,
            location: .init(line: 1, column: 13),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Key",
            fullyQualifiedName: "Key",
            kind: .usage,
            location: .init(line: 1, column: 30),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Value",
            fullyQualifiedName: "Value",
            kind: .usage,
            location: .init(line: 1, column: 35),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test("Initializer with a generic type parameter like Result<String, Error>.")
    func testInitializerWithGenericTypeParameter() {
        let sut = visitor()
        let node = node("init(result: Result<String, Error>) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 14),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 1, column: 29),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test("Convenience initializer with a generic parameter.")
    func testConvenienceInitializerWithGenericConstraint() {
        let sut = visitor()
        let node = node("convenience init<T: Codable>(from: T) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test("Initializer with multiple generic parameters and constraints.")
    func testInitializerWithMultipleGenericConstraints() {
        let sut = visitor()
        let node = node("init<T: Codable, U: Equatable>(first: T, second: U) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 9),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Equatable",
            fullyQualifiedName: "Equatable",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Initializer with a compound generic constraint.")
    func testInitializerWithCompoundGenericConstraint() {
        let sut = visitor()
        let node = node("init<T: Hashable & Codable>(input: T) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: 9),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 20),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Initializer with a tuple parameter.")
    func testInitializerWithTupleParameter() {
        let sut = visitor()
        let node = node("init(origin: (Float, Float)) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Float",
            fullyQualifiedName: "Float",
            kind: .usage,
            location: .init(line: 1, column: 15),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Float",
            fullyQualifiedName: "Float",
            kind: .usage,
            location: .init(line: 1, column: 22),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Initializer with a where clause.")
    func testInitializerWithWhereClause() {
        let sut = visitor()
        let node = node("init<T>(value: T) where T: Hashable {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: 28),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test("Initializer with multiple generic constraints in a where clause.")
    func testInitializerWithComplexWhereClause() {
        let sut = visitor()
        let node = node("init<T, U>(first: T, second: U) where T: Codable, U: Hashable {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 42),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: 54),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Initializer with a compound constraint in a where clause.")
    func testInitializerWithCompoundWhereClause() {
        let sut = visitor()
        let node = node("init<T>(item: T) where T: Codable & Sendable {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 27),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Sendable",
            fullyQualifiedName: "Sendable",
            kind: .usage,
            location: .init(line: 1, column: 37),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }
}
