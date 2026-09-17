import Foundation

public struct IPCProtocol {
    public static var defaultSocketPath: String {
        return "/tmp/zedflow-\(getuid()).sock"
    }
}

public enum IPCCommand: String, Codable, Sendable {
    case list
    case add
    case remove
    case run
    case stop
    case status
    case history
    case ping
}

public struct IPCRequest: Codable, Sendable {
    public var command: IPCCommand
    public var name: String?
    public var action: String?
    public var path: String?
    public var interpreter: String?
    public var waitForCompletion: Bool?

    public init(
        command: IPCCommand,
        name: String? = nil,
        action: String? = nil,
        path: String? = nil,
        interpreter: String? = nil,
        waitForCompletion: Bool? = nil
    ) {
        self.command = command
        self.name = name
        self.action = action
        self.path = path
        self.interpreter = interpreter
        self.waitForCompletion = waitForCompletion
    }
}

public struct ScriptActionDTO: Codable, Sendable {
    public var id: UUID
    public var name: String
    public var arguments: [String]
    public var systemImage: String

    public init(
        id: UUID = UUID(),
        name: String,
        arguments: [String] = [],
        systemImage: String = "bolt"
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.systemImage = systemImage
    }

    public init(from action: ScriptAction) {
        self.id = action.id
        self.name = action.name
        self.arguments = action.arguments
        self.systemImage = action.systemImage
    }
}

public struct ScriptDTO: Codable, Sendable {
    public var id: UUID
    public var name: String
    public var path: String
    public var interpreter: String
    public var schedule: String
    public var isEnabled: Bool
    public var isRunning: Bool
    public var actions: [ScriptActionDTO]
    public var lastStatus: ExecutionStatus?
    public var lastExitCode: Int32?
    public var lastDuration: TimeInterval?

    public init(
        id: UUID,
        name: String,
        path: String,
        interpreter: String,
        schedule: String,
        isEnabled: Bool,
        isRunning: Bool,
        actions: [ScriptActionDTO] = [],
        lastStatus: ExecutionStatus? = nil,
        lastExitCode: Int32? = nil,
        lastDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.interpreter = interpreter
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.isRunning = isRunning
        self.actions = actions
        self.lastStatus = lastStatus
        self.lastExitCode = lastExitCode
        self.lastDuration = lastDuration
    }
}

public struct IPCResponse: Codable, Sendable {
    public var success: Bool
    public var message: String?
    public var scripts: [ScriptDTO]?
    public var script: ScriptDTO?
    public var execution: ScriptExecution?
    public var history: [ScriptExecution]?
    public var exitCode: Int32?

    public init(
        success: Bool,
        message: String? = nil,
        scripts: [ScriptDTO]? = nil,
        script: ScriptDTO? = nil,
        execution: ScriptExecution? = nil,
        history: [ScriptExecution]? = nil,
        exitCode: Int32? = nil
    ) {
        self.success = success
        self.message = message
        self.scripts = scripts
        self.script = script
        self.execution = execution
        self.history = history
        self.exitCode = exitCode
    }
}
