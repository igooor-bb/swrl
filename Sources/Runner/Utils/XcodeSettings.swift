//
//  XcodeSettings.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 07.04.2025.
//

import Foundation
import SymbolsResolver

enum XcodeSettingsError: Error, CustomStringConvertible {
    case missingCommandLineTools
    case missingIndexStoreLibrary
    case missingDerivedDataLocation

    var description: String {
        switch self {
        case .missingCommandLineTools:
            "Missing Xcode or Xcode Command Line Tools."

        case .missingIndexStoreLibrary:
            "Unable to find indexStore.dylib path. Please ensure that Xcode is installed correctly."

        case .missingDerivedDataLocation:
            "Unable to find DerivedData location. Please ensure that Xcode is installed correctly."
        }
    }
}

final class XcodeSettings: XcodeSettingsProviding {

    private enum Constants {
        static let xcodeDefaultsSuiteName = "com.apple.dt.Xcode.plist"
        static let customDerivedDataLocationKey = "IDECustomDerivedDataLocation"
        static let defaultDerivedDataLocation = "~/Library/Developer/Xcode/DerivedData"
        static let indexStoreLibraryPath = "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        static let xcodeInfoPlistPath = "Contents/Info.plist"
        static let indexStoreRootPath = "Index.noindex"
        static let legacyIndexStoreRootPath = "Index"
    }

    private let userDefaults = UserDefaults(suiteName: Constants.xcodeDefaultsSuiteName)
    private let shell: ShellCommandExecuting
    private var activeXcodeURL: URL!

    init(shell: ShellCommandExecuting) {
        self.shell = shell
    }

    func ensureXcodeCommandLineToolsInstalled() throws {
        do {
            let activeXcodePath = try shell.run("xcode-select -p")
            activeXcodeURL = URL(expandingPath: activeXcodePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        } catch {
            switch error {
            case .executionFailed:
                throw XcodeSettingsError.missingCommandLineTools

            default:
                throw error
            }
        }
    }

    func derivedDataURL() throws -> URL {
        let customDerivedDataLocation = userDefaults?.string(forKey: Constants.customDerivedDataLocationKey)
        let xcodePath = customDerivedDataLocation ?? Constants.defaultDerivedDataLocation
        let xcodeURL = URL(expandingPath: xcodePath)

        if FileManager.default.fileExists(atURL: xcodeURL) {
            return xcodeURL
        } else {
            throw XcodeSettingsError.missingDerivedDataLocation
        }
    }

    func relativeIndexStorePath() throws -> String {
        let version = try xcodeVersion()
        let path = if version.starts(with: "13") {
            Constants.legacyIndexStoreRootPath
        } else {
            Constants.indexStoreRootPath
        }
        return path
    }

    func indexStoreLibraryURL() throws -> URL {
        let indexStoreLibraryURL = activeXcodeURL
            .appendingPathComponent(Constants.indexStoreLibraryPath)

        if FileManager.default.fileExists(atURL: indexStoreLibraryURL) {
            return indexStoreLibraryURL
        } else {
            throw XcodeSettingsError.missingIndexStoreLibrary
        }
    }

    private func xcodeVersion() throws -> String {
        let infoPlistURL = activeXcodeURL.appendingPathComponent(Constants.xcodeInfoPlistPath)
        let version = try shell.run("/usr/libexec/PlistBuddy -c \"Print CFBundleShortVersionString\" \(infoPlistURL.path)")
        return version
    }
}
