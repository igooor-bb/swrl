//
//  PropertyWrapperSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 28.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Property Wrapper Usages")
struct PropertyWrapperSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test(
        "Simple property wrapper usage.",
        .tags(.symbolKind.usage)
    )
    func testSimplePropertyWrapperUsage() {
        let sut = visitor()
        let node = node("""
        @State var title: String
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let wrapper = SyntaxSymbolOccurrence(
            symbolName: "State",
            fullyQualifiedName: "State",
            kind: .usage,
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let string = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 19),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([wrapper, string]))
    }

    @Test(
        "Multiple property wrappers on one property.",
        .tags(.symbolKind.usage)
    )
    func testMultiplePropertyWrappers() {
        let sut = visitor()
        let node = node("""
        @State @Published var count: Int
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let wrapper1 = SyntaxSymbolOccurrence(
            symbolName: "State",
            fullyQualifiedName: "State",
            kind: .usage,
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let wrapper2 = SyntaxSymbolOccurrence(
            symbolName: "Published",
            fullyQualifiedName: "Published",
            kind: .usage,
            location: .init(line: 1, column: 8),
            scopeChain: []
        )

        let int = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 1, column: 30),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([wrapper1, wrapper2, int]))
    }

    @Test(
        "Property wrapper with closure parameter.",
        .tags(.symbolKind.usage)
    )
    func testPropertyWrapperWithClosure() {
        let sut = visitor()
        let node = node("""
        @CustomWrapper(transform: { $0.uppercased() }) var name: String
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let wrapper = SyntaxSymbolOccurrence(
            symbolName: "CustomWrapper",
            fullyQualifiedName: "CustomWrapper",
            kind: .usage,
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let string = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 58),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([wrapper, string]))
    }
}
