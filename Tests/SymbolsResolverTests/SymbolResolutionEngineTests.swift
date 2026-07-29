import Common
import Testing
@testable import SymbolsResolver

@Suite("Symbol resolution engine")
struct SymbolResolutionEngineTests {
    @Test("System lookups resolve without an IndexStoreDB value")
    func resolvesSystemLookup() throws {
        let resolution = try #require(
            SymbolResolutionEngine().resolve(
                usage("URL"),
                lookup: .system,
                imports: ["App", "Foundation"],
                currentModuleName: "App"
            )
        )

        #expect(resolution.origin == .system)
        #expect(resolution.originKind == .unknown)
    }

    @Test("Undefined lookups remain available for framework fallback")
    func preservesUndefinedLookup() {
        let resolution = SymbolResolutionEngine().resolve(
            usage("FallbackType"),
            lookup: .undefined,
            imports: ["App", "Foundation"],
            currentModuleName: "App"
        )

        #expect(resolution == nil)
    }

    @Test("Current module candidates resolve internally")
    func resolvesCurrentModuleCandidate() throws {
        let symbol = usage("Feature")
        let resolution = try #require(
            SymbolResolutionEngine().resolve(
                symbol,
                lookup: .resolved([
                    indexedSymbol("Feature", module: "App", kind: .struct),
                ]),
                imports: ["App", "Foundation"],
                currentModuleName: "App"
            )
        )

        #expect(
            resolution == SymbolResolution(
                targetSymbol: symbol,
                origin: .internalToModule,
                originKind: .struct
            )
        )
    }

    @Test("A single external submodule candidate stays external")
    func resolvesSingleExternalCandidate() throws {
        let symbol = usage("RemoteFeature")
        let resolution = try #require(
            SymbolResolutionEngine().resolve(
                symbol,
                lookup: .resolved([
                    indexedSymbol("RemoteFeature", module: "FeatureKit.Models", kind: .class),
                ]),
                imports: ["App", "FeatureKit", "Foundation"],
                currentModuleName: "App"
            )
        )

        #expect(
            resolution == SymbolResolution(
                targetSymbol: symbol,
                origin: .externalModule("FeatureKit.Models"),
                originKind: .class
            )
        )
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

    private func indexedSymbol(
        _ name: String,
        module: String,
        kind: SymbolDefinitionKind
    ) -> IndexedSymbolOccurrence {
        IndexedSymbolOccurrence(
            usr: "s:\(module).\(name)",
            moduleName: module,
            isSystem: false,
            kind: kind
        )
    }
}
