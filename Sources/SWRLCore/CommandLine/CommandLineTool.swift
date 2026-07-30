import Foundation
import SymbolsResolver
import SyntaxAnalysis

struct CommandLineTool: Sendable {
    private let resolver: SymbolsResolver

    init(resolver: SymbolsResolver) {
        self.resolver = resolver
    }

    func processInputFile(_ file: InputFile) async throws -> FileAnalysisContext {
        let syntaxContext = try await createSyntaxAnalysisContext(for: file)
        let analyzedContext = try performSyntaxAnalysis(on: syntaxContext)
        return try await performSymbolsResolution(on: analyzedContext)
    }

    // MARK: Processing

    /// Step 1
    private func createSyntaxAnalysisContext(for file: InputFile) async throws -> FileAnalysisContext {
        let moduleName = try await resolver.determineFileModule(fileURL: file.url)
        return FileAnalysisContext(file: file, moduleName: moduleName)
    }

    /// Step 2
    private func performSyntaxAnalysis(on context: FileAnalysisContext) throws -> FileAnalysisContext {
        let symbolsAnalyzer = SyntaxSymbolsAnalyzer()
        let result = try symbolsAnalyzer.analyzeFile(at: context.file.url)

        var updated = context
        updated.declarations = Set(result.symbols.filter(\.kind.isDefinition))
        updated.dependencies = Set(result.symbols.filter(\.kind.isUsage))
        updated.imports = Set(result.imports)

        return updated
    }

    /// Step 3
    private func performSymbolsResolution(on context: FileAnalysisContext) async throws -> FileAnalysisContext {
        let resolvedSymbols = try await resolver.resolveSymbols(
            Array(context.dependencies),
            relativeToModule: context.moduleName,
            amongDependencies: context.imports
        )

        var updated = context
        updated.resolvedSymbols = resolvedSymbols
        return updated
    }
}
