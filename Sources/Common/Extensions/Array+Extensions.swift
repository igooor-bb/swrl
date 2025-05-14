//
//  Array+Extensions.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 07.05.2025.
//

import Foundation

public extension Array where Element: Equatable {
    func isPrefix(to collection: [Element]) -> Bool {
        guard self.count <= collection.count else { return false }
        return self == Array(collection.prefix(self.count))
    }
}
