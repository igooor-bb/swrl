//
//  Glob.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 08.04.2025.
//

import Darwin
import Foundation

func globFiles(pattern: String) -> [String] {
    if pattern.contains("**") {
        findFilesRecursively(pattern: pattern)
    } else {
        simpleGlob(pattern: pattern)
    }
}

private func simpleGlob(pattern: String) -> [String] {
    var globResult = glob_t()
    defer { globfree(&globResult) }

    let flags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK
    if glob(pattern, flags, nil, &globResult) == 0 {
        var matches: [String] = []
        for i in 0..<globResult.gl_pathc {
            if let path = globResult.gl_pathv[i] {
                matches.append(String(cString: path))
            }
        }
        return matches
    }
    return []
}

private func findFilesRecursively(pattern: String) -> [String] {
    let components = pattern.components(separatedBy: "**")
    guard components.count == 2 else {
        return []
    }

    let basePath = components[0].isEmpty ? "." : components[0]
    let baseURL = URL(fileURLWithPath: basePath)

    var remainingPattern = components[1]
    if !remainingPattern.isEmpty && !remainingPattern.hasPrefix("/") {
        remainingPattern = "/" + remainingPattern
    }

    var allDirectories: [URL] = []
    let fileManager = FileManager.default

    func addDirectoriesRecursively(at url: URL) {
        do {
            allDirectories.append(url)
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            for fileURL in contents {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                    addDirectoriesRecursively(at: fileURL)
                }
            }
        } catch {
            return
        }
    }

    addDirectoriesRecursively(at: baseURL)

    var results: [String] = []
    for directory in allDirectories {
        let fullPattern = directory.path + remainingPattern
        let matches = simpleGlob(pattern: fullPattern)
        results.append(contentsOf: matches)
    }

    return results
}
