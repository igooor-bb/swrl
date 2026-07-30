import ArgumentParser
import Foundation

struct InputFile: ExpressibleByArgument, Hashable, Sendable {
    let url: URL

    var name: String {
        url.lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension
    }

    var normalizedPath: String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    init(path: String) {
        url = URL(expandingPath: path)
    }

    init?(argument: String) {
        self.init(path: argument)
    }
}
