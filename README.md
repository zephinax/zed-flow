<p align="center">
  <img src="https://raw.githubusercontent.com/zephinax/zed-flow/main/Config/Icon.png" alt="ZedFlow Logo" width="100" onerror="this.style.display='none'"/>
</p>

<h1 align="center">ZedFlow</h1>

<p align="center">
  <strong>The lightweight macOS menu bar script runner, scheduler, and automation companion for developers, power users, and AI agents.</strong>
</p>

<p align="center">
  <a href="#features"><img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-blue.svg?style=flat-square" alt="Platform: macOS 14.0+"></a>
  <a href="#features"><img src="https://img.shields.io/badge/Swift-6.0-F05138.svg?style=flat-square&logo=swift" alt="Swift 6.0"></a>
  <a href="#testing"><img src="https://img.shields.io/badge/tests-103%20passed-success.svg?style=flat-square" alt="103 Passed Tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg?style=flat-square" alt="License: MIT"></a>
  <a href="https://github.com/zephinax/zed-flow"><img src="https://img.shields.io/badge/architecture-Universal%20(ARM%20%2B%20x86)-purple.svg?style=flat-square" alt="Universal Binary"></a>
</p>

---

## 💡 What is ZedFlow?

**ZedFlow** bridges the gap between terminal automation and the macOS menu bar. It lets you run, schedule, monitor, and manage shell scripts, Python tools, Node scripts, and CLI utilities with zero friction:

- **Menu Bar First**: Keep your most important development tasks, proxy toggles, docker cleaners, and scrapers one click away in your macOS menu bar.
- **Actions & Subcommands**: Define sub-actions for a script (e.g., `Start`, `Stop`, `Status`, `Dev`, `Prod`) with custom arguments and SF Symbol icons.
- **Headless CLI Companion (`zedflow`)**: Full IPC control over Unix Domain Socket with streaming output and machine-readable `--json` flags for AI agents, shell aliases, and Raycast/Alfred workflows.
- **Rock-Solid Force Stop**: Immediately halts runaway processes, process groups, and descendant child processes (`SIGKILL`) without hanging open pipes or leaving orphaned workers.
- **Zero Config Environment**: Automatically resolves your actual user login shell environment (`PATH`, Homebrew, nvm, pyenv, asdf, cargo) so scripts execute exactly as they do in your terminal.

---

## ✨ Key Features

### 🖥️ Native macOS Menu Bar Experience
- Clean, compact single-line script rows with dynamic status indicators (`active`, `clear`, `failed`, `running`, `stopped`).
- Minimal icon-capsule dropdown for scripts with multi-action workflows.
- Rich detail view with a real-time log console, execution duration, and ANSI color decoding.

### 🛑 Reliable Force Stop & Process Tree Teardown
- Never deal with stuck background jobs again.
- Recursively enumerates child process IDs via `proc_listchildpids` and terminates the entire process hierarchy (`-pid`, root `pid`, and all children) with `SIGKILL`.
- Uses non-blocking stream reads so dangling child file descriptors never freeze the app.

### 🧩 Actions & Flag Presets
- Attach multiple action presets to any script (e.g. `zedflow run vpn --action connect`).
- Each action carries its own arguments, flags, and custom SF Symbol icon.

### 📡 Universal Status Protocol
Scripts can communicate dynamic state directly to ZedFlow using simple output directives or standard Linux Standard Base (LSB) exit codes:
- **Output Directives**: Emit `[zedflow:status=active]`, `[zedflow:status=clear]`, or `[zedflow:status=failed]` anywhere in stdout.
- **Standard Exit Codes**:
  - `0`: Success / Active (Green indicator)
  - `2` or `3`: Clear / Inactive / Off (Gray indicator)
  - Non-zero: Error / Failed (Red indicator)

### ⏰ Native Background Job Scheduler
- Automated recurring executions:
  - **Intervals**: Every 1m, 5m, 15m, 30m, 1h, 2h, 4h, 8h, 12h, 24h.
  - **Daily**: Execute at a specific time of day (e.g. `09:30` or `18:00`).
- Built-in sleep and wake compensation prevents backlog stampedes when waking from sleep.

### 📜 Execution History & Logs
- Live streaming output buffer with 60fps UI throttling.
- Persistent execution history storing up to 50 past executions per script with exit codes, timestamps, and full combined stdout/stderr output.

### 💻 Fast Headless CLI (`zedflow`)
- Control everything from the terminal, shell scripts, or AI coding agents.
- `--json` flag on every command returns structured, machine-parsable JSON.

### 🔔 Notifications & Launch at Login
- Native macOS User Notifications for script completion, errors, or failures.
- Native `SMAppService` launch at login support with zero helper daemon bloat.

---

## 🚀 Quick Start & Installation

### Prerequisites
- macOS 14.0 (Sonoma) or newer
- Swift 6.0+ (Xcode 16+ or Command Line Tools)

### Build & Install from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/zephinax/zed-flow.git
   cd zed-flow
   ```

2. Build the release app and install the CLI:
   ```bash
   ./scripts/build.sh --install
   ```

   This compiles ZedFlow in production release mode, packages `ZedFlow.app` into `/Applications/ZedFlow.app`, and creates a symlink for the `zedflow` CLI in `/usr/local/bin/zedflow` (or `~/.local/bin/zedflow`).

3. Launch the app:
   ```bash
   open /Applications/ZedFlow.app
   ```

---

## 📖 CLI Guide (`zedflow`)

The `zedflow` CLI communicates directly with `ZedFlow.app` via a fast Unix Domain Socket (`/tmp/zedflow-<uid>.sock`).

### Discovery & Status

```bash
# List all configured scripts, their schedules, and defined actions
zedflow list

# Inspect script details and its latest execution
zedflow status "Proxy Manager"

# Check connection to the ZedFlow background server
zedflow ping
```

### Script Execution & Control

```bash
# Run a script and stream output in real-time
zedflow run "Backup Database"

# Run a specific action on a script
zedflow run "Proxy Manager" --action "Enable"

# Run in background (fire-and-forget)
zedflow run "Nightly Sync" --async

# Force stop a currently running script and all its subprocesses
zedflow stop "Nightly Sync"

# View previous execution history and logs
zedflow history "Backup Database"
```

### Script Management

```bash
# Register a new script
zedflow add ~/Scripts/deploy.sh --name "Deploy" --interpreter bash

# Configure a recurring schedule (manual | interval <mins> | daily <HH:mm>)
zedflow schedule "Deploy" "interval 30"
zedflow schedule "Nightly Backup" "daily 02:00"

# Enable or disable a script's schedule
zedflow enable "Nightly Backup"
zedflow disable "Nightly Backup"

# Configure native macOS notifications
zedflow notify "Deploy" --success true --failure true

# Remove a script from ZedFlow (file remains on disk)
zedflow remove "Deploy"
```

### Action Management

```bash
# List actions on a script
zedflow action list "Proxy Manager"

# Add an action with custom arguments and an SF Symbol icon
zedflow action add "Proxy Manager" "Start" --icon "bolt.fill" --args "--mode=socks5" "--port=1080"
zedflow action add "Proxy Manager" "Stop" --icon "stop.circle" --args "--shutdown"

# Update an action
zedflow action update "Proxy Manager" "Start" --name "Enable" --icon "play.fill"

# Reorder an action
zedflow action reorder "Proxy Manager" "Stop" 1

# Delete an action
zedflow action remove "Proxy Manager" "Enable"
```

### 🤖 Machine-Readable JSON Mode (for AI Agents & Scripts)

Pass `--json` to any command for clean, structured JSON output:

```bash
zedflow list --json
```

```json
[
  {
    "id": "7D5072DE-8C37-4180-877B-1EE1A53DE3AA",
    "name": "Proxy Manager",
    "scriptPath": "/Users/user/Scripts/proxy.sh",
    "interpreter": "bash",
    "isEnabled": true,
    "schedule": {
      "type": "manual"
    },
    "actions": [
      {
        "id": "2E9102B3-739F-499D-B19F-667790EBD072",
        "name": "Enable",
        "arguments": ["--mode=socks5"],
        "systemImage": "bolt.fill"
      },
      {
        "id": "DF9C103F-5D2B-4A73-A332-9F08EB924DC4",
        "name": "Disable",
        "arguments": ["--stop"],
        "systemImage": "stop.fill"
      }
    ]
  }
]
```

---

## 🛠️ Universal Script Protocol

ZedFlow scripts can control how they appear in the menu bar using **directives** or **standard exit codes**.

### 1. Dynamic Status Directives

Print a status tag anywhere in your script's output (`stdout` or `stderr`):

```bash
#!/bin/bash
if curl -sSf https://my-vpn.internal/health > /dev/null; then
    echo "[zedflow:status=active] VPN is online"
    exit 0
else
    echo "[zedflow:status=clear] VPN disconnected"
    exit 2
fi
```

Supported status directives:
- `[zedflow:status=active]` or `@zedflow:status=active` 🟢 **Active / Green**
- `[zedflow:status=clear]` or `@zedflow:status=clear` ⚪ **Inactive / Clear**
- `[zedflow:status=failed]` or `@zedflow:status=failed` 🔴 **Failed / Red**

### 2. Exit Code Standards

If no directive tag is present, ZedFlow follows the standard Linux Standard Base (LSB) exit code conventions:

| Exit Code | Status | Indicator | Description |
| :---: | :---: | :---: | :--- |
| `0` | **Success** | 🟢 Green | Operation completed successfully / service active |
| `2` or `3` | **Clear** | ⚪ Gray | Service inactive, toggled off, or cleared |
| Other | **Failed** | 🔴 Red | Execution failed or terminated with error |

---

## 🏗️ Project Architecture

```
zedflow/
├── Package.swift                    # Swift Package definition
├── Config/
│   └── Info.plist                   # App bundle configuration (LSUIElement=true)
├── scripts/
│   └── build.sh                     # Release build, signing & install script
├── Sources/
│   ├── ZedFlow/                     # SwiftUI Menu Bar Application
│   │   ├── App/                     # AppDelegate & MenuBarExtra root
│   │   └── Views/                   # Row views, detail consoles, edit sheets
│   ├── ZedFlowCLI/                  # Headless companion CLI (zedflow)
│   │   └── main.swift               # Command routing, argument parser & JSON emitter
│   └── ZedFlowKit/                  # Core library
│       ├── Core/                    # ProcessRunner, EnvironmentResolver, JobScheduler
│       ├── IPC/                     # Unix domain socket protocol, client, server
│       ├── Models/                  # Script, ScriptAction, ScriptExecution, ScheduleConfig
│       └── State/                   # ScriptStore observable state manager
└── Tests/
    └── ZedFlowTests/                # 100+ assertion automated test runner
```

---

## 🧪 Testing

ZedFlow includes a standalone test suite with **103 passing tests** verifying:
- Model serialization and JSON storage capping
- Process runner cancellation and immediate `SIGKILL` force termination
- Recursive child process enumeration and teardown
- PATH and shebang detection across interpreters (`sh`, `bash`, `zsh`, `python3`)
- Interval and daily schedule rollover logic
- IPC Unix domain socket client/server request/response cycles
- Script actions, flag splitting, and argument preservation

Run the test suite at any time:

```bash
swift run ZedFlowTests
```

---

## 📄 License

ZedFlow is released under the [MIT License](LICENSE).  
Copyright © 2026 [Zephinax](https://github.com/zephinax).
