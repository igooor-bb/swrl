//
//  SyntaxSymbolsAnalyzer+Extensions.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 07.04.2025.
//

import Common
import Foundation
import SymbolsResolver
import SyntaxAnalysis

extension SyntaxSymbolsAnalyzer: FrameworkDefinitionsAnalyzer {
    public func findDefinitions(at url: URL) -> [SyntaxSymbolOccurrence] {
        do {
            let result = try analyzeFile(at: url, options: .includeDefinitions)
            return result.symbols
        } catch {
            return []
        }
    }
}
