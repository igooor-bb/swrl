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

    init(path: String) {
        url = URL(expandingPath: path)
    }

    init?(argument: String) {
        self.init(path: argument)
    }
}
