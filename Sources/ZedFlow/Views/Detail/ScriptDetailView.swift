import SwiftUI
import AppKit
import ZedFlowKit

struct ScriptDetailView: View {
    let script: Script
    let store: ScriptStore
    let onBack: () -> Void

    enum DetailTab: String, CaseIterable, Identifiable {
        case liveConsole = "Console"
        case history = "History"
        var id: String { rawValue }
    }

    @State private var selectedTab: DetailTab = .liveConsole

    private var isRunning: Bool {
        store.isRunningScript[script.id] == true
    }

    private var activeExecution: ScriptExecution? {
        store.activeExecutions[script.id] ?? store.latestExecutions[script.id]
    }

    private var executionStatus: ExecutionStatus? {
        store.executionStatus(for: script)
    }

    private var historyCount: Int {
        store.executionHistories[script.id]?.count ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Metadata Strip
            metadataStrip

            Divider()

            // Tab Selector
            tabSelector
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Tab Content
            Group {
                switch selectedTab {
                case .liveConsole:
                    LogConsoleView(execution: activeExecution, isRunning: isRunning)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                case .history:
                    ExecutionHistoryView(script: script, store: store)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .task {
            _ = await store.loadHistory(for: script)
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Scripts")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(script.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Quick Actions: Open Editor, Reveal Finder, Run/Stop
            HStack(spacing: 6) {
                Button {
                    store.openInEditor(script)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Open in Default Editor")

                Button {
                    store.revealInFinder(script)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Divider()
                    .frame(height: 12)

                Button {
                    if isRunning {
                        store.stopScript(script)
                    } else {
                        store.runScript(script)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(isRunning ? "Stop" : "Run")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isRunning ? .orange : .accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
                .help(isRunning ? "Stop Script" : "Run Script Now")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Metadata Strip

    private var metadataStrip: some View {
        HStack(spacing: 16) {
            // Status
            HStack(spacing: 6) {
                StatusIndicatorView(status: executionStatus)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }

            Divider()
                .frame(height: 12)

            // Start Time
            if let start = activeExecution?.startTime {
                HStack(spacing: 4) {
                    Text("Started:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(formatTime(start))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            // Duration
            if let duration = activeExecution?.duration {
                Divider()
                    .frame(height: 12)
                HStack(spacing: 4) {
                    Text("Duration:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(formatDuration(duration))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                }
            }

            // Exit Code
            if let code = activeExecution?.exitCode {
                Divider()
                    .frame(height: 12)
                HStack(spacing: 4) {
                    Text("Exit:")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(code)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(code == 0 ? .green : .red)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private var statusText: String {
        switch executionStatus {
        case .running:
            return "Running"
        case .success:
            return "Success"
        case .failed:
            return "Failed"
        case .stopped:
            return "Stopped"
        case .none:
            return "Idle"
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        Picker("", selection: $selectedTab) {
            Text("Console").tag(DetailTab.liveConsole)
            Text(historyCount > 0 ? "History (\(historyCount))" : "History").tag(DetailTab.history)
        }
        .pickerStyle(.segmented)
    }

    private func formatTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .medium
        df.dateStyle = .none
        return df.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1.0 {
            return String(format: "%.2fs", duration)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            return "\(mins)m \(secs)s"
        }
    }
}
