# Changelog

All notable changes to ZedFlow will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-10-19

### Added
- **Heartbeat Status Monitoring**: Continuous background health check probes for registered scripts with customizable intervals and dedicated status actions.
- **Modern GitHub Pages Landing Page**: High-performance, responsive showcase website with interactive UI tour, simulated terminal, and protocol playground.
- **Automated Pages CI/CD**: Seamless GitHub Actions workflow deploying `/docs` to GitHub Pages upon push.
- **Product Hunt Launch Kit**: Comprehensive launch materials, maker story, community threads, and promotional assets.

### Fixed
- **APFS Case-Insensitive Packaging**: Fixed an architecture build script issue on macOS APFS where the CLI binary collided with and overwrote the GUI app bundle in the temporary build directory.
- **CLI Install Fallback**: Improved installation path resolution to automatically fall back to `~/.local/bin/zedflow` when `/usr/local/bin` is not writable.
- **Dynamic Version Display**: Settings View now dynamically reads the application version from the bundle's `Info.plist`.

## [1.0.0] - 2026-10-13

### Added
- **Native macOS Menu Bar App**: Clean, compact menu bar interface built with SwiftUI and AppKit.
- **Dynamic Status Directives**: Scripts can emit `[zedflow:status=active]`, `[zedflow:status=clear]`, or `[zedflow:status=failed]`.
- **LSB Exit Code Compliance**: Automatically maps standard exit codes (0 = Success, 2/3 = Clear/Inactive, non-zero = Failed).
- **Headless Companion CLI (`zedflow`)**: Full IPC control over Unix Domain Socket (`/tmp/zedflow-<uid>.sock`) with `--json` output support.
- **Process Hierarchy Teardown**: Recursive descendant child process enumeration via `proc_listchildpids` and non-blocking `SIGKILL` termination.
- **User Environment Resolution**: Automatic login shell environment resolution (PATH, Homebrew, nvm, pyenv, asdf, cargo).
- **Script Actions & Flag Presets**: Support multiple action subcommands per script with dedicated arguments and SF Symbol icons.
- **Background Job Scheduler**: Recurring interval timers (1m to 24h) and daily time-of-day execution with sleep/wake backlog compensation.
- **Execution History & Logs**: Real-time 60fps streaming log console and persistent history storage up to 50 executions per script.
- **macOS Notifications & Launch at Login**: Native UserNotifications and modern `SMAppService` launch-at-login integration.
- **Automated Test Suite**: 103 assertions validating storage, IPC, scheduling, and process execution.
