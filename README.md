# Swift Lightweight Resolver

A command-line tool for resolving symbols in Swift source files.

## Overview

Swift Lightweight Resolver (swrl) is a specialized command-line utility designed to analyze and resolve symbols found in Swift source files. It helps developers identify and manage symbol references, making it easier to understand dependencies between different parts of your codebase.

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
git clone https://github.com/username/swrl.git
cd swrl

# Build and install (may require sudo)
make install
```

This will install the `swrl` executable to `/usr/local/bin`. You can verify the installation with:

```bash
swrl --help
```

## Usage

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
