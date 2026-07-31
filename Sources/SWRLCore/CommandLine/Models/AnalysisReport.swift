import Foundation
import SymbolsResolver

struct AnalysisReport: Encodable {
    enum DiagnosticSeverity: String, Encodable {
        case warning
        case error
    }

    struct Summary: Encodable, Equatable {
        let requested: Int
        let succeeded: Int
        let failed: Int
        let unresolved: Int
    }

    struct File: Encodable, Equatable {
        let file: String
        let module: String
        let imports: [String]
        let declarations: [Declaration]
        let symbols: [Symbol]
    }

    struct Declaration: Encodable, Equatable {
        let name: String
        let type: String
    }

    struct Symbol: Encodable, Equatable {
        let symbol: String
        let chain: String
        let line: Int
        let column: Int
        let originType: String?
        let originModuleType: String
        let originModuleName: String?
    }

    struct Diagnostic: Encodable, Equatable {
        let code: String
        let severity: DiagnosticSeverity
        let message: String
        let file: String?

        static func stableOrder(_ lhs: Diagnostic, _ rhs: Diagnostic) -> Bool {
            if lhs.file != rhs.file {
                return (lhs.file ?? "") < (rhs.file ?? "")
            }
            if lhs.code != rhs.code {
                return lhs.code < rhs.code
            }
            if lhs.severity != rhs.severity {
                return lhs.severity.rawValue < rhs.severity.rawValue
            }
            return lhs.message < rhs.message
        }
    }

    let project: String
    let summary: Summary
    let files: [File]
    let diagnostics: [Diagnostic]
}

struct AnalysisReportBuilder {
    private enum DiagnosticCode {
        static let fileAnalysisFailed = "analysis.file_failed"
    }

    func build(
        project: InputFile,
        processingResults: [FileProcessingResult]
    ) -> AnalysisReport {
        var files: [AnalysisReport.File] = []
        var diagnostics: [AnalysisReport.Diagnostic] = []
        var unresolvedCount = 0

        for processingResult in processingResults {
            switch processingResult.outcome {
            case let .success(context):
                files.append(context.dumpOutput())
                unresolvedCount += context.resolvedSymbols.count { $0.origin == .unknown }

            case let .failure(error):
                diagnostics.append(
                    AnalysisReport.Diagnostic(
                        code: DiagnosticCode.fileAnalysisFailed,
                        severity: .error,
                        message: String(describing: error),
                        file: processingResult.file.normalizedPath
                    )
                )
            }
        }

        let failedCount = diagnostics.count
        return AnalysisReport(
            project: project.normalizedPath,
            summary: AnalysisReport.Summary(
                requested: processingResults.count,
                succeeded: files.count,
                failed: failedCount,
                unresolved: unresolvedCount
            ),
            files: files.sorted { $0.file < $1.file },
            diagnostics: diagnostics.sorted(by: AnalysisReport.Diagnostic.stableOrder)
        )
    }
}
