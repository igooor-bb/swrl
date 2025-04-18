//
//  EnumDeclarationSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 18.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Enum Declarations")
struct EnumDeclarationSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test("Enum case with no associated values.")
    func testEnumWithSimpleCase() {
        let sut = visitor()
        let node = node("""
        enum Status {
            case success
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Status",
            fullyQualifiedName: "Status",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test("Enum case with an associated value.")
    func testEnumWithAssociatedType() {
        let sut = visitor()
        let node = node("""
        enum Result {
            case success(data: Data)
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Data",
            fullyQualifiedName: "Data",
            kind: .usage,
            location: .init(line: 2, column: 24),
            scopeChain: ["Result"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Enum case with a tuple type.")
    func testEnumWithTuplePayload() {
        let sut = visitor()
        let node = node("""
        enum Values {
            case pair((Int, Int))
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Values",
            fullyQualifiedName: "Values",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 2, column: 16),
            scopeChain: ["Values"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 2, column: 21),
            scopeChain: ["Values"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test("Enum case with a generic payload.")
    func testEnumWithGenericAssociatedType() {
        let sut = visitor()
        let node = node("""
        enum State {
            case data(Result<String, Error>)
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "State",
            fullyQualifiedName: "State",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 2, column: 15),
            scopeChain: ["State"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 2, column: 22),
            scopeChain: ["State"]
        )

        let expected4 = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 2, column: 30),
            scopeChain: ["State"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3, expected4]))
    }

    @Test("Enum case with multiple associated values.")
    func testEnumWithMultipleAssociatedValues() {
        let sut = visitor()
        let node = node("""
        enum UserEvent {
            case clicked(x: Int, y: Int)
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "UserEvent",
            fullyQualifiedName: "UserEvent",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 2, column: 21),
            scopeChain: ["UserEvent"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 2, column: 29),
            scopeChain: ["UserEvent"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test("Indirect enum with self-referencing associated values.")
    func testIndirectEnumWithSelfRecursiveCase() {
        let sut = visitor()
        let node = node("""
        indirect enum Tree {
            case node(left: Tree, right: Tree)
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Tree",
            fullyQualifiedName: "Tree",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Tree",
            fullyQualifiedName: "Tree",
            kind: .usage,
            location: .init(line: 2, column: 21),
            scopeChain: ["Tree"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Tree",
            fullyQualifiedName: "Tree",
            kind: .usage,
            location: .init(line: 2, column: 34),
            scopeChain: ["Tree"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
}
