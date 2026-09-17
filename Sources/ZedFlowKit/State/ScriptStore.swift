import Foundation
import Observation
import AppKit

private final class LiveOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks: [LogChunk] = []
    private var stdout: String = ""
    private var stderr: String = ""
    private var hasPendingUpdates: Bool = false

    func append(stream: StreamType, text: String) {
        lock.lock()
        defer { lock.unlock() }
        let chunk = LogChunk(stream: stream, text: text)
        chunks.append(chunk)
        if stream == .stdout {
            stdout += text
        } else {
            stderr += text
        }
        hasPendingUpdates = true
    }

    func snapshot() -> (chunks: [LogChunk], stdout: String, stderr: String) {
        lock.lock()
        defer { lock.unlock() }
        return (chunks, stdout, stderr)
    }

    func drainPending() -> (chunks: [LogChunk], stdout: String, stderr: String)? {
        lock.lock()
        defer { lock.unlock() }
        guard hasPendingUpdates else { return nil }
        hasPendingUpdates = false
        return (chunks, stdout, stderr)
    }
}

@Observable
@MainActor
public final class ScriptStore {
    public private(set) var scripts: [Script] = []
    public private(set) var activeExecutions: [UUID: ScriptExecution] = [:]
    public private(set) var latestExecutions: [UUID: ScriptExecution] = [:]
    public private(set) var executionHistories: [UUID: [ScriptExecution]] = [:]
    public private(set) var isRunningScript: [UUID: Bool] = [:]
    public private(set) var isLoading: Bool = false
    public var errorMessage: String? = nil

    private var activeProcesses: [UUID: RunningProcess] = [:]
    public let storageService: StorageService
    public let processRunner: ProcessRunner
    public let scheduler: JobScheduler
    public let notificationService: NotificationService
    public let launchAtLoginService: LaunchAtLoginService

    @ObservationIgnored nonisolated(unsafe) private var wakeObserver: NSObjectProtocol?

    public var runningCount: Int {
        isRunningScript.values.filter { $0 }.count
    }

    public init(
        storageService: StorageService? = nil,
        processRunner: ProcessRunner = ProcessRunner(),
        scheduler: JobScheduler? = nil,
        notificationService: NotificationService = .shared,
        launchAtLoginService: LaunchAtLoginService = .shared
    ) {
        self.storageService = storageService ?? StorageService()
        self.processRunner = processRunner
        self.scheduler = scheduler ?? JobScheduler()
        self.notificationService = notificationService
        self.launchAtLoginService = launchAtLoginService

        // Configure scheduler hooks
        self.scheduler.onTrigger = { [weak self] script in
            self?.runScript(script)
        }
        self.scheduler.isRunningCheck = { [weak self] script in
            self?.isRunningScript[script.id] == true
        }

        // Handle macOS sleep/wake to recalculate schedules without backlog storms
        self.wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduler.handleSystemWake()
            }
        }
    }

    deinit {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Script Management

    public func loadScripts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            scripts = try await storageService.loadScripts()
            for script in scripts {
                if let latest = try? await storageService.loadExecutions(for: script.id).first {
                    latestExecutions[script.id] = latest
                }
            }
            scheduler.reconcile(scripts: scripts)
        } catch {
            errorMessage = "Failed to load scripts: \(error.localizedDescription)"
        }
    }

    public func addScript(_ script: Script) async throws {
        scripts.append(script)
        try await storageService.saveScripts(scripts)
        scheduler.reconcile(scripts: scripts)
    }

    public func updateScript(_ script: Script) async throws {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = script
            try await storageService.saveScripts(scripts)
            scheduler.reconcile(scripts: scripts)
        }
    }

    public func deleteScript(_ script: Script) async throws {
        stopScript(script)
        scripts.removeAll { $0.id == script.id }
        latestExecutions.removeValue(forKey: script.id)
        activeExecutions.removeValue(forKey: script.id)
        executionHistories.removeValue(forKey: script.id)
        isRunningScript.removeValue(forKey: script.id)
        scheduler.reconcile(scripts: scripts)
        try await storageService.saveScripts(scripts)
        try? await storageService.deleteHistory(for: script.id)
    }

    public func toggleEnabled(for script: Script) async throws {
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index].isEnabled.toggle()
            scripts[index].updatedAt = Date()
            try await storageService.saveScripts(scripts)
            scheduler.reconcile(scripts: scripts)
        }
    }

    // MARK: - History Management

    public func loadHistory(for script: Script) async -> [ScriptExecution] {
        let history = (try? await storageService.loadExecutions(for: script.id)) ?? []
        executionHistories[script.id] = history
        if let first = history.first, isRunningScript[script.id] != true {
            latestExecutions[script.id] = first
        }
        return history
    }

    public func clearHistory(for script: Script) async throws {
        try await storageService.deleteHistory(for: script.id)
        executionHistories[script.id] = []
        if isRunningScript[script.id] != true {
            latestExecutions.removeValue(forKey: script.id)
            activeExecutions.removeValue(forKey: script.id)
        }
    }

    // MARK: - Script Execution

    public func runScript(_ script: Script) {
        guard isRunningScript[script.id] != true else { return }

        isRunningScript[script.id] = true

        let buffer = LiveOutputBuffer()

        do {
            let (initialExecution, handle) = try processRunner.run(script: script) { stream, text in
                let streamType: StreamType = (stream == .stdout ? .stdout : .stderr)
                buffer.append(stream: streamType, text: text)
            }

            activeProcesses[script.id] = handle
            activeExecutions[script.id] = initialExecution

            // Periodic buffer flusher to keep UI fluid without main thread starvation
            let flushTask = Task.detached { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms interval (~20 fps)
                    if Task.isCancelled { break }
                    if let pending = buffer.drainPending() {
                        await MainActor.run { [weak self] in
                            guard let self = self, self.isRunningScript[script.id] == true else { return }
                            if var current = self.activeExecutions[script.id] {
                                current.stdout = pending.stdout
                                current.stderr = pending.stderr
                                current.outputChunks = pending.chunks
                                self.activeExecutions[script.id] = current
                            }
                        }
                    }
                }
            }

            Task.detached { [processRunner, storageService, notificationService] in
                // Wait for process to exit
                handle.process.waitUntilExit()

                flushTask.cancel()

                // Allow any final readability callbacks to be processed
                try? await Task.sleep(nanoseconds: 30_000_000)

                let finalSnapshot = buffer.snapshot()
                let finalExecution = processRunner.waitForCompletion(
                    handle: handle,
                    initialExecution: initialExecution,
                    accumulatedStdout: finalSnapshot.stdout,
                    accumulatedStderr: finalSnapshot.stderr,
                    outputChunks: finalSnapshot.chunks
                )

                try? await storageService.recordExecution(finalExecution)
                notificationService.sendNotificationIfNeeded(for: script, execution: finalExecution)

                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.activeProcesses.removeValue(forKey: script.id)
                    self.isRunningScript[script.id] = false
                    self.activeExecutions[script.id] = finalExecution
                    self.latestExecutions[script.id] = finalExecution

                    var history = self.executionHistories[script.id] ?? []
                    history.insert(finalExecution, at: 0)
                    if history.count > 50 {
                        history = Array(history.prefix(50))
                    }
                    self.executionHistories[script.id] = history
                }
            }
        } catch {
            isRunningScript[script.id] = false
            let failedExecution = ScriptExecution(
                scriptId: script.id,
                scriptName: script.name,
                status: .failed,
                endTime: Date(),
                duration: 0,
                exitCode: -1,
                stderr: error.localizedDescription,
                outputChunks: [LogChunk(stream: .stderr, text: error.localizedDescription)]
            )
            activeExecutions[script.id] = failedExecution
            latestExecutions[script.id] = failedExecution
            var history = executionHistories[script.id] ?? []
            history.insert(failedExecution, at: 0)
            executionHistories[script.id] = history

            notificationService.sendNotificationIfNeeded(for: script, execution: failedExecution)

            Task {
                try? await storageService.recordExecution(failedExecution)
            }
        }
    }

    public func stopScript(_ script: Script) {
        guard let handle = activeProcesses[script.id] else { return }
        handle.stop()
    }

    public func executionStatus(for script: Script) -> ExecutionStatus? {
        if isRunningScript[script.id] == true {
            return .running
        }
        return latestExecutions[script.id]?.status
    }

    // MARK: - Workspace Actions

    public func openInEditor(_ script: Script) {
        let url = URL(fileURLWithPath: script.scriptPath)
        NSWorkspace.shared.open(url)
    }

    public func revealInFinder(_ script: Script) {
        let url = URL(fileURLWithPath: script.scriptPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
