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

    // Management & configuration commands
    case update
    case actionAdd
    case actionUpdate
    case actionRemove
    case actionReorder
}

public struct IPCRequest: Codable, Sendable {
    public var command: IPCCommand
    public var name: String?
    public var newName: String?
    public var action: String?
    public var newActionName: String?
    public var path: String?
    public var interpreter: String?
    public var customInterpreterPath: String?
    public var waitForCompletion: Bool?
    public var isEnabled: Bool?
    public var schedule: String?
    public var notifyOnSuccess: Bool?
    public var notifyOnFailure: Bool?
    public var actionIcon: String?
    public var actionArgs: [String]?
    public var targetIndex: Int?

    public init(
        command: IPCCommand,
        name: String? = nil,
        newName: String? = nil,
        action: String? = nil,
        newActionName: String? = nil,
        path: String? = nil,
        interpreter: String? = nil,
        customInterpreterPath: String? = nil,
        waitForCompletion: Bool? = nil,
        isEnabled: Bool? = nil,
        schedule: String? = nil,
        notifyOnSuccess: Bool? = nil,
        notifyOnFailure: Bool? = nil,
        actionIcon: String? = nil,
        actionArgs: [String]? = nil,
        targetIndex: Int? = nil
    ) {
        self.command = command
        self.name = name
        self.newName = newName
        self.action = action
        self.newActionName = newActionName
        self.path = path
        self.interpreter = interpreter
        self.customInterpreterPath = customInterpreterPath
        self.waitForCompletion = waitForCompletion
        self.isEnabled = isEnabled
        self.schedule = schedule
        self.notifyOnSuccess = notifyOnSuccess
        self.notifyOnFailure = notifyOnFailure
        self.actionIcon = actionIcon
        self.actionArgs = actionArgs
        self.targetIndex = targetIndex
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
    public var customInterpreterPath: String?
    public var schedule: String
    public var isEnabled: Bool
    public var notifyOnSuccess: Bool
    public var notifyOnFailure: Bool
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
        customInterpreterPath: String? = nil,
        schedule: String,
        isEnabled: Bool,
        notifyOnSuccess: Bool = false,
        notifyOnFailure: Bool = true,
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
        self.customInterpreterPath = customInterpreterPath
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.notifyOnSuccess = notifyOnSuccess
        self.notifyOnFailure = notifyOnFailure
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
