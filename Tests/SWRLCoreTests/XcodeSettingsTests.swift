import Foundation
import Testing
@testable import SWRLCore

@Suite("Xcode environment")
struct XcodeSettingsTests {
    @Test("DEVELOPER_DIR takes priority over xcode-select")
    func prefersDeveloperDirectoryEnvironment() throws {
        let fixture = try XcodeFixture(version: "26.0")
        defer { fixture.remove() }
        let runner = StubProcessRunner(
            output: ProcessOutput(
                standardOutput: "/path/that/must/not/be/used",
                standardError: "",
                terminationStatus: 0
            )
        )
        let settings = XcodeSettings(
            processRunner: runner,
            environment: ["DEVELOPER_DIR": fixture.developerDirectory.path],
            userDefaults: nil
        )

        try settings.ensureXcodeCommandLineToolsInstalled()

        #expect(try settings.indexStoreLibraryURL() == fixture.indexStoreLibrary)
        #expect(try settings.relativeIndexStorePath() == "Index.noindex")
    }

    @Test("xcode-select is used when DEVELOPER_DIR is absent")
    func fallsBackToXcodeSelect() throws {
        let fixture = try XcodeFixture(version: "13.4")
        defer { fixture.remove() }
        let expectedCommand = ProcessCommand(
            executableURL: URL(fileURLWithPath: "/usr/bin/xcode-select"),
            arguments: ["-p"]
        )
        let runner = StubProcessRunner(
            expectedCommand: expectedCommand,
            output: ProcessOutput(
                standardOutput: fixture.developerDirectory.path + "\n",
                standardError: "",
                terminationStatus: 0
            )
        )
        let settings = XcodeSettings(
            processRunner: runner,
            environment: [:],
            userDefaults: nil
        )

        try settings.ensureXcodeCommandLineToolsInstalled()

        #expect(try settings.indexStoreLibraryURL() == fixture.indexStoreLibrary)
        #expect(try settings.relativeIndexStorePath() == "Index")
    }

    @Test("An invalid developer directory is rejected")
    func rejectsInvalidDeveloperDirectory() {
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let settings = XcodeSettings(
            processRunner: StubProcessRunner(output: .init(standardOutput: "", standardError: "", terminationStatus: 0)),
            environment: ["DEVELOPER_DIR": invalidURL.path],
            userDefaults: nil
        )

        #expect(throws: XcodeSettingsError.invalidDeveloperDirectory(invalidURL)) {
            try settings.ensureXcodeCommandLineToolsInstalled()
        }
    }
}

private struct StubProcessRunner: ProcessRunning {
    let expectedCommand: ProcessCommand?
    let output: ProcessOutput

    init(expectedCommand: ProcessCommand? = nil, output: ProcessOutput) {
        self.expectedCommand = expectedCommand
        self.output = output
    }

    func run(_ command: ProcessCommand) throws -> ProcessOutput {
        if let expectedCommand {
            #expect(command == expectedCommand)
        }
        return output
    }
}

private final class XcodeFixture {
    let root: URL
    let developerDirectory: URL
    let indexStoreLibrary: URL

    init(version: String) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        developerDirectory = root
            .appendingPathComponent("Xcode With Spaces.app/Contents/Developer")
        indexStoreLibrary = developerDirectory
            .appendingPathComponent("Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib")

        try FileManager.default.createDirectory(
            at: indexStoreLibrary.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: indexStoreLibrary)

        let infoPlist = developerDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleShortVersionString": version],
            format: .xml,
            options: 0
        )
        try plistData.write(to: infoPlist)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
