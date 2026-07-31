import Darwin
import Foundation

enum GlobError: Error, CustomStringConvertible {
    case invalidRecursivePattern(String)
    case evaluationFailed(pattern: String, code: Int32)
    case traversalFailed(URL, reason: String)

    var description: String {
        switch self {
        case let .invalidRecursivePattern(pattern):
            "Invalid recursive glob pattern: \(pattern)"

        case let .evaluationFailed(pattern, code):
            "Glob evaluation failed for '\(pattern)' with code \(code)"

        case let .traversalFailed(url, reason):
            "Unable to traverse \(url.path): \(reason)"
        }
    }
}

func globFiles(pattern: String) throws -> [String] {
    if pattern.contains("**") {
        try findFilesRecursively(pattern: pattern)
    } else {
        try simpleGlob(pattern: pattern)
    }
}

private func simpleGlob(pattern: String) throws -> [String] {
    var globResult = glob_t()
    defer { globfree(&globResult) }

    let flags = GLOB_TILDE | GLOB_BRACE | GLOB_MARK
    let result = glob(pattern, flags, nil, &globResult)
    if result == 0 {
        var matches: [String] = []
        for i in 0 ..< globResult.gl_pathc {
            if let path = globResult.gl_pathv[i] {
                matches.append(String(cString: path))
            }
        }
        return matches
    } else if result == GLOB_NOMATCH {
        return []
    } else {
        throw GlobError.evaluationFailed(pattern: pattern, code: result)
    }
}

private func findFilesRecursively(pattern: String) throws -> [String] {
    let components = pattern.components(separatedBy: "**")
    guard components.count == 2 else {
        throw GlobError.invalidRecursivePattern(pattern)
    }

    let basePath = components[0].isEmpty ? "." : components[0]
    let baseURL = URL(fileURLWithPath: basePath)

    var remainingPattern = components[1]
    if !remainingPattern.isEmpty, !remainingPattern.hasPrefix("/") {
        remainingPattern = "/" + remainingPattern
    }

    var allDirectories: [URL] = []
    let fileManager = FileManager.default
    guard fileManager.fileExists(atURL: baseURL) else { return [] }

    func addDirectoriesRecursively(at url: URL) throws {
        allDirectories.append(url)
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            .sorted { $0.path < $1.path }

            for fileURL in contents {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                    try addDirectoriesRecursively(at: fileURL)
                }
            }
        } catch {
            throw GlobError.traversalFailed(url, reason: String(describing: error))
        }
    }

    try addDirectoriesRecursively(at: baseURL)

    var results: [String] = []
    for directory in allDirectories {
        let fullPattern = directory.path + remainingPattern
        let matches = try simpleGlob(pattern: fullPattern)
        results.append(contentsOf: matches)
    }

    return results
}
