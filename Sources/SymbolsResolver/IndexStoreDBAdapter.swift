import Common
import Foundation
import IndexStoreDB

protocol SymbolIndexReading: Sendable {
    func prewarm() async
    func determineFileModule(fileURL: URL) async throws -> String
    func lookup(symbolName: String) async -> SymbolIndexLookup
}

actor IndexStoreDBAdapter: SymbolIndexReading {
    private enum Constants {
        static let dataStorePath = "DataStore"
    }

    private let database: IndexStoreDB

    init(
        storeURL: URL,
        databaseURL: URL,
        libraryURL: URL
    ) throws {
        let library = try IndexStoreLibrary(dylibPath: libraryURL.path)
        database = try IndexStoreDB(
            storePath: storeURL.appendingPathComponent(Constants.dataStorePath).path,
            databasePath: databaseURL.path,
            library: library,
            delegate: nil,
            waitUntilDoneInitializing: false,
            listenToUnitEvents: true
        )
    }

    func prewarm() async {
        database.pollForUnitChangesAndWait()
    }

    func determineFileModule(fileURL: URL) async throws -> String {
        let occurrences = database.symbolOccurrences(inFilePath: fileURL.path)
        guard let moduleName = Self.moduleName(from: occurrences) else {
            throw SymbolResolverError.moduleNameNotFound(fileName: fileURL.lastPathComponent)
        }
        return moduleName
    }

    func lookup(symbolName: String) async -> SymbolIndexLookup {
        var foundOccurrences: [SymbolOccurrence] = []
        let allowedKinds: Set<IndexSymbolKind> = [.class, .struct, .protocol, .enum, .typealias, .macro]
        database.forEachCanonicalSymbolOccurrence(
            containing: symbolName,
            anchorStart: true,
            anchorEnd: true,
            subsequence: false,
            ignoreCase: false
        ) { occurrence in
            guard Self.isResolutionCandidate(occurrence, allowedKinds: allowedKinds) else {
                return true
            }

            foundOccurrences.append(occurrence)
            return true
        }

        let indexedOccurrences = foundOccurrences.map {
            IndexedSymbolOccurrence(
                usr: $0.symbol.usr,
                moduleName: $0.location.moduleName,
                isSystem: $0.location.isSystem,
                kind: SymbolDefinitionKind(from: $0.symbol.kind)
            )
        }
        let nonSystemOccurrences = indexedOccurrences.filter { !$0.isSystem }
        if !indexedOccurrences.isEmpty, nonSystemOccurrences.isEmpty {
            return .system
        }

        if nonSystemOccurrences.isEmpty {
            return .undefined
        } else {
            return .resolved(nonSystemOccurrences)
        }
    }

    static func moduleName(from occurrences: [SymbolOccurrence]) -> String? {
        let kindsOfInterest: Set<IndexSymbolKind> = [.class, .struct, .protocol, .typealias, .enum, .extension, .function]
        return occurrences
            .filter { kindsOfInterest.contains($0.symbol.kind) && !$0.location.moduleName.isEmpty }
            .map(\.location.moduleName)
            .sorted()
            .first
    }

    static func isResolutionCandidate(
        _ occurrence: SymbolOccurrence,
        allowedKinds: Set<IndexSymbolKind> = [.class, .struct, .protocol, .enum, .typealias, .macro]
    ) -> Bool {
        allowedKinds.contains(occurrence.symbol.kind) &&
            (occurrence.roles.contains(.definition) || occurrence.roles.contains(.declaration))
    }
}
