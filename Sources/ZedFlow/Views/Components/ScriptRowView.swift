import SwiftUI
import ZedFlowKit

struct ScriptRowView: View {
    let script: Script
    let store: ScriptStore
    let onSelect: (Script) -> Void
    let onEdit: (Script) -> Void

    @State private var isHovered: Bool = false
    @State private var showingDeleteAlert: Bool = false

    private var isRunning: Bool {
        store.isRunningScript[script.id] == true
    }

    private var executionStatus: ExecutionStatus? {
        store.executionStatus(for: script)
    }

    private var latestExecution: ScriptExecution? {
        store.latestExecutions[script.id]
    }

    private var subtitleText: String {
        var components: [String] = []

        // Interpreter
        switch script.interpreter {
        case .automatic:
            components.append("auto")
        case .zsh:
            components.append("zsh")
        case .bash:
            components.append("bash")
        case .sh:
            components.append("sh")
        case .python3:
            components.append("python3")
        case .custom:
            components.append("custom")
        }

        // Enabled state
        if !script.isEnabled {
            components.append("Disabled")
        } else if script.schedule != .manual {
            components.append(script.schedule.displayTitle)
        }

        // Last execution status / duration
        if let latest = latestExecution, !isRunning {
            if let duration = latest.duration {
                if duration < 1.0 {
                    components.append(String(format: "%.1fs", duration))
                } else if duration < 60 {
                    components.append(String(format: "%.0fs", duration))
                } else {
                    let mins = Int(duration) / 60
                    let secs = Int(duration) % 60
                    components.append("\(mins)m \(secs)s")
                }
            }
        }

        return components.joined(separator: " • ")
    }

    var body: some View {
        HStack(spacing: 10) {
            StatusIndicatorView(status: executionStatus)

            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            // Run / Stop Action Button
            Button {
                if isRunning {
                    store.stopScript(script)
                } else {
                    store.runScript(script)
                }
            } label: {
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isRunning ? .orange : .primary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }
            .buttonStyle(.plain)
            .help(isRunning ? "Stop Script" : "Run Script")

            // Chevron to view details
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(isHovered ? 0.8 : 0.3))
                .frame(width: 12)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(script)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button {
                onSelect(script)
            } label: {
                Label("View Output & History…", systemImage: "terminal")
            }

            Divider()

            Button {
                store.runScript(script)
            } label: {
                Label("Run Now", systemImage: "play.fill")
            }
            .disabled(isRunning)

            Button {
                store.stopScript(script)
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!isRunning)

            Divider()

            Button {
                store.openInEditor(script)
            } label: {
                Label("Open in Default Editor", systemImage: "arrow.up.forward.app")
            }

            Button {
                store.revealInFinder(script)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Divider()

            Button {
                Task {
                    try? await store.toggleEnabled(for: script)
                }
            } label: {
                Label(script.isEnabled ? "Disable Schedule" : "Enable Schedule", systemImage: script.isEnabled ? "pause.circle" : "play.circle")
            }

            Divider()

            Button {
                onEdit(script)
            } label: {
                Label("Edit Script…", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete Script…", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete “\(script.name)”?",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await store.deleteScript(script)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This script will be removed from ZedFlow. The script file itself will remain on your disk.")
        }
    }
}
