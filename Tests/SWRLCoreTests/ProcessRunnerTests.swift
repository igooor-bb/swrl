import Foundation
import Testing
@testable import SWRLCore

@Suite("Process runner")
struct ProcessRunnerTests {
    @Test("Arguments are passed directly without shell interpretation")
    func passesTypedArguments() throws {
        let runner = FoundationProcessRunner()
        let output = try runner.run(
            ProcessCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
                arguments: ["%s", "value with spaces; echo not-executed"]
            )
        )

        #expect(output.standardOutput == "value with spaces; echo not-executed")
        #expect(output.standardError.isEmpty)
        #expect(output.terminationStatus == 0)
    }

    @Test("Non-zero exit statuses are surfaced")
    func reportsFailure() throws {
        let runner = FoundationProcessRunner()

        do {
            _ = try runner.run(ProcessCommand(executableURL: URL(fileURLWithPath: "/usr/bin/false")))
            Issue.record("Expected the process to fail")
        } catch let error as ProcessRunnerError {
            guard case let .executionFailed(executable, exitCode, _) = error else {
                Issue.record("Unexpected process error: \(error)")
                return
            }
            #expect(executable.path == "/usr/bin/false")
            #expect(exitCode != 0)
        }
    }
}
