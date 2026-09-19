import Foundation
@preconcurrency import UserNotifications

public final class NotificationService: Sendable {
    public static let shared = NotificationService()

    public init() {}

    /// Requests user authorization for notifications if not yet determined.
    public func requestAuthorizationIfNeeded() async -> Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                return true
            case .notDetermined:
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            case .denied:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Evaluates whether a notification is warranted based on script configuration and status.
    public func shouldNotify(for script: Script, status: ExecutionStatus) -> Bool {
        switch status {
        case .success:
            return script.notifyOnSuccess
        case .failed:
            return script.notifyOnFailure
        case .stopped, .running, .clear:
            return false
        }
    }

    /// Dispatches a notification if the script is configured for this execution outcome.
    public func sendNotificationIfNeeded(for script: Script, execution: ScriptExecution) {
        guard shouldNotify(for: script, status: execution.status) else { return }
        guard Bundle.main.bundleIdentifier != nil else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = script.name

        let durationText: String
        if let d = execution.duration {
            if d < 1.0 {
                durationText = String(format: " (%.2fs)", d)
            } else {
                durationText = String(format: " (%.1fs)", d)
            }
        } else {
            durationText = ""
        }

        switch execution.status {
        case .success:
            content.subtitle = "Script Succeeded\(durationText)"
            content.sound = .default
        case .failed:
            let codeText = execution.exitCode.map { " (exit \($0))" } ?? ""
            content.subtitle = "Script Failed\(codeText)\(durationText)"
            if !execution.stderr.isEmpty {
                let trimmed = execution.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                content.body = String(trimmed.prefix(200))
            }
            content.sound = .default
        default:
            return
        }

        let identifier = "zedflow.run.\(script.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        center.add(request)
    }
}
