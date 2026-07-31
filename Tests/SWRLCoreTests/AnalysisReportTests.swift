import Common
import Foundation
import SymbolsResolver
import Testing
@testable import SWRLCore

@Suite("Analysis report")
struct AnalysisReportTests {
    @Test("Partial results include summary files and diagnostics")
    func buildsPartialReport() throws {
        let project = InputFile(path: "/tmp/Report/App.xcodeproj")
        let successFile = InputFile(path: "/tmp/Report/A.swift")
        let failedFile = InputFile(path: "/tmp/Report/B.swift")
        var context = FileAnalysisContext(file: successFile, moduleName: "App")
        context.resolvedSymbols = [unknownResolution()]
        let results = [
            FileProcessingResult(file: failedFile, outcome: .failure(FixtureError())),
            FileProcessingResult(file: successFile, outcome: .success(context)),
        ]

        let report = AnalysisReportBuilder().build(project: project, processingResults: results)

        #expect(report.project == project.normalizedPath)
        #expect(report.summary == .init(requested: 2, succeeded: 1, failed: 1, unresolved: 1))
        #expect(report.files.map(\.file) == [successFile.normalizedPath])
        let diagnostic = try #require(report.diagnostics.first)
        #expect(diagnostic.code == "analysis.file_failed")
        #expect(diagnostic.severity == .error)
        #expect(diagnostic.message == "fixture analysis failed")
        #expect(diagnostic.file == failedFile.normalizedPath)
    }

    @Test("The report has no schema version and encodes deterministically")
    func encodesWithoutSchemaVersion() throws {
        let project = InputFile(path: "/tmp/Report/App.xcodeproj")
        let firstFile = InputFile(path: "/tmp/Report/A.swift")
        let secondFile = InputFile(path: "/tmp/Report/B.swift")
        let firstResult = FileProcessingResult(
            file: firstFile,
            outcome: .success(FileAnalysisContext(file: firstFile, moduleName: "App"))
        )
        let secondResult = FileProcessingResult(file: secondFile, outcome: .failure(FixtureError()))
        let builder = AnalysisReportBuilder()
        let dumper = CommandLineResultDumper()

        let forwardData = try dumper.encodeToJSON(
            builder.build(project: project, processingResults: [firstResult, secondResult])
        )
        let reversedData = try dumper.encodeToJSON(
            builder.build(project: project, processingResults: [secondResult, firstResult])
        )
        let json = try #require(JSONSerialization.jsonObject(with: forwardData) as? [String: Any])

        #expect(forwardData == reversedData)
        #expect(json["schemaVersion"] == nil)
        #expect(Set(json.keys) == ["project", "summary", "files", "diagnostics"])
    }

    @Test("Reports are atomically written into a newly created directory")
    func writesReportAtomically() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let outputURL = root
            .appendingPathComponent("Reports", isDirectory: true)
            .appendingPathComponent("output.json")
        let report = AnalysisReport(
            project: "/tmp/App.xcodeproj",
            summary: .init(requested: 1, succeeded: 1, failed: 0, unresolved: 0),
            files: [],
            diagnostics: []
        )

        try CommandLineResultDumper().dump(report, to: InputFile(path: outputURL.path))

        let data = try Data(contentsOf: outputURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["project"] as? String == "/tmp/App.xcodeproj")
        let directoryContents = try FileManager.default.contentsOfDirectory(
            at: outputURL.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        #expect(directoryContents.map(\.lastPathComponent) == ["output.json"])
    }

    private func unknownResolution() -> SymbolResolution {
        let symbol = SyntaxSymbolOccurrence(
            symbolName: "MissingType",
            fullyQualifiedName: nil,
            kind: .usage,
            location: SyntaxSymbolLocation(line: 1, column: 1),
            scopeChain: []
        )
        return SymbolResolution(
            targetSymbol: symbol,
            origin: .unknown,
            originKind: .unknown
        )
    }
}

private struct FixtureError: Error, CustomStringConvertible {
    let description = "fixture analysis failed"
}
