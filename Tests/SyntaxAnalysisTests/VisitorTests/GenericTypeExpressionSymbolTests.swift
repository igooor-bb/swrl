//
//  GenericTypeExpressionSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 20.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Generic Type Expressions")
struct GenericTypeExpressionSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test(
        "Generic used in variable declaration.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericInVariable() {
        let sut = visitor()
        let node = node("let cache: Box<Int>")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Box",
            fullyQualifiedName: "Box",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 1, column: 16),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic in variable declaration with specified type.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericInVariableWithSpecifiedType() {
        let sut = visitor()
        let node = node("let cache = Box<Int>()")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Box",
            fullyQualifiedName: "Box",
            kind: .usage,
            location: .init(line: 1, column: 13),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 1, column: 17),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic in function parameter.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericInFunctionParameter() {
        let sut = visitor()
        let node = node("func process(data: Array<String>) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Array",
            fullyQualifiedName: "Array",
            kind: .usage,
            location: .init(line: 1, column: 20),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 26),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic as function return type.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericAsReturnType() {
        let sut = visitor()
        let node = node("func result() -> Result<Data, Error> {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 18),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Data",
            fullyQualifiedName: "Data",
            kind: .usage,
            location: .init(line: 1, column: 25),
            scopeChain: []
        )
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 1, column: 31),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }

    @Test(
        "Generic in initializer.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericInInitializer() {
        let sut = visitor()
        let node = node("init(service: Service<Client>) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Service",
            fullyQualifiedName: "Service",
            kind: .usage,
            location: .init(line: 1, column: 15),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Client",
            fullyQualifiedName: "Client",
            kind: .usage,
            location: .init(line: 1, column: 23),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic in throwing type.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericInTypedThrow() {
        let sut = visitor()
        let node = node("func load() throws(NetworkError<Code>) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "NetworkError",
            fullyQualifiedName: "NetworkError",
            kind: .usage,
            location: .init(line: 1, column: 20),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Code",
            fullyQualifiedName: "Code",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic in typealias.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericInTypealias() {
        let sut = visitor()
        let node = node("typealias Handler = (Result<Value, Error>) -> Void")
        let result = sut.parseSymbols(node: node, fileName: "")

        let typealiasDef = SyntaxSymbolOccurrence(
            symbolName: "Handler",
            fullyQualifiedName: "Handler",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )
        let resultType = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 22),
            scopeChain: []
        )
        let value = SyntaxSymbolOccurrence(
            symbolName: "Value",
            fullyQualifiedName: "Value",
            kind: .usage,
            location: .init(line: 1, column: 29),
            scopeChain: []
        )
        let error = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 1, column: 36),
            scopeChain: []
        )
        let void = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 47),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([typealiasDef, resultType, value, error, void]))
    }

    @Test(
        "Generic with qualified member type.",
        .tags(.symbolKind.usage, .syntaxFeature.generic, .syntaxFeature.memberName)
    )
    func testGenericWithNestedQualifiedType() {
        let sut = visitor()
        let node = node("let list: Array<Container.Payload>")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Array",
            fullyQualifiedName: "Array",
            kind: .usage,
            location: .init(line: 1, column: 11),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Payload",
            fullyQualifiedName: "Container.Payload",
            kind: .usage,
            location: .init(line: 1, column: 17),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Generic where argument is a local generic type parameter.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testGenericWithLocalTypeArgument() {
        let sut = visitor()
        let node = node("func process<T>(input: Array<T>) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Array",
            fullyQualifiedName: "Array",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Generic where local generic type is used inside another generic.",
        .tags(.symbolKind.usage, .syntaxFeature.generic)
    )
    func testNestedGenericWithLocalGenericArgument() {
        let sut = visitor()
        let node = node("func wrap<T>(value: Optional<Array<T>>) {}")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Optional",
            fullyQualifiedName: "Optional",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Array",
            fullyQualifiedName: "Array",
            kind: .usage,
            location: .init(line: 1, column: 30),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Enum case with a generic payload.",
        .tags(.symbolKind.definition, .symbolKind.usage, .syntaxFeature.generic)
    )
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
}
