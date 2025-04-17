//
//  VariableDeclarationSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 17.04.2025.
//

import Common
import Testing
import SwiftSyntax
import SwiftParser

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
    
    @Test("A let declaration with a simple type.")
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
    
    @Test("A var declaration with a simple type.")
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
    
    @Test("A let declaration with an optional type.")
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
    
    @Test("A var declaration with an optional type.")
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
    
    @Test("A let declaration with an implicitly unwrapped optional.")
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
    
    @Test("An array type in a let declaration.")
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
    
    @Test("An array type in a var declaration.")
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
    
    @Test("A dictionary type in a let declaration.")
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
    
    @Test("A dictionary type in a var declaration.")
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
    
    @Test("A tuple type in a let declaration.")
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
    
    @Test("Variable with an existential type reference.")
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
    
    @Test("Variable with a specified generic type.")
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
    
    @Test("Variable with a complex specified generic type such.")
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
}
