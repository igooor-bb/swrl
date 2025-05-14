//
//  SyntaxSymbolsAnalyzer.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 24.03.2025.
//

import Common
import Foundation
import SwiftParser
import SwiftSyntax

public final class SyntaxSymbolsAnalyzer {

    private static let swiftBuiltInTypes: Set<String> = [
        "Bool", "String", "Int", "Double", "Float", "Any", "AnyObject", "AnyHashable", "Never", "Optional", "Void"
    ]

    // MARK: Properties

    public init () {}

    // MARK: Analysis

    public func analyzeFile(
        at url: URL,
        options: SwiftSymbolsAnalyzerOptions = .default
    ) throws -> SyntaxSymbolsAnalysis {
        let content = try String(contentsOf: url)
        let node = SwiftParser.Parser.parse(source: content)
        let visitor = SyntaxSymbolsVisitor()
        let result = visitor.parseSymbols(node: node, fileName: url.lastPathComponent)
        let imports = result.imports
        var symbolOccurrences = result.symbolOccurrences

        filterOccurrences(&symbolOccurrences, using: options)
        filterStaticallyResolvableOccurrences(&symbolOccurrences, withImports: imports)
        return SyntaxSymbolsAnalysis(symbols: Array(symbolOccurrences), imports: imports)
    }

    // MARK: Evaluation

    private func filterOccurrences(
        _ occurrences: inout Set<SyntaxSymbolOccurrence>,
        using options: SwiftSymbolsAnalyzerOptions
    ) {
        occurrences = occurrences.filter {
            let isDefinition = $0.kind.isDefinition && options.contains(.includeDefinitions)
            let isUsage = $0.kind.isUsage && options.contains(.includeUsages)
            let isBuiltIn = Self.swiftBuiltInTypes.contains($0.symbolName)
            return (isUsage || isDefinition) && !isBuiltIn
        }
    }

    private func filterStaticallyResolvableOccurrences(
        _ occurrences: inout Set<SyntaxSymbolOccurrence>,
        withImports imports: Set<String>
    ) {
        var localDefinitions: [String: [SyntaxSymbolOccurrence]] = [:]
        for occ in occurrences where occ.kind.isDefinition {
            localDefinitions[occ.symbolName, default: []].append(occ)
        }

        occurrences = occurrences.filter { occ in
            // Always keep definitions.
            if occ.kind.isDefinition {
                return true
            }

            if let fqn = occ.fullyQualifiedName,
               let firstComponent = fqn.components(separatedBy: ".").first,
               imports.contains(firstComponent) {
                if let defs = localDefinitions[occ.symbolName] {
                    // If any local definition's scope chain is a prefix of the usage's,
                    // then the usage is considered local.
                    for def in defs where isPrefix(defChain: def.scopeChain, of: occ.scopeChain) {
                        return false
                    }
                }
                // If no local definition is found, treat the usage as external.
                return true
            }

            // For usage occurrences without external module qualification,
            // if there is any local definition for the same name whose scope chain is a prefix, filter it out.
            if let defs = localDefinitions[occ.symbolName] {
                for def in defs where isPrefix(defChain: def.scopeChain, of: occ.scopeChain) {
                    return false
                }
            }

            return true
        }
    }

    private func isPrefix(defChain: [String], of usageChain: [String]) -> Bool {
        guard defChain.count <= usageChain.count else { return false }
        return defChain == Array(usageChain.prefix(defChain.count))
    }
}
