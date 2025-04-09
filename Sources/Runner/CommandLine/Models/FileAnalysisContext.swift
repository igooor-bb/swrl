//
//  FileAnalysisContext.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 08.04.2025.
//

import Common
import Foundation
import SymbolsResolver

struct FileAnalysisContext: Sendable {

    // Initial file information
    let file: InputFile
    let moduleName: String
    
    // Syntax analysis data
    var imports: Set<String> = []
    var declarations: Set<SyntaxSymbolOccurrence> = []
    var dependencies: Set<SyntaxSymbolOccurrence> = []
    
    // Symbol resolution data
    var resolvedSymbols: [SymbolResolution] = []
    
    init(file: InputFile, moduleName: String) {
        self.file = file
        self.moduleName = moduleName
    }
    
    @discardableResult
    func apply<T>(_ transform: (FileAnalysisContext) throws -> T) rethrows -> T {
        try transform(self)
    }
}

// MARK: - Intermediate Output

extension FileAnalysisContext {
    func printDescription(with logger: Logger) {
        logger.performStep(number: 1, description: "File Information") {
            printFileModuleInfo(with: logger)
        }

        logger.performStep(number: 2, description: "Imports & Dependencies") {
            printSyntaxAnalysis(with: logger)
        }

        logger.performStep(number: 3, description: "Symbols Resolution") {
            printSymbolsResolution(with: logger)
        }
    }

    private func printFileModuleInfo(with logger: Logger) {
        logger.bulletPoint(title: "File", message: file.name)
        logger.bulletPoint(title: "Module", message: moduleName)
    }
    
    private func printSyntaxAnalysis(with logger: Logger) {
        let importStrings = imports
        let declStrings = declarations.map { decl in
            switch decl.kind {
            case .usage, .definition(.unknown):
                "\(decl.symbolName)"
                
            case let .definition(type):
                "\(decl.symbolName) (\(type))"
            }
        }
        let depStrings = dependencies.map(\.symbolName)

        logger.bulletPoint(title: "Imports (unique names)")
        logger.list(Set(importStrings))
        logger.bulletPoint(title: "Declarations (unique names)")
        logger.list(Set(declStrings))
        logger.bulletPoint(title: "Dependencies (unique names)")
        logger.list(Set(depStrings))
    }
    
    private func printSymbolsResolution(with logger: Logger) {
        let sortedSymbols = resolvedSymbols.sorted { lhs, rhs in
            lhs.targetSymbol.symbolName < rhs.targetSymbol.symbolName
        }
        for resolution in sortedSymbols {
            let loc = resolution.targetSymbol.location
            let kind = resolution.originKind == .unknown ? "" : " [\(resolution.originKind)]"
            let title = "\(resolution.targetSymbol.symbolName.bold) (\(loc.line):\(loc.column))\(kind.lightBlack)"
            
            switch resolution.origin {
            case .internalToModule:
                logger.bulletPoint(
                    message: "\(title) → \(moduleName.lightGreen) (this module)"
                )
                
            case let .externalModule(moduleName):
                logger.bulletPoint(
                    message: "\(title) → \(moduleName.lightGreen)"
                )
                
            case .system:
                logger.bulletPoint(
                    message: "\(title) → \("System Library".lightBlack)"
                )
                
            case .unknown:
                logger.bulletPoint(
                    message: "\(title) → \("Unknown".lightYellow)"
                )
            }
        }
    }
}
