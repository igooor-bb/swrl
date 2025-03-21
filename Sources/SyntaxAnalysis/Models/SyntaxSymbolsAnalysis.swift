//
//  SyntaxSymbolsAnalysis.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 04.04.2025.
//

import Common
import Foundation

public struct SyntaxSymbolsAnalysis {
    public let symbols: [SyntaxSymbolOccurrence]
    public let imports: Set<String>
}
