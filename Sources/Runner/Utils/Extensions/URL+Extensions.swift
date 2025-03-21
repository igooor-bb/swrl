//
//  URL+Extensions.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 22.03.2025.
//

import Foundation

extension URL {
    init(expandingPath path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let absoluteURL = URL(fileURLWithPath: expandedPath).standardizedFileURL
        self = absoluteURL
    }
}
