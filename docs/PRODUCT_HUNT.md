# 🚀 Product Hunt Launch Kit — ZedFlow

Welcome to the official Product Hunt launch kit for **ZedFlow**. This document provides all the ready-to-use copy, assets, Maker's comment, social media announcements, and launch day strategy to ensure a successful launch on Product Hunt.

---

## 📋 1. Product Metadata & Listing Details

| Field | Content |
| :--- | :--- |
| **Product Name** | `ZedFlow` |
| **Tagline** *(Max 60 chars)* | `Lightweight macOS menu bar script runner & scheduler` |
| **Alternative Taglines** | 1. `Run, schedule & monitor scripts from the macOS menu bar`<br>2. `The native macOS script runner with headless AI IPC`<br>3. `Lightweight script automation companion for macOS & AI agents` |
| **Product URL** | `https://zephinax.github.io/zed-flow/` |
| **GitHub Repository** | `https://github.com/zephinax/zed-flow` |
| **Pricing** | **Free & 100% Open Source** (MIT License) |
| **Platforms** | macOS 14.0+ (Sonoma, Sequoia) • Universal (Apple Silicon & Intel) |
| **Categories / Topics** | `Developer Tools`, `Mac Apps`, `Open Source`, `Productivity`, `Artificial Intelligence` |

---

## 📝 2. Product Description (Product Hunt Listing)

### Short Description (Punchy Summary)
> ZedFlow bridges the gap between terminal automation and the macOS menu bar. Run, schedule, and monitor shell scripts, Python tools, and CLI workflows with zero friction. Features sub-action presets with SF Symbols, unstoppable recursive SIGKILL force stop, zero-config shell environment loader, and headless Unix domain socket IPC with `--json` output for AI agents.

### Detailed Description (Full Listing Body)

**Tired of terminal clutter, stuck background workers, and bloated Electron wrappers?**

ZedFlow is a high-performance, native macOS menu bar app written in Swift 6. It gives developers, power users, and AI coding agents instant control over recurring tasks, dev environments, proxy toggles, scrapers, and database backups.

#### 🌟 Key Highlights:
- **🖥️ Native Menu Bar First**: Lives unobtrusively in your macOS status bar. Single-click script execution with dynamic status dots (`active`, `clear`, `failed`, `running`).
- **🧩 Actions & Subcommands**: Define custom action verbs on any script (e.g., `Start`, `Stop`, `Status`, `Dev`, `Prod`) with custom arguments and native SF Symbol icons.
- **🛑 Rock-Solid Force Stop**: No more runaway background jobs. Recursively discovers all child PIDs using `proc_listchildpids` and terminates the entire process tree (`-pid`, root `pid`, and children) with `SIGKILL`.
- **💻 Headless IPC CLI (`zedflow`)**: Full Unix Domain Socket control. Control scripts, trigger runs, or inspect statuses directly from the terminal or AI agents (Claude Code, Cursor, Raycast, Alfred) with structured `--json` output.
- **⏰ Built-In Job Scheduler**: Recurring intervals (1m to 24h) or exact daily time-of-day execution with intelligent sleep/wake drift compensation.
- **📡 Universal Status Protocol**: Scripts communicate dynamic status without SDK dependencies using stdout directives (e.g. `[zedflow:status=active]`) or standard LSB exit codes (`0`, `2`, `3`).
- **🐚 Zero-Config Shell Environment**: Executes an interactive login shell probe at startup to resolve your real `$PATH`, Homebrew, nvm, pyenv, asdf, and cargo binaries.
- **📜 60fps ANSI Streaming Console**: Real-time log console with ANSI escape code decoding and persistent execution history storing up to 50 runs per script.
- **🪶 Ultra-Lightweight**: Native AppKit + SwiftUI. Weighs less than 25MB RAM and idles at 0% CPU.

---

## 💬 3. Maker's First Comment (Launch Story)

*Post this comment immediately after publishing the product on Product Hunt.*

> Hey Product Hunt community! 👋
>
> I'm the maker of **ZedFlow**, and I'm super excited to share it with all of you today!
>
> ### 💡 Why I built ZedFlow
> Like many developers, my daily workflow involves dozens of scripts: toggling DNS proxies, cleaning up Docker artifacts, backing up local databases, triggering deployment jobs, and running test suites.
>
> For years, my choices were:
> 1. Keep a messy sprawl of terminal tabs open.
> 2. Set up heavy launchd / cron jobs with silent failures.
> 3. Use bulky Electron-based script runners that hog 500MB of RAM just to run a bash script.
> 4. Deal with stuck child processes and orphaned background workers when stopping a script.
>
> I wanted something that felt like a **true native citizen of macOS** — ultra-fast, lightweight (< 25MB RAM), aesthetically clean, and capable of both human interaction and AI agent automation.
>
> ### 🛠️ What makes ZedFlow different?
> - **Pure Swift 6 & AppKit**: Built from scratch with Swift 6 strict concurrency. No web views, no Electron, no tracking, and 100% open source under MIT.
> - **Sub-Action Presets**: Scripts aren't just one-shot commands. A single script can have multiple actions (`On`, `Off`, `Check`, `Rebuild`) with custom SF Symbol icons.
> - **Bulletproof Process Teardown**: Many tools leave child processes hanging when you hit stop. ZedFlow walks the actual kernel process tree (`proc_listchildpids`) and wipes out the whole family with `SIGKILL`.
> - **AI & CLI First**: With the included `zedflow` CLI and Unix Domain Socket IPC, AI coding agents (Claude Code, Cursor, Codex) can inspect, configure, and run tasks with machine-readable `--json` flags.
>
> ### 🎁 100% Free & Open Source
> ZedFlow is completely free and open source. You can download pre-built signed universal binaries (Apple Silicon & Intel) or compile it directly from source in seconds.
>
> 🔗 **Website**: https://zephinax.github.io/zed-flow/  
> 📦 **GitHub**: https://github.com/zephinax/zed-flow  
>
> I'd love to hear your feedback, thoughts, or feature requests! What scripts would you love to automate from your menu bar?
>
> Thank you for your support! ❤️

---

## 🖼️ 4. Gallery & Media Assets Guide

Product Hunt allows up to **6 gallery images** and a **thumbnail**. Use the existing high-resolution screenshots located in `docs/screenshots/`:

| Slide # | Asset Source | Headline / Overlay Caption | Description |
| :---: | :--- | :--- | :--- |
| **Thumbnail** | `docs/assets/icon.png` | *(App Icon Squircle)* | 240x240px high-contrast icon with glowing border. |
| **Image 1** | `docs/screenshots/menu-bar-actions.png` | **Instant Menu Bar Automation** | Compact popover showing multi-action buttons, status indicators, and quick triggers. |
| **Image 2** | `docs/screenshots/new-script-config.png` | **Flexible Script & Schedule Config** | Modal showing interpreter selection, action flags, intervals, and notifications. |
| **Image 3** | `docs/screenshots/live-console-directives.png` | **Real-Time Streaming ANSI Console** | Live output buffer with ANSI color decoding, duration timer, and Force Stop button. |
| **Image 4** | `docs/screenshots/execution-history.png` | **Persistent Execution History** | Inspecting past 50 runs, exit codes, and combined stdout/stderr history. |
| **Image 5** | Simulated CLI Graphic | **Headless IPC for AI Agents** | Split visual showing `zedflow list` and `zedflow status --json` in terminal. |

---

## 📣 5. Social Media Announcement Templates

### 🐦 Twitter / X Thread

**Tweet 1 (Hook):**
> 🚀 Launching ZedFlow today on Product Hunt!
>
> The lightweight macOS menu bar script runner, scheduler, and automation companion — built 100% native with Swift 6.
>
> 🔗 Support us: https://www.producthunt.com/products/zedflow
>
> Here's why we built it 👇 (1/6)

**Tweet 2 (Problem & Solution):**
> Running recurring scripts shouldn't require 10 open terminal tabs or a 500MB Electron wrapper.
>
> ZedFlow sits quietly in your menu bar (< 25MB RAM) and lets you run, schedule, and monitor Bash, Python, Node, and CLI tools with one click. (2/6)

**Tweet 3 (Key Feature - Actions):**
> Scripts aren't one-dimensional.
>
> With ZedFlow Actions, attach multiple verbs to a single script (e.g. `start`, `stop`, `status`, `rebuild`) with custom arguments and native SF Symbol icons. (3/6)

**Tweet 4 (Key Feature - Force Stop & IPC):**
> Tired of runaway background processes?
>
> ZedFlow walks the kernel process tree via `proc_listchildpids` to ensure a true `SIGKILL` cleanup.
>
> Plus, full Unix Socket IPC with `--json` for Claude Code, Cursor, and AI agents! (4/6)

**Tweet 5 (Open Source & Free):**
> ⚡ Universal macOS binary (Apple Silicon + Intel)
> 🔒 100% local-only & open source (MIT)
> ⏱️ Interval & daily job scheduler
> 🎨 ANSI streaming console with history
>
> Free on GitHub: https://github.com/zephinax/zed-flow (5/6)

**Tweet 6 (CTA):**
> If you love native macOS dev tools, we'd appreciate your upvote and feedback on Product Hunt today! 🙏
>
> https://www.producthunt.com/products/zedflow (6/6)

---

### 💼 LinkedIn Post

> Exciting news! Today we're launching **ZedFlow** on Product Hunt.
>
> If you're a developer or power user on macOS, you probably have a collection of utility scripts: toggling DNS proxies, cleaning Docker containers, running database backups, or triggering build tasks.
>
> We built ZedFlow to make script automation feel like second nature:
> • 🖥️ **Menu Bar First**: Clean, native AppKit/SwiftUI interface.
> • 🧩 **Multi-Action Presets**: Attach custom verbs and flags with SF Symbol icons.
> • 🛑 **Recursive Force Stop**: Bulletproof process hierarchy termination (`SIGKILL`).
> • 💻 **Headless CLI (`zedflow`)**: Unix domain socket with `--json` output for AI coding agents.
> • 🪶 **Ultra-lightweight**: < 25MB RAM, Swift 6 native, Apple Silicon & Intel universal binary.
>
> It's 100% free and open-source under the MIT license.
>
> Check out the launch on Product Hunt and let us know your thoughts:
> 🔗 https://www.producthunt.com/products/zedflow
> 📦 GitHub: https://github.com/zephinax/zed-flow

---

### 👾 Reddit Announcement (r/macapps, r/commandline, r/apple)

**Title**: `I built ZedFlow: A lightweight native macOS menu bar script runner, scheduler, and CLI companion (Swift 6, Open Source)`

**Post Body**:
> Hey r/macapps!
>
> I wanted to share a project I've been working on called **ZedFlow**.
>
> **The Problem**:
> I got tired of having terminal windows open just to run routine maintenance scripts, and launchd is overkill when you just want a quick toggle in your menu bar. At the same time, most existing tools are bloated Electron apps or lack basic features like child process cleanup.
>
> **What ZedFlow is**:
> A native macOS menu bar app written in Swift 6. It lets you register, run, and schedule any script (Bash, Zsh, Python, Node, Ruby, binaries) right from your status bar.
>
> **Cool Features**:
> 1. **Multi-Action Presets**: You can attach multiple subcommands to one script (e.g. `VPN -> Connect / Disconnect / Status`) with custom SF Symbols.
> 2. **Recursive Process Cleanup**: When you hit Stop, it enumerates child processes with `proc_listchildpids` and terminates the whole process tree so no orphan background tasks stay running.
> 3. **Universal Status Protocol**: Scripts can output `[zedflow:status=active]` or use standard exit codes (0 = Success, 2/3 = Inactive) to dynamically update the menu bar indicator dot.
> 4. **Headless CLI**: Includes a `zedflow` CLI that communicates with the app over a Unix domain socket. Supports `--json` for integration with Claude Code, Cursor, Raycast, and shell aliases.
> 5. **Native & Fast**: No web wrappers, under 25MB RAM, Universal binary (Apple Silicon + Intel).
>
> It's 100% free and open source:
> - **GitHub**: https://github.com/zephinax/zed-flow
> - **Website**: https://zephinax.github.io/zed-flow/
> - **Product Hunt Launch**: https://www.producthunt.com/products/zedflow
>
> Would love to hear what kind of scripts you'd use this for or any features you'd like to see!

---

## 🎯 6. Launch Day Hour-by-Hour Checklist

- [ ] **12:01 AM PST**: Product Hunt listing goes live (Product Hunt resets at midnight Pacific Time).
- [ ] **12:05 AM PST**: Post the **Maker's First Comment** (Section 3 above).
- [ ] **12:15 AM PST**: Post on **Twitter / X** with screenshots and tag relevant macOS / developer tool accounts.
- [ ] **07:00 AM PST**: Post to **LinkedIn** and **Reddit** (`r/macapps`, `r/commandline`).
- [ ] **08:30 AM PST**: Share in relevant Discord and Slack developer communities (without explicitly asking for upvotes, focus on feedback and open-source contribution).
- [ ] **All Day**: Respond to **every single comment** on Product Hunt within 15–30 minutes to maintain high engagement velocity.
