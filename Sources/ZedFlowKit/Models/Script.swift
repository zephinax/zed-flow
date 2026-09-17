import Foundation

public enum InterpreterType: String, Codable, CaseIterable, Sendable {
    case automatic = "Auto-detect"
    case zsh = "zsh (/bin/zsh)"
    case bash = "bash (/bin/bash)"
    case python3 = "python3"
    case sh = "sh (/bin/sh)"
    case custom = "Custom..."

    public var defaultBinaryPath: String? {
        switch self {
        case .automatic:
            return nil
        case .zsh:
            return "/bin/zsh"
        case .bash:
            return "/bin/bash"
        case .sh:
            return "/bin/sh"
        case .python3:
            return "/usr/bin/python3"
        case .custom:
            return nil
        }
    }
}

public struct Script: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var scriptPath: String
    public var interpreter: InterpreterType
    public var customInterpreterPath: String?
    public var schedule: ScheduleConfig
    public var isEnabled: Bool
    public var notifyOnSuccess: Bool
    public var notifyOnFailure: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        scriptPath: String,
        interpreter: InterpreterType = .automatic,
        customInterpreterPath: String? = nil,
        schedule: ScheduleConfig = .manual,
        isEnabled: Bool = true,
        notifyOnSuccess: Bool = false,
        notifyOnFailure: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.scriptPath = scriptPath
        self.interpreter = interpreter
        self.customInterpreterPath = customInterpreterPath
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.notifyOnSuccess = notifyOnSuccess
        self.notifyOnFailure = notifyOnFailure
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
