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

    private let visitor = SyntaxSymbolsVisitor()

    public init () {}

    public func analyzeFile(
        at url: URL,
        options: SwiftSymbolsAnalyzerOptions = [.includeDefinitions, .includeUsages]
    ) throws -> SyntaxSymbolsAnalysis {
        let content = try String(contentsOf: url)
        let node = SwiftParser.Parser.parse(source: content)
        let result = visitor.parseSymbols(node: node, fileName: url.lastPathComponent)
        let symbolOccurrences = result.symbolOccurrences
        let imports = result.imports

        let filteredOccurrences = filterStaticallyResolvableUsages(
            from: symbolOccurrences,
            withImports: imports
        )

        return SyntaxSymbolsAnalysis(
            symbols: filteredOccurrences,
            imports: imports
        )
    }

    private func filterStaticallyResolvableUsages(
        from occurrences: Set<SyntaxSymbolOccurrence>,
        withImports imports: Set<String>
    ) -> [SyntaxSymbolOccurrence] {
        var localDefinitions: [String: [SyntaxSymbolOccurrence]] = [:]
        for occ in occurrences where occ.kind.isDefinition {
            localDefinitions[occ.symbolName, default: []].append(occ)
        }

        return occurrences.filter { occ in
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
