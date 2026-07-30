import Common
import Foundation
import Testing
@testable import SymbolsResolver

@Suite("Framework index")
struct FrameworksIndexTests {
    @Test("A symbol from one imported framework resolves")
    func resolvesUniqueFrameworkCandidate() throws {
        let fixture = try FrameworkFixture(names: ["FeatureKit"])
        defer { fixture.remove() }
        let index = FrameworksIndex(
            storeURL: fixture.rootURL,
            analyzer: StaticDefinitionsAnalyzer(definitions: [definition("SharedType", kind: .struct)])
        )
        index.prewarm()
        let symbol = usage("SharedType")

        let result = index.resolveSymbols([symbol], imports: ["FeatureKit"])

        #expect(result[symbol]?.frameworkName == "FeatureKit")
    }

    @Test("A symbol from multiple imported frameworks stays unresolved")
    func rejectsAmbiguousFrameworkCandidate() throws {
        let fixture = try FrameworkFixture(names: ["FeatureA", "FeatureB"])
        defer { fixture.remove() }
        let index = FrameworksIndex(
            storeURL: fixture.rootURL,
            analyzer: StaticDefinitionsAnalyzer(definitions: [definition("SharedType", kind: .class)])
        )
        index.prewarm()
        let symbol = usage("SharedType")

        let result = index.resolveSymbols([symbol], imports: ["FeatureA", "FeatureB"])

        #expect(result[symbol] == nil)
    }

    private func usage(_ name: String) -> SyntaxSymbolOccurrence {
        SyntaxSymbolOccurrence(
            symbolName: name,
            fullyQualifiedName: nil,
            kind: .usage,
            location: SyntaxSymbolLocation(line: 1, column: 1),
            scopeChain: []
        )
    }

    private func definition(
        _ name: String,
        kind: SymbolDefinitionKind
    ) -> SyntaxSymbolOccurrence {
        SyntaxSymbolOccurrence(
            symbolName: name,
            fullyQualifiedName: nil,
            kind: .definition(kind),
            location: SyntaxSymbolLocation(line: 1, column: 1),
            scopeChain: []
        )
    }
}

private struct StaticDefinitionsAnalyzer: FrameworkDefinitionsAnalyzer {
    let definitions: [SyntaxSymbolOccurrence]

    func findDefinitions(at _: URL) -> [SyntaxSymbolOccurrence] {
        definitions
    }
}

private struct FrameworkFixture {
    let rootURL: URL

    init(names: [String]) throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        for name in names {
            let moduleURL = rootURL
                .appendingPathComponent("\(name).framework", isDirectory: true)
                .appendingPathComponent("Modules", isDirectory: true)
                .appendingPathComponent("\(name).swiftmodule", isDirectory: true)
            try FileManager.default.createDirectory(at: moduleURL, withIntermediateDirectories: true)
            try "".write(
                to: moduleURL.appendingPathComponent("arm64.swiftinterface"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
