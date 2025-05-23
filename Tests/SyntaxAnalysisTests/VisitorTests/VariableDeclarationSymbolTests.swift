//
//  VariableDeclarationSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 17.04.2025.
//

import Common
import SwiftParser
import SwiftSyntax
import Testing

@testable import SyntaxAnalysis

@Suite("Variable and Constant Declarations")
struct VariableDeclarationSymbolTests {

    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test(
        "A let declaration with a simple type.",
        .tags(.symbolKind.usage)
    )
    func testLetWithSingleType() {
        let sut = visitor()
        let node = node("let x: UserID")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "UserID",
            fullyQualifiedName: "UserID",
            kind: .usage,
            location: .init(line: 1, column: 8),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "A var declaration with a simple type.",
        .tags(.symbolKind.usage)
    )
    func testVarWithSingleType() {
        let sut = visitor()
        let node = node("var y: Int")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Int",
            fullyQualifiedName: "Int",
            kind: .usage,
            location: .init(line: 1, column: 8),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "A let declaration with an optional type.",
        .tags(.symbolKind.usage)
    )
    func testLetWithOptionalType() {
        let sut = visitor()
        let node = node("let optional: CustomType?")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "CustomType",
            fullyQualifiedName: "CustomType",
            kind: .usage,
            location: .init(line: 1, column: 15),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "A var declaration with an optional type.",
        .tags(.symbolKind.usage)
    )
    func testVarWithOptionalType() {
        let sut = visitor()
        let node = node("var item: CustomType?")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "CustomType",
            fullyQualifiedName: "CustomType",
            kind: .usage,
            location: .init(line: 1, column: 11),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "A let declaration with an implicitly unwrapped optional.",
        .tags(.symbolKind.usage)
    )
    func testLetWithImplicitlyUnwrappedOptional() {
        let sut = visitor()
        let node = node("let label: CustomType!")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "CustomType",
            fullyQualifiedName: "CustomType",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "An array type in a let declaration.",
        .tags(.symbolKind.usage)
    )
    func testLetWithArrayType() {
        let sut = visitor()
        let node = node("let items: [Product]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Product",
            fullyQualifiedName: "Product",
            kind: .usage,
            location: .init(line: 1, column: 13),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "An array type in a var declaration.",
        .tags(.symbolKind.usage)
    )
    func testVarWithArrayType() {
        let sut = visitor()
        let node = node("var results: [Result]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 15),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "A dictionary type in a let declaration.",
        .tags(.symbolKind.usage)
    )
    func testLetWithDictionaryType() {
        let sut = visitor()
        let node = node("let dict: [Key: Value]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expectedKey = SyntaxSymbolOccurrence(
            symbolName: "Key",
            fullyQualifiedName: "Key",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        let expectedValue = SyntaxSymbolOccurrence(
            symbolName: "Value",
            fullyQualifiedName: "Value",
            kind: .usage,
            location: .init(line: 1, column: 17),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expectedKey, expectedValue]))
    }

    @Test(
        "A dictionary type in a var declaration.",
        .tags(.symbolKind.usage)
    )
    func testVarWithDictionaryType() {
        let sut = visitor()
        let node = node("var lookup: [ID: Name]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expectedKey = SyntaxSymbolOccurrence(
            symbolName: "ID",
            fullyQualifiedName: "ID",
            kind: .usage,
            location: .init(line: 1, column: 14),
            scopeChain: []
        )

        let expectedValue = SyntaxSymbolOccurrence(
            symbolName: "Name",
            fullyQualifiedName: "Name",
            kind: .usage,
            location: .init(line: 1, column: 18),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expectedKey, expectedValue]))
    }

    @Test(
        "A tuple type in a let declaration.",
        .tags(.symbolKind.usage)
    )
    func testLetWithTupleOfTypes() {
        let sut = visitor()
        let node = node("let config: (Bool, Settings)")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Bool",
            fullyQualifiedName: "Bool",
            kind: .usage,
            location: .init(line: 1, column: 14),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Settings",
            fullyQualifiedName: "Settings",
            kind: .usage,
            location: .init(line: 1, column: 20),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Variable with an existential type reference.",
        .tags(.symbolKind.usage)
    )
    func testVariableWithExistentialType() {
        let sut = visitor()
        let node = node("let service: any Service")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Service",
            fullyQualifiedName: "Service",
            kind: .usage,
            location: .init(line: 1, column: 18),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Variable with a specified generic type.",
        .tags(.symbolKind.usage)
    )
    func testVariableWithGenericType() {
        let sut = visitor()
        let node = node("let ids: Set<String>")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Set",
            fullyQualifiedName: "Set",
            kind: .usage,
            location: .init(line: 1, column: 10),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 14),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Variable with a complex specified generic type.",
        .tags(.symbolKind.usage)
    )
    func testVariableWithComplexGenericType() {
        let sut = visitor()
        let node = node("let outcome: Result<String, Error>")
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

    @Test(
        "Variable with a member type.",
        .tags(.symbolKind.usage, .syntaxFeature.memberName)
    )
    func testVariableWithMemberType() {
        let sut = visitor()
        let node = node("let user: User.Profile")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Profile",
            fullyQualifiedName: "User.Profile",
            kind: .usage,
            location: .init(line: 1, column: 11),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Variable with an array of member types.",
        .tags(.symbolKind.usage)
    )
    func testVariableWithArrayOfMemberTypes() {
        let sut = visitor()
        let node = node("let users: [User.Profile]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "Profile",
            fullyQualifiedName: "User.Profile",
            kind: .usage,
            location: .init(line: 1, column: 13),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Variable with a dictionary of member types.",
        .tags(.symbolKind.usage, .syntaxFeature.memberName)
    )
    func testVariableWithDictionaryOfMemberTypes() {
        let sut = visitor()
        let node = node("let userDict: [String: User.Profile]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Profile",
            fullyQualifiedName: "User.Profile",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 16),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Variable with a closure type.",
        .tags(.symbolKind.usage)
    )
    func testVariableWithClosureType() {
        let sut = visitor()
        let node = node("let completion: (Result<String, Error>) -> Void")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 18),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 25),
            scopeChain: []
        )

        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Error",
            fullyQualifiedName: "Error",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )

        let expected4 = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 44),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3, expected4]))
    }

    @Test(
        "Variable with a closure with member type.",
        .tags(.symbolKind.usage, .syntaxFeature.memberName)
    )
    func testVariableWithClosureWithMemberType() {
        let sut = visitor()
        let node = node("let handler: (User.Profile) -> Void")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Profile",
            fullyQualifiedName: "User.Profile",
            kind: .usage,
            location: .init(line: 1, column: 15),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 32),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Variable initialized with a custom type.",
        .tags(.symbolKind.usage)
    )
    func testVariableInitializationWithCustomType() {
        let sut = visitor()
        let node = node("let user = User(name: \"John\")")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected]))
    }

    @Test(
        "Variable initialized with an array of custom types.",
        .tags(.symbolKind.usage)
    )
    func testVariableInitializationWithArrayOfCustomTypes() {
        let sut = visitor()
        let node = node("let users = [User(name: \"John\"), User(name: \"Jane\")]")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 14),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 34),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Variable initialized with custom type with custom type in parameters.",
        .tags(.symbolKind.usage)
    )
    func testVariableInitializationWithCustomTypeWithCustomTypeInParameters() {
        let sut = visitor()
        let node = node("let user = User(profile: Profile(name: \"John\"))")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "User",
            fullyQualifiedName: "User",
            kind: .usage,
            location: .init(line: 1, column: 12),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Profile",
            fullyQualifiedName: "Profile",
            kind: .usage,
            location: .init(line: 1, column: 26),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }

    @Test(
        "Variable initialized with an existential type.",
        .tags(.symbolKind.usage, .syntaxFeature.existential)
    )
    func testVariableInitializationWithExistentialType() {
        let sut = visitor()
        let node = node("let service: any Service = MyService()")
        let result = sut.parseSymbols(node: node, fileName: "")

        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Service",
            fullyQualifiedName: "Service",
            kind: .usage,
            location: .init(line: 1, column: 18),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "MyService",
            fullyQualifiedName: "MyService",
            kind: .usage,
            location: .init(line: 1, column: 28),
            scopeChain: []
        )

        #expect(result.symbolOccurrences == Set([expected1, expected2]))
    }
}
