import SwiftUI
import AppKit
import ZedFlowKit

struct ExecutionHistoryView: View {
    let script: Script
    let store: ScriptStore

    @State private var selectedExecutionId: UUID? = nil
    @State private var showingClearConfirmation: Bool = false

    private var history: [ScriptExecution] {
        store.executionHistories[script.id] ?? []
    }

    private var selectedExecution: ScriptExecution? {
        if let id = selectedExecutionId {
            return history.first { $0.id == id }
        }
        return history.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // History Subheader
            HStack {
                Text(history.count == 1 ? "1 Previous Run" : "\(history.count) Previous Runs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                if !history.isEmpty {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Clear History…")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear all previous run logs for this script")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No Execution History")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Runs will automatically be recorded here.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 30)
            } else {
                // Split Layout: History List (left) + Log Inspector (right)
                HSplitView {
                    // History Run List
                    List(history, selection: $selectedExecutionId) { run in
                        HStack(spacing: 8) {
                            StatusIndicatorView(status: run.status)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(formatDate(run.startTime))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary)
                                    if let action = run.actionName, !action.isEmpty {
                                        Text(action)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.accentColor.opacity(0.12))
                                            )
                                    }
                                }

                                HStack(spacing: 4) {
                                    if let duration = run.duration {
                                        Text(formatDuration(duration))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    if let code = run.exitCode {
                                        Text("• exit \(code)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .tag(run.id)
                    }
                    .frame(minWidth: 160, idealWidth: 180, maxWidth: 210)
                    .listStyle(.sidebar)

                    // Selected Run Output & Metadata
                    VStack(spacing: 0) {
                        if let selected = selectedExecution {
                            LogConsoleView(execution: selected, isRunning: false)
                        } else {
                            Text("Select an execution to inspect logs")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(minWidth: 260)
                }
            }
        }
        .task {
            _ = await store.loadHistory(for: script)
            if selectedExecutionId == nil {
                selectedExecutionId = history.first?.id
            }
        }
        .confirmationDialog(
            "Clear Execution History for “\(script.name)”?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) {
                Task {
                    try? await store.clearHistory(for: script)
                    selectedExecutionId = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all captured logs and execution records for this script.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .medium
        timeFormatter.dateStyle = .none

        if calendar.isDateInToday(date) {
            return "Today, " + timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, " + timeFormatter.string(from: date)
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1.0 {
            return String(format: "%.1fs", duration)
        } else if duration < 60 {
            return String(format: "%.0fs", duration)
        } else {
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            return "\(mins)m \(secs)s"
        }
    }
}
