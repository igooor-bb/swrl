import Foundation
import Testing
@testable import SWRLCore

@Suite("Project index locator")
struct ProjectIndexLocatorTests {
    @Test("An explicit IndexStore has priority over an explicit DerivedData directory")
    func prioritizesIndexStoreOverride() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App.xcodeproj")
        let indexStore = try fixture.createIndexStore(named: "Manual Index.noindex")
        let missingDerivedData = fixture.root.appendingPathComponent("Missing DerivedData")
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        let result = try locator.locate(
            projectURL: project,
            derivedDataOverride: missingDerivedData,
            indexStoreOverride: indexStore
        )

        #expect(result.derivedDataURL == nil)
        #expect(result.indexStoreURL == indexStore.standardizedFileURL)
    }

    @Test("An explicit DerivedData directory resolves its IndexStore")
    func usesDerivedDataOverride() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App.xcodeproj")
        let derivedData = fixture.root.appendingPathComponent("Manual DerivedData")
        let indexStore = try fixture.createIndexStore(
            named: "Index.noindex",
            under: derivedData
        )
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        let result = try locator.locate(
            projectURL: project,
            derivedDataOverride: derivedData
        )

        #expect(result.derivedDataURL == derivedData.standardizedFileURL)
        #expect(result.indexStoreURL == indexStore.standardizedFileURL)
    }

    @Test("Finds a workspace index under a custom DerivedData path with spaces")
    func findsWorkspaceInCustomRoot() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App Workspace.xcworkspace")
        let derivedData = try fixture.createDerivedData(
            named: "Arbitrary-Hash",
            workspaceURL: project,
            dataStoreDate: Date(timeIntervalSince1970: 100)
        )
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        let result = try locator.locate(projectURL: project)

        #expect(result.projectURL == project.standardizedFileURL)
        #expect(result.derivedDataURL == derivedData.standardizedFileURL)
        #expect(result.indexStoreURL == derivedData.appendingPathComponent("Index.noindex").standardizedFileURL)
    }

    @Test("Matches an Xcode project's internal workspace")
    func matchesProjectWorkspace() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "Application.xcodeproj")
        let internalWorkspace = project.appendingPathComponent("project.xcworkspace")
        try FileManager.default.createDirectory(at: internalWorkspace, withIntermediateDirectories: true)
        let derivedData = try fixture.createDerivedData(
            named: "Unrelated-Directory-Name",
            workspaceURL: internalWorkspace,
            dataStoreDate: Date(timeIntervalSince1970: 100)
        )
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        let result = try locator.locate(projectURL: project)

        #expect(result.derivedDataURL == derivedData.standardizedFileURL)
    }

    @Test("Selects the newest usable index deterministically")
    func selectsNewestUsableIndex() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App.xcworkspace")
        _ = try fixture.createDerivedData(
            named: "Newest-But-Missing-DataStore",
            workspaceURL: project,
            dataStoreDate: nil
        )
        _ = try fixture.createDerivedData(
            named: "Older-Valid",
            workspaceURL: project,
            dataStoreDate: Date(timeIntervalSince1970: 100)
        )
        let newest = try fixture.createDerivedData(
            named: "Newer-Valid",
            workspaceURL: project,
            dataStoreDate: Date(timeIntervalSince1970: 200)
        )
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        let result = try locator.locate(projectURL: project)

        #expect(result.derivedDataURL == newest.standardizedFileURL)
    }

    @Test("Reports a missing DataStore separately from missing DerivedData")
    func reportsMissingDataStore() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App.xcworkspace")
        let derivedData = try fixture.createDerivedData(
            named: "Matching-But-Unindexed",
            workspaceURL: project,
            dataStoreDate: nil
        )
        let expectedIndexStore = derivedData.appendingPathComponent("Index.noindex").standardizedFileURL
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        #expect(throws: ProjectIndexLocatorError.dataStoreNotFound(indexStore: expectedIndexStore)) {
            try locator.locate(projectURL: project)
        }
    }

    @Test("Reports a missing project before searching DerivedData")
    func reportsMissingProject() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = fixture.root.appendingPathComponent("Missing.xcodeproj").standardizedFileURL
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        #expect(throws: ProjectIndexLocatorError.projectNotFound(project)) {
            try locator.locate(projectURL: project)
        }
    }

    @Test("Reports when no DerivedData belongs to the project")
    func reportsMissingDerivedData() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App.xcodeproj")
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        #expect(
            throws: ProjectIndexLocatorError.derivedDataNotFound(
                project: project.standardizedFileURL,
                searchRoot: fixture.derivedDataRoot.standardizedFileURL
            )
        ) {
            try locator.locate(projectURL: project)
        }
    }

    @Test("Reports a missing DerivedData root")
    func reportsMissingDerivedDataRoot() throws {
        let fixture = try LocatorFixture()
        defer { fixture.remove() }
        let project = try fixture.createProject(named: "App.xcodeproj")
        try FileManager.default.removeItem(at: fixture.derivedDataRoot)
        let locator = ProjectIndexLocator(
            xcodeSettings: StubXcodeSettings(derivedDataRoot: fixture.derivedDataRoot)
        )

        #expect(
            throws: ProjectIndexLocatorError.derivedDataRootNotFound(fixture.derivedDataRoot.standardizedFileURL)
        ) {
            try locator.locate(projectURL: project)
        }
    }
}

private struct StubXcodeSettings: DerivedDataRootProviding {
    let derivedDataRoot: URL

    func derivedDataURL() throws -> URL {
        derivedDataRoot
    }
}

private final class LocatorFixture {
    let root: URL
    let derivedDataRoot: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        derivedDataRoot = root.appendingPathComponent("Custom Derived Data")
        try FileManager.default.createDirectory(at: derivedDataRoot, withIntermediateDirectories: true)
    }

    func createProject(named name: String) throws -> URL {
        let projectURL = root
            .appendingPathComponent("Projects With Spaces")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        return projectURL.standardizedFileURL
    }

    func createDerivedData(
        named name: String,
        workspaceURL: URL,
        dataStoreDate: Date?
    ) throws -> URL {
        let derivedDataURL = derivedDataRoot.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: derivedDataURL, withIntermediateDirectories: true)

        let infoPlistURL = derivedDataURL.appendingPathComponent("info.plist")
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: ["WorkspacePath": workspaceURL.path],
            format: .xml,
            options: 0
        )
        try plistData.write(to: infoPlistURL)

        if let dataStoreDate {
            let dataStoreURL = derivedDataURL.appendingPathComponent("Index.noindex/DataStore")
            try FileManager.default.createDirectory(at: dataStoreURL, withIntermediateDirectories: true)
            try FileManager.default.setAttributes(
                [.modificationDate: dataStoreDate],
                ofItemAtPath: dataStoreURL.path
            )
        }

        return derivedDataURL
    }

    func createIndexStore(
        named name: String,
        under parent: URL? = nil
    ) throws -> URL {
        let indexStoreURL = (parent ?? root).appendingPathComponent(name)
        let dataStoreURL = indexStoreURL.appendingPathComponent("DataStore")
        try FileManager.default.createDirectory(at: dataStoreURL, withIntermediateDirectories: true)
        return indexStoreURL
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
