import Foundation

struct FileProcessingResult: Sendable {
    enum Outcome: Sendable {
        case success(FileAnalysisContext)
        case failure(any Error)
    }

    let file: InputFile
    let outcome: Outcome
}

struct AnalysisCoordinator: Sendable {
    private struct IndexedResult: Sendable {
        let index: Int
        let result: FileProcessingResult
    }

    private let maxConcurrentTasks: Int

    init(maxConcurrentTasks: Int = min(ProcessInfo.processInfo.activeProcessorCount, 8)) {
        self.maxConcurrentTasks = max(1, maxConcurrentTasks)
    }

    func process(
        files: [InputFile],
        operation: @escaping @Sendable (InputFile) async throws -> FileAnalysisContext
    ) async -> [FileProcessingResult] {
        let sortedFiles = files.sorted { $0.normalizedPath < $1.normalizedPath }
        guard !sortedFiles.isEmpty else { return [] }

        return await withTaskGroup(of: IndexedResult.self) { group in
            let initialTaskCount = min(maxConcurrentTasks, sortedFiles.count)
            for index in 0 ..< initialTaskCount {
                addTask(for: index, files: sortedFiles, operation: operation, to: &group)
            }

            var nextIndex = initialTaskCount
            var indexedResults = [FileProcessingResult?](repeating: nil, count: sortedFiles.count)
            for await indexedResult in group {
                indexedResults[indexedResult.index] = indexedResult.result
                if nextIndex < sortedFiles.count {
                    addTask(for: nextIndex, files: sortedFiles, operation: operation, to: &group)
                    nextIndex += 1
                }
            }

            return indexedResults.compactMap(\.self)
        }
    }

    private func addTask(
        for index: Int,
        files: [InputFile],
        operation: @escaping @Sendable (InputFile) async throws -> FileAnalysisContext,
        to group: inout TaskGroup<IndexedResult>
    ) {
        let file = files[index]
        group.addTask {
            do {
                let context = try await operation(file)
                return IndexedResult(
                    index: index,
                    result: FileProcessingResult(file: file, outcome: .success(context))
                )
            } catch {
                return IndexedResult(
                    index: index,
                    result: FileProcessingResult(file: file, outcome: .failure(error))
                )
            }
        }
    }
}
