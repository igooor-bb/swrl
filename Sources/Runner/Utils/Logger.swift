//
//  Logger.swift
//  SwiftLightweightResolver
//
//  Created by Igor Belov on 23.03.2025.
//

import Foundation
import Rainbow

protocol LoggerPrintable {
    func print(with logger: Logger)
}

final class Logger {

    typealias Block<T> = () throws -> T

    // MARK: Properties

    private var isMuted = false
    private var isSorted = false

    // MARK: - Configuration

    func setMuted(_ muted: Bool) {
        isMuted = muted
    }

    func setSorted(_ sorted: Bool) {
        isSorted = sorted
    }

    private func log(_ message: String...) {
        guard !isMuted else { return }
        print(message.joined(separator: " "))
    }

    func printGreeting() {
        log("Welcome to Swift Lightweight Resolver!".lightCyan.bold)
    }

    func printSuccess(_ message: String) {
        log(message.green)
    }

    func describeProcess(for files: [InputFile]) {
        log("Starting lightweight analysis...".lightGreen)
        log("\nProcessing \(files.count) .swift file\(files.count == 1 ? "" : "s"):")
        files.enumerated().forEach { log("  \($0 + 1)) \($1.name)") }
    }

    func printNewLine() {
        log()
    }

    func performStep<T>(number: inout Int, description: String, action: Block<T>) rethrows -> T {
        defer { number += 1 }
        logStepHeader(number, description: description)
        let result = try action()
        printNewLine()
        return result
    }

    func bulletPoint(title: String? = nil, message: String = "") {
        if let title = title {
            log(" • \(title): ".bold + message)
        } else {
            log(" • \(message)")
        }
    }

    func list(_ items: [String]) {
        items.sorted().forEach { log("   - \($0)") }
    }
    func list(_ items: Set<String>) {
        list(Array(items))
    }

    func displayFileSection<T>(for file: InputFile, at index: Int, total: Int, action: Block<T>) throws -> T {
        printNewLine()
        logFileHeader(file: file, index: index, total: total)
        let result = try action()
        log("(End of analysis for \(file.name))")
        return result
    }

    func logError(_ error: Error) {
        printNewLine()
        log("✖ ERROR".bold.red)
        log("\(error)\n".red)
    }

    private func logStepHeader(_ number: Int, description: String) {
        let header = "Step \(number). \(description)"
        log(" \(header)".yellow)
        log(" " + String(repeating: "─", count: header.count))
    }

    private func logFileHeader(file: InputFile, index: Int, total: Int) {
        let header = " File \(index + 1)/\(total): \(file.name) "
        let boxWidth = max(60, header.count + 4)
        let horizontalBorder = String(repeating: "━", count: boxWidth)
        log(("┏" + horizontalBorder + "┓").bold.magenta)
        log(("┃" + header.centered(to: boxWidth) + "┃").bold.magenta)
        log(("┗" + horizontalBorder + "┛").bold.magenta)
    }
}

private extension String {
    func centered(to width: Int) -> String {
        guard count < width else { return self }
        let totalPadding = width - count
        let leftPadding = totalPadding / 2
        let rightPadding = totalPadding - leftPadding
        return String(repeating: " ", count: leftPadding) + self + String(repeating: " ", count: rightPadding)
    }
}
