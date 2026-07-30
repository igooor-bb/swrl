import Common
import Foundation

// MARK: Dependencies

public protocol FrameworkDefinitionsAnalyzer: Sendable {
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
        indexStoreURL = storeURL
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
        let frameworkDirectories = frameworkDirectoryByName
            .filter { imports.contains($0.key) }
            .sorted { lhs, rhs in
                (lhs.key, lhs.value.path) < (rhs.key, rhs.value.path)
            }
        var lookupsBySymbolIdentifier: [String: [FrameworkSymbolLookup]] = [:]

        for (frameworkName, frameworkDirectoryURL) in frameworkDirectories {
            let frameworkInterfaceFileURL = interfaceContentForFramework(frameworkName, at: frameworkDirectoryURL)
            guard let frameworkInterfaceFileURL else { continue }

            // Analyze the interface file using the SwiftSyntax analysis, since the interface conforms to Swift.
            // We consider only definitions.
            let result = analyzer.findDefinitions(at: frameworkInterfaceFileURL)
            for item in result {
                lookupsBySymbolIdentifier[item.symbolName, default: []].append(
                    FrameworkSymbolLookup(frameworkName: frameworkName, symbol: item)
                )
            }
        }

        var resolvedSymbols: [SyntaxSymbolOccurrence: FrameworkSymbolLookup] = [:]
        for symbol in symbolsToResolve {
            let candidates = lookupsBySymbolIdentifier[symbol.symbolName, default: []]
                .sorted(by: lookupPrecedes)
            let candidateFrameworks = Set(candidates.map(\.frameworkName))
            guard candidateFrameworks.count == 1, let candidate = candidates.first else {
                continue
            }

            resolvedSymbols[symbol] = candidate
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
            errorHandler: { _, _ -> Bool in
                // Continue enumeration even if an error occurs.
                return true
            }
        ) else {
            return foundFrameworks
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true, fileURL.pathExtension == "framework" {
                    let frameworkName = fileURL.deletingPathExtension().lastPathComponent
                    if let existingURL = foundFrameworks[frameworkName] {
                        foundFrameworks[frameworkName] = existingURL.path < fileURL.path ? existingURL : fileURL
                    } else {
                        foundFrameworks[frameworkName] = fileURL
                    }
                }
            } catch {
                continue
            }
        }

        return foundFrameworks
    }

    private func lookupPrecedes(_ lhs: FrameworkSymbolLookup, _ rhs: FrameworkSymbolLookup) -> Bool {
        let lhsKind = lhs.symbol.kind.definitionKind?.rawValue ?? ""
        let rhsKind = rhs.symbol.kind.definitionKind?.rawValue ?? ""
        return (
            lhs.frameworkName,
            lhs.symbol.symbolName,
            lhsKind,
            lhs.symbol.location.line,
            lhs.symbol.location.column
        ) < (
            rhs.frameworkName,
            rhs.symbol.symbolName,
            rhsKind,
            rhs.symbol.location.line,
            rhs.symbol.location.column
        )
    }
}

private extension SymbolOccurrenceKind {
    var definitionKind: SymbolDefinitionKind? {
        if case let .definition(kind) = self {
            kind
        } else {
            nil
        }
    }
}
