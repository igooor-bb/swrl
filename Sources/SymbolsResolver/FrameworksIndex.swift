//
//  FrameworksIndex.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 28.03.2025.
//

import Common
import Foundation

// MARK: Dependencies

public protocol FrameworkDefinitionsAnalyzer {
    func findDefinitions(at url: URL) -> [SyntaxSymbolOccurrence]
}

final class FrameworksIndex {

    // MARK: Nested Types

    struct FrameworkSymbolLookup {
        let frameworkName: String
        let symbol: SyntaxSymbolOccurrence
    }

    // MARK: Properties

    private let indexStoreURL: URL
    private let analyzer: FrameworkDefinitionsAnalyzer
    private var frameworkDirectoryByName: [String: URL] = [:]

    // MARK: Lifecycle

    init(
        storeURL: URL,
        analyzer: FrameworkDefinitionsAnalyzer
    ) {
        self.indexStoreURL = storeURL
        self.analyzer = analyzer
    }

    func prewarm() {
        frameworkDirectoryByName = findFrameworkDirectories(in: indexStoreURL)
    }

    // MARK: Interface

    func resolveSymbols(
        _ symbolsToResolve: [SyntaxSymbolOccurrence],
        imports: Set<String>
    ) -> [SyntaxSymbolOccurrence: FrameworkSymbolLookup] {
        // We are looking only among frameworks that are listed in imports:
        let frameworkDirectoryByName = frameworkDirectoryByName.filter { imports.contains($0.key) }

        var frameworkNameBySymbolIdentifier: [String: String] = [:]
        var resolvedSymbolsByIdentifier: [String: SyntaxSymbolOccurrence] = [:]

        for (frameworkName, frameworkDirectoryURL) in frameworkDirectoryByName {
            let frameworkInterfaceFileURL = interfaceContentForFramework(frameworkName, at: frameworkDirectoryURL)
            guard let frameworkInterfaceFileURL else { continue }

            // Analyze the interface file using the SwiftSyntax analysis, since the interface conforms to Swift.
            // We consider only definitions.
            let result = analyzer.findDefinitions(at: frameworkInterfaceFileURL)
            result.forEach {
                frameworkNameBySymbolIdentifier[$0.symbolName] = frameworkName
                resolvedSymbolsByIdentifier[$0.symbolName] = $0
            }
        }

        var resolvedSymbols: [SyntaxSymbolOccurrence: FrameworkSymbolLookup] = [:]
        symbolsToResolve.forEach { symbol in
            guard
                let frameworkName = frameworkNameBySymbolIdentifier[symbol.symbolName],
                let foundSymbol = resolvedSymbolsByIdentifier[symbol.symbolName]
            else {
                return
            }

            // TODO: Consider several occurrences.
            resolvedSymbols[symbol] = FrameworkSymbolLookup(frameworkName: frameworkName, symbol: foundSymbol)
        }

        return resolvedSymbols
    }

    // MARK: - Helpers

    private func interfaceContentForFramework(_ framework: String, at url: URL) -> URL? {
        let swiftModulePath = "Modules/\(framework).swiftmodule"
        let swiftModuleURL = url.appendingPathComponent(swiftModulePath)

        guard FileManager.default.fileExists(atURL: swiftModuleURL) else {
            return nil
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: swiftModuleURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: .skipsHiddenFiles
            )
            guard let swiftInterfaceFile = files.first(where: { $0.pathExtension == "swiftinterface" }) else {
                return nil
            }
            return swiftInterfaceFile
        } catch {
            return nil
        }
    }

    private func findFrameworkDirectories(in directory: URL) -> [String: URL] {
        var foundFrameworks: [String: URL] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles],
            errorHandler: { (_, _) -> Bool in
                // Continue enumeration even if an error occurs.
                return true
            }
        ) else {
            return foundFrameworks
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true && fileURL.pathExtension == "framework" {
                    let frameworkName = fileURL.deletingPathExtension().lastPathComponent
                    foundFrameworks[frameworkName] = fileURL
                }
            } catch {
                continue
            }
        }

        return foundFrameworks
    }
}
