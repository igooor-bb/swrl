//
//  ExpressionTypeUsageSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 20.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Type Usages in Expressions")
struct ExpressionTypeUsageSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test(
        "Type used in initialization expression.",
        .tags(.symbolKind.usage, .semantics.expression)
    )
    func testTypeUsedInInitCall() {
        let sut = visitor()
        let node = node("let user = User()")
        let result = sut.parseSymbols(node: node, fileName: "")

        let userType = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([userType]))
    }

    @Test(
        "Type used in cast expression.",
        .tags(.symbolKind.usage, .semantics.expression)
    )
    func testTypeUsedInCast() {
        let sut = visitor()
        let node = node("""
        let obj = Object()
        let person = obj as? Person"
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Object",
            fullyQualifiedName: "Object",
            kind: .usage,
            location: .init(line: 1, column: 11),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Person",
            fullyQualifiedName: "Person",
            kind: .usage,
            location: .init(line: 2, column: 22),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Type used in generic init expression.",
        .tags(.symbolKind.usage, .syntaxFeature.generic, .semantics.expression)
    )
    func testTypeUsedInGenericInit() {
        let sut = visitor()
        let node = node("let result = Result<String, Error>.success(\"OK\")")
        let result = sut.parseSymbols(node: node, fileName: "")

        let resultType = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 14),
            scopeChain: []
        )

        let stringType = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )

        let errorType = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 1, column: 29),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([resultType, stringType, errorType]))
    }

    @Test(
        "Type used in throw expression.",
        .tags(.symbolKind.usage, .semantics.expression)
    )
    func testTypeUsedInThrowExpression() {
        let sut = visitor()
        let node = node("""
        func fail() throws {
            throw NetworkError(code: 404)
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let errorType = SyntaxSymbolOccurrence(
            symbolName: "NetworkError",
            fullyQualifiedName: "NetworkError",
            kind: .usage,
            location: .init(line: 2, column: 11),
            scopeChain: ["fail():Void"]
        )

        #expect(result.symbolOccurrences == Set([errorType]))
    }

    @Test(
        "Type used in return expression.",
        .tags(.symbolKind.usage, .semantics.expression)
    )
    func testTypeUsedInReturn() {
        let sut = visitor()
        let node = node("""
        func make() -> User {
            return User()
        }
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 16),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 2, column: 12),
            scopeChain: ["make():User"]
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Type used in key path expression.",
        .tags(.symbolKind.usage, .semantics.expression)
    )
    func testTypeUsedInKeyPath() {
        let sut = visitor()
        let node = node("let key = \\User.name")
        let result = sut.parseSymbols(node: node, fileName: "")

        let userType = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([userType]))
    }
}
