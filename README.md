# swrl

[![CI](https://img.shields.io/github/actions/workflow/status/igooor-bb/swrl/ci.yml?branch=main&label=CI&logo=github)](https://github.com/igooor-bb/swrl/actions/workflows/ci.yml)
[![Swift 6.0+](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MIT License](https://img.shields.io/github/license/igooor-bb/swrl)](https://github.com/igooor-bb/swrl/blob/main/LICENSE)

`swrl` is a command-line symbol dependency analyzer for Swift projects. It shows what each source file declares, which symbols it uses, and where those symbols come from.

It works with an existing Xcode index: `swrl` never runs `xcodebuild` or modifies the project it analyzes.

## Quick start

### Requirements

- macOS 12 or later
- Xcode with Swift 6.0 or later
- [mise](https://mise.jdx.dev/) 2026.7.13 or later

Clone, validate, and install the project:

```bash
git clone https://github.com/igooor-bb/swrl.git
cd swrl
mise install --locked
mise run doctor
mise run install
```

The executable is installed to `~/.local/bin/swrl`. To choose another location, set `SWRL_INSTALL_DIR`:

```bash
SWRL_INSTALL_DIR=/usr/local/bin mise run install
```

`swrl` uses the active Xcode. Select a different installation through `xcode-select` or `DEVELOPER_DIR` if needed.

## Analyze a project

First, build the `.xcodeproj` or `.xcworkspace` in Xcode so its IndexStore is available. Then pass the project and at least one file or glob pattern:

```bash
swrl MyApp.xcodeproj --file Sources/AppDelegate.swift
```

```bash
swrl MyApp.xcworkspace \
  --pattern 'Sources/Features/**/*.swift' \
  --pattern 'Sources/Services/*.swift' \
  --output reports/analysis.json
```

Files and patterns can be combined and repeated.

### Command reference

```text
swrl <project>
  [--file <path> ...]
  [--pattern <glob> ...]
  [--derived-data <path> | --index-store <path>]
  [--output <path>]
  [--silent]
```

| Option | Short | Description |
| --- | :---: | --- |
| `--file <path>` | `-f` | Analyze a Swift file. Repeatable. |
| `--pattern <glob>` | `-p` | Analyze files matching a glob. Repeatable. |
| `--derived-data <path>` |  | Use a specific DerivedData directory. |
| `--index-store <path>` |  | Use a specific Xcode index. |
| `--output <path>` | `-o` | Write the report to this path. Defaults to `output.json`. |
| `--silent` | `-s` | Suppress progress and diagnostic output. |

Run `swrl --help` for built-in help or `swrl --version` for the installed version.

### Using a specific index

By default, `swrl` finds the matching index in Xcode's DerivedData directory. You can override it when the index is stored elsewhere:

```bash
swrl MyApp.xcodeproj \
  --pattern 'Sources/**/*.swift' \
  --derived-data '/tmp/Derived Data/MyApp'
```

Use `--derived-data` for a project-specific DerivedData directory or `--index-store` for a direct path to `Index.noindex`.

## Output

During analysis, `swrl` prints a clear, structured view of the discovered declarations and symbol dependencies directly to the terminal. Use `--silent` when only the JSON report is needed.

The JSON report contains the analyzed project, per-file declarations and symbol references, diagnostics, and a summary:

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

Failed files appear in `diagnostics` while successful results remain in `files`. Unresolved symbols increase `summary.unresolved` but do not fail the analysis.

### Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | All requested files were processed; unresolved symbols are allowed. |
| `1` | An environment or output error occurred, or at least one file failed. |
| `64` | The command arguments are invalid. |

## Development

Run the full validation suite before submitting changes:

```bash
mise install --locked
mise run check
```

Useful tasks:

| Command | Purpose |
| --- | --- |
| `mise run doctor` | Validate the active Xcode toolchain. |
| `mise run format` | Format the package and Swift sources. |
| `mise run lint` | Run SwiftLint in strict mode. |
| `mise run test` | Run unit and integration tests. |
| `mise run build` | Build the release executable. |
| `mise run check` | Run all project checks. |
| `mise run clean` | Remove SwiftPM build artifacts. |
| `mise run uninstall` | Remove the installed executable. |

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Wrong Xcode is active | Run `xcode-select -p` and `swift --version`. Use the same `DEVELOPER_DIR` to build the project and run `swrl`. |
| Project or DerivedData is not found | Verify the project path or pass its build directory with `--derived-data`. |
| IndexStore is unavailable | Build the project in Xcode. If it uses a custom location, pass it with `--derived-data` or `--index-store`. |
| Some files fail | Check stderr and `diagnostics`. Each file must exist, use the `.swift` extension, and be present in the selected index. |

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

swrl is available under the MIT license. See [LICENSE](LICENSE) file for more details.
