import Foundation

struct ProcessCommand: Equatable, Sendable {
    let executableURL: URL
    let arguments: [String]
    let environment: [String: String]?
    let currentDirectoryURL: URL?

    init(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectoryURL: URL? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryURL = currentDirectoryURL
    }
}

struct ProcessOutput: Equatable, Sendable {
    let standardOutput: String
    let standardError: String
    let terminationStatus: Int32
}

protocol ProcessRunning: Sendable {
    func run(_ command: ProcessCommand) throws -> ProcessOutput
}

enum ProcessRunnerError: Error, CustomStringConvertible {
    case launchFailed(executable: URL, message: String)
    case executionFailed(executable: URL, exitCode: Int32, standardError: String)
    case invalidUTF8Output(executable: URL)

    var description: String {
        switch self {
        case let .launchFailed(executable, message):
            "Failed to launch \(executable.path): \(message)"

        case let .executionFailed(executable, exitCode, standardError):
            "\(executable.path) exited with code \(exitCode): \(standardError)"

        case let .invalidUTF8Output(executable):
            "\(executable.path) produced output that is not valid UTF-8."
        }
    }
}

struct FoundationProcessRunner: ProcessRunning {
    func run(_ command: ProcessCommand) throws -> ProcessOutput {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.environment = command.environment
        process.currentDirectoryURL = command.currentDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(
                executable: command.executableURL,
                message: error.localizedDescription
            )
        }
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let output = String(data: outputData, encoding: .utf8),
            let errorOutput = String(data: errorData, encoding: .utf8)
        else {
            throw ProcessRunnerError.invalidUTF8Output(executable: command.executableURL)
        }

        if process.terminationStatus != 0 {
            throw ProcessRunnerError.executionFailed(
                executable: command.executableURL,
                exitCode: process.terminationStatus,
                standardError: errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return ProcessOutput(
            standardOutput: output,
            standardError: errorOutput,
            terminationStatus: process.terminationStatus
        )
    }
}
