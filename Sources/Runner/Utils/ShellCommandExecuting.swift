//
//  ShellCommandExecuting.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 22.03.2025.
//

import Foundation

protocol ShellCommandExecuting {
    @discardableResult
    func run(_ command: String) throws(ShellError) -> String
}

enum ShellError: Error, CustomStringConvertible {
    case executionFailed(exitCode: Int32, errorMessage: String?)
    case unexpectedError
    case commandNotFound(String)
    case invalidOutput
    case commandTimeout

    var description: String {
        switch self {
        case let .executionFailed(exitCode, message):
            "Execution failed with exit code \(exitCode) (\(message ?? "Unknown error"))"

        case .unexpectedError:
            "Unexpected shell error"

        case let .commandNotFound(command):
            "Command not found (\(command))"

        case .invalidOutput:
            "Invalid or empty output received from the command"

        case .commandTimeout:
            "Command execution timed out"
        }
    }
}

final class BashCommandExecutor: ShellCommandExecuting {

    @discardableResult
    func run(_ command: String) throws(ShellError) -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw .unexpectedError
        }
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let outputString = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let errorString = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 {
            throw ShellError.executionFailed(exitCode: process.terminationStatus, errorMessage: errorString)
        }

        guard let output = outputString, !output.isEmpty else {
            throw ShellError.invalidOutput
        }

        return output
    }
}
