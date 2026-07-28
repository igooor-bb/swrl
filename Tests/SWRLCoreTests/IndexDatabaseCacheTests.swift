import Foundation
import Testing
@testable import SWRLCore

@Suite("Index database cache")
struct IndexDatabaseCacheTests {
    @Test("Identical inputs produce a stable cache key")
    func producesStableKey() {
        let cache = IndexDatabaseCache()
        let project = URL(fileURLWithPath: "/Projects/App.xcodeproj")
        let indexStore = URL(fileURLWithPath: "/DerivedData/App/Index.noindex")
        let xcode = URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")

        let first = cache.cacheKey(
            projectURL: project,
            indexStoreURL: indexStore,
            activeXcodeURL: xcode
        )
        let second = cache.cacheKey(
            projectURL: project,
            indexStoreURL: indexStore,
            activeXcodeURL: xcode
        )

        #expect(first == second)
        #expect(first.count == 64)
    }

    @Test("Projects with the same name at different paths do not collide")
    func separatesProjects() {
        let cache = IndexDatabaseCache()
        let first = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/One/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )
        let second = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/Two/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )

        #expect(first != second)
    }

    @Test("Different IndexStores do not collide")
    func separatesIndexStores() {
        let cache = IndexDatabaseCache()
        let first = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/One/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )
        let second = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/Two/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )

        #expect(first != second)
    }

    @Test("Different active Xcode installations do not collide")
    func separatesXcodeInstallations() {
        let cache = IndexDatabaseCache()
        let first = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )
        let second = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode-beta.app/Contents/Developer")
        )

        #expect(first != second)
    }

    @Test("Equivalent normalized paths share a key")
    func normalizesPaths() {
        let cache = IndexDatabaseCache()
        let first = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/Folder/../App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/./App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )
        let second = cache.cacheKey(
            projectURL: URL(fileURLWithPath: "/Projects/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )

        #expect(first == second)
    }

    @Test("Database URLs are created under the configured cache root")
    func createsDatabaseURLUnderRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = IndexDatabaseCache(rootURL: root)

        let databaseURL = try cache.databaseURL(
            projectURL: URL(fileURLWithPath: "/Projects/App.xcodeproj"),
            indexStoreURL: URL(fileURLWithPath: "/DerivedData/App/Index.noindex"),
            activeXcodeURL: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer")
        )

        #expect(databaseURL.deletingLastPathComponent().path == root.path)
        #expect(FileManager.default.fileExists(atPath: root.path))
    }
}
