//
//  CommandLineResultDumper.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 08.04.2025.
//

import Common
import Foundation
import SyntaxAnalysis
import SymbolsResolver

struct OutputModel: Encodable {

    struct Declaration: Encodable {
        let name: String
        let type: String
    }

    struct Resolution: Encodable {
        let symbol: String
        let chain: String
        let line: Int
        let column: Int
        let originType: String?
        let originModuleType: String
        let originModuleName: String?
    }

    let file: String
    let module: String
    let imports: [String]
    let declarations: [Declaration]
    let symbols: [Resolution]
}

final class CommandLineResultDumper {
    func dump(_ models: [OutputModel], to file: InputFile) throws {
        let jsonData = try encodeToJSON(models)
        try writeJSON(jsonData, to: file.url)
    }

    private func encodeToJSON<T: Encodable>(_ data: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return try encoder.encode(data)
    }

    private func writeJSON(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: url)
    }
}

extension FileAnalysisContext {
    func dumpOutput() -> OutputModel {
        let outputImports = imports.sorted()
        let outputDeclarations = declarations
            .sorted { $0.symbolName < $1.symbolName }
            .compactMap(createDeclaration)
        let outputResolutions = resolvedSymbols.compactMap { resolution in
            createOutputResolution(
                from: resolution,
                currentModuleName: moduleName
            )
        }
        
        return OutputModel(
            file: file.url.path,
            module: moduleName,
            imports: outputImports,
            declarations: outputDeclarations,
            symbols: outputResolutions
        )
    }
    
    private func createDeclaration(from occ: SyntaxSymbolOccurrence) -> OutputModel.Declaration? {
        guard let type = occ.kind.definitionType else { return nil }
        return OutputModel.Declaration(name: occ.symbolName, type: type.rawValue)
    }
    
    private func createOutputResolution(from resolution: SymbolResolution, currentModuleName: String) -> OutputModel.Resolution? {
        let (moduleType, moduleName) = resolution.origin.moduleDetails(currentModuleName: currentModuleName)
        let type = resolution.originKind == .unknown ? nil : resolution.originKind
        
        return OutputModel.Resolution(
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
            return nil
        case let .definition(type):
            return type
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
