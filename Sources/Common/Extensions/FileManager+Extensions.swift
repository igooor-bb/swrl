//
//  FileManager+Extensions.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 22.03.2025.
//

import Foundation

public extension FileManager {
    func fileExists(atURL url: URL) -> Bool {
        if #available(macOS 13.0, *) {
            fileExists(atPath: url.path())
        } else {
            fileExists(atPath: url.path)
        }
    }
}
