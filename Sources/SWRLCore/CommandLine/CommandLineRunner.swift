import ArgumentParser
import Foundation
import SymbolsResolver
import SyntaxAnalysis

public struct CommandLineRunner: AsyncParsableCommand {
    // MARK: Constants

    private static let defaultOutputFileName = "output.json"

    // MARK: Arguments

    @Argument(
        help: "Path to the .xcodeproj or .xcworkspace file.",
        completion: .file(extensions: CommandLineValidator.expectedProjectExtensions)
    )
    var project: InputFile

    @Option(
        name: [.customLong("file"), .customShort("f")],
        help: "Path to the target file to analyze.",
        completion: .file(extensions: ["swift"])
    )
    var inputFiles: [InputFile] = []

    @Option(
        name: [.customLong("pattern"), .customShort("p")],
        help: "Glob pattern describing target files to analyze."
    )
    var pattern: String?

    @Option(
        name: .customLong("derived-data"),
        help: "Path to the project's DerivedData directory."
    )
    var derivedData: InputFile?

    @Option(
        name: .customLong("index-store"),
        help: "Path to an IndexStore directory containing DataStore."
    )
    var indexStore: InputFile?

    @Flag(
        name: [.customLong("silent"), .customShort("s")],
        help: "Suppress all output."
    )
    var isSilent: Bool = false

    @Option(
        name: [.customLong("output"), .customShort("o")],
        help: "Path to the output json file.",
        completion: .file(extensions: ["json"])
    )
    var output: InputFile?

    public init() {}

    // MARK: Execution

    public func run() async throws {
        let logger = setupLogger()
        logger.printGreeting()

        let resolver = try setupResolver(project: project)
        try await resolver.prewarm()

        let totalFiles = try gatherFiles()
        logger.describeProcess(for: totalFiles)

        let processingResults = try await processFiles(totalFiles, resolver: resolver, logger: logger)
        let report = AnalysisReportBuilder().build(
            project: project,
            processingResults: processingResults
        )

        let dumper = CommandLineResultDumper()
        let outputFile = output ?? InputFile(path: Self.defaultOutputFileName)
        try dumper.dump(report, to: outputFile)

        logger.printNewLine()
        logger.printSuccess("Success! Result is written to the file: \(outputFile.url.path)")
    }

    public func validate() throws {
        let validator = CommandLineValidator()
        try validator.validate(command: self)
    }

    // MARK: Private Helpers

    private func setupLogger() -> Logger {
        var logger = Logger()
        logger.setMuted(isSilent)
        logger.setSorted(true)
        return logger
    }

    private func setupResolver(project: InputFile) throws -> SymbolsResolver {
        let xcodeSettings = XcodeSettings()
        try xcodeSettings.ensureXcodeCommandLineToolsInstalled()

        let indexLocation = try ProjectIndexLocator(xcodeSettings: xcodeSettings)
            .locate(
                projectURL: project.url,
                derivedDataOverride: derivedData?.url,
                indexStoreOverride: indexStore?.url
            )

        let databaseURL = try IndexDatabaseCache().databaseURL(
            projectURL: project.url,
            indexStoreURL: indexLocation.indexStoreURL,
            activeXcodeURL: xcodeSettings.activeDeveloperDirectoryURL()
        )

        return try SymbolsResolver(
            storeURL: indexLocation.indexStoreURL,
            databaseURL: databaseURL,
            xcodeSettings: xcodeSettings,
            frameworksAnalyzer: SyntaxSymbolsAnalyzer()
        )
    }

    private func gatherFiles() throws -> [InputFile] {
        var totalFiles = inputFiles
        if let pattern {
            let extraFiles = globFiles(pattern: pattern)
                .compactMap(InputFile.init)
                .filter { $0.fileExtension == "swift" }
            totalFiles += extraFiles
        }
        return totalFiles.sorted { $0.normalizedPath < $1.normalizedPath }
    }

    private func processFiles(
        _ files: [InputFile],
        resolver: SymbolsResolver,
        logger: Logger
    ) async throws -> [FileProcessingResult] {
        let coordinator = AnalysisCoordinator()
        let processingResults = await coordinator.process(files: files) { file in
            let tool = CommandLineTool(resolver: resolver)
            return try await tool.processInputFile(file)
        }

        for processingResult in processingResults {
            switch processingResult.outcome {
            case let .success(context):
                try logger.displayFileSection(for: processingResult.file) {
                    context.printDescription(with: logger)
                }

            case let .failure(error):
                try logger.displayFileSection(for: processingResult.file) {
                    logger.logError(error)
                }
            }
        }

        return processingResults
    }
}
