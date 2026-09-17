import Foundation

public enum ExecutionStatus: String, Codable, Sendable {
    case running
    case success
    case failed
    case stopped
    case clear
}

public enum StreamType: String, Codable, Sendable {
    case stdout
    case stderr
}

public struct LogChunk: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var stream: StreamType
    public var text: String
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        stream: StreamType,
        text: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.stream = stream
        self.text = text
        self.timestamp = timestamp
    }
}

public struct ScriptExecution: Identifiable, Codable, Sendable {
    public var id: UUID
    public var scriptId: UUID
    public var scriptName: String
    public var actionName: String?
    public var status: ExecutionStatus
    public var startTime: Date
    public var endTime: Date?
    public var duration: TimeInterval?
    public var exitCode: Int32?
    public var stdout: String
    public var stderr: String
    public var outputChunks: [LogChunk]

    public var displayName: String {
        if let action = actionName, !action.isEmpty {
            return "\(scriptName) → \(action)"
        }
        return scriptName
    }

    public init(
        id: UUID = UUID(),
        scriptId: UUID,
        scriptName: String,
        actionName: String? = nil,
        status: ExecutionStatus,
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        exitCode: Int32? = nil,
        stdout: String = "",
        stderr: String = "",
        outputChunks: [LogChunk] = []
    ) {
        self.id = id
        self.scriptId = scriptId
        self.scriptName = scriptName
        self.actionName = actionName
        self.status = status
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.outputChunks = outputChunks
    }

    enum CodingKeys: String, CodingKey {
        case id, scriptId, scriptName, actionName, status, startTime, endTime, duration, exitCode, stdout, stderr, outputChunks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scriptId = try container.decode(UUID.self, forKey: .scriptId)
        scriptName = try container.decode(String.self, forKey: .scriptName)
        actionName = try container.decodeIfPresent(String.self, forKey: .actionName)
        status = try container.decode(ExecutionStatus.self, forKey: .status)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        exitCode = try container.decodeIfPresent(Int32.self, forKey: .exitCode)
        stdout = try container.decode(String.self, forKey: .stdout)
        stderr = try container.decode(String.self, forKey: .stderr)
        outputChunks = try container.decodeIfPresent([LogChunk].self, forKey: .outputChunks) ?? []
    }
}
