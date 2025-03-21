//
//  XcodeSettings.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 21.03.2025.
//

import Foundation

public protocol XcodeSettingsProviding {
    func ensureXcodeCommandLineToolsInstalled() throws
    func derivedDataURL() throws -> URL
    func indexStoreLibraryURL() throws -> URL

    func relativeIndexStorePath() throws -> String
}
