import SwiftUI
import AppKit
import ZedFlowKit

struct ScriptEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingScript: Script?
    let onSave: (Script) -> Void

    @State private var name: String = ""
    @State private var scriptPath: String = ""
    @State private var interpreter: InterpreterType = .automatic
    @State private var customInterpreterPath: String = ""

    // Actions state
    @State private var actions: [ScriptAction] = []
    @State private var showingActionSheet: Bool = false
    @State private var editingActionIndex: Int? = nil
    @State private var editingAction: ScriptAction? = nil

    // Schedule state
    enum ScheduleType: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case interval = "Every X Minutes"
        case daily = "Daily at Time"
        var id: String { rawValue }
    }
    @State private var scheduleType: ScheduleType = .manual
    @State private var intervalMinutes: Int = 30
    @State private var dailyTime: Date = {
        var comp = DateComponents()
        comp.hour = 9
        comp.minute = 0
        return Calendar.current.date(from: comp) ?? Date()
    }()

    // Notifications
    @State private var notifyOnSuccess: Bool = false
    @State private var notifyOnFailure: Bool = true

    init(script: Script? = nil, onSave: @escaping (Script) -> Void) {
        self.existingScript = script
        self.onSave = onSave
    }

    private var isFormValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = scriptPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPath.isEmpty else { return false }

        if interpreter == .custom {
            return !customInterpreterPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                Text(existingScript == nil ? "New Script" : "Edit Script")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            // Form Content
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Daily Cleanup"))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Script Path", text: $scriptPath, prompt: Text("~/scripts/cleanup.sh"))
                            Button("Choose…") {
                                chooseScriptFile()
                            }
                            .controlSize(.small)
                        }
                    }

                    Picker("Interpreter", selection: $interpreter) {
                        ForEach(InterpreterType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    if interpreter == .custom {
                        HStack {
                            TextField("Interpreter Path", text: $customInterpreterPath, prompt: Text("/usr/local/bin/my-runner"))
                            Button("Choose…") {
                                chooseCustomInterpreter()
                            }
                            .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Script Details")
                }

                // Actions Section
                Section {
                    if actions.isEmpty {
                        HStack {
                            Text("No actions configured. The script will execute without extra flags.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                editingAction = nil
                                editingActionIndex = nil
                                showingActionSheet = true
                            } label: {
                                Label("Add Action", systemImage: "plus")
                            }
                            .controlSize(.small)
                        }
                    } else {
                        ForEach(actions.indices, id: \.self) { index in
                            let action = actions[index]
                            HStack(spacing: 8) {
                                Image(systemName: action.systemImage)
                                    .font(.system(size: 13))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 18)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(action.name)
                                        .font(.system(size: 12, weight: .medium))
                                    if !action.arguments.isEmpty {
                                        Text(action.arguments.joined(separator: " "))
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                // Move up
                                Button {
                                    if index > 0 {
                                        actions.swapAt(index, index - 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .disabled(index == 0)
                                .help("Move Up")

                                // Move down
                                Button {
                                    if index < actions.count - 1 {
                                        actions.swapAt(index, index + 1)
                                    }
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .disabled(index == actions.count - 1)
                                .help("Move Down")

                                // Edit
                                Button {
                                    editingActionIndex = index
                                    editingAction = action
                                    showingActionSheet = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                                .help("Edit Action")

                                // Delete
                                Button {
                                    actions.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Delete Action")
                            }
                            .padding(.vertical, 2)
                        }

                        Button {
                            editingAction = nil
                            editingActionIndex = nil
                            showingActionSheet = true
                        } label: {
                            Label("Add Action…", systemImage: "plus")
                        }
                        .controlSize(.small)
                    }
                } header: {
                    Text("Actions / Flags")
                }

                Section {
                    Picker("Run Mode", selection: $scheduleType) {
                        ForEach(ScheduleType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    if scheduleType == .interval {
                        Stepper("Every \(intervalMinutes) minute\(intervalMinutes == 1 ? "" : "s")", value: $intervalMinutes, in: 1...1440, step: 5)
                    } else if scheduleType == .daily {
                        DatePicker("Time", selection: $dailyTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Schedule")
                }

                Section {
                    Toggle("Notify on success", isOn: $notifyOnSuccess)
                    Toggle("Notify on failure", isOn: $notifyOnFailure)
                } header: {
                    Text("Notifications")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            // Action Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(existingScript == nil ? "Add Script" : "Save") {
                    saveScript()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isFormValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 540)
        .onAppear {
            populateFields()
        }
        .sheet(isPresented: $showingActionSheet) {
            ActionEditSheet(action: editingAction) { savedAction in
                if let idx = editingActionIndex, idx < actions.count {
                    actions[idx] = savedAction
                } else {
                    actions.append(savedAction)
                }
            }
        }
    }

    private func populateFields() {
        guard let script = existingScript else { return }
        name = script.name
        scriptPath = script.scriptPath
        interpreter = script.interpreter
        customInterpreterPath = script.customInterpreterPath ?? ""
        actions = script.actions
        notifyOnSuccess = script.notifyOnSuccess
        notifyOnFailure = script.notifyOnFailure

        switch script.schedule {
        case .manual:
            scheduleType = .manual
        case .interval(let minutes):
            scheduleType = .interval
            intervalMinutes = minutes
        case .daily(let hour, let minute):
            scheduleType = .daily
            var comp = DateComponents()
            comp.hour = hour
            comp.minute = minute
            if let date = Calendar.current.date(from: comp) {
                dailyTime = date
            }
        }
    }

    private func saveScript() {
        let schedule: ScheduleConfig
        switch scheduleType {
        case .manual:
            schedule = .manual
        case .interval:
            schedule = .interval(minutes: max(1, intervalMinutes))
        case .daily:
            let comp = Calendar.current.dateComponents([.hour, .minute], from: dailyTime)
            schedule = .daily(hour: comp.hour ?? 9, minute: comp.minute ?? 0)
        }

        let script = Script(
            id: existingScript?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            scriptPath: scriptPath.trimmingCharacters(in: .whitespacesAndNewlines),
            interpreter: interpreter,
            customInterpreterPath: interpreter == .custom ? customInterpreterPath.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            schedule: schedule,
            isEnabled: existingScript?.isEnabled ?? true,
            notifyOnSuccess: notifyOnSuccess,
            notifyOnFailure: notifyOnFailure,
            actions: actions,
            createdAt: existingScript?.createdAt ?? Date(),
            updatedAt: Date()
        )

        onSave(script)
        dismiss()
    }

    private func chooseScriptFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            scriptPath = url.path
            if name.isEmpty {
                name = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func chooseCustomInterpreter() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            customInterpreterPath = url.path
        }
    }
}

// MARK: - Action Edit Sheet

struct ActionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let initialAction: ScriptAction?
    let onSave: (ScriptAction) -> Void

    @State private var name: String = ""
    @State private var icon: String = "bolt"
    @State private var arguments: [String] = []
    @State private var newArgText: String = ""

    init(action: ScriptAction? = nil, onSave: @escaping (ScriptAction) -> Void) {
        self.initialAction = action
        self.onSave = onSave
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(initialAction == nil ? "New Action" : "Edit Action")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Form {
                Section("Action Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. On, Off, Status"))

                    HStack {
                        Text("Icon")
                        Spacer()
                        ActionIconPicker(selectedIcon: $icon)
                    }
                }

                Section {
                    if arguments.isEmpty {
                        Text("No arguments specified. The script will be invoked with no additional arguments.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(arguments.indices, id: \.self) { idx in
                            HStack(spacing: 8) {
                                Text("\(idx + 1).")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .trailing)

                                TextField("Argument", text: $arguments[idx])
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    arguments.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove argument")
                            }
                        }
                    }

                    HStack {
                        TextField("New argument (supports spaces)", text: $newArgText, prompt: Text("e.g. --verbose or status"))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addArgument()
                            }

                        Button("Add") {
                            addArgument()
                        }
                        .controlSize(.small)
                        .disabled(newArgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Arguments / Flags")
                } footer: {
                    Text("Each argument is passed as an isolated parameter without shell string escaping.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(initialAction == nil ? "Add Action" : "Save Action") {
                    let finalAction = ScriptAction(
                        id: initialAction?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        arguments: arguments.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                        systemImage: icon.isEmpty ? "bolt" : icon
                    )
                    onSave(finalAction)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 420)
        .onAppear {
            if let action = initialAction {
                name = action.name
                icon = action.systemImage
                arguments = action.arguments
            }
        }
    }

    private func addArgument() {
        let trimmed = newArgText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        arguments.append(trimmed)
        newArgText = ""
    }
}
