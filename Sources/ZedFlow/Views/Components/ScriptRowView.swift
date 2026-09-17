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

    private var activeActionName: String? {
        store.activeExecutions[script.id]?.actionName
    }

    private var executionStatus: ExecutionStatus? {
        store.executionStatus(for: script)
    }

    private var latestExecution: ScriptExecution? {
        store.latestExecutions[script.id]
    }

    private var subtitleText: String? {
        var components: [String] = []

        // Only show special schedule or disabled state
        if !script.isEnabled {
            components.append("Disabled")
        } else if script.schedule != .manual {
            components.append(script.schedule.displayTitle)
        }

        return components.isEmpty ? nil : components.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Main row header
            HStack(spacing: 10) {
                StatusIndicatorView(status: executionStatus)

                VStack(alignment: .leading, spacing: 2) {
                    Text(script.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let subtitle = subtitleText {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 8)

                if isRunning {
                    // Running state: Stop button
                    Button {
                        store.stopScript(script)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9, weight: .bold))
                            if let action = activeActionName {
                                Text(action)
                                    .font(.system(size: 10, weight: .medium))
                            }
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.15))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Stop Running Script")
                } else if script.actions.isEmpty {
                    // Standard single Run button when script has no actions
                    Button {
                        store.runScript(script)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Run Script")
                }

                // Chevron to view details
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(isHovered ? 0.8 : 0.3))
                    .frame(width: 12)
            }

            // Action Buttons Bar (when script defines actions)
            if !script.actions.isEmpty {
                HStack(spacing: 6) {
                    // Display up to 3 actions inline
                    ForEach(Array(script.actions.prefix(3))) { action in
                        let isThisActionRunning = isRunning && activeActionName == action.name
                        ScriptActionButton(
                            action: action,
                            isRunning: isRunning,
                            isCurrentActionRunning: isThisActionRunning,
                            size: .compact,
                            onExecute: {
                                store.runScript(script, action: action)
                            },
                            onStop: {
                                store.stopScript(script)
                            }
                        )
                    }

                    // Compact Overflow Menu if > 3 actions
                    if script.actions.count > 3 {
                        Menu {
                            ForEach(Array(script.actions.dropFirst(3))) { overflowAction in
                                Button {
                                    store.runScript(script, action: overflowAction)
                                } label: {
                                    Label(overflowAction.name, systemImage: overflowAction.systemImage)
                                }
                                .disabled(isRunning)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                )
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 20)
                        .help("More Actions")
                    }

                    Spacer()
                }
                .padding(.leading, 22) // align with text under indicator
            }
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

            if script.actions.isEmpty {
                Button {
                    store.runScript(script)
                } label: {
                    Label("Run Now", systemImage: "play.fill")
                }
                .disabled(isRunning)
            } else {
                Menu("Run Action") {
                    ForEach(script.actions) { action in
                        Button {
                            store.runScript(script, action: action)
                        } label: {
                            Label(action.name, systemImage: action.systemImage)
                        }
                    }
                }
                .disabled(isRunning)
            }

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
