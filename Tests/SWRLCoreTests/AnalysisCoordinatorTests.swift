import Foundation
import Testing
@testable import SWRLCore

@Suite("Analysis coordinator")
struct AnalysisCoordinatorTests {
    @Test("Concurrency is bounded and results follow normalized file order")
    func boundsConcurrencyAndSortsResults() async {
        let files = ["d.swift", "a.swift", "c.swift", "b.swift", "e.swift"]
            .map { InputFile(path: "/tmp/swrl-coordinator/\($0)") }
        let probe = ConcurrencyProbe()
        let coordinator = AnalysisCoordinator(maxConcurrentTasks: 2)

        let results = await coordinator.process(files: files) { file in
            await probe.enter()
            do {
                try await Task.sleep(for: .milliseconds(15))
                await probe.leave()
                return FileAnalysisContext(file: file, moduleName: "App")
            } catch {
                await probe.leave()
                throw error
            }
        }
        let maximumConcurrency = await probe.maximumConcurrency

        #expect(maximumConcurrency == 2)
        #expect(results.map(\.file.name) == ["a.swift", "b.swift", "c.swift", "d.swift", "e.swift"])
    }

    @Test("Zero configured concurrency still makes progress")
    func normalizesZeroConcurrency() async {
        let file = InputFile(path: "/tmp/swrl-coordinator/only.swift")

        let results = await AnalysisCoordinator(maxConcurrentTasks: 0).process(files: [file]) { input in
            FileAnalysisContext(file: input, moduleName: "App")
        }

        #expect(results.count == 1)
    }
}

private actor ConcurrencyProbe {
    private var activeCount = 0
    private(set) var maximumConcurrency = 0

    func enter() {
        activeCount += 1
        maximumConcurrency = max(maximumConcurrency, activeCount)
    }

    func leave() {
        activeCount -= 1
    }
}
