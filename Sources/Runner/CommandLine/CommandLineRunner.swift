import ArgumentParser
import Foundation
import SymbolsResolver
import SyntaxAnalysis

@main
struct CommandLineRunner: AsyncParsableCommand {

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

    // MARK: Execution

    func run() async throws {
        let logger = setupLogger()
        logger.printGreeting()

        let resolver = try setupResolver(project: project)
        await resolver.prewarm()

        let totalFiles = try gatherFiles()
        logger.describeProcess(for: totalFiles)

        let outputs = try await processFiles(totalFiles, resolver: resolver, logger: logger)

        let dumper = CommandLineResultDumper()
        let outputFile = output ?? InputFile(argument: Self.defaultOutputFileName)!
        try dumper.dump(outputs, to: outputFile)

        logger.printNewLine()
        logger.printSuccess("Success! Result is written to the file: \(outputFile.url.path)")
    }

    func validate() throws {
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
        let xcodeSettings = XcodeSettings(shell: BashCommandExecutor())
        try xcodeSettings.ensureXcodeCommandLineToolsInstalled()

        let derivedDataProvider = ProjectDerivedDataFinder(xcodeSettings: xcodeSettings)
        let projectDerivedDataURL = try derivedDataProvider.findForProject(at: project.url)
        let indexStoreURL = try resolveIndexStoreURL(
            projectDerivedDataURL: projectDerivedDataURL,
            xcodeSettings: xcodeSettings
        )

        let databaseName = project.url.deletingPathExtension().lastPathComponent
        let databaseURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".swrl/\(databaseName)")

        return try SymbolsResolver(
            storeURL: indexStoreURL,
            databaseURL: databaseURL,
            xcodeSettings: xcodeSettings,
            frameworksAnalyzer: SyntaxSymbolsAnalyzer()
        )
    }

    private func resolveIndexStoreURL(projectDerivedDataURL: URL, xcodeSettings: XcodeSettings) throws -> URL {
        let indexStorePath = try xcodeSettings.relativeIndexStorePath()
        return projectDerivedDataURL.appendingPathComponent(indexStorePath)
    }

    private func gatherFiles() throws -> [InputFile] {
        var totalFiles = inputFiles
        if let pattern {
            let extraFiles = globFiles(pattern: pattern)
                .compactMap(InputFile.init)
                .filter { $0.fileExtension == "swift" }
            totalFiles += extraFiles
        }
        return totalFiles
    }

    private func processFiles(
        _ files: [InputFile],
        resolver: SymbolsResolver,
        logger: Logger
    ) async throws -> [OutputModel] {
        struct ProcessingResult {
            let file: InputFile
            let result: Result<FileAnalysisContext, Error>
        }

        return try await withThrowingTaskGroup(of: ProcessingResult.self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    let tool = CommandLineTool(logger: logger, resolver: resolver, project: project)

                    do {
                        let context = try await tool.processInputFile(file, at: index, totalCount: files.count)
                        return ProcessingResult(file: file, result: .success(context))
                    } catch {
                        return ProcessingResult(file: file, result: .failure(error))
                    }
                }
            }

            var results: [OutputModel] = []
            for try await processingResult in group {
                let result = processingResult.result

                switch result {
                case let .success(context):
                    try logger.displayFileSection(for: processingResult.file) {
                        context.printDescription(with: logger)
                    }
                    results.append(context.dumpOutput())

                case let .failure(error):
                    try logger.displayFileSection(for: processingResult.file) {
                        logger.logError(error)
                    }
                }
            }

            return results
        }
    }
}
