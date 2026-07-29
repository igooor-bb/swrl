import Common
import Foundation

public enum ResolvedSymbolOrigin: Equatable, Sendable {
    case externalModule(String)
    case internalToModule
    case system
    case unknown
}

public struct SymbolResolution: Equatable, Sendable {
    public let targetSymbol: SyntaxSymbolOccurrence
    public let origin: ResolvedSymbolOrigin
    public let originKind: SymbolDefinitionKind
}

extension SymbolResolution {
    static func resolvedSymbol(
        _ symbol: SyntaxSymbolOccurrence,
        indexOccurrence occurrence: IndexedSymbolOccurrence,
        currentModuleName: String
    ) -> SymbolResolution {
        let foundModuleName = occurrence.moduleName
        let origin: ResolvedSymbolOrigin = if occurrence.isSystem {
            .system
        } else if foundModuleName == currentModuleName {
            .internalToModule
        } else {
            .externalModule(foundModuleName)
        }

        return SymbolResolution(
            targetSymbol: symbol,
            origin: origin,
            originKind: occurrence.kind
        )
    }

    static func system(
        symbol: SyntaxSymbolOccurrence
    ) -> SymbolResolution {
        SymbolResolution(
            targetSymbol: symbol,
            origin: .system,
            originKind: .unknown
        )
    }

    static func external(
        symbol: SyntaxSymbolOccurrence,
        originKind: SymbolDefinitionKind,
        dependency: String
    ) -> SymbolResolution {
        SymbolResolution(
            targetSymbol: symbol,
            origin: .externalModule(dependency),
            originKind: originKind
        )
    }

    static func `internal`(
        symbol: SyntaxSymbolOccurrence,
        originKind: SymbolDefinitionKind,
        currentModuleName _: String
    ) -> SymbolResolution {
        SymbolResolution(
            targetSymbol: symbol,
            origin: .internalToModule,
            originKind: originKind
        )
    }

    static func unknown(
        symbol: SyntaxSymbolOccurrence
    ) -> SymbolResolution {
        SymbolResolution(
            targetSymbol: symbol,
            origin: .unknown,
            originKind: .unknown
        )
    }
}
