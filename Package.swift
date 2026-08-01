// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLightweightResolver",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(
            name: "swrl",
            targets: ["Runner"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "603.0.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            .upToNextMajor(from: "1.5.0")
        ),
        .package(
            url: "https://github.com/swiftlang/indexstore-db.git",
            revision: "003ac41513ba291f10ff1a0147ae68588914668d"
        ),
        .package(
            url: "https://github.com/onevcat/Rainbow.git",
            .upToNextMajor(from: "4.0.0")
        ),
    ],
    targets: [
        .executableTarget(
            name: "Runner",
            dependencies: [
                .target(name: "SWRLCore"),
            ]
        ),
        .target(
            name: "SWRLCore",
            dependencies: [
                .target(name: "Common"),
                .target(name: "SyntaxAnalysis"),
                .target(name: "SymbolsResolver"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Rainbow", package: "Rainbow"),
            ]
        ),
        .target(
            name: "SyntaxAnalysis",
            dependencies: [
                .target(name: "Common"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SymbolsResolver",
            dependencies: [
                .target(name: "Common"),
                .product(name: "IndexStoreDB", package: "indexstore-db"),
            ]
        ),
        .target(name: "Common"),
        .testTarget(
            name: "SWRLCoreTests",
            dependencies: [.target(name: "SWRLCore")]
        ),
        .testTarget(
            name: "SymbolsResolverTests",
            dependencies: [
                .target(name: "SymbolsResolver"),
                .product(name: "IndexStoreDB", package: "indexstore-db"),
            ]
        ),
        .testTarget(
            name: "SyntaxAnalysisTests",
            dependencies: [.target(name: "SyntaxAnalysis")]
        ),
    ]
)
