# Swift Lightweight Resolver

A command-line tool for resolving symbols in Swift source files.

## Overview

Swift Lightweight Resolver (swrl) is a specialized command-line utility designed to analyze and resolve symbols found in Swift source files. It helps developers identify and manage symbol references, making it easier to understand dependencies between different parts of your codebase.

Based on the combination of [SwiftSyntax](https://github.com/swiftlang/swift-syntax) and [IndexStoreDB](https://github.com/swiftlang/indexstore-db).

## Motivation

- The problem of broken indexing and SourceKit interaction in large Xcode projects.
- The problem of manually analyzing large files for external dependencies.

## Features

- Searching for external symbols in source file.
- Resolving symbols to identify the modules they came from
- Beautiful and effective output of the found information

## Requirements

To build and use this package, you'll need:

- Swift 6.0 or later: This package requires Swift 6.0 as the minimum Swift version.
- macOS 12 (Monterey) or later: The package is designed to run on macOS 12 or newer versions.
- Command Line Tools for Xcode

## Installation

### Using Make

The easiest way to install swrl is using the provided Makefile:

```bash
# Clone the repository
git clone https://github.com/igooor-bb/swrl.git
cd swrl

# Build and install (may require sudo)
make install
```

This will install the `swrl` executable to `/usr/local/bin`. You can verify the installation with:

```bash
swrl --help
```

## Usage

**Before using the tool, pre-build the project in Xcode**

Analyze a specific file in a project:

```bash
swrl MyApp.xcodeproj --file Sources/AppDelegate.swift
```

Analyze multiple specific files:

```bash
swrl MyApp.xcworkspace --file Sources/Model.swift --file Sources/ViewModel.swift
```

Analyze Swift files in a project based on a pattern:

```bash
swrl MyApp.xcodeproj --pattern "**/*.swift"
```

Save results to a file with different name (default is `output.json` in the run directory):

```bash
swrl MyApp.xcodeproj --pattern "**/*.swift" --output results.json
```

## Output Example

<details>

<summary>JSON</summary>

```json
{
  "declarations": [
    {
      "name": "UserFeedbackHandler",
      "type": "class"
    },
    {
      "name": "FeedbackFactory",
      "type": "struct"
    },
    {
      "name": "FeedbackAdapter",
      "type": "class"
    }
  ],
  "file": "UserFeedbackHandler.swift",
  "imports": [
    "FeedbackSDK",
    "SupportLibrary",
    "CoreFoundation",
    "Messaging",
    "UIKit"
  ],
  "module": "FeedbackModule",
  "symbols": [
    {
      "chain": "UserFeedbackHandler",
      "column": 13,
      "line": 60,
      "originModuleName": "FeedbackModule",
      "originModuleType": "this",
      "originType": "enum",
      "symbol": "ConfirmationType"
    },
    {
      "chain": "FeedbackFactory.buildHandler",
      "column": 10,
      "line": 20,
      "originModuleName": "Messaging",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "FeedbackDelegate"
    },
    {
      "chain": "FeedbackAdapter.feedbackDidCloseWithReason",
      "column": 43,
      "line": 116,
      "originModuleName": "FeedbackSDK",
      "originModuleType": "external",
      "originType": "typealias",
      "symbol": "FeedbackCloseReason"
    },
    {
      "chain": "FeedbackAdapter",
      "column": 57,
      "line": 92,
      "originModuleName": "FeedbackSDK",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "FeedbackProtocol"
    },
    {
      "chain": "FeedbackFactory",
      "column": 41,
      "line": 16,
      "originModuleName": "SupportLibrary",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "FeedbackFactoryProtocol"
    },
    {
      "chain": "UserFeedbackHandler",
      "column": 47,
      "line": 30,
      "originModuleName": "Messaging",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "FeedbackDelegate"
    },
    {
      "chain": "UserFeedbackHandler.showFeedback",
      "column": 26,
      "line": 62,
      "originModuleName": "FeedbackSDK",
      "originModuleType": "external",
      "originType": "struct",
      "symbol": "FeedbackParameters"
    },
    {
      "chain": "UserFeedbackHandler",
      "column": 34,
      "line": 35,
      "originModuleName": "FeedbackSDK",
      "originModuleType": "external",
      "originType": "class",
      "symbol": "FeedbackFlowCoordinator"
    },
    {
      "chain": "getCloseReason",
      "column": 26,
      "line": 122,
      "originModuleName": "Messaging",
      "originModuleType": "external",
      "originType": "enum",
      "symbol": "FeedbackCloseReason"
    },
    {
      "chain": "UserFeedbackHandler.showFeedback",
      "column": 27,
      "line": 73,
      "originModuleName": "FeedbackSDK",
      "originModuleType": "external",
      "originType": "class",
      "symbol": "FeedbackFlowCoordinator"
    },
    {
      "chain": "UserFeedbackHandler",
      "column": 27,
      "line": 33,
      "originModuleName": "CoreFoundation",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "ResolverProtocol"
    },
    {
      "chain": "FeedbackFactory.buildHandler",
      "column": 19,
      "line": 19,
      "originModuleName": "CoreFoundation",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "ResolverProtocol"
    },
    {
      "chain": "UserFeedbackHandler.init",
      "column": 19,
      "line": 40,
      "originModuleName": "CoreFoundation",
      "originModuleType": "external",
      "originType": "protocol",
      "symbol": "ResolverProtocol"
    }
  ]
}
```

</details>

## Contribution

To contribute, use the follow "fork-and-pull" git workflow:

1. Fork the repository on github
2. Clone the project to your own machine
3. Commit changes to your own branch
4. Push your work back up to your fork
5. Submit a pull request so that I can review your changes

*NOTE: Be sure to merge the latest from "upstream" before making a pull request!*

## License

Swift Lightweight Resolver is released under the MIT license. See [LICENSE](LICENSE) for details.
