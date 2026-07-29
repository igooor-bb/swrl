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
        let symbols = database.symbols(inFilePath: fileURL.path)
        let kindsOfInterest: Set<IndexSymbolKind> = [.class, .struct, .protocol, .typealias, .enum, .extension, .function]
        let symbolOfInterest = symbols.first { kindsOfInterest.contains($0.kind) }

        guard let symbolOfInterest, let moduleName = extractSymbolName(from: symbolOfInterest.usr) else {
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
            guard
                allowedKinds.contains(occurrence.symbol.kind) &&
                occurrence.roles.contains(.definition) || occurrence.roles.contains(.declaration)
            else {
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

    private func extractSymbolName(from usr: String) -> String? {
        guard
            usr.hasPrefix("s:"),
            let mangledSymbolName = usr.components(separatedBy: ":").last
        else {
            return nil
        }

        let demangledSymbolName = demangleSwiftSymbol("$s" + mangledSymbolName)
        guard demangledSymbolName != mangledSymbolName else {
            return nil
        }

        let components = demangledSymbolName.components(separatedBy: ".")
        return components.first
    }
}
