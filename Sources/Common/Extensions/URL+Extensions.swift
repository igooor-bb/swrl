import Foundation

public extension URL {
    init(expandingPath path: String) {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let absoluteURL = URL(fileURLWithPath: expandedPath).standardizedFileURL
        self = absoluteURL
    }
}
