//
//  SyntaxSymbolOccurrence.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 08.04.2025.
//

import Foundation

public struct SyntaxSymbolOccurrence: Hashable {
    public var id: String { String(hashValue) }
    public let symbolName: String
    public let fullyQualifiedName: String?
    public let kind: SymbolOccurrenceKind
    public let location: SyntaxSymbolLocation
    public let scopeChain: [String]

    public init(
        symbolName: String,
        fullyQualifiedName: String?,
        kind: SymbolOccurrenceKind,
        location: SyntaxSymbolLocation,
        scopeChain: [String]
    ) {
        self.symbolName = symbolName
        self.fullyQualifiedName = fullyQualifiedName
        self.kind = kind
        self.location = location
        self.scopeChain = scopeChain
    }
}

public enum SymbolDefinitionKind: String, Hashable {
    case `actor`
    case `class`
    case `protocol`
    case `struct`
    case `enum`
    case `typealias`
    case `macro`
    case unknown
}

public enum SymbolOccurrenceKind: Hashable {
    case definition(SymbolDefinitionKind)
    case usage

    public var isDefinition: Bool {
        if case .definition = self {
            return true
        }
        return false
    }

    public var isUsage: Bool {
        if case .usage = self {
            return true
        }
        return false
    }
}

public struct SyntaxSymbolLocation: Hashable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}
