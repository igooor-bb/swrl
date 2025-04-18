//
//  NestedTypeSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 18.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Nested Types and Usage")
struct NestedTypeSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test("Nested struct inside a struct.")
    func testNestedStructDefinition() {
        let sut = visitor()
        let node = node("""
        struct Outer {
            struct Inner {}
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let outer = SyntaxSymbolOccurrence(
            symbolName: "Outer",
            fullyQualifiedName: "Outer",
            kind: .definition(.struct),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let inner = SyntaxSymbolOccurrence(
            symbolName: "Inner",
            fullyQualifiedName: "Outer.Inner",
            kind: .definition(.struct),
            location: .init(line: 2, column: 5),
            scopeChain: ["Outer"]
        )

        #expect(result.symbolOccurrences == Set([outer, inner]))
    }

    @Test("Usage of nested type.")
    func testUsageOfNestedType() {
        let sut = visitor()
        let node = node("""
        struct Container {
            struct Payload {}
            let value: Payload
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let container = SyntaxSymbolOccurrence(
            symbolName: "Container",
            fullyQualifiedName: "Container",
            kind: .definition(.struct),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let payload = SyntaxSymbolOccurrence(
            symbolName: "Payload",
            fullyQualifiedName: "Container.Payload",
            kind: .definition(.struct),
            location: .init(line: 2, column: 5),
            scopeChain: ["Container"]
        )

        let usage = SyntaxSymbolOccurrence(
            symbolName: "Payload",
            fullyQualifiedName: "Payload",
            kind: .usage,
            location: .init(line: 3, column: 16),
            scopeChain: ["Container"]
        )

        #expect(result.symbolOccurrences == Set([container, payload, usage]))
    }

    @Test("Nested type usage inside nested method.")
    func testNestedTypeUsedInMethodScope() {
        let sut = visitor()
        let node = node("""
        struct Box {
            struct Item {}

            func make() -> Item {
                Item()
            }
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let box = SyntaxSymbolOccurrence(
            symbolName: "Box",
            fullyQualifiedName: "Box",
            kind: .definition(.struct),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let item = SyntaxSymbolOccurrence(
            symbolName: "Item",
            fullyQualifiedName: "Box.Item",
            kind: .definition(.struct),
            location: .init(line: 2, column: 5),
            scopeChain: ["Box"]
        )

        let returnType = SyntaxSymbolOccurrence(
            symbolName: "Item",
            fullyQualifiedName: "Item",
            kind: .usage,
            location: .init(line: 4, column: 20),
            scopeChain: ["Box"]
        )

        let initializerCall = SyntaxSymbolOccurrence(
            symbolName: "Item",
            fullyQualifiedName: "Item",
            kind: .usage,
            location: .init(line: 5, column: 9),
            scopeChain: ["Box", "make():Item"]
        )

        #expect(result.symbolOccurrences == Set([box, item, returnType, initializerCall]))
    }

    @Test("Deeply nested type declaration.")
    func testDeeplyNestedTypeDefinition() {
        let sut = visitor()
        let node = node("""
        struct A {
            struct B {
                struct C {}
            }
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let a = SyntaxSymbolOccurrence(
            symbolName: "A",
            fullyQualifiedName: "A",
            kind: .definition(.struct),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let b = SyntaxSymbolOccurrence(
            symbolName: "B",
            fullyQualifiedName: "A.B",
            kind: .definition(.struct),
            location: .init(line: 2, column: 5),
            scopeChain: ["A"]
        )

        let c = SyntaxSymbolOccurrence(
            symbolName: "C",
            fullyQualifiedName: "A.B.C",
            kind: .definition(.struct),
            location: .init(line: 3, column: 9),
            scopeChain: ["A", "B"]
        )

        #expect(result.symbolOccurrences == Set([a, b, c]))
    }

    @Test("Usage of nested type inside an enum.")
    func testNestedUsageInsideEnum() {
        let sut = visitor()
        let node = node("""
        enum Kind {
            struct Payload {}
            case boxed(Payload)
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let kind = SyntaxSymbolOccurrence(
            symbolName: "Kind",
            fullyQualifiedName: "Kind",
            kind: .definition(.enum),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let payloadDef = SyntaxSymbolOccurrence(
            symbolName: "Payload",
            fullyQualifiedName: "Kind.Payload",
            kind: .definition(.struct),
            location: .init(line: 2, column: 5),
            scopeChain: ["Kind"]
        )

        let payloadUsage = SyntaxSymbolOccurrence(
            symbolName: "Payload",
            fullyQualifiedName: "Payload",
            kind: .usage,
            location: .init(line: 3, column: 16),
            scopeChain: ["Kind"]
        )

        #expect(result.symbolOccurrences == Set([kind, payloadDef, payloadUsage]))
    }

    @Test("Usage of nested type across sibling scopes.")
    func testCrossScopeUsage() {
        let sut = visitor()
        let node = node("""
        struct Container {
            struct Data {}
        }

        struct Usage {
            let value: Container.Data
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let container = SyntaxSymbolOccurrence(
            symbolName: "Container",
            fullyQualifiedName: "Container",
            kind: .definition(.struct),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let data = SyntaxSymbolOccurrence(
            symbolName: "Data",
            fullyQualifiedName: "Container.Data",
            kind: .definition(.struct),
            location: .init(line: 2, column: 5),
            scopeChain: ["Container"]
        )

        let usage = SyntaxSymbolOccurrence(
            symbolName: "Data",
            fullyQualifiedName: "Container.Data",
            kind: .usage,
            location: .init(line: 6, column: 16),
            scopeChain: ["Usage"]
        )

        let usageStruct = SyntaxSymbolOccurrence(
            symbolName: "Usage",
            fullyQualifiedName: "Usage",
            kind: .definition(.struct),
            location: .init(line: 5, column: 1),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([container, data, usageStruct, usage]))
    }
}
