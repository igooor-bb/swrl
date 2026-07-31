import Foundation

public extension FileManager {
    func fileExists(atURL url: URL) -> Bool {
        fileExists(atPath: url.path)
    }
}
