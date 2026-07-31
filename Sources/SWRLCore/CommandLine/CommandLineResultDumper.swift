import Common
import Foundation
import SymbolsResolver
import SyntaxAnalysis

final class CommandLineResultDumper {
    func dump(_ report: AnalysisReport, to file: InputFile) throws {
        let jsonData = try encodeToJSON(report)
        try writeJSON(jsonData, to: file.url)
    }

    func encodeToJSON(_ data: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return try encoder.encode(data)
    }

    private func writeJSON(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: url, options: .atomic)
    }
}

extension FileAnalysisContext {
    func dumpOutput() -> AnalysisReport.File {
        let outputImports = imports.sorted()
        let outputDeclarations = declarations
            .sorted(by: SyntaxSymbolOccurrence.stableOrder)
            .compactMap(createDeclaration)
        let outputResolutions = resolvedSymbols
            .sorted(by: SymbolResolution.stableOrder)
            .compactMap { resolution in
                createOutputResolution(
                    from: resolution,
                    currentModuleName: moduleName
                )
            }

        return AnalysisReport.File(
            file: file.normalizedPath,
            module: moduleName,
            imports: outputImports,
            declarations: outputDeclarations,
            symbols: outputResolutions
        )
    }

    private func createDeclaration(from occ: SyntaxSymbolOccurrence) -> AnalysisReport.Declaration? {
        guard let type = occ.kind.definitionType else { return nil }
        return AnalysisReport.Declaration(name: occ.symbolName, type: type.rawValue)
    }

    private func createOutputResolution(from resolution: SymbolResolution, currentModuleName: String) -> AnalysisReport.Symbol? {
        let (moduleType, moduleName) = resolution.origin.moduleDetails(currentModuleName: currentModuleName)
        let type = resolution.originKind == .unknown ? nil : resolution.originKind

        return AnalysisReport.Symbol(
            symbol: resolution.targetSymbol.symbolName,
            chain: resolution.targetSymbol.scopeChain.joined(separator: "."),
            line: resolution.targetSymbol.location.line,
            column: resolution.targetSymbol.location.column,
            originType: type?.rawValue,
            originModuleType: moduleType,
            originModuleName: moduleName
        )
    }
}

private extension SymbolOccurrenceKind {
    var definitionType: SymbolDefinitionKind? {
        switch self {
        case .usage:
            nil

        case let .definition(type):
            type
        }
    }
}

private extension ResolvedSymbolOrigin {
    func moduleDetails(currentModuleName: String) -> (moduleType: String, moduleName: String?) {
        switch self {
        case let .externalModule(name):
            ("external", name)

        case .internalToModule:
            ("this", currentModuleName)

        case .system:
            ("system", nil)

        case .unknown:
            ("unknown", nil)
        }
    }
}
