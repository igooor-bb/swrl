import Common
import Foundation
import IndexStoreDB

extension SymbolDefinitionKind {
    init(from indexSymbolKind: IndexSymbolKind) {
        switch indexSymbolKind {
        case .class:
            self = .class

        case .protocol:
            self = .protocol

        case .struct:
            self = .struct

        case .enum:
            self = .enum

        case .typealias:
            self = .typealias

        case .macro:
            self = .macro

        default:
            self = .unknown
        }
    }
}
