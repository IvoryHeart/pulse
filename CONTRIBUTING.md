# Contributing to pulse

Thanks for your interest in contributing! `pulse` is a macOS health monitoring tool written in pure Swift with zero external dependencies. Contributions of all sizes are welcome.

## Ground rules

- **No external Swift package dependencies.** The project intentionally uses only the Swift standard library, Foundation, and system frameworks (Darwin, IOKit, CoreWLAN, IOBluetooth, SwiftUI, etc.). Please don't add third-party packages.
- **No `sudo`, no system file writes, no silent deletions.** The cleanup and process-management features are built around explicit user permission and protected-path checks. Any new destructive action must follow the same permission model (see `pulse clean`).
- **macOS 14+ and Swift 5.9+.** Code should compile and run on the current supported target.

## Getting started

```sh
git clone https://github.com/IvoryHeart/pulse.git
cd pulse
swift build
.build/debug/pulse           # runs `pulse status` by default
swift test                # run the test suite
```

The project is a Swift Package with three products:

- `PulseCore` — library containing monitors, storage, and networking
- `pulse` — CLI executable and terminal UI
- `PulseApp` — SwiftUI menu bar app and dashboard

## Development workflow

1. **Fork** the repository and create a topic branch off `main`.
2. **Make your change.** Keep diffs focused — one feature or fix per PR.
3. **Add or update tests.** New monitors, storage changes, and CLI commands should have corresponding tests under `Tests/`.
4. **Run the test suite** with `swift test` and make sure everything passes.
5. **Open a pull request** with a clear description of the change, the motivation, and any manual testing you did.

## Coding guidelines

- Follow existing Swift style in the codebase (4-space indent, trailing commas where present, `// MARK:` section dividers).
- Prefer small, composable types. Each monitor should expose a `Codable` snapshot struct for JSON output.
- For any `Process`/`Pipe` usage, always call `readDataToEndOfFile()` *before* `waitUntilExit()` to avoid the classic pipe-buffer deadlock.
- Avoid commands known to hang (`top -l 1`, `netstat -v`). Use lower-level APIs or alternative flags.
- Keep CLI output terminal-friendly (no unconditional ANSI colors without a TTY check) and add a `--json` variant where it makes sense.

## Reporting bugs

Please open an issue with:

- Your macOS version and hardware (Apple Silicon vs Intel)
- The `pulse` version / commit hash you're running
- The exact command you ran and its output
- What you expected to happen

## Feature requests

Open an issue describing the use case. Because the project deliberately avoids dependencies and privileged operations, please explain how the feature fits within those constraints.

## Code of conduct

Be kind, be constructive, and assume good faith. Harassment of any kind will not be tolerated.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
