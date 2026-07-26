import Common
import SwiftParser
import SwiftSyntax
import Testing
@testable import SyntaxAnalysis

@Suite("Imports")
struct ImportSymbolTests {
    // MARK: - Setup

    private func visitor() -> SyntaxSymbolsVisitor {
        SyntaxSymbolsVisitor()
    }

    private func node(_ content: String) -> SourceFileSyntax {
        SwiftParser.Parser.parse(source: content)
    }

    // MARK: - Tests

    @Test(
        "Basic module import.",
        .tags(.symbolKind.import)
    )
    func simpleImport() {
        let sut = visitor()
        let node = node("import Foundation")
        let result = sut.parseSymbols(node: node, fileName: "")

        #expect(result.imports == Set(["Foundation"]))
        #expect(result.symbolOccurrences.isEmpty)
    }

    @Test(
        "Multiple module imports.",
        .tags(.symbolKind.import)
    )
    func multipleImports() {
        let sut = visitor()
        let node = node("""
        import Foundation
        import UIKit
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        #expect(result.imports == Set(["Foundation", "UIKit"]))
        #expect(result.symbolOccurrences.isEmpty)
    }

    @Test("Qualified module import.")
    func qualifiedImport() {
        let sut = visitor()
        let node = node("import struct Foundation.URL")
        let result = sut.parseSymbols(node: node, fileName: "")

        #expect(result.imports == Set(["Foundation.URL"]))
        #expect(result.symbolOccurrences.isEmpty)
    }

    @Test(
        "Imports with declarations.",
        .tags(.symbolKind.import, .symbolKind.definition)
    )
    func importsWithDeclarations() {
        let sut = visitor()
        let node = node("""
        import Foundation
        import UIKit

        struct MyStruct {}
        """)
        let result = sut.parseSymbols(node: node, fileName: "")

        #expect(result.imports == Set(["Foundation", "UIKit"]))
        #expect(result.symbolOccurrences.count == 1)

        let myStruct = SyntaxSymbolOccurrence(
            symbolName: "MyStruct",
            fullyQualifiedName: "MyStruct",
            kind: .definition(.struct),
            location: .init(line: 4, column: 1),
            scopeChain: []
        )

        #expect(result.symbolOccurrences.contains(myStruct))
    }
}
