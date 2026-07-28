import CryptoKit
import Foundation

struct IndexDatabaseCache {
    private enum Constants {
        static let keyVersion = "v1"
        static let cacheDirectory = "Library/Caches/swrl"
    }

    private let fileManager: FileManager
    private let rootURL: URL

    init(
        fileManager: FileManager = .default,
        rootURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.rootURL = rootURL ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(Constants.cacheDirectory)
    }

    func databaseURL(
        projectURL: URL,
        indexStoreURL: URL,
        activeXcodeURL: URL
    ) throws -> URL {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL.appendingPathComponent(
            cacheKey(
                projectURL: projectURL,
                indexStoreURL: indexStoreURL,
                activeXcodeURL: activeXcodeURL
            ),
            isDirectory: true
        )
    }

    func cacheKey(
        projectURL: URL,
        indexStoreURL: URL,
        activeXcodeURL: URL
    ) -> String {
        let identity = [
            Constants.keyVersion,
            normalizedPath(projectURL),
            normalizedPath(indexStoreURL),
            normalizedPath(activeXcodeURL),
        ].joined(separator: "\0")
        let digest = SHA256.hash(data: Data(identity.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
