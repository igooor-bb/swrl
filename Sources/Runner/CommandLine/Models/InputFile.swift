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
        url = URL(expandingPath: argument)
    }
}
