import ArgumentParser
import Foundation

enum ArgumentsValidationError: Error, Equatable, CustomStringConvertible {
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
        try validateInputSelection(command)
        try validateInputFiles(command.inputFiles)
        try validatePatterns(command.patterns)
        try validateIndexOverrides(command)
    }

    func swiftFiles(matching pattern: String) throws -> [InputFile] {
        let matchedFiles: [InputFile]
        do {
            matchedFiles = try globFiles(pattern: pattern)
                .compactMap(InputFile.init)
                .filter { $0.fileExtension.lowercased() == "swift" }
        } catch {
            throw ArgumentsValidationError.invalidArguments("Unable to evaluate pattern '\(pattern)': \(error)")
        }

        guard !matchedFiles.isEmpty else {
            throw ArgumentsValidationError.invalidArguments("Pattern '\(pattern)' did not match any Swift files")
        }
        return matchedFiles
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
            try validateFileExtension(
                inputFile.url,
                allowedExtensions: ["swift"],
                errorMessage: "Input files must use the .swift extension"
            )
        }
    }

    private func validateInputSelection(_ command: CommandLineRunner) throws {
        guard !command.inputFiles.isEmpty || !command.patterns.isEmpty else {
            throw ArgumentsValidationError.invalidArguments("Provide at least one --file or --pattern")
        }
    }

    private func validatePatterns(_ patterns: [String]) throws {
        for pattern in patterns {
            _ = try swiftFiles(matching: pattern)
        }
    }

    private func validateIndexOverrides(_ command: CommandLineRunner) throws {
        guard command.derivedData == nil || command.indexStore == nil else {
            throw ArgumentsValidationError.invalidArguments("--derived-data and --index-store are mutually exclusive")
        }

        if let derivedData = command.derivedData {
            try validateDirectoryExists(at: derivedData.url)
        }
        if let indexStore = command.indexStore {
            try validateDirectoryExists(at: indexStore.url)
        }
    }

    private func validateFileExists(at url: URL) throws {
        guard FileManager.default.fileExists(atURL: url) else {
            throw ArgumentsValidationError.fileDoesNotExist(url)
        }
    }

    private func validateDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ArgumentsValidationError.fileDoesNotExist(url)
        }
    }

    private func validateFileExtension(
        _ url: URL,
        allowedExtensions: [String],
        errorMessage: String
    ) throws {
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            throw ArgumentsValidationError.invalidArguments(errorMessage)
        }
    }
}
