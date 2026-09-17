import Foundation

public actor StorageService {
    public let baseDirectory: URL
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private var scriptsFileURL: URL {
        baseDirectory.appendingPathComponent("scripts.json")
    }

    private var historyDirectoryURL: URL {
        baseDirectory.appendingPathComponent("history", isDirectory: true)
    }

    public init(baseDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let baseDirectory = baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.baseDirectory = appSupport.appendingPathComponent("ZedFlow", isDirectory: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
    }

    // MARK: - Directory Management

    public func ensureDirectoriesExist() throws {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: historyDirectoryURL.path) {
            try fileManager.createDirectory(at: historyDirectoryURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Scripts Persistence

    public func loadScripts() throws -> [Script] {
        guard fileManager.fileExists(atPath: scriptsFileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: scriptsFileURL)
        return try jsonDecoder.decode([Script].self, from: data)
    }

    public func saveScripts(_ scripts: [Script]) throws {
        try ensureDirectoriesExist()
        let data = try jsonEncoder.encode(scripts)
        try data.write(to: scriptsFileURL, options: .atomic)
    }

    // MARK: - Execution History Persistence

    private func historyFileURL(for scriptId: UUID) -> URL {
        historyDirectoryURL.appendingPathComponent("\(scriptId.uuidString).json")
    }

    public func loadExecutions(for scriptId: UUID) throws -> [ScriptExecution] {
        let fileURL = historyFileURL(for: scriptId)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try jsonDecoder.decode([ScriptExecution].self, from: data)
    }

    public func saveExecutions(_ executions: [ScriptExecution], for scriptId: UUID) throws {
        try ensureDirectoriesExist()
        let fileURL = historyFileURL(for: scriptId)
        let data = try jsonEncoder.encode(executions)
        try data.write(to: fileURL, options: .atomic)
    }

    public func recordExecution(_ execution: ScriptExecution, maxHistoryCount: Int = 50) throws {
        try ensureDirectoriesExist()
        var current = (try? loadExecutions(for: execution.scriptId)) ?? []
        current.insert(execution, at: 0)
        if current.count > maxHistoryCount {
            current = Array(current.prefix(maxHistoryCount))
        }
        try saveExecutions(current, for: execution.scriptId)
    }

    public func deleteHistory(for scriptId: UUID) throws {
        let fileURL = historyFileURL(for: scriptId)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
}
