//
//  FunctionSignatureSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 17.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Function and Method Signatures")
struct FunctionSignatureSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test(
        "Function with a return type.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithReturnType() {
        let sut = visitor()
        let node = node("func fetch() -> Response")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Response",
            fullyQualifiedName: "Response",
            kind: .usage,
            location: .init(line: 1, column: 17),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with a parameter.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithSingleParameter() {
        let sut = visitor()
        let node = node("func process(input: Data)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Data",
            fullyQualifiedName: "Data",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with a variadic parameter.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithVariadicParameter() {
        let sut = visitor()
        let node = node("func sum(values: Int...)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 1, column: 18),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with multiple parameters.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithMultipleParameters() {
        let sut = visitor()
        let node = node("func merge(lhs: Version, rhs: Version)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Version",
            fullyQualifiedName: "Version",
            kind: .usage,
            location: .init(line: 1, column: 17),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Version",
            fullyQualifiedName: "Version",
            kind: .usage,
            location: .init(line: 1, column: 31),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected, expected2]))
    }

    @Test(
        "Function with a tuple parameter.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithTupleParameter() {
        let sut = visitor()
        let node = node("func setPoint(position: (Float, Float))")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Float",
            fullyQualifiedName: "Float",
            kind: .usage,
            location: .init(line: 1, column: 26),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Float",
            fullyQualifiedName: "Float",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with an array parameter.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithArrayParameter() {
        let sut = visitor()
        let node = node("func render(images: [Image])")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Image",
            fullyQualifiedName: "Image",
            kind: .usage,
            location: .init(line: 1, column: 22),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with a dictionary parameter.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithDictionaryParameter() {
        let sut = visitor()
        let node = node("func map(values: [Key: Value])")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Key",
            fullyQualifiedName: "Key",
            kind: .usage,
            location: .init(line: 1, column: 19),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Value",
            fullyQualifiedName: "Value",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with single generic parameter and constraint.",
        .tags(.symbolKind.usage, .syntaxFeature.generic, .syntaxFeature.constraint)
    )
    func testFunctionWithGenericParameterConstraint() {
        let sut = visitor()
        let node = node("func decode<T: Decodable>(value: T)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expectedConstraint = SyntaxSymbolOccurrence(
            symbolName: "Decodable",
            fullyQualifiedName: "Decodable",
            kind: .usage,
            location: .init(line: 1, column: 16),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expectedConstraint]))
    }

    @Test(
        "Function with multiple generic parameters and constraints.",
        .tags(.symbolKind.usage, .syntaxFeature.generic, .syntaxFeature.constraint)
    )
    func testFunctionWithMultipleGenericParameterConstraint() {
        let sut = visitor()
        let node = node("func decode<T: Decodable, Q: Encodable>(value: T, into: inout Q)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Decodable",
            fullyQualifiedName: "Decodable",
            kind: .usage,
            location: .init(line: 1, column: 16),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Encodable",
            fullyQualifiedName: "Encodable",
            kind: .usage,
            location: .init(line: 1, column: 30),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with compound generic parameter constraints.",
        .tags(.symbolKind.usage, .syntaxFeature.generic, .syntaxFeature.compoundConstraint)
    )
    func testFunctionWithMultipleParameterGenericConstraints() {
        let sut = visitor()
        let node = node("func process<T: Codable & Equatable>(value: T)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 17),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Equatable",
            fullyQualifiedName: "Equatable",
            kind: .usage,
            location: .init(line: 1, column: 27),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with a closure parameter.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithClosureParameter() {
        let sut = visitor()
        let node = node("func run(completion: () -> Void)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 28),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function returning a closure.",
        .tags(.symbolKind.usage)
    )
    func testFunctionReturningClosure() {
        let sut = visitor()
        let node = node("func makeHandler() -> () -> Output")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Output",
            fullyQualifiedName: "Output",
            kind: .usage,
            location: .init(line: 1, column: 29),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with a closure parameter that accepts a type.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithClosureParameterWithInput() {
        let sut = visitor()
        let node = node("func handle(callback: (Error) -> Void)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 34),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with a generic constraint in where clause.",
        .tags(
            .symbolKind.usage,
            .syntaxFeature.generic,
            .syntaxFeature.constraint,
            .syntaxFeature.whereClause
        )
    )
    func testFunctionWithWhereClause() {
        let sut = visitor()
        let node = node("func sync<T>(input: T) where T: Codable")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with multiple generic constraints in where clause.",
        .tags(
            .symbolKind.usage,
            .syntaxFeature.generic,
            .syntaxFeature.constraint,
            .syntaxFeature.whereClause
        )
    )
    func testFunctionWithComplexWhereClause() {
        let sut = visitor()
        let node = node("func sync<T, Q>(input: T, queue: Q) where T: Codable, Q: Sendable")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 46),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Sendable",
            fullyQualifiedName: "Sendable",
            kind: .usage,
            location: .init(line: 1, column: 58),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with a compound where clause.",
        .tags(
            .symbolKind.usage,
            .syntaxFeature.generic,
            .syntaxFeature.compoundConstraint,
            .syntaxFeature.whereClause
        )
    )
    func testFunctionWithCompoundWhereClause() {
        let sut = visitor()
        let node = node("func sync<T>(input: T) where T: Codable & Hashable")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: 43),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Function with a return type using opaque result type.",
        .tags(.symbolKind.usage, .syntaxFeature.opaque)
    )
    func testFunctionWithOpaqueReturnType() {
        let sut = visitor()
        let node = node("func render() -> some View")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "View",
            fullyQualifiedName: "View",
            kind: .usage,
            location: .init(line: 1, column: 23),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with an existential type parameter.",
        .tags(.symbolKind.usage, .syntaxFeature.existential)
    )
    func testFunctionWithExistentialParameter() {
        let sut = visitor()
        let node = node("func resolve(service: any Service)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Service",
            fullyQualifiedName: "Service",
            kind: .usage,
            location: .init(line: 1, column: 27),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Function with a typed throwing error.",
        .tags(.symbolKind.usage)
    )
    func testFunctionWithTypedThrowingError() {
        let sut = visitor()
        let node = node("func risky() throws(MyError) -> Void")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "MyError",
            fullyQualifiedName: "MyError",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected, expected2]))
    }
}
