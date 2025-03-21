//
//  CommandLineValidator.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 23.03.2025.
//

import ArgumentParser
import Foundation

enum ArgumentsValidationError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case fileDoesNotExist(URL)
    case unexpected

    var description: String {
        switch self {
        case let .invalidArguments(message):
            "Invalid input arguments. \(message)."

        case let .fileDoesNotExist(fileURL):
            "File '\(fileURL.path)' does not exist."

        case .unexpected:
            "Unexpected error occurred."
        }
    }
}

struct CommandLineValidator {
    static let expectedProjectExtensions = ["xcodeproj", "xcworkspace"]

    func validate(command: CommandLineRunner) throws {
        try validateProjectFile(command.project)
        try validateInputFiles(command.inputFiles)
    }

    private func validateProjectFile(_ project: InputFile) throws {
        try validateFileExists(at: project.url)
        try validateFileExtension(
            project.url,
            allowedExtensions: Self.expectedProjectExtensions,
            errorMessage: "Project must be either a .xcodeproj or .xcworkspace file"
        )
    }

    private func validateInputFiles(_ inputFiles: [InputFile]) throws {
        try inputFiles.forEach { inputFile in
            try validateFileExists(at: inputFile.url)
        }
    }

    private func validateFileExists(at url: URL) throws {
        guard FileManager.default.fileExists(atURL: url) else {
            throw ArgumentsValidationError.fileDoesNotExist(url)
        }
    }

    private func validateFileExtension(
        _ url: URL,
        allowedExtensions: [String],
        errorMessage: String
    ) throws {
        guard allowedExtensions.contains(url.pathExtension) else {
            throw ArgumentsValidationError.invalidArguments(errorMessage)
        }
    }
}
