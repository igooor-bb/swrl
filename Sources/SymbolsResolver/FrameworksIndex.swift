import Common
import Foundation

// MARK: Dependencies

public protocol FrameworkDefinitionsAnalyzer: Sendable {
    func findDefinitions(at url: URL) throws -> [SyntaxSymbolOccurrence]
}

enum FrameworkIndexError: Error, CustomStringConvertible {
    case directoryEnumerationFailed(URL, reason: String)
    case resourceInspectionFailed(URL, reason: String)
    case interfaceDirectoryReadFailed(framework: String, URL, reason: String)
    case interfaceAnalysisFailed(framework: String, URL, reason: String)

    var description: String {
        switch self {
        case let .directoryEnumerationFailed(url, reason):
            "Unable to enumerate frameworks at \(url.path): \(reason)"

        case let .resourceInspectionFailed(url, reason):
            "Unable to inspect framework resource at \(url.path): \(reason)"

        case let .interfaceDirectoryReadFailed(framework, url, reason):
            "Unable to read the \(framework) interface directory at \(url.path): \(reason)"

        case let .interfaceAnalysisFailed(framework, url, reason):
            "Unable to analyze the \(framework) interface at \(url.path): \(reason)"
        }
    }
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

    func prewarm() throws {
        frameworkDirectoryByName = try findFrameworkDirectories(in: indexStoreURL)
    }

    // MARK: Interface

    func resolveSymbols(
        _ symbolsToResolve: [SyntaxSymbolOccurrence],
        imports: Set<String>
    ) throws -> [SyntaxSymbolOccurrence: FrameworkSymbolLookup] {
        // We are looking only among frameworks that are listed in imports:
        let frameworkDirectories = frameworkDirectoryByName
            .filter { imports.contains($0.key) }
            .sorted { lhs, rhs in
                (lhs.key, lhs.value.path) < (rhs.key, rhs.value.path)
            }
        var lookupsBySymbolIdentifier: [String: [FrameworkSymbolLookup]] = [:]

        for (frameworkName, frameworkDirectoryURL) in frameworkDirectories {
            let frameworkInterfaceFileURL = try interfaceContentForFramework(frameworkName, at: frameworkDirectoryURL)
            guard let frameworkInterfaceFileURL else { continue }

            // Analyze the interface file using the SwiftSyntax analysis, since the interface conforms to Swift.
            // We consider only definitions.
            let result: [SyntaxSymbolOccurrence]
            do {
                result = try analyzer.findDefinitions(at: frameworkInterfaceFileURL)
            } catch {
                throw FrameworkIndexError.interfaceAnalysisFailed(
                    framework: frameworkName,
                    frameworkInterfaceFileURL,
                    reason: String(describing: error)
                )
            }
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

    private func interfaceContentForFramework(_ framework: String, at url: URL) throws -> URL? {
        let swiftModulePath = "Modules/\(framework).swiftmodule"
        let swiftModuleURL = url.appendingPathComponent(swiftModulePath)

        guard FileManager.default.fileExists(atURL: swiftModuleURL) else {
            return nil
        }

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: swiftModuleURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: .skipsHiddenFiles
            )
        } catch {
            throw FrameworkIndexError.interfaceDirectoryReadFailed(
                framework: framework,
                swiftModuleURL,
                reason: String(describing: error)
            )
        }
        return files
            .filter { $0.pathExtension == "swiftinterface" }
            .sorted { $0.path < $1.path }
            .first
    }

    private func findFrameworkDirectories(in directory: URL) throws -> [String: URL] {
        var foundFrameworks: [String: URL] = [:]
        let subpaths: [String]
        do {
            subpaths = try FileManager.default.subpathsOfDirectory(atPath: directory.path).sorted()
        } catch {
            throw FrameworkIndexError.directoryEnumerationFailed(
                directory,
                reason: String(describing: error)
            )
        }

        for subpath in subpaths where !subpath.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
            let fileURL = directory.appendingPathComponent(subpath)
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
                throw FrameworkIndexError.resourceInspectionFailed(
                    fileURL,
                    reason: String(describing: error)
                )
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
