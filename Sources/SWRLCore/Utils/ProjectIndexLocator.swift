import Foundation

protocol DerivedDataRootProviding {
    func derivedDataURL() throws -> URL
}

extension XcodeSettings: DerivedDataRootProviding {}

struct ProjectIndexLocation: Equatable, Sendable {
    let projectURL: URL
    let derivedDataURL: URL?
    let indexStoreURL: URL
}

enum ProjectIndexLocatorError: Error, Equatable, CustomStringConvertible {
    case projectNotFound(URL)
    case derivedDataRootNotFound(URL)
    case derivedDataDirectoryNotFound(URL)
    case derivedDataNotFound(project: URL, searchRoot: URL)
    case invalidDerivedDataMetadata(URL)
    case indexStoreDirectoryNotFound(URL)
    case dataStoreNotFound(indexStore: URL)

    var description: String {
        switch self {
        case let .projectNotFound(url):
            "Project was not found at \(url.path)."

        case let .derivedDataRootNotFound(url):
            "DerivedData root was not found at \(url.path)."

        case let .derivedDataDirectoryNotFound(url):
            "DerivedData directory was not found at \(url.path)."

        case let .derivedDataNotFound(project, searchRoot):
            "No DerivedData for \(project.path) was found under \(searchRoot.path)."

        case let .invalidDerivedDataMetadata(url):
            "Unable to read DerivedData metadata at \(url.path)."

        case let .indexStoreDirectoryNotFound(url):
            "IndexStore directory was not found at \(url.path)."

        case let .dataStoreNotFound(indexStore):
            "IndexStore at \(indexStore.path) does not contain DataStore. Build the project in Xcode to generate its index; swrl does not build projects automatically."
        }
    }
}

final class ProjectIndexLocator {
    private enum Constants {
        static let derivedDataInfoPlistName = "info.plist"
        static let derivedDataWorkspacePathKey = "WorkspacePath"
        static let indexStorePath = "Index.noindex"
        static let dataStorePath = "DataStore"
    }

    private struct Candidate {
        let derivedDataURL: URL
        let indexStoreURL: URL
        let modificationDate: Date
    }

    private let fileManager: FileManager
    private let xcodeSettings: DerivedDataRootProviding

    init(
        xcodeSettings: DerivedDataRootProviding,
        fileManager: FileManager = .default
    ) {
        self.xcodeSettings = xcodeSettings
        self.fileManager = fileManager
    }

    // MARK: Interface

    func locate(
        projectURL: URL,
        derivedDataOverride: URL? = nil,
        indexStoreOverride: URL? = nil
    ) throws -> ProjectIndexLocation {
        let projectURL = normalize(projectURL)
        guard fileManager.fileExists(atPath: projectURL.path) else {
            throw ProjectIndexLocatorError.projectNotFound(projectURL)
        }

        if let indexStoreOverride {
            return try locationForIndexStoreOverride(indexStoreOverride, projectURL: projectURL)
        }

        if let derivedDataOverride {
            return try locationForDerivedDataOverride(derivedDataOverride, projectURL: projectURL)
        }

        return try automaticallyLocatedIndex(for: projectURL)
    }

    // MARK: Overrides

    private func locationForIndexStoreOverride(_ overrideURL: URL, projectURL: URL) throws -> ProjectIndexLocation {
        let indexStoreURL = normalize(overrideURL)
        guard isDirectory(indexStoreURL) else {
            throw ProjectIndexLocatorError.indexStoreDirectoryNotFound(indexStoreURL)
        }
        try validateDataStore(in: indexStoreURL)
        return ProjectIndexLocation(
            projectURL: projectURL,
            derivedDataURL: nil,
            indexStoreURL: indexStoreURL
        )
    }

    private func locationForDerivedDataOverride(_ overrideURL: URL, projectURL: URL) throws -> ProjectIndexLocation {
        let derivedDataURL = normalize(overrideURL)
        guard isDirectory(derivedDataURL) else {
            throw ProjectIndexLocatorError.derivedDataDirectoryNotFound(derivedDataURL)
        }
        let indexStoreURL = derivedDataURL.appendingPathComponent(Constants.indexStorePath)
        try validateDataStore(in: indexStoreURL)
        return ProjectIndexLocation(
            projectURL: projectURL,
            derivedDataURL: derivedDataURL,
            indexStoreURL: indexStoreURL
        )
    }

    // MARK: Automatic Discovery

    private func automaticallyLocatedIndex(for projectURL: URL) throws -> ProjectIndexLocation {
        let searchRoot = try normalize(xcodeSettings.derivedDataURL())
        guard isDirectory(searchRoot) else {
            throw ProjectIndexLocatorError.derivedDataRootNotFound(searchRoot)
        }

        let directoryURLs = try fileManager.contentsOfDirectory(
            at: searchRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var invalidMetadataURLs: [URL] = []
        var matchingDerivedDataURLs: [URL] = []
        var candidates: [Candidate] = []

        for directoryURL in directoryURLs.sorted(by: { $0.path < $1.path }) where isDirectory(directoryURL) {
            let infoPlistURL = directoryURL.appendingPathComponent(Constants.derivedDataInfoPlistName)
            guard fileManager.fileExists(atPath: infoPlistURL.path) else {
                continue
            }

            let workspaceURL: URL
            do {
                workspaceURL = try readWorkspaceURL(from: infoPlistURL)
            } catch {
                invalidMetadataURLs.append(infoPlistURL)
                continue
            }

            guard workspaceMatchesProject(workspaceURL, projectURL: projectURL) else {
                continue
            }

            let derivedDataURL = normalize(directoryURL)
            matchingDerivedDataURLs.append(derivedDataURL)
            let indexStoreURL = derivedDataURL.appendingPathComponent(Constants.indexStorePath)
            let dataStoreURL = indexStoreURL.appendingPathComponent(Constants.dataStorePath)
            guard isDirectory(dataStoreURL) else {
                continue
            }

            let modificationDate = try dataStoreURL.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate ?? .distantPast
            candidates.append(
                Candidate(
                    derivedDataURL: derivedDataURL,
                    indexStoreURL: indexStoreURL,
                    modificationDate: modificationDate
                )
            )
        }

        if let candidate = candidates.sorted(by: candidatePrecedes).first {
            return ProjectIndexLocation(
                projectURL: projectURL,
                derivedDataURL: candidate.derivedDataURL,
                indexStoreURL: candidate.indexStoreURL
            )
        }

        if let missingIndexDerivedData = matchingDerivedDataURLs.sorted(by: { $0.path < $1.path }).first {
            let indexStoreURL = missingIndexDerivedData.appendingPathComponent(Constants.indexStorePath)
            throw ProjectIndexLocatorError.dataStoreNotFound(indexStore: indexStoreURL)
        }

        if let invalidMetadataURL = invalidMetadataURLs.sorted(by: { $0.path < $1.path }).first {
            throw ProjectIndexLocatorError.invalidDerivedDataMetadata(invalidMetadataURL)
        }

        throw ProjectIndexLocatorError.derivedDataNotFound(project: projectURL, searchRoot: searchRoot)
    }

    // MARK: Helpers

    private func validateDataStore(in indexStoreURL: URL) throws {
        guard isDirectory(indexStoreURL) else {
            throw ProjectIndexLocatorError.indexStoreDirectoryNotFound(indexStoreURL)
        }
        let dataStoreURL = indexStoreURL.appendingPathComponent(Constants.dataStorePath)
        guard isDirectory(dataStoreURL) else {
            throw ProjectIndexLocatorError.dataStoreNotFound(indexStore: indexStoreURL)
        }
    }

    private func readWorkspaceURL(from infoPlistURL: URL) throws -> URL {
        let data = try Data(contentsOf: infoPlistURL)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard
            let values = plist as? [String: Any],
            let workspacePath = values[Constants.derivedDataWorkspacePathKey] as? String,
            !workspacePath.isEmpty
        else {
            throw ProjectIndexLocatorError.invalidDerivedDataMetadata(infoPlistURL)
        }
        return normalize(URL(expandingPath: workspacePath))
    }

    private func workspaceMatchesProject(_ workspaceURL: URL, projectURL: URL) -> Bool {
        if workspaceURL == projectURL {
            return true
        }

        return projectURL.pathExtension == "xcodeproj" &&
            workspaceURL.lastPathComponent == "project.xcworkspace" &&
            workspaceURL.deletingLastPathComponent() == projectURL
    }

    private func normalize(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func candidatePrecedes(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.modificationDate != rhs.modificationDate {
            return lhs.modificationDate > rhs.modificationDate
        }
        return lhs.indexStoreURL.path < rhs.indexStoreURL.path
    }
}
