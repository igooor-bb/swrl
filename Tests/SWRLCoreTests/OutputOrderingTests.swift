import Common
import SymbolsResolver
import Testing
@testable import SWRLCore

@Suite("Output ordering")
struct OutputOrderingTests {
    @Test("Imports declarations and resolutions are stable")
    func sortsOutputCollections() {
        let file = InputFile(path: "/tmp/App.swift")
        let alpha = occurrence("Alpha", kind: .definition(.struct), line: 4)
        let alphaClass = occurrence("Alpha", kind: .definition(.class), line: 2)
        let zeta = occurrence("Zeta", kind: .usage, line: 1)
        let beta = occurrence("Beta", kind: .usage, line: 3)
        var context = FileAnalysisContext(file: file, moduleName: "App")
        context.imports = ["ZetaKit", "AlphaKit"]
        context.declarations = [alpha, alphaClass]
        context.resolvedSymbols = [
            SymbolResolution(targetSymbol: zeta, origin: .unknown, originKind: .unknown),
            SymbolResolution(targetSymbol: beta, origin: .system, originKind: .class),
        ]

        let output = context.dumpOutput()

        #expect(output.imports == ["AlphaKit", "ZetaKit"])
        #expect(output.declarations.map(\.type) == ["class", "struct"])
        #expect(output.symbols.map(\.symbol) == ["Beta", "Zeta"])
    }

    private func occurrence(
        _ name: String,
        kind: SymbolOccurrenceKind,
        line: Int
    ) -> SyntaxSymbolOccurrence {
        SyntaxSymbolOccurrence(
            symbolName: name,
            fullyQualifiedName: nil,
            kind: kind,
            location: SyntaxSymbolLocation(line: line, column: 1),
            scopeChain: []
        )
    }
}
