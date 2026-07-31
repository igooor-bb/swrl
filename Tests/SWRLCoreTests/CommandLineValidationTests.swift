import ArgumentParser
import Foundation
import Testing
@testable import SWRLCore

@Suite("CLI validation and status")
struct CommandLineValidationTests {
    @Test("At least one file or pattern is required")
    func requiresInputSelection() throws {
        let fixture = try ValidationFixture()
        defer { fixture.remove() }

        expectValidationFailure(
            arguments: [fixture.project.path],
            containing: "Provide at least one --file or --pattern"
        )
    }

    @Test("Explicit files must exist and use the Swift extension")
    func validatesExplicitFiles() throws {
        let fixture = try ValidationFixture()
        defer { fixture.remove() }
        let wrongExtension = fixture.root.appendingPathComponent("Source.txt")
        try Data().write(to: wrongExtension)
        expectValidationFailure(
            arguments: [fixture.project.path, "--file", wrongExtension.path],
            containing: ".swift extension"
        )
        expectValidationFailure(
            arguments: [
                fixture.project.path,
                "--file",
                fixture.root.appendingPathComponent("Missing.swift").path,
            ],
            containing: "does not exist"
        )
    }

    @Test("Multiple patterns are accepted")
    func acceptsMultiplePatterns() throws {
        let fixture = try ValidationFixture()
        defer { fixture.remove() }
        let command = try CommandLineRunner.parse([
            fixture.project.path,
            "--pattern",
            fixture.root.appendingPathComponent("*.swift").path,
            "--pattern",
            fixture.root.appendingPathComponent("Nested/*.swift").path,
        ])

        #expect(command.patterns.count == 2)
        try command.validate()
    }

    @Test("Every pattern must match at least one Swift file")
    func rejectsUnmatchedPatterns() throws {
        let fixture = try ValidationFixture()
        defer { fixture.remove() }
        let pattern = fixture.root.appendingPathComponent("Missing/*.swift").path
        expectValidationFailure(
            arguments: [fixture.project.path, "--pattern", pattern],
            containing: "did not match any Swift files"
        )
    }

    @Test("Help and version are clean exits for the swrl command")
    func supportsHelpAndVersion() {
        let help = CommandLineRunner.helpMessage()

        #expect(help.contains("swrl"))
        #expect(help.contains("--file"))
        #expect(help.contains("--pattern"))
        expectCleanExit(arguments: ["--help"], messageContains: "USAGE: swrl")
        expectCleanExit(arguments: ["--version"], messageContains: "0.1.0")
    }

    @Test("Partial analysis uses exit code one while unknown symbols remain successful")
    func mapsAnalysisStatusToExitCode() {
        let successfulReport = report(failed: 0, unresolved: 3)
        let partialReport = report(failed: 1, unresolved: 0)

        #expect(CommandLineRunner.analysisExitCode(for: successfulReport) == .success)
        #expect(CommandLineRunner.analysisExitCode(for: partialReport) == .failure)
    }

    private func expectValidationFailure(
        arguments: [String],
        containing message: String
    ) {
        do {
            _ = try CommandLineRunner.parse(arguments)
            Issue.record("Expected command validation to fail")
        } catch {
            #expect(CommandLineRunner.exitCode(for: error) == .validationFailure)
            #expect(String(describing: error).contains(message))
        }
    }

    private func expectCleanExit(
        arguments: [String],
        messageContains message: String
    ) {
        do {
            _ = try CommandLineRunner.parse(arguments)
            Issue.record("Expected a clean CLI exit")
        } catch {
            #expect(CommandLineRunner.exitCode(for: error) == .success)
            #expect(CommandLineRunner.message(for: error).contains(message))
        }
    }

    private func report(failed: Int, unresolved: Int) -> AnalysisReport {
        AnalysisReport(
            project: "/tmp/App.xcodeproj",
            summary: AnalysisReport.Summary(
                requested: failed,
                succeeded: 0,
                failed: failed,
                unresolved: unresolved
            ),
            files: [],
            diagnostics: []
        )
    }
}

private final class ValidationFixture {
    let root: URL
    let project: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        project = root.appendingPathComponent("App.xcodeproj", isDirectory: true)
        let nested = root.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("struct RootType {}".utf8).write(to: root.appendingPathComponent("Root.swift"))
        try Data("struct NestedType {}".utf8).write(to: nested.appendingPathComponent("Nested.swift"))
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
