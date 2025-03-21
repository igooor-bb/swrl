//
//  ProjectDerivedData.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 21.03.2025.
//

import Darwin
import Foundation
import SymbolsResolver

enum CommandLineToolError: Error, CustomStringConvertible {
    case invalidPath(String)
    case directoryNotFound(String)
    case plistReadError(String)
    case derivedDataNotFound

    var description: String {
        switch self {
        case let .invalidPath(path):
            "Invalid path: \(path)"

        case let .directoryNotFound(path):
            "Directory not found: \(path)"

        case let .plistReadError(path):
            "Failed to read plist at: \(path)"

        case .derivedDataNotFound:
            "Derived data path not found."
        }
    }
}

protocol ProjectDerivedDataProviding {
    func findForProject(at url: URL) throws -> URL
}

final class ProjectDerivedDataFinder: ProjectDerivedDataProviding {

    private enum Constants {
        static let derivedDataInfoPlistName = "info.plist"
        static let derivedDataWorkspacePathKey = "WorkspacePath"
    }

    private let xcodeSettings: XcodeSettingsProviding

    init(xcodeSettings: XcodeSettingsProviding) {
        self.xcodeSettings = xcodeSettings
    }

    private func readPlist(at url: URL) throws -> [String: Any]? {
        let data = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
    }

    // MARK: Interface

    func findForProject(at xcodeProjectURL: URL) throws -> URL {
        let derivedDataURL = try xcodeSettings.derivedDataURL()
        let derivedDataContents = try FileManager.default.contentsOfDirectory(
            at: derivedDataURL,
            includingPropertiesForKeys: nil
        )

        let projectName = xcodeProjectURL.deletingPathExtension().lastPathComponent
        let prefix = projectName + "-"

        for directoryURL in derivedDataContents where directoryURL.lastPathComponent.hasPrefix(prefix) {
            let infoPlistURL = directoryURL.appendingPathComponent(Constants.derivedDataInfoPlistName)

            do {
                guard
                    let plist = try readPlist(at: infoPlistURL),
                    let projectPathFromManifest = plist[Constants.derivedDataWorkspacePathKey] as? String
                else {
                    continue
                }

                let urlFromManifest = URL(expandingPath: projectPathFromManifest)
                if xcodeProjectURL == urlFromManifest {
                    return directoryURL
                }
            } catch {
                continue
            }
        }

        throw CommandLineToolError.derivedDataNotFound
    }
}
