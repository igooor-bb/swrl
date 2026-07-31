import ArgumentParser
import Foundation
import Testing
@testable import SWRLCore

@Suite("CLI index overrides")
struct CommandLineIndexOverrideTests {
    @Test("Parses a DerivedData override")
    func parsesDerivedDataOverride() throws {
        let fixture = try CommandLineFixture()
        defer { fixture.remove() }

        let command = try CommandLineRunner.parse([
            fixture.project.path,
            "--file",
            fixture.sourceFile.path,
            "--derived-data",
            fixture.derivedData.path,
        ])

        #expect(command.derivedData?.url == fixture.derivedData.standardizedFileURL)
        #expect(command.indexStore == nil)
        try command.validate()
    }

    @Test("Parses an IndexStore override")
    func parsesIndexStoreOverride() throws {
        let fixture = try CommandLineFixture()
        defer { fixture.remove() }

        let command = try CommandLineRunner.parse([
            fixture.project.path,
            "--file",
            fixture.sourceFile.path,
            "--index-store",
            fixture.indexStore.path,
        ])

        #expect(command.indexStore?.url == fixture.indexStore.standardizedFileURL)
        #expect(command.derivedData == nil)
        try command.validate()
    }

    @Test("Rejects simultaneous DerivedData and IndexStore overrides")
    func rejectsConflictingOverrides() throws {
        let fixture = try CommandLineFixture()
        defer { fixture.remove() }
        var command = try CommandLineRunner.parse([
            fixture.project.path,
            "--file",
            fixture.sourceFile.path,
            "--derived-data",
            fixture.derivedData.path,
        ])
        command.indexStore = InputFile(path: fixture.indexStore.path)

        do {
            try command.validate()
            Issue.record("Expected conflicting index overrides to fail validation")
        } catch {
            #expect(CommandLineRunner.exitCode(for: error) == .validationFailure)
            #expect(String(describing: error).contains("--derived-data and --index-store are mutually exclusive"))
        }
    }

    @Test("Rejects a missing explicit index directory")
    func rejectsMissingOverride() throws {
        let fixture = try CommandLineFixture()
        defer { fixture.remove() }
        let missingIndexStore = fixture.root.appendingPathComponent("Missing Index.noindex").standardizedFileURL
        var command = try CommandLineRunner.parse([
            fixture.project.path,
            "--file",
            fixture.sourceFile.path,
            "--derived-data",
            fixture.derivedData.path,
        ])
        command.derivedData = nil
        command.indexStore = InputFile(path: missingIndexStore.path)

        do {
            try command.validate()
            Issue.record("Expected the missing index override to fail validation")
        } catch {
            #expect(CommandLineRunner.exitCode(for: error) == .validationFailure)
            #expect(String(describing: error).contains(missingIndexStore.path))
        }
    }

    @Test("Help documents both explicit index locations")
    func documentsOverrides() {
        let help = CommandLineRunner.helpMessage()

        #expect(help.contains("--derived-data"))
        #expect(help.contains("--index-store"))
    }
}

private final class CommandLineFixture {
    let root: URL
    let project: URL
    let sourceFile: URL
    let derivedData: URL
    let indexStore: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        project = root.appendingPathComponent("App.xcodeproj")
        sourceFile = root.appendingPathComponent("Source.swift")
        derivedData = root.appendingPathComponent("Derived Data")
        indexStore = root.appendingPathComponent("Manual Index.noindex")

        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: derivedData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexStore, withIntermediateDirectories: true)
        try Data("struct Source {}".utf8).write(to: sourceFile)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
