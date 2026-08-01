# swrl

[![CI](https://img.shields.io/github/actions/workflow/status/igooor-bb/swrl/ci.yml?branch=main&label=CI&logo=github)](https://github.com/igooor-bb/swrl/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![macOS 12+](https://img.shields.io/badge/macOS-12%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![MIT License](https://img.shields.io/github/license/igooor-bb/swrl)](https://github.com/igooor-bb/swrl/blob/main/LICENSE)

`swrl` is a lightweight command-line symbol resolver for Swift projects built with Xcode. It parses source with SwiftSyntax, looks up definitions in IndexStoreDB, and classifies each reference as internal, external, system, or unresolved.

The project must already be indexed by Xcode. `swrl` does not run `xcodebuild` or change the analyzed project.

## Requirements

- macOS 12 or later
- Xcode with Swift 6.0 or newer and `libIndexStore`
- [mise](https://mise.jdx.dev/) 2026.7.13 or later

`swrl` uses Swift 6.0 or newer and `libIndexStore` from the selected Xcode. mise installs only SwiftFormat and SwiftLint. Select Xcode with `DEVELOPER_DIR` or `xcode-select` before running the tasks below.

## Setup

```bash
git clone https://github.com/igooor-bb/swrl.git
cd swrl
mise install --locked
mise run doctor
mise run check
```

`mise install --locked` installs the pinned SwiftFormat and SwiftLint versions. `doctor` checks for Swift 6.0 or newer, the active developer directory, and `libIndexStore`.

Install the release executable into `~/.local/bin`:

```bash
mise run install
```

Set `SWRL_INSTALL_DIR` to use another destination:

```bash
SWRL_INSTALL_DIR=/usr/local/bin mise run install
SWRL_INSTALL_DIR=/usr/local/bin mise run uninstall
```

## Preparing a project

Build the `.xcodeproj` or `.xcworkspace` with the active Xcode before running `swrl`. The resulting IndexStore must contain a `DataStore` directory.

Without an override, `swrl` searches Xcode's configured DerivedData directory. It matches the project against `WorkspacePath` in each `info.plist` and uses the newest valid index. Locations are checked in this order:

1. `--index-store <path>` — an IndexStore directory containing `DataStore`;
2. `--derived-data <path>` — a DerivedData directory containing `Index.noindex/DataStore`;
3. automatic DerivedData discovery.

All paths are normalized and may contain spaces.

## Usage

```text
swrl <project>
  [--file <path> ...]
  [--pattern <glob> ...]
  [--derived-data <path> | --index-store <path>]
  [--output <path>]
  [--silent]
```

At least one `--file` or `--pattern` is required. Both options can be repeated. Duplicate matches are analyzed once, and every pattern must match at least one Swift file.

```bash
# Analyze one file using automatic DerivedData discovery.
swrl MyApp.xcodeproj --file Sources/AppDelegate.swift

# Combine files and multiple patterns.
swrl MyApp.xcworkspace \
  --file Sources/Model.swift \
  --pattern 'Sources/Features/**/*.swift' \
  --pattern 'Sources/Services/*.swift'

# Use an explicit DerivedData directory and output path.
swrl MyApp.xcodeproj \
  --pattern 'Sources/**/*.swift' \
  --derived-data '/tmp/Derived Data/MyApp' \
  --output reports/analysis.json

# Use an IndexStore directly.
swrl MyApp.xcodeproj \
  --file Sources/AppDelegate.swift \
  --index-store '/tmp/Index.noindex'
```

The default output path is `output.json`. Progress and diagnostics go to stderr; `--silent` suppresses progress output. Run `swrl --help` or `swrl --version` for command help and the installed version.

## Report

The report keeps successful file results and records failures in `diagnostics`:

```json
{
  "diagnostics": [
    {
      "code": "analysis.file_failed",
      "file": "/path/to/MyApp/Sources/Broken.swift",
      "message": "The file could not be indexed.",
      "severity": "error"
    }
  ],
  "files": [
    {
      "declarations": [
        {
          "name": "AppDelegate",
          "type": "class"
        }
      ],
      "file": "/path/to/MyApp/Sources/AppDelegate.swift",
      "imports": [
        "UIKit"
      ],
      "module": "MyApp",
      "symbols": [
        {
          "chain": "AppDelegate",
          "column": 18,
          "line": 3,
          "originModuleName": "UIKit",
          "originModuleType": "external",
          "originType": "class",
          "symbol": "UIResponder"
        }
      ]
    }
  ],
  "project": "/path/to/MyApp/MyApp.xcodeproj",
  "summary": {
    "failed": 1,
    "requested": 2,
    "succeeded": 1,
    "unresolved": 0
  }
}
```

Files, imports, declarations, symbols, diagnostics, and JSON keys have stable ordering. The output file is replaced atomically. Repeated runs against the same index produce the same bytes. An `unknown` symbol increments `summary.unresolved` but does not fail the file.

Exit statuses:

| Code | Meaning |
| ---: | --- |
| `0` | Every requested file was processed. Unresolved symbols are allowed. |
| `1` | Environment or output error, or at least one file failed. Successful file results and diagnostics are still written for a partial analysis. |
| `64` | Invalid arguments, including missing files, unsupported extensions, empty patterns, or conflicting index overrides. |

## Developer tasks

| Command | Purpose |
| --- | --- |
| `mise run doctor` | Validate the active Xcode, Swift, and `libIndexStore`. |
| `mise run format` | Format `Package.swift`, `Sources`, and `Tests`. |
| `mise run format:check` | Check formatting without changing files. |
| `mise run lint` | Run SwiftLint in strict mode. |
| `mise run test` | Run unit and integration tests. |
| `mise run build` | Build the release executable. |
| `mise run check` | Run doctor, formatting, lint, tests, and release build in order. |
| `mise run clean` | Remove SwiftPM build artifacts. |
| `mise run install` | Install the release executable. |
| `mise run uninstall` | Remove the installed executable. |

The integration test creates a real IndexStore with `swiftc`, so it uses the Xcode toolchain checked by `doctor`. CI runs `mise run check` on macOS with the committed lockfile.

## Troubleshooting

### The active Xcode is wrong

Check the selected toolchain, then rerun `doctor`:

```bash
xcode-select -p
swift --version
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer mise run doctor
```

Use the same `DEVELOPER_DIR` while building the project and running `swrl`.

### Project or DerivedData was not found

Pass an existing `.xcodeproj` or `.xcworkspace`. If its path does not match `WorkspacePath` in DerivedData, pass the build directory with `--derived-data`.

For a custom DerivedData root, configure it in Xcode or pass the individual build directory explicitly.

### IndexStore does not contain DataStore

Build the project in Xcode and check that `<DerivedData>/Index.noindex/DataStore` exists. If the index is elsewhere, pass its `Index.noindex` directory with `--index-store`.

### Some files fail

Check stderr and the report's `diagnostics`. A partial analysis exits with `1`, but successful results remain in `files`. Each source file must exist, use the `.swift` extension, and be present in the selected IndexStore.

### Index database cache

IndexStoreDB data is cached under `~/Library/Caches/swrl`. The cache key includes the normalized project path, IndexStore path, and active Xcode path.

## Contribution

To contribute, use the follow "fork-and-pull" git workflow:

1. Fork the repository on github
2. Clone the project to your own machine
3. Commit changes to your own branch
4. Push your work back up to your fork
5. Submit a pull request so that I can review your changes

Run `mise run check` before committing.

*NOTE: Be sure to merge the latest from "upstream" before making a pull request!*

## License

`swrl` is released under the MIT license. See [LICENSE](LICENSE) for details.
