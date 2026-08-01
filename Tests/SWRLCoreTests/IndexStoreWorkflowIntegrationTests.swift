import Foundation
import Testing
@testable import SWRLCore

@Suite("IndexStore workflow integration")
struct IndexStoreWorkflowIntegrationTests {
    @Test("A swiftc IndexStore produces classified deterministic partial reports")
    func analyzesSwiftcIndexStore() throws {
        let fixture = try IndexStoreWorkflowFixture()
        defer { fixture.remove() }
        try fixture.buildIndexStore()

        let firstOutput = fixture.rootURL.appendingPathComponent("first-output.json")
        let secondOutput = fixture.rootURL.appendingPathComponent("second-output.json")
        let successfulRun = try fixture.runSWRL(
            files: [fixture.indexedSourceURL],
            outputURL: firstOutput
        )

        #expect(successfulRun.terminationStatus == 0)
        #expect(successfulRun.standardOutput.isEmpty)
        #expect(successfulRun.standardError.contains("Starting lightweight analysis"))
        #expect(successfulRun.standardError.contains("Success!"))
        let firstData = try Data(contentsOf: firstOutput)
        let firstReport = try reportJSON(from: firstData)
        let firstSummary = try #require(firstReport["summary"] as? [String: Int])
        #expect(firstSummary == ["requested": 1, "succeeded": 1, "failed": 0, "unresolved": 0])
        let firstFiles = try #require(firstReport["files"] as? [[String: Any]])
        let analyzedFile = try #require(firstFiles.first)
        #expect(analyzedFile["module"] as? String == "FixtureModule")
        let symbols = try #require(analyzedFile["symbols"] as? [[String: Any]])
        let urlSymbol = try #require(symbols.first(where: { $0["symbol"] as? String == "URL" }))
        #expect(urlSymbol["originModuleType"] as? String == "system")

        let repeatedRun = try fixture.runSWRL(
            files: [fixture.indexedSourceURL],
            outputURL: secondOutput,
            silent: true
        )
        #expect(repeatedRun.standardOutput.isEmpty)
        #expect(repeatedRun.standardError.isEmpty)
        #expect(try Data(contentsOf: secondOutput) == firstData)

        let partialOutput = fixture.rootURL.appendingPathComponent("partial-output.json")
        do {
            _ = try fixture.runSWRL(
                files: [fixture.indexedSourceURL, fixture.unindexedSourceURL],
                outputURL: partialOutput
            )
            Issue.record("Expected the partial analysis to exit with a failure")
        } catch let error as ProcessRunnerError {
            guard case let .executionFailed(_, exitCode, standardError) = error else {
                Issue.record("Unexpected process error: \(error)")
                return
            }
            #expect(exitCode == 1)
            #expect(standardError.contains("Cannot determine module"))
        }

        let partialReport = try reportJSON(from: Data(contentsOf: partialOutput))
        let partialSummary = try #require(partialReport["summary"] as? [String: Int])
        #expect(partialSummary == ["requested": 2, "succeeded": 1, "failed": 1, "unresolved": 0])
        let partialFiles = try #require(partialReport["files"] as? [[String: Any]])
        #expect(partialFiles.count == 1)
        let diagnostics = try #require(partialReport["diagnostics"] as? [[String: Any]])
        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic["code"] as? String == "analysis.file_failed")
        #expect(diagnostic["severity"] as? String == "error")
        #expect(diagnostic["file"] as? String == InputFile(path: fixture.unindexedSourceURL.path).normalizedPath)
    }

    private func reportJSON(from data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class IndexStoreWorkflowFixture {
    let rootURL: URL
    let projectURL: URL
    let indexStoreURL: URL
    let indexedSourceURL: URL
    let unindexedSourceURL: URL

    private let executableURL: URL
    private let processRunner = FoundationProcessRunner()

    init() throws {
        rootURL = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("swrl integration \(UUID().uuidString)", isDirectory: true)
        projectURL = rootURL.appendingPathComponent("Fixture App.xcodeproj", isDirectory: true)
        indexStoreURL = rootURL.appendingPathComponent("Fixture Index.noindex", isDirectory: true)
        indexedSourceURL = rootURL.appendingPathComponent("Indexed Source.swift")
        unindexedSourceURL = rootURL.appendingPathComponent("Unindexed Source.swift")
        executableURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".build/debug/swrl")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try Data(
            """
            import Foundation

            struct LocalType {
                let url: URL
            }
            """.utf8
        ).write(to: indexedSourceURL)
        try Data("struct UnindexedType {}".utf8).write(to: unindexedSourceURL)
    }

    func buildIndexStore() throws {
        let dataStoreURL = indexStoreURL.appendingPathComponent("DataStore", isDirectory: true)
        let moduleCacheURL = rootURL.appendingPathComponent("Module Cache", isDirectory: true)
        _ = try processRunner.run(
            ProcessCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: [
                    "swiftc",
                    "-typecheck",
                    "-module-name",
                    "FixtureModule",
                    "-module-cache-path",
                    moduleCacheURL.path,
                    "-index-store-path",
                    dataStoreURL.path,
                    indexedSourceURL.path,
                ],
                currentDirectoryURL: rootURL
            )
        )
    }

    func runSWRL(
        files: [URL],
        outputURL: URL,
        silent: Bool = false
    ) throws -> ProcessOutput {
        guard FileManager.default.fileExists(atURL: projectURL) else {
            throw FixtureError.missingPath(projectURL)
        }
        guard FileManager.default.fileExists(atURL: indexStoreURL.appendingPathComponent("DataStore")) else {
            throw FixtureError.missingPath(indexStoreURL.appendingPathComponent("DataStore"))
        }

        var arguments = [projectURL.path]
        for file in files {
            arguments += ["--file", file.path]
        }
        arguments += [
            "--index-store",
            indexStoreURL.path,
            "--output",
            outputURL.path,
        ]
        if silent {
            arguments.append("--silent")
        }

        return try processRunner.run(
            ProcessCommand(
                executableURL: executableURL,
                arguments: arguments,
                currentDirectoryURL: rootURL
            )
        )
    }

    func remove() {
        do {
            let xcodeSettings = XcodeSettings()
            let cacheURL = try IndexDatabaseCache().databaseURL(
                projectURL: projectURL,
                indexStoreURL: indexStoreURL,
                activeXcodeURL: xcodeSettings.activeDeveloperDirectoryURL()
            )
            if FileManager.default.fileExists(atURL: cacheURL) {
                try FileManager.default.removeItem(at: cacheURL)
            }
        } catch {
            // Cache cleanup does not affect the observable test result.
        }
        do {
            try FileManager.default.removeItem(at: rootURL)
        } catch {
            // Fixture cleanup does not affect the observable test result.
        }
    }
}

private enum FixtureError: Error, CustomStringConvertible {
    case missingPath(URL)

    var description: String {
        switch self {
        case let .missingPath(url):
            "Integration fixture path does not exist: \(url.path)"
        }
    }
}
