//
//  InputFile.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 23.03.2025.
//

import ArgumentParser
import Foundation

struct InputFile: ExpressibleByArgument {
    let url: URL

    var name: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension
    }

    init?(argument: String) {
        self.url = URL(expandingPath: argument)
    }
}
