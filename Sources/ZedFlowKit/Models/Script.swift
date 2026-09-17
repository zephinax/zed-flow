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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let exact = InterpreterType(rawValue: raw) {
            self = exact
            return
        }
        switch raw.lowercased() {
        case "automatic", "auto", "auto-detect": self = .automatic
        case "zsh", "zsh (/bin/zsh)": self = .zsh
        case "bash", "bash (/bin/bash)": self = .bash
        case "sh", "sh (/bin/sh)": self = .sh
        case "python", "python3": self = .python3
        case "custom", "custom...": self = .custom
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown interpreter type: \(raw)")
            )
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
    public var actions: [ScriptAction]
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
        actions: [ScriptAction] = [],
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
        self.actions = actions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, scriptPath, interpreter, customInterpreterPath, schedule, isEnabled, notifyOnSuccess, notifyOnFailure, actions, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        scriptPath = try container.decode(String.self, forKey: .scriptPath)
        interpreter = try container.decode(InterpreterType.self, forKey: .interpreter)
        customInterpreterPath = try container.decodeIfPresent(String.self, forKey: .customInterpreterPath)
        schedule = try container.decode(ScheduleConfig.self, forKey: .schedule)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        notifyOnSuccess = try container.decode(Bool.self, forKey: .notifyOnSuccess)
        notifyOnFailure = try container.decode(Bool.self, forKey: .notifyOnFailure)
        actions = try container.decodeIfPresent([ScriptAction].self, forKey: .actions) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
