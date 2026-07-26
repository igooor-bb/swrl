import Foundation

public protocol XcodeSettingsProviding {
    func ensureXcodeCommandLineToolsInstalled() throws
    func derivedDataURL() throws -> URL
    func indexStoreLibraryURL() throws -> URL

    func relativeIndexStorePath() throws -> String
}
