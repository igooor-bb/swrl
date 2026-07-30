import Common
import Foundation
import SymbolsResolver
import SyntaxAnalysis

extension SyntaxSymbolsAnalyzer: FrameworkDefinitionsAnalyzer {
    public func findDefinitions(at url: URL) throws -> [SyntaxSymbolOccurrence] {
        let result = try analyzeFile(at: url, options: .includeDefinitions)
        return result.symbols
    }
}
