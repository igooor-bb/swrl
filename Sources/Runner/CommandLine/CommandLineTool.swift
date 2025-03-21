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
    private var resolver: SymbolsResolver!

    private var stepNumber = 1

    init(logger: Logger, project: InputFile) {
        self.logger = logger
        self.project = project
    }

    func setup() throws {
        let xcodeSettings = XcodeSettings(shell: BashCommandExecutor())
        try xcodeSettings.ensureXcodeCommandLineToolsInstalled()

        let derivedDataProvider = ProjectDerivedDataFinder(xcodeSettings: xcodeSettings)
        let projectDerivedDataURL = try derivedDataProvider.findForProject(at: project.url)
        let indexStoreURL = try resolveIndexStoreURL(
            projectDerivedDataURL: projectDerivedDataURL,
            xcodeSettings: xcodeSettings
        )

        self.resolver = try SymbolsResolver(
            storeURL: indexStoreURL,
            xcodeSettings: xcodeSettings,
            frameworksAnalyzer: SyntaxSymbolsAnalyzer()
        )
    }

    func processInputFile(_ file: InputFile, at index: Int, totalCount: Int) throws -> OutputModel {
        try logger.displayFileSection(for: file, at: index, total: totalCount) {
            stepNumber = 1
            resolver.prewarm()

            let context = try createSyntaxAnalysisContext(for: file)
                .apply(performSyntaxAnalysis)
                .apply(performSymbolsResolution)

            return context.dumpOutput()
        }
    }

    // MARK: Helpers

    private func resolveIndexStoreURL(projectDerivedDataURL: URL, xcodeSettings: XcodeSettings) throws -> URL {
        let indexStorePath = try xcodeSettings.relativeIndexStorePath()
        return projectDerivedDataURL.appendingPathComponent(indexStorePath)
    }
    
    // MARK: Processing

    // Step 1
    private func createSyntaxAnalysisContext(for file: InputFile) throws -> FileAnalysisContext {
        try logger.performStep(number: &stepNumber, description: "Determining module") {
            let moduleName = try resolver.determineFileModule(fileURL: file.url)
            let context = FileAnalysisContext(file: file, moduleName: moduleName)
            context.printFileModuleInfo(with: logger)
            return context
        }
    }

    // Step 2
    private func performSyntaxAnalysis(on context: FileAnalysisContext) throws -> FileAnalysisContext {
        try logger.performStep(number: &stepNumber, description: "Imports & Dependencies") {
            let symbolsAnalyzer = SyntaxSymbolsAnalyzer()
            let result = try symbolsAnalyzer.analyzeFile(at: context.file.url)

            var updated = context
            updated.declarations = Set(result.symbols.filter(\.kind.isDefinition))
            updated.dependencies = Set(result.symbols.filter(\.kind.isUsage))
            updated.imports = Set(result.imports)
            updated.printSyntaxAnalysis(with: logger)

            return updated
        }
    }

    // Step 3
    private func performSymbolsResolution(on context: FileAnalysisContext) throws -> FileAnalysisContext {
        logger.performStep(number: &stepNumber, description: "Resolving symbols") {
            let resolvedSymbols = resolver.resolveSymbols(
                Array(context.dependencies),
                relativeToModule: context.moduleName,
                amongDependencies: context.imports
            )
            
            var updated = context
            updated.resolvedSymbols = resolvedSymbols
            updated.printSymbolsResolution(with: logger)

            return updated
        }
    }
}
