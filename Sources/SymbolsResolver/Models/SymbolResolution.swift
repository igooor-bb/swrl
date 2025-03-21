//
//  SymbolResolution.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 07.04.2025.
//

import Common
import Foundation
import struct IndexStoreDB.SymbolOccurrence

public enum ResolvedSymbolOrigin {
    case externalModule(String)
    case internalToModule
    case system
    case unknown
}

public struct SymbolResolution {
    public let targetSymbol: SyntaxSymbolOccurrence
    public let origin: ResolvedSymbolOrigin
    public let originKind: SymbolDefinitionKind
}

extension SymbolResolution {
    static func resolvedSymbol(
        _ symbol: SyntaxSymbolOccurrence,
        indexOccurrence occurrence: IndexStoreDB.SymbolOccurrence,
        currentModuleName: String
    ) -> SymbolResolution {
        let foundModuleName = occurrence.location.moduleName
        let origin: ResolvedSymbolOrigin
        
        if occurrence.location.isSystem {
            origin = .system
        } else if foundModuleName == currentModuleName {
            origin = .internalToModule
        } else {
            origin = .externalModule(foundModuleName)
        }
        
        return SymbolResolution(
            targetSymbol: symbol,
            origin: origin,
            originKind: SymbolDefinitionKind(from: occurrence.symbol.kind)
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
        currentModuleName: String
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
