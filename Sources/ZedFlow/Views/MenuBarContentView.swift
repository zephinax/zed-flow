import SwiftUI
import AppKit
import ZedFlowKit

struct MenuBarContentView: View {
    @Bindable var store: ScriptStore

    @State private var showingAddSheet: Bool = false
    @State private var showingSettings: Bool = false
    @State private var scriptToEdit: Script? = nil
    @State private var selectedScriptForDetail: Script? = nil

    var body: some View {
        Group {
            if let selectedScript = selectedScriptForDetail,
               let currentScript = store.scripts.first(where: { $0.id == selectedScript.id }) {
                ScriptDetailView(script: currentScript, store: store) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedScriptForDetail = nil
                    }
                }
                .frame(width: 480, height: 420)
            } else {
                mainListView
                    .frame(width: 320)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ScriptEditSheet { newScript in
                Task {
                    try? await store.addScript(newScript)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(store: store)
        }
        .sheet(item: $scriptToEdit) { script in
            ScriptEditSheet(script: script) { updatedScript in
                Task {
                    try? await store.updateScript(updatedScript)
                }
            }
        }
    }

    // MARK: - Main List View

    private var mainListView: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar

            Divider()

            // Main Content Area
            if store.scripts.isEmpty {
                emptyStateView
            } else {
                scriptsListView
            }

            Divider()

            // Footer Bar
            footerBar
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)

            Text("ZedFlow")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)

            if store.runningCount > 0 {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(store.runningCount) running")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            Spacer()

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Add Script…")

            Menu {
                Button("Add Script…") {
                    showingAddSheet = true
                }

                Divider()

                Button("Settings…") {
                    showingSettings = true
                }
                .keyboardShortcut(",")

                Divider()

                Button("Quit ZedFlow") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20, height: 20)
            .help("More Options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.7))

            VStack(spacing: 4) {
                Text("No Scripts")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text("Add shell or Python scripts to run and manage them from your menu bar.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Script…", systemImage: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scripts List View

    private var scriptsListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.scripts) { script in
                    ScriptRowView(
                        script: script,
                        store: store,
                        onSelect: { selected in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedScriptForDetail = selected
                            }
                        },
                        onEdit: { scriptToModify in
                            scriptToEdit = scriptToModify
                        }
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 360)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Text(store.scripts.count == 1 ? "1 script" : "\(store.scripts.count) scripts")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
