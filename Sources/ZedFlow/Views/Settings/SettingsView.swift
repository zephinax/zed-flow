import SwiftUI
import AppKit
@preconcurrency import UserNotifications
import ZedFlowKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let store: ScriptStore

    @State private var launchAtLogin: Bool = false
    @State private var notificationStatus: String = "Checking…"
    @State private var launchAtLoginError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)

                Text("Settings")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            Form {
                // System Integration Section
                Section {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            do {
                                try store.launchAtLoginService.setEnabled(newValue)
                                launchAtLoginError = nil
                            } catch {
                                launchAtLoginError = error.localizedDescription
                                // Revert to actual state
                                launchAtLogin = store.launchAtLoginService.isEnabled
                            }
                        }

                    if let error = launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Status: \(store.launchAtLoginService.statusDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Startup")
                }

                // Notifications Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(.body)
                            Text(notificationStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Request Permission") {
                            Task {
                                let granted = await store.notificationService.requestAuthorizationIfNeeded()
                                notificationStatus = granted ? "Authorized" : "Denied in System Settings"
                            }
                        }
                        .controlSize(.small)
                    }

                    Text("Per-script notification alerts (on success or failure) can be enabled when adding or editing each script.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                } header: {
                    Text("Notifications")
                }

                // About Section
                Section {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Platform", value: "Native macOS (Local-only)")
                } header: {
                    Text("About ZedFlow")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 420, height: 380)
        .onAppear {
            launchAtLogin = store.launchAtLoginService.isEnabled
            Task {
                let center = UNUserNotificationCenter.current()
                let settings = await center.notificationSettings()
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    notificationStatus = "Authorized"
                case .denied:
                    notificationStatus = "Denied in System Settings"
                case .notDetermined:
                    notificationStatus = "Not yet requested"
                @unknown default:
                    notificationStatus = "Unknown"
                }
            }
        }
    }
}
