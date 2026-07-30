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

    public init(
        targetSymbol: SyntaxSymbolOccurrence,
        origin: ResolvedSymbolOrigin,
        originKind: SymbolDefinitionKind
    ) {
        self.targetSymbol = targetSymbol
        self.origin = origin
        self.originKind = originKind
    }

    public static func stableOrder(_ lhs: SymbolResolution, _ rhs: SymbolResolution) -> Bool {
        if lhs.targetSymbol != rhs.targetSymbol {
            return SyntaxSymbolOccurrence.stableOrder(lhs.targetSymbol, rhs.targetSymbol)
        }
        if lhs.origin.stableSortName != rhs.origin.stableSortName {
            return lhs.origin.stableSortName < rhs.origin.stableSortName
        }
        return lhs.originKind.rawValue < rhs.originKind.rawValue
    }
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

private extension ResolvedSymbolOrigin {
    var stableSortName: String {
        switch self {
        case let .externalModule(moduleName):
            "external.\(moduleName)"

        case .internalToModule:
            "internal"

        case .system:
            "system"

        case .unknown:
            "unknown"
        }
    }
}
