import Foundation

public extension SyntaxSymbolOccurrence {
    static func stableOrder(_ lhs: SyntaxSymbolOccurrence, _ rhs: SyntaxSymbolOccurrence) -> Bool {
        if lhs.symbolName != rhs.symbolName {
            return lhs.symbolName < rhs.symbolName
        }
        if lhs.fullyQualifiedName != rhs.fullyQualifiedName {
            return (lhs.fullyQualifiedName ?? "") < (rhs.fullyQualifiedName ?? "")
        }
        if lhs.stableKindName != rhs.stableKindName {
            return lhs.stableKindName < rhs.stableKindName
        }
        if lhs.scopeChain != rhs.scopeChain {
            return lhs.scopeChain.lexicographicallyPrecedes(rhs.scopeChain)
        }
        return (lhs.location.line, lhs.location.column) < (rhs.location.line, rhs.location.column)
    }

    private var stableKindName: String {
        switch kind {
        case .usage:
            "usage"

        case let .definition(kind):
            "definition.\(kind.rawValue)"
        }
    }
}
