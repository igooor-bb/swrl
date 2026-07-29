import Common
import Foundation

struct SymbolResolutionEngine: Sendable {
    func resolve(
        _ symbol: SyntaxSymbolOccurrence,
        lookup: SymbolIndexLookup,
        imports: Set<String>,
        currentModuleName: String
    ) -> SymbolResolution? {
        if let fqn = symbol.fullyQualifiedName {
            let fqnComponents = fqn.components(separatedBy: ".")
            let rootModuleName = fqnComponents[0]
            if imports.contains(rootModuleName) {
                return .external(
                    symbol: symbol,
                    originKind: .unknown,
                    dependency: rootModuleName
                )
            }
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
        let relatedOccurrences = possibleOccurrences.filter { occurrence in
            let fqnComponents = occurrence.moduleName.components(separatedBy: ".")
            let rootModuleName = fqnComponents[0]
            return imports.contains(rootModuleName)
        }

        let filteredOccurrences = relatedOccurrences.reduce((Set<String>(), [IndexedSymbolOccurrence]())) { accumulator, occurrence in
            var (usrSet, filteredOccurrences) = accumulator
            if !usrSet.contains(occurrence.usr) {
                usrSet.insert(occurrence.usr)
                filteredOccurrences.append(occurrence)
            }
            return (usrSet, filteredOccurrences)
        }.1

        var bestFitCandidate: IndexedSymbolOccurrence?
        for occurrence in filteredOccurrences {
            guard imports.contains(occurrence.moduleName) else { continue }
            if bestFitCandidate == nil {
                bestFitCandidate = occurrence
            } else {
                bestFitCandidate = nil
                break
            }
        }

        if let bestFitCandidate {
            return .resolvedSymbol(
                symbol,
                indexOccurrence: bestFitCandidate,
                currentModuleName: currentModuleName
            )
        }

        let uniqueModules = Set(filteredOccurrences.map(\.moduleName))
        if uniqueModules.isEmpty {
            return nil
        } else if uniqueModules.count > 1 {
            if uniqueModules.contains(currentModuleName) {
                let occurrence = filteredOccurrences.first { $0.moduleName == currentModuleName }
                return .internal(
                    symbol: symbol,
                    originKind: occurrence?.kind ?? .unknown,
                    currentModuleName: currentModuleName
                )
            } else {
                return .unknown(symbol: symbol)
            }
        } else {
            let finalOccurrence = filteredOccurrences[0]
            return .resolvedSymbol(
                symbol,
                indexOccurrence: finalOccurrence,
                currentModuleName: currentModuleName
            )
        }
    }
}
