import Common
import Foundation

struct SymbolResolutionEngine: Sendable {
    func resolve(
        _ symbol: SyntaxSymbolOccurrence,
        lookup: SymbolIndexLookup,
        imports: Set<String>,
        currentModuleName: String
    ) -> SymbolResolution? {
        if let qualifiedResolution = resolveQualifiedSymbol(
            symbol,
            lookup: lookup,
            imports: imports,
            currentModuleName: currentModuleName
        ) {
            return qualifiedResolution
        }

        switch lookup {
        case let .resolved(possibleOccurrences):
            return resolve(
                symbol,
                among: possibleOccurrences,
                imports: imports,
                currentModuleName: currentModuleName
            )

        case .system:
            return .system(symbol: symbol)

        case .undefined:
            return nil
        }
    }

    private func resolve(
        _ symbol: SyntaxSymbolOccurrence,
        among possibleOccurrences: [IndexedSymbolOccurrence],
        imports: Set<String>,
        currentModuleName: String
    ) -> SymbolResolution? {
        let relatedOccurrences = possibleOccurrences
            .filter { imports.contains(rootModuleName(of: $0.moduleName)) }
            .sorted(by: occurrencePrecedes)

        let filteredOccurrences = relatedOccurrences.reduce((Set<String>(), [IndexedSymbolOccurrence]())) { accumulator, occurrence in
            var (usrSet, filteredOccurrences) = accumulator
            if !usrSet.contains(occurrence.usr) {
                usrSet.insert(occurrence.usr)
                filteredOccurrences.append(occurrence)
            }
            return (usrSet, filteredOccurrences)
        }.1

        if let currentModuleCandidate = filteredOccurrences.first(where: { $0.moduleName == currentModuleName }) {
            return .resolvedSymbol(
                symbol,
                indexOccurrence: currentModuleCandidate,
                currentModuleName: currentModuleName
            )
        }

        let exactImportedCandidates = filteredOccurrences.filter { imports.contains($0.moduleName) }
        let exactImportedModules = Set(exactImportedCandidates.map(\.moduleName))
        if exactImportedModules.count == 1, let exactImportedCandidate = exactImportedCandidates.first {
            return .resolvedSymbol(
                symbol,
                indexOccurrence: exactImportedCandidate,
                currentModuleName: currentModuleName
            )
        } else if exactImportedModules.count > 1 {
            return .unknown(symbol: symbol)
        }

        let uniqueModules = Set(filteredOccurrences.map(\.moduleName))
        if uniqueModules.isEmpty {
            return nil
        } else if uniqueModules.count > 1 {
            return .unknown(symbol: symbol)
        } else {
            let finalOccurrence = filteredOccurrences[0]
            return .resolvedSymbol(
                symbol,
                indexOccurrence: finalOccurrence,
                currentModuleName: currentModuleName
            )
        }
    }

    private func resolveQualifiedSymbol(
        _ symbol: SyntaxSymbolOccurrence,
        lookup: SymbolIndexLookup,
        imports: Set<String>,
        currentModuleName: String
    ) -> SymbolResolution? {
        guard
            let fullyQualifiedName = symbol.fullyQualifiedName,
            let qualifiedModuleName = fullyQualifiedName.components(separatedBy: ".").first,
            imports.contains(qualifiedModuleName)
        else {
            return nil
        }

        if qualifiedModuleName == currentModuleName {
            let currentModuleCandidate = lookup.occurrences
                .filter { $0.moduleName == currentModuleName }
                .sorted(by: occurrencePrecedes)
                .first
            return if let currentModuleCandidate {
                .resolvedSymbol(
                    symbol,
                    indexOccurrence: currentModuleCandidate,
                    currentModuleName: currentModuleName
                )
            } else {
                .internal(
                    symbol: symbol,
                    originKind: .unknown,
                    currentModuleName: currentModuleName
                )
            }
        }

        if case .system = lookup {
            return .system(symbol: symbol)
        }

        let moduleCandidates = lookup.occurrences
            .filter { rootModuleName(of: $0.moduleName) == qualifiedModuleName }
            .sorted(by: occurrencePrecedes)
        let exactCandidates = moduleCandidates.filter { $0.moduleName == qualifiedModuleName }
        if let exactCandidate = exactCandidates.first {
            return .resolvedSymbol(
                symbol,
                indexOccurrence: exactCandidate,
                currentModuleName: currentModuleName
            )
        }

        let candidateModules = Set(moduleCandidates.map(\.moduleName))
        if candidateModules.count == 1, let candidate = moduleCandidates.first {
            return .resolvedSymbol(
                symbol,
                indexOccurrence: candidate,
                currentModuleName: currentModuleName
            )
        } else if candidateModules.count > 1 {
            return .unknown(symbol: symbol)
        }

        return .external(
            symbol: symbol,
            originKind: .unknown,
            dependency: qualifiedModuleName
        )
    }

    private func rootModuleName(of moduleName: String) -> String {
        moduleName.components(separatedBy: ".")[0]
    }

    private func occurrencePrecedes(_ lhs: IndexedSymbolOccurrence, _ rhs: IndexedSymbolOccurrence) -> Bool {
        (lhs.moduleName, lhs.usr, lhs.kind.rawValue) < (rhs.moduleName, rhs.usr, rhs.kind.rawValue)
    }
}

private extension SymbolIndexLookup {
    var occurrences: [IndexedSymbolOccurrence] {
        if case let .resolved(occurrences) = self {
            occurrences
        } else {
            []
        }
    }
}
