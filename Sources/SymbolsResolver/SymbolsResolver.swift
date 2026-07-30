import Common
import Foundation

enum SymbolResolverError: Error, CustomStringConvertible {
    case moduleNameNotFound(fileName: String)

    var description: String {
        switch self {
        case let .moduleNameNotFound(fileName):
            "Cannot determine module for the file \(fileName)."
        }
    }
}

public actor SymbolsResolver {
    private let symbolIndex: any SymbolIndexReading
    private let frameworksIndex: FrameworksIndex
    private let resolutionEngine = SymbolResolutionEngine()

    public init(
        storeURL: URL,
        databaseURL: URL,
        xcodeSettings: XcodeSettingsProviding,
        frameworksAnalyzer: FrameworkDefinitionsAnalyzer
    ) throws {
        symbolIndex = try IndexStoreDBAdapter(
            storeURL: storeURL,
            databaseURL: databaseURL,
            libraryURL: xcodeSettings.indexStoreLibraryURL()
        )
        frameworksIndex = FrameworksIndex(
            storeURL: storeURL,
            analyzer: frameworksAnalyzer
        )
    }

    public func prewarm() async throws {
        await symbolIndex.prewarm()
        try frameworksIndex.prewarm()
    }

    public func determineFileModule(fileURL: URL) async throws -> String {
        try await symbolIndex.determineFileModule(fileURL: fileURL)
    }

    public func resolveSymbols(
        _ symbols: [SyntaxSymbolOccurrence],
        relativeToModule moduleName: String,
        amongDependencies imports: Set<String>
    ) async throws -> [SymbolResolution] {
        let generalizedImports = Set(imports).union(["Foundation", moduleName])
        var orphanSymbols: Set<SyntaxSymbolOccurrence> = []
        var result: [SymbolResolution] = []

        for symbol in symbols where symbol.kind == .usage {
            let lookup = await symbolIndex.lookup(symbolName: symbol.symbolName)
            let resolution = resolutionEngine.resolve(
                symbol,
                lookup: lookup,
                imports: generalizedImports,
                currentModuleName: moduleName
            )
            if let resolution {
                result.append(resolution)
            } else {
                orphanSymbols.insert(symbol)
            }
        }

        if !orphanSymbols.isEmpty {
            let resolvedSymbols = try frameworksIndex.resolveSymbols(
                Array(orphanSymbols),
                imports: generalizedImports
            )
            for (occurrence, frameworkLookup) in resolvedSymbols {
                if case let .definition(kind) = frameworkLookup.symbol.kind {
                    let resolution = SymbolResolution.external(
                        symbol: occurrence,
                        originKind: kind,
                        dependency: frameworkLookup.frameworkName
                    )

                    orphanSymbols.remove(occurrence)
                    result.append(resolution)
                }
            }

            for occurrence in orphanSymbols {
                result.append(.unknown(symbol: occurrence))
            }
        }

        return result
    }
}
