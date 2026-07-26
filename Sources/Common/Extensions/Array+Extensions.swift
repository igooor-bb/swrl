import Foundation

public extension Array where Element: Equatable {
    func isPrefix(to collection: [Element]) -> Bool {
        guard count <= collection.count else { return false }
        return self == Array(collection.prefix(count))
    }
}
