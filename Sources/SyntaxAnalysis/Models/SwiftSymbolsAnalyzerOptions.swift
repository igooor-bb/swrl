//
//  SwiftSymbolsAnalyzerOptions.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 04.04.2025.
//

import Foundation

public struct SwiftSymbolsAnalyzerOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let includeDefinitions = SwiftSymbolsAnalyzerOptions(rawValue: 1 << 0)
    public static let includeUsages = SwiftSymbolsAnalyzerOptions(rawValue: 1 << 1)
}
