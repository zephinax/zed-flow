import Foundation
import ServiceManagement

public final class LaunchAtLoginService: Sendable {
    public static let shared = LaunchAtLoginService()

    public init() {}

    /// Returns whether the main application is registered to launch at login.
    public var isEnabled: Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// User-facing description of the registration status.
    public var statusDescription: String {
        guard Bundle.main.bundleIdentifier != nil else { return "Disabled" }
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Disabled"
        case .requiresApproval:
            return "Requires System Approval"
        case .notFound:
            return "App Not Found"
        @unknown default:
            return "Unknown"
        }
    }

    /// Registers or unregisters the app with the system login service.
    public func setEnabled(_ enabled: Bool) throws {
        guard Bundle.main.bundleIdentifier != nil else { return }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
