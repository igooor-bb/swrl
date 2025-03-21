//
//  SymbolsResolver.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 22.03.2025.
//

import Common
import Foundation
import IndexStoreDB

enum SymbolResolverError: Error, CustomStringConvertible {
    case moduleNameNotFound(fileName: String)

    var description: String {
        switch self {
        case let .moduleNameNotFound(fileName):
            "Cannot determine module for the file \(fileName)."
        }
    }
}

public final class SymbolsResolver {
    
    // MARK: - Nested Types
    
    private typealias IndexStoreSymbolOccurrence = SymbolOccurrence
    
    private enum IndexStoreLookup {
        case resolved([IndexStoreSymbolOccurrence])
        case system
        case undefined
    }

    // MARK: Properties

    private enum Constants {
        static let dataStorePath = "DataStore"
        static let databaseName = "swrl_indexstore"
    }

    private let database: IndexStoreDB
    private let frameworksIndex: FrameworksIndex

    public init(
        storeURL: URL,
        xcodeSettings: XcodeSettingsProviding,
        frameworksAnalyzer: FrameworkDefinitionsAnalyzer
    ) throws {
        let databaseURL = FileManager.default.temporaryDirectory.appendingPathComponent(Constants.databaseName)

        let libraryPath = try xcodeSettings.indexStoreLibraryURL()
        let library = try IndexStoreLibrary(dylibPath: libraryPath.path)

        self.database = try IndexStoreDB(
            storePath: storeURL.appendingPathComponent(Constants.dataStorePath).path,
            databasePath: databaseURL.path,
            library: library,
            delegate: nil,
            waitUntilDoneInitializing: false,
            listenToUnitEvents: true
        )
        self.frameworksIndex = FrameworksIndex(
            storeURL: storeURL,
            analyzer: frameworksAnalyzer
        )
    }

    // MARK: Interface

    public func prewarm() {
        database.pollForUnitChangesAndWait()
        frameworksIndex.prewarm()
    }

    public func determineFileModule(fileURL: URL) throws -> String {
        let symbols = database.symbols(inFilePath: fileURL.path)
        let kindsOfInterest: Set<IndexSymbolKind> = [.class, .struct, .enum, .extension, .function]
        let symbolOfInterest = symbols.first { kindsOfInterest.contains($0.kind) }
        guard let symbolOfInterest else {
            throw SymbolResolverError.moduleNameNotFound(fileName: fileURL.lastPathComponent)
        }

        var mangledSymbolName = symbolOfInterest.usr
        if mangledSymbolName.hasPrefix("s:") {
            mangledSymbolName = "$s" + mangledSymbolName.dropFirst(2)
        }

        let demangledSymbolName = demangleSwiftSymbol(mangledSymbolName)
        guard demangledSymbolName != mangledSymbolName else {
            throw SymbolResolverError.moduleNameNotFound(fileName: fileURL.lastPathComponent)
        }

        let components = demangledSymbolName.components(separatedBy: ".")
        if let moduleName = components.first {
            return moduleName
        } else {
            throw SymbolResolverError.moduleNameNotFound(fileName: fileURL.lastPathComponent)
        }
    }

    public func resolveSymbols(
        _ symbols: [SyntaxSymbolOccurrence],
        relativeToModule moduleName: String,
        amongDependencies imports: Set<String>
    ) -> [SymbolResolution] {
        let generalizedImports = Set(imports).union(["Foundation", moduleName])

        // Symbols that cannot be found through IndexStore-DB (for some reason)
        // will be searched separately manually.
        var orphanSymbols: Set<SyntaxSymbolOccurrence> = []
        var result: [SymbolResolution] = []

        for symbol in symbols where symbol.kind == .usage {
            let resolutionResult = resolveSingleSymbol(
                symbol,
                imports: generalizedImports,
                currentModuleName: moduleName
            )
            if let resolutionResult {
                result.append(resolutionResult)
            } else {
                orphanSymbols.insert(symbol)
            }
        }

        if !orphanSymbols.isEmpty {
            let resolvedSymbols = frameworksIndex.resolveSymbols(
                Array(orphanSymbols),
                imports: generalizedImports
            )
            for (occ, frameworkLookup) in resolvedSymbols {
                if case let .definition(kind) = frameworkLookup.symbol.kind {
                    let resolution = SymbolResolution.external(
                        symbol: occ,
                        originKind: kind,
                        dependency: frameworkLookup.frameworkName
                    )

                    orphanSymbols.remove(occ)
                    result.append(resolution)
                }
            }

            for occ in orphanSymbols {
                result.append(.unknown(symbol: occ))
            }
        }

        return result
    }

    private func resolveSingleSymbol(
        _ symbol: SyntaxSymbolOccurrence,
        imports: Set<String>,
        currentModuleName: String
    ) -> SymbolResolution? {

        // If the module name is explicitly specified when using, we can immediately resolve it.
        if let fqn = symbol.fullyQualifiedName {
            let fqnComponents = fqn.components(separatedBy: ".")
            let rootModuleName = fqnComponents[0]
            if imports.contains(rootModuleName) {
                return .external(
                    symbol: symbol,
                    originKind: .unknown, // TODO: Resolve actual kind.
                    dependency: rootModuleName
                )
            }
        }

        let symbolResolutionResult: SymbolResolution?
        let lookupResult = findIndexStoreSymbolOccurrences(symbol: symbol)

        switch lookupResult {
        case let .resolved(possibleOccurrences):

            // Looking for occurrences that fit the modules used.
            // A symbol module can (but not have to) consist of several parts separated by a period.
            // Example: Foundation.NSFileCoordinator
            let relatedOccurrences = possibleOccurrences.filter { occurrence in
                let fqn = occurrence.location.moduleName
                let fqnComponents = fqn.components(separatedBy: ".")
                let rootModuleName = fqnComponents[0]
                return imports.contains(rootModuleName)
            }

            // Remove duplicate occurrences, considering the USR to be unique identifier.
            let filteredOccurrences = relatedOccurrences.reduce((Set<String>(), [IndexStoreSymbolOccurrence]())) { (acc, occ) in
                var (usrSet, filteredOccurrences) = acc
                if !usrSet.contains(occ.symbol.usr) {
                    usrSet.insert(occ.symbol.usr)
                    filteredOccurrences.append(occ)
                }
                return (usrSet, filteredOccurrences)
            }.1

            // Consider the module, which is clearly among the imports,
            // to be the best candidate.
            var bestFitCandidate: IndexStoreSymbolOccurrence?
            for occ in filteredOccurrences {
                guard imports.contains(occ.location.moduleName) else { continue }
                if bestFitCandidate == nil {
                    bestFitCandidate = occ
                } else {
                    // If there are several such modules,
                    // then we believe that there is no the best candidate.
                    bestFitCandidate = nil
                    break
                }
            }

            if let bestFitCandidate {
                symbolResolutionResult = .resolvedSymbol(
                    symbol,
                    indexOccurrence: bestFitCandidate,
                    currentModuleName: currentModuleName
                )
                break
            }

            let uniqueModules = Set(filteredOccurrences.map(\.location.moduleName))

            if uniqueModules.isEmpty {
                symbolResolutionResult = nil
            } else if uniqueModules.count > 1 {
                if uniqueModules.contains(currentModuleName) {
                    // If there are several candidates for symbol resolution,
                    // we give priority to the current module.
                    let occ = filteredOccurrences.first { $0.location.moduleName == currentModuleName }
                    // TODO: Resolve shadowed types of typealias if it is defined in same module.
                    let indexKind = occ?.symbol.kind ?? .unknown
                    symbolResolutionResult = .internal(
                        symbol: symbol,
                        originKind: SymbolDefinitionKind(from: indexKind),
                        currentModuleName: currentModuleName
                    )
                } else {
                    // If there are several candidates for symbol resolution,
                    // but current module does not contain such symbol, this is actually
                    // an invalid state for building the project, because even Xcode will not
                    // be able to determine the desired symbol among several imports.
                    symbolResolutionResult = .unknown(symbol: symbol)
                }
            } else {
                let finalOccurrence = filteredOccurrences[0]
                let foundModuleName = finalOccurrence.location.moduleName
                symbolResolutionResult = .resolvedSymbol(
                    symbol,
                    indexOccurrence: finalOccurrence,
                    currentModuleName: foundModuleName
                )
            }

        case .system:
            symbolResolutionResult = .system(symbol: symbol)

        case .undefined:
            symbolResolutionResult = nil
        }

        return symbolResolutionResult
    }

    private func findIndexStoreSymbolOccurrences(symbol: SyntaxSymbolOccurrence) -> IndexStoreLookup {
        var foundOccurrences: [IndexStoreSymbolOccurrence] = []
        let allowedKinds: Set<IndexSymbolKind> = [.class, .struct, .protocol, .enum, .typealias, .macro]
        database.forEachCanonicalSymbolOccurrence(
            containing: symbol.symbolName,
            anchorStart: true,
            anchorEnd: true,
            subsequence: false,
            ignoreCase: false
        ) { occurrence in
            guard
                allowedKinds.contains(occurrence.symbol.kind) &&
                occurrence.roles.contains(.definition) || occurrence.roles.contains(.declaration) else {
                return true
            }

            foundOccurrences.append(occurrence)
            return true
        }

        // If occurrences are found only in system libraries,
        // we consider the dependency to be system.
        let filteredOccurrences = foundOccurrences.filter { !$0.location.isSystem }
        if !foundOccurrences.isEmpty && filteredOccurrences.isEmpty {
            return IndexStoreLookup.system
        }

        if filteredOccurrences.isEmpty {
            return IndexStoreLookup.undefined
        } else {
            return IndexStoreLookup.resolved(filteredOccurrences)
        }
    }
}
