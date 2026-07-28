import Foundation
import SymbolsResolver

enum XcodeSettingsError: Error, Equatable, CustomStringConvertible {
    case missingCommandLineTools
    case invalidDeveloperDirectory(URL)
    case missingIndexStoreLibrary(URL)
    case missingXcodeVersion(URL)

    var description: String {
        switch self {
        case .missingCommandLineTools:
            "Missing Xcode or Xcode Command Line Tools."

        case let .invalidDeveloperDirectory(url):
            "The active developer directory does not exist: \(url.path)"

        case let .missingIndexStoreLibrary(url):
            "Unable to find libIndexStore at \(url.path). Please ensure that the active Xcode is installed correctly."

        case let .missingXcodeVersion(url):
            "Unable to read the active Xcode version from \(url.path)."
        }
    }
}

final class XcodeSettings: XcodeSettingsProviding {
    private enum Constants {
        static let xcodeDefaultsSuiteName = "com.apple.dt.Xcode.plist"
        static let customDerivedDataLocationKey = "IDECustomDerivedDataLocation"
        static let defaultDerivedDataLocation = "~/Library/Developer/Xcode/DerivedData"
        static let indexStoreLibraryPath = "Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        static let xcodeInfoPlistName = "Info.plist"
        static let xcodeVersionKey = "CFBundleShortVersionString"
        static let indexStoreRootPath = "Index.noindex"
        static let legacyIndexStoreRootPath = "Index"
        static let xcodeSelectURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let processRunner: ProcessRunning
    private let userDefaults: UserDefaults?
    private var developerDirectoryURL: URL?

    init(
        processRunner: ProcessRunning = FoundationProcessRunner(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults? = UserDefaults(suiteName: Constants.xcodeDefaultsSuiteName)
    ) {
        self.processRunner = processRunner
        self.environment = environment
        self.fileManager = fileManager
        self.userDefaults = userDefaults
    }

    func ensureXcodeCommandLineToolsInstalled() throws {
        _ = try resolveDeveloperDirectoryURL()
    }

    func activeDeveloperDirectoryURL() throws -> URL {
        try resolveDeveloperDirectoryURL()
    }

    func derivedDataURL() throws -> URL {
        let customDerivedDataLocation = userDefaults?.string(forKey: Constants.customDerivedDataLocationKey)
        let xcodePath = customDerivedDataLocation ?? Constants.defaultDerivedDataLocation
        return URL(expandingPath: xcodePath)
    }

    func relativeIndexStorePath() throws -> String {
        let version = try xcodeVersion()
        return if version.starts(with: "13") {
            Constants.legacyIndexStoreRootPath
        } else {
            Constants.indexStoreRootPath
        }
    }

    func indexStoreLibraryURL() throws -> URL {
        let indexStoreLibraryURL = try resolveDeveloperDirectoryURL()
            .appendingPathComponent(Constants.indexStoreLibraryPath)

        if fileManager.fileExists(atPath: indexStoreLibraryURL.path) {
            return indexStoreLibraryURL
        } else {
            throw XcodeSettingsError.missingIndexStoreLibrary(indexStoreLibraryURL)
        }
    }

    private func xcodeVersion() throws -> String {
        let infoPlistURL = try resolveDeveloperDirectoryURL()
            .deletingLastPathComponent()
            .appendingPathComponent(Constants.xcodeInfoPlistName)
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard
            let values = plist as? [String: Any],
            let version = values[Constants.xcodeVersionKey] as? String
        else {
            throw XcodeSettingsError.missingXcodeVersion(infoPlistURL)
        }

        return version
    }

    private func resolveDeveloperDirectoryURL() throws -> URL {
        if let developerDirectoryURL {
            return developerDirectoryURL
        }

        let developerDirectoryPath: String
        if let configuredPath = environment["DEVELOPER_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines), !configuredPath.isEmpty {
            developerDirectoryPath = configuredPath
        } else {
            do {
                let output = try processRunner.run(
                    ProcessCommand(executableURL: Constants.xcodeSelectURL, arguments: ["-p"])
                )
                developerDirectoryPath = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                throw XcodeSettingsError.missingCommandLineTools
            }
        }

        guard !developerDirectoryPath.isEmpty else {
            throw XcodeSettingsError.missingCommandLineTools
        }

        let resolvedURL = URL(expandingPath: developerDirectoryPath)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw XcodeSettingsError.invalidDeveloperDirectory(resolvedURL)
        }

        developerDirectoryURL = resolvedURL
        return resolvedURL
    }
}
