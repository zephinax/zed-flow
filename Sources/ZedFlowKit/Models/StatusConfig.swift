import Foundation

public enum StatusSourceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case lastExecution = "lastExecution"
    case heartbeat = "heartbeat"
    case runOnly = "runOnly"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .lastExecution:
            return "Last Execution"
        case .heartbeat:
            return "Periodic Heartbeat"
        case .runOnly:
            return "Active While Running Only"
        }
    }

    public var description: String {
        switch self {
        case .lastExecution:
            return "Status reflects the exit code and directives of the last manual or scheduled execution."
        case .heartbeat:
            return "Runs a background probe periodically to monitor if the service or process is alive."
        case .runOnly:
            return "Active while the process is executing; clears back to idle once completed."
        }
    }
}

public struct HeartbeatConfig: Codable, Hashable, Sendable {
    public var intervalSeconds: Int
    public var actionName: String?
    public var arguments: [String]

    public init(
        intervalSeconds: Int = 30,
        actionName: String? = nil,
        arguments: [String] = []
    ) {
        self.intervalSeconds = max(5, intervalSeconds)
        self.actionName = actionName
        self.arguments = arguments
    }
}

public struct StatusConfig: Codable, Hashable, Sendable {
    public var mode: StatusSourceMode
    public var heartbeat: HeartbeatConfig

    public init(
        mode: StatusSourceMode = .lastExecution,
        heartbeat: HeartbeatConfig = HeartbeatConfig()
    ) {
        self.mode = mode
        self.heartbeat = heartbeat
    }

    public static let `default` = StatusConfig(mode: .lastExecution)
}
