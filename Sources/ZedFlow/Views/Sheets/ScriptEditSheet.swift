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
        .frame(width: 440, height: 460)
        .onAppear {
            populateFields()
        }
    }

    private func populateFields() {
        guard let script = existingScript else { return }
        name = script.name
        scriptPath = script.scriptPath
        interpreter = script.interpreter
        customInterpreterPath = script.customInterpreterPath ?? ""
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
