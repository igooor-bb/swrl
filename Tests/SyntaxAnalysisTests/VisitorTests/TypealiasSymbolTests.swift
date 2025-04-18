//
//  TypealiasSymbolTests.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 18.04.2025.
//

import Common
import Testing
import SwiftSyntax
import SwiftParser

@testable import SyntaxAnalysis

@Suite("Typealiases")
struct TypealiasSymbolTests {
    
    // MARK: - Setup
    
    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }
    
    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }
    
    // MARK: - Tests
    
    @Test("Typealias to a simple type.")
    func testTypealiasToSimpleType() {
        let sut = visitor()
        let node = node("typealias ID = String")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "ID",
            fullyQualifiedName: "ID",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
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
    
    @Test("Typealias to a complex type.")
    func testTypealiasToComplexType() {
        let sut = visitor()
        let node = node("typealias StringMap = [String: Value]")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "StringMap",
            fullyQualifiedName: "StringMap",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "String",
            fullyQualifiedName: "String",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Value",
            fullyQualifiedName: "Value",
            kind: .usage,
            location: .init(line: 1, column: 32),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
    
    @Test("Typealias to a function type.")
    func testTypealiasToFunctionType() {
        let sut = visitor()
        let node = node("typealias Completion = (Result) -> Void")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Completion",
            fullyQualifiedName: "Completion",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Result",
            fullyQualifiedName: "Result",
            kind: .usage,
            location: .init(line: 1, column: 25),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Void",
            fullyQualifiedName: "Void",
            kind: .usage,
            location: .init(line: 1, column: 36),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
    
    @Test("Typealias with generic parameters and constraints.")
    func testGenericTypealiasWithConstraint() {
        let sut = visitor()
        let node = node("typealias Filter<T: Hashable> = (T) -> Bool")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Filter",
            fullyQualifiedName: "Filter",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )
        
        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Bool",
            fullyQualifiedName: "Bool",
            kind: .usage,
            location: .init(line: 1, column: 40),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
    
    @Test("Typealias with a where clause.")
    func testTypealiasWithWhereClause() {
        let sut = visitor()
        let node = node("typealias Filter<T> = (T) -> Bool where T: Equatable")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Filter",
            fullyQualifiedName: "Filter",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Bool",
            fullyQualifiedName: "Bool",
            kind: .usage,
            location: .init(line: 1, column: 30),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Equatable",
            fullyQualifiedName: "Equatable",
            kind: .usage,
            location: .init(line: 1, column: 44),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
    
    @Test("Typealias with multiple generic constraints.")
    func testTypealiasWithMultipleGenericConstraints() {
        let sut = visitor()
        let node = node("typealias Transform<T: Decodable, U: Encodable> = (T) -> U")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Transform",
            fullyQualifiedName: "Transform",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Decodable",
            fullyQualifiedName: "Decodable",
            kind: .usage,
            location: .init(line: 1, column: 24),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Encodable",
            fullyQualifiedName: "Encodable",
            kind: .usage,
            location: .init(line: 1, column: 38),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
    
    @Test("Typealias with compound generic constraint.")
    func testTypealiasWithCompoundGenericConstraint() {
        let sut = visitor()
        let node = node("typealias Storable<T: Codable & Hashable> = (T) -> Bool")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Storable",
            fullyQualifiedName: "Storable",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 23),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Hashable",
            fullyQualifiedName: "Hashable",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )
        
        let expected4 = SyntaxSymbolOccurrence(
            symbolName: "Bool",
            fullyQualifiedName: "Bool",
            kind: .usage,
            location: .init(line: 1, column: 52),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3, expected4]))
    }
    
    @Test("Typealias with compound constraint in a where clause.")
    func testTypealiasWithCompoundWhereClause() {
        let sut = visitor()
        let node = node("typealias Filter<T> = (T) -> Bool where T: Codable & Sendable")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Filter",
            fullyQualifiedName: "Filter",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Bool",
            fullyQualifiedName: "Bool",
            kind: .usage,
            location: .init(line: 1, column: 30),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .usage,
            location: .init(line: 1, column: 44),
            scopeChain: []
        )
        
        let expected4 = SyntaxSymbolOccurrence(
            symbolName: "Sendable",
            fullyQualifiedName: "Sendable",
            kind: .usage,
            location: .init(line: 1, column: 54),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3, expected4]))
    }
    
    @Test("Typealias to a protocol composition.")
    func testTypealiasToProtocolComposition() {
        let sut = visitor()
        let node = node("typealias Codable = Encodable & Decodable")
        let result = sut.parseSymbols(node: node, fileName: "")
        
        let expected1 = SyntaxSymbolOccurrence(
            symbolName: "Codable",
            fullyQualifiedName: "Codable",
            kind: .definition(.typealias),
            location: .init(line: 1, column: 1),
            scopeChain: []
        )

        let expected2 = SyntaxSymbolOccurrence(
            symbolName: "Encodable",
            fullyQualifiedName: "Encodable",
            kind: .usage,
            location: .init(line: 1, column: 21),
            scopeChain: []
        )
        
        let expected3 = SyntaxSymbolOccurrence(
            symbolName: "Decodable",
            fullyQualifiedName: "Decodable",
            kind: .usage,
            location: .init(line: 1, column: 33),
            scopeChain: []
        )
        
        #expect(result.symbolOccurrences == Set([expected1, expected2, expected3]))
    }
}
