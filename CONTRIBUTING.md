# Contributing to ZedFlow

Thank you for your interest in contributing to ZedFlow! ZedFlow is designed to be a lightweight, rock-solid script runner, scheduler, and process manager for macOS with both a native menu bar UI and a fast headless CLI.

---

## Architecture Overview

ZedFlow is organized as a modular Swift package:

- **`Sources/ZedFlowKit`**: Core engine shared across the app, CLI, and test suite.
  - **`Core/ProcessRunner.swift`**: Script execution, stream handling, environment resolution, process group management, recursive descendant PID enumeration (`proc_listchildpids`), and force termination.
  - **`Core/EnvironmentResolver.swift`**: Automatically captures full shell environment (zsh, bash, fish, Homebrew, pyenv, nvm, asdf).
  - **`Core/JobScheduler.swift`**: Background timer-based job scheduler (interval and daily cron schedules).
  - **`Core/LaunchAtLoginService.swift`**: Native macOS `SMAppService` launch-at-login integration.
  - **`Core/NotificationService.swift`**: Native macOS UserNotifications on execution success or failure.
  - **`Core/StorageService.swift`**: JSON persistence for scripts and execution history (`~/Library/Application Support/ZedFlow/`).
  - **`IPC/IPCProtocol.swift`, `IPCServer.swift`, `IPCClient.swift`**: Unix domain socket IPC protocol (`/tmp/zedflow-<uid>.sock`).
  - **`State/ScriptStore.swift`**: Observable state manager coordinating processes, executions, schedules, and live UI updates.
- **`Sources/ZedFlow`**: Native SwiftUI Menu Bar Application (`ZedFlowApp`).
  - Minimal script list with quick action triggers and force stop controls.
  - Detail inspection view with real-time log console and execution history.
  - Script configuration sheets (parameters, interpreter selection, schedules, notifications).
- **`Sources/ZedFlowCLI`**: Companion CLI binary (`zedflow`).
  - Full headless control with streaming output and machine-readable `--json` support.
- **`Tests/ZedFlowTests`**: Comprehensive standalone test suite covering all phases (storage, process execution, scheduling, IPC, CLI, actions).

---

## Development Setup

### Prerequisites

- macOS 14.0 (Sonoma) or newer
- Swift 6.0 toolchain or Xcode 16+

### Building

To build the complete package:

```bash
swift build
```

To build in production release mode and assemble the `.app` bundle:

```bash
./scripts/build.sh
```

To install directly to `/Applications`:

```bash
./scripts/build.sh --install
```

---

## Running Tests

ZedFlow includes a 100+ assertion automated test suite covering storage, process execution, cancellation, process hierarchy teardown, IPC client/server communication, scheduling calculations, and action management.

Run the test suite with:

```bash
swift run ZedFlowTests
```

Ensure all tests pass before submitting a pull request.

---

## Coding Guidelines

- **Swift Concurrency & Thread Safety**: Ensure background tasks, actors, and locks are strictly respected (`@MainActor`, `Sendable`, `NSLock`).
- **Non-blocking I/O**: Never block the main thread or asynchronous event loops. Use non-blocking stream reads (`availableData`) for process streams.
- **Process Management**: Always ensure child processes and process groups are cleanly cleaned up upon cancellation or termination.
- **Error Handling**: Use typed errors and informative feedback messages in both CLI responses and UI notifications.
- **Minimal UI Aesthetic**: Maintain ZedFlow's clean, distraction-free macOS menu bar aesthetic. Avoid unnecessary clutter or visual noise.

---

## Submitting Pull Requests

1. Fork the repository and create a feature branch (`git checkout -b feature/amazing-idea`).
2. Make your changes and add tests for any new functionality or bug fixes.
3. Verify that `swift run ZedFlowTests` passes cleanly.
4. Commit your changes with clear, descriptive commit messages.
5. Push your branch to your fork and open a Pull Request against `main`.
