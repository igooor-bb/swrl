//
//  ProtocolDeclarationSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 18.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Protocol Declarations")
struct ProtocolDeclarationSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test("Protocol with unbounded associated type.")
    func testProtocolWithUnboundedAssociatedType() {
        let sut = visitor()
        let node = node("""
        protocol Basic {
            associatedtype Element
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Basic",
            fullyQualifiedName: "Basic",
            kind: .definition(.protocol),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Element",
            fullyQualifiedName: "Basic.Element",
            kind: .definition(.associatedType),
            location: .init(line: 2, column: 5),
            scopeChain: ["Basic"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test("Protocol with associated type with constraint.")
    func testProtocolWithAssociatedTypeConstraint() {
        let sut = visitor()
        let node = node("""
        protocol Identifiable {
            associatedtype ID: Hashable
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Identifiable",
            fullyQualifiedName: "Identifiable",
            kind: .definition(.protocol),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "ID",
            fullyQualifiedName: "Identifiable.ID",
            kind: .definition(.associatedType),
            location: .init(line: 2, column: 5),
            scopeChain: ["Identifiable"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Identifiable.Hashable",
            kind: .usage,
            location: .init(line: 2, column: 24),
            scopeChain: ["Identifiable"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test("Protocol with associated type with multiple constraints.")
    func testProtocolWithAssociatedTypeMultipleConstraints() {
        let sut = visitor()
        let node = node("""
        protocol Serializable {
            associatedtype Value where Value: Encodable, Value: Hashable
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Serializable",
            fullyQualifiedName: "Serializable",
            kind: .definition(.protocol),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Value",
            fullyQualifiedName: "Serializable.Value",
            kind: .definition(.associatedType),
            location: .init(line: 2, column: 5),
            scopeChain: ["Serializable"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Encodable",
            fullyQualifiedName: "Serializable.Encodable",
            kind: .usage,
            location: .init(line: 2, column: 39),
            scopeChain: ["Serializable"]
        )

        let expected4 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Serializable.Hashable",
            kind: .usage,
            location: .init(line: 2, column: 57),
            scopeChain: ["Serializable"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3, expected4]))
    }

    @Test("Protocol with associated type with compound constraint.")
    func testProtocolWithAssociatedTypeCompoundConstraint() {
        let sut = visitor()
        let node = node("""
        protocol Cacheable {
            associatedtype Key where Key: Hashable & Sendable
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Cacheable",
            fullyQualifiedName: "Cacheable",
            kind: .definition(.protocol),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Key",
            fullyQualifiedName: "Cacheable.Key",
            kind: .definition(.associatedType),
            location: .init(line: 2, column: 5),
            scopeChain: ["Cacheable"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Cacheable.Hashable",
            kind: .usage,
            location: .init(line: 2, column: 35),
            scopeChain: ["Cacheable"]
        )

        let expected4 = SyntaxSymbolOccurrence(
            symbolName: "Sendable",
            fullyQualifiedName: "Cacheable.Sendable",
            kind: .usage,
            location: .init(line: 2, column: 46),
            scopeChain: ["Cacheable"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3, expected4]))
    }

    @Test("Protocol with associated type with default value.")
    func testProtocolWithAssociatedTypeDefaultValue() {
        let sut = visitor()
        let node = node("""
        protocol Defaultable {
            associatedtype ID = UUID
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Defaultable",
            fullyQualifiedName: "Defaultable",
            kind: .definition(.protocol),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "ID",
            fullyQualifiedName: "Defaultable.ID",
            kind: .definition(.associatedType),
            location: .init(line: 2, column: 5),
            scopeChain: ["Defaultable"]
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "UUID",
            fullyQualifiedName: "Defaultable.UUID",
            kind: .usage,
            location: .init(line: 2, column: 25),
            scopeChain: ["Defaultable"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
}
