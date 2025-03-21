// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLightweightResolver",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "swrl",
            targets: ["Runner"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "600.0.1"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.5.0"
        ),
        .package(
            url: "https://github.com/swiftlang/indexstore-db.git",
            branch: "release/6.0"
        ),
        .package(
            url: "https://github.com/onevcat/Rainbow.git",
            .upToNextMajor(from: "4.0.0")
        ),
        .package(
            url: "https://github.com/SimplyDanny/SwiftLintPlugins.git",
            .upToNextMajor(from: "0.58.2")
        )
    ],
    targets: [
        .executableTarget(
            name: "Runner",
            dependencies: [
                .target(name: "Common"),
                .target(name: "SyntaxAnalysis"),
                .target(name: "SymbolsResolver"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Rainbow", package: "Rainbow")
            ]
        ),
        .target(
            name: "SyntaxAnalysis",
            dependencies: [
                .target(name: "Common"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .target(
            name: "SymbolsResolver",
            dependencies: [
                .target(name: "Common"),
                .product(name: "IndexStoreDB", package: "indexstore-db")
            ]
        ),
        .target(name: "Common")
    ]
)
