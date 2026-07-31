import Foundation
import Testing
@testable import SWRLCore

@Suite("Executable entry point")
struct ExecutableEntryPointTests {
    @Test("The executable invokes async command validation")
    func invokesAsyncCommand() throws {
        let currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let executableURL = currentDirectoryURL
            .appendingPathComponent(".build/debug/swrl")
        let missingProject = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("Missing.xcodeproj")

        do {
            _ = try FoundationProcessRunner().run(
                ProcessCommand(
                    executableURL: executableURL,
                    arguments: [
                        missingProject.path,
                        "--file",
                        missingProject.deletingLastPathComponent().appendingPathComponent("Missing.swift").path,
                    ],
                    currentDirectoryURL: currentDirectoryURL
                )
            )
            Issue.record("Expected invalid executable arguments to fail")
        } catch let error as ProcessRunnerError {
            guard case let .executionFailed(_, exitCode, standardError) = error else {
                Issue.record("Unexpected process error: \(error)")
                return
            }
            #expect(exitCode == 64)
            #expect(standardError.contains("does not exist"))
            #expect(!standardError.contains("USAGE: swrl"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
