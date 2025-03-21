import ArgumentParser
import Foundation
import Rainbow

@main
struct CommandLineRunner: ParsableCommand {

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

    func run() throws {
        let logger = setupLogger()
        logger.printGreeting()

        let tool = CommandLineTool(logger: logger, project: project)
        try tool.setup()

        let totalFiles = try gatherFiles()
        logger.describeProcess(for: totalFiles)

        let outputs = try processFiles(totalFiles, using: tool, logger: logger)

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
        let logger = Logger()
        logger.setMuted(isSilent)
        logger.setSorted(true)
        return logger
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
        using tool: CommandLineTool,
        logger: Logger
    ) throws -> [OutputModel] {
        var results: [OutputModel] = []
        for (index, file) in files.enumerated() {
            do {
                let processingResult = try tool.processInputFile(file, at: index, totalCount: files.count)
                results.append(processingResult)
            } catch {
                logger.logError(error)
            }
        }
        return results
    }
}
