//
//  CommandLineTool.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 23.03.2025.
//

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

    func processInputFile(_ file: InputFile, at index: Int, totalCount: Int) async throws -> FileAnalysisContext {
        try createSyntaxAnalysisContext(for: file)
            .apply(performSyntaxAnalysis)
            .apply(performSymbolsResolution)
    }

    // MARK: Processing

    // Step 1
    private func createSyntaxAnalysisContext(for file: InputFile) throws -> FileAnalysisContext {
        let moduleName = try resolver.determineFileModule(fileURL: file.url)
        let context = FileAnalysisContext(file: file, moduleName: moduleName)
        return context
    }

    // Step 2
    private func performSyntaxAnalysis(on context: FileAnalysisContext) throws -> FileAnalysisContext {
        let symbolsAnalyzer = SyntaxSymbolsAnalyzer()
        let result = try symbolsAnalyzer.analyzeFile(at: context.file.url)

        var updated = context
        updated.declarations = Set(result.symbols.filter(\.kind.isDefinition))
        updated.dependencies = Set(result.symbols.filter(\.kind.isUsage))
        updated.imports = Set(result.imports)

        return updated
    }

    // Step 3
    private func performSymbolsResolution(on context: FileAnalysisContext) throws -> FileAnalysisContext {
        let resolvedSymbols = resolver.resolveSymbols(
            Array(context.dependencies),
            relativeToModule: context.moduleName,
            amongDependencies: context.imports
        )

        var updated = context
        updated.resolvedSymbols = resolvedSymbols
        return updated
    }
}
