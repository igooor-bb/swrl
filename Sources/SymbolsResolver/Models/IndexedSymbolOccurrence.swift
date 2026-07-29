import Common
import Foundation

struct IndexedSymbolOccurrence: Hashable, Sendable {
    let usr: String
    let moduleName: String
    let isSystem: Bool
    let kind: SymbolDefinitionKind
}

enum SymbolIndexLookup: Sendable {
    case resolved([IndexedSymbolOccurrence])
    case system
    case undefined
}
