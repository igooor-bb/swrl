import Common
import Foundation
import Testing

@Suite("FileManager URL extensions")
struct FileManagerExtensionsTests {
    @Test("URLs containing spaces are checked without percent encoding")
    func findsFileAtURLContainingSpaces() throws {
        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("swrl file URL \(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Source File.swift")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data().write(to: fileURL)

        #expect(FileManager.default.fileExists(atURL: fileURL))
    }
}
