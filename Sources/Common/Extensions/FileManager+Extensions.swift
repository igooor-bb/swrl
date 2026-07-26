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
