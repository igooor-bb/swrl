import Foundation
import SymbolsResolver
import SyntaxAnalysis

final class CommandLineTool {
    private let logger: Logger
    private let project: InputFile
    private let resolver: SymbolsResolver

    private var stepNumber = 1

    init(
        logger: Logger,
        resolver: SymbolsResolver,
        project: InputFile
    ) {
        self.logger = logger
        self.resolver = resolver
        self.project = project
    }

    func processInputFile(_ file: InputFile, at _: Int, totalCount _: Int) async throws -> FileAnalysisContext {
        let syntaxContext = try await createSyntaxAnalysisContext(for: file)
        let analyzedContext = try performSyntaxAnalysis(on: syntaxContext)
        return await performSymbolsResolution(on: analyzedContext)
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
    private func performSymbolsResolution(on context: FileAnalysisContext) async -> FileAnalysisContext {
        let resolvedSymbols = await resolver.resolveSymbols(
            Array(context.dependencies),
            relativeToModule: context.moduleName,
            amongDependencies: context.imports
        )

        var updated = context
        updated.resolvedSymbols = resolvedSymbols
        return updated
    }
}
