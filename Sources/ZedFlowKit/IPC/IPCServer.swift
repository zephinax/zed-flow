import Foundation
import Darwin

public final class IPCServer: @unchecked Sendable {
    public let socketPath: String
    public let store: ScriptStore

    private var serverFd: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.zephinax.zedflow.ipc", qos: .userInitiated)
    private let lock = NSLock()
    private var _isRunning: Bool = false

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isRunning
    }

    public init(
        socketPath: String = IPCProtocol.defaultSocketPath,
        store: ScriptStore
    ) {
        self.socketPath = socketPath
        self.store = store
    }

    deinit {
        stop()
    }

    // MARK: - Server Lifecycle

    public func start() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !_isRunning else { return }

        // Ensure parent directory exists
        let parentDir = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Remove any stale socket file
        Darwin.unlink(socketPath)

        // Create domain socket
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw IPCError.bindFailed(errno: errno)
        }

        // Prepare sockaddr_un
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            Darwin.close(fd)
            throw IPCError.socketPathTooLong
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            pathBytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: buf.count)
            }
        }

        // Bind socket
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                Darwin.bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            let err = errno
            Darwin.close(fd)
            throw IPCError.bindFailed(errno: err)
        }

        // Restrict socket access to current user only (0600)
        Darwin.chmod(socketPath, 0o600)

        // Listen
        guard Darwin.listen(fd, 16) == 0 else {
            let err = errno
            Darwin.close(fd)
            Darwin.unlink(socketPath)
            throw IPCError.bindFailed(errno: err)
        }

        serverFd = fd
        _isRunning = true

        // Create dispatch read source to accept incoming connections asynchronously
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.acceptIncomingConnections()
        }
        source.setCancelHandler { [fd, socketPath] in
            Darwin.close(fd)
            Darwin.unlink(socketPath)
        }
        source.resume()
        readSource = source
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard _isRunning else { return }
        _isRunning = false

        if let source = readSource {
            source.cancel()
            readSource = nil
        } else if serverFd >= 0 {
            Darwin.close(serverFd)
        }
        Darwin.unlink(socketPath)
        serverFd = -1
    }

    // MARK: - Connection Handling

    private func acceptIncomingConnections() {
        guard serverFd >= 0 else { return }
        let clientFd = Darwin.accept(serverFd, nil, nil)
        guard clientFd >= 0 else { return }

        Task { [weak self] in
            guard let self = self else {
                Darwin.close(clientFd)
                return
            }
            await self.handleClientConnection(clientFd)
        }
    }

    private func handleClientConnection(_ clientFd: Int32) async {
        defer { Darwin.close(clientFd) }

        // Read request from client
        var buffer = [UInt8](repeating: 0, count: 8192)
        var accumulatedData = Data()

        while true {
            let bytesRead = Darwin.read(clientFd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            accumulatedData.append(buffer, count: bytesRead)
            if accumulatedData.contains(UInt8(ascii: "\n")) { break }
        }

        guard !accumulatedData.isEmpty else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let response: IPCResponse
        do {
            let request = try decoder.decode(IPCRequest.self, from: accumulatedData)
            response = await handleRequest(request)
        } catch {
            response = IPCResponse(success: false, message: "Invalid request: \(error.localizedDescription)")
        }

        // Send response back
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let responseData = try? encoder.encode(response) {
            var fullData = responseData
            fullData.append(UInt8(ascii: "\n"))
            _ = fullData.withUnsafeBytes { rawBuffer in
                Darwin.write(clientFd, rawBuffer.baseAddress, rawBuffer.count)
            }
        }
    }

    // MARK: - Command Routing

    @MainActor
    private func handleRequest(_ request: IPCRequest) async -> IPCResponse {
        switch request.command {
        case .ping:
            return IPCResponse(success: true, message: "pong")

        case .list:
            let dtos = store.scripts.map { script in
                makeDTO(script: script)
            }
            return IPCResponse(success: true, scripts: dtos)

        case .add:
            guard let path = request.path, !path.trimmingCharacters(in: .whitespaces).isEmpty else {
                return IPCResponse(success: false, message: "Path is required to add a script.")
            }

            let expandedPath = NSString(string: path).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                return IPCResponse(success: false, message: "Script file not found at path: \(path)")
            }

            let name: String
            if let customName = request.name, !customName.trimmingCharacters(in: .whitespaces).isEmpty {
                name = customName.trimmingCharacters(in: .whitespaces)
            } else {
                name = URL(fileURLWithPath: expandedPath).deletingPathExtension().lastPathComponent
            }

            let interpreter: InterpreterType
            if let interpStr = request.interpreter?.lowercased() {
                switch interpStr {
                case "zsh": interpreter = .zsh
                case "bash": interpreter = .bash
                case "sh": interpreter = .sh
                case "python", "python3": interpreter = .python3
                default: interpreter = .automatic
                }
            } else {
                interpreter = .automatic
            }

            let script = Script(
                name: name,
                scriptPath: expandedPath,
                interpreter: interpreter
            )

            do {
                try await store.addScript(script)
                return IPCResponse(
                    success: true,
                    message: "Successfully added script '\(name)'",
                    script: makeDTO(script: script)
                )
            } catch {
                return IPCResponse(success: false, message: "Failed to save script: \(error.localizedDescription)")
            }

        case .remove:
            guard let name = request.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return IPCResponse(success: false, message: "Script name is required.")
            }

            guard let script = findScript(named: name) else {
                return IPCResponse(success: false, message: "Script '\(name)' not found.")
            }

            do {
                try await store.deleteScript(script)
                return IPCResponse(success: true, message: "Successfully removed script '\(script.name)'.")
            } catch {
                return IPCResponse(success: false, message: "Failed to remove script: \(error.localizedDescription)")
            }

        case .run:
            guard let name = request.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return IPCResponse(success: false, message: "Script name is required.")
            }

            guard let script = findScript(named: name) else {
                return IPCResponse(success: false, message: "Script '\(name)' not found.")
            }

            var resolvedAction: ScriptAction? = nil
            if let actionName = request.action, !actionName.trimmingCharacters(in: .whitespaces).isEmpty {
                let trimmedAction = actionName.trimmingCharacters(in: .whitespaces)
                guard let matchedAction = script.actions.first(where: {
                    $0.name.localizedCaseInsensitiveCompare(trimmedAction) == .orderedSame
                }) ?? script.actions.first(where: {
                    $0.name.localizedStandardContains(trimmedAction)
                }) else {
                    return IPCResponse(
                        success: false,
                        message: "Action '\(actionName)' not found on script '\(script.name)'."
                    )
                }
                resolvedAction = matchedAction
            }

            if store.isRunningScript[script.id] == true {
                return IPCResponse(success: false, message: "Script '\(script.name)' is already running.")
            }

            store.runScript(script, action: resolvedAction)

            // If async run requested:
            if request.waitForCompletion == false {
                return IPCResponse(
                    success: true,
                    message: "Started script '\(script.name)'.",
                    script: makeDTO(script: script)
                )
            }

            // Wait for completion (default for CLI)
            var attempts = 0
            while store.isRunningScript[script.id] == true && attempts < 6000 { // up to 5 minutes
                try? await Task.sleep(nanoseconds: 50_000_000)
                attempts += 1
            }

            let execution = store.latestExecutions[script.id]
            let success = execution?.status == .success
            let exitCode = execution?.exitCode ?? (success ? 0 : 1)

            return IPCResponse(
                success: success,
                message: execution?.status.rawValue.capitalized ?? "Completed",
                script: makeDTO(script: script),
                execution: execution,
                exitCode: exitCode
            )

        case .stop:
            guard let name = request.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return IPCResponse(success: false, message: "Script name is required.")
            }

            guard let script = findScript(named: name) else {
                return IPCResponse(success: false, message: "Script '\(name)' not found.")
            }

            guard store.isRunningScript[script.id] == true else {
                return IPCResponse(success: true, message: "Script '\(script.name)' is not currently running.")
            }

            store.stopScript(script)

            // Give process a moment to terminate
            try? await Task.sleep(nanoseconds: 100_000_000)

            return IPCResponse(success: true, message: "Stopped script '\(script.name)'.")

        case .status:
            guard let name = request.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return IPCResponse(success: false, message: "Script name is required.")
            }

            guard let script = findScript(named: name) else {
                return IPCResponse(success: false, message: "Script '\(name)' not found.")
            }

            let latest = store.latestExecutions[script.id]
            return IPCResponse(
                success: true,
                script: makeDTO(script: script),
                execution: latest,
                exitCode: latest?.exitCode
            )

        case .history:
            guard let name = request.name, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                return IPCResponse(success: false, message: "Script name is required.")
            }

            guard let script = findScript(named: name) else {
                return IPCResponse(success: false, message: "Script '\(name)' not found.")
            }

            let history = await store.loadHistory(for: script)
            return IPCResponse(
                success: true,
                script: makeDTO(script: script),
                history: history
            )
        }
    }

    @MainActor
    private func findScript(named target: String) -> Script? {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        return store.scripts.first { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
            ?? store.scripts.first { $0.name.localizedStandardContains(trimmed) }
    }

    @MainActor
    private func makeDTO(script: Script) -> ScriptDTO {
        let isRunning = store.isRunningScript[script.id] == true
        let latest = store.latestExecutions[script.id]
        return ScriptDTO(
            id: script.id,
            name: script.name,
            path: script.scriptPath,
            interpreter: script.interpreter.rawValue,
            schedule: script.schedule.displayTitle,
            isEnabled: script.isEnabled,
            isRunning: isRunning,
            actions: script.actions.map { ScriptActionDTO(from: $0) },
            lastStatus: isRunning ? .running : latest?.status,
            lastExitCode: latest?.exitCode,
            lastDuration: latest?.duration
        )
    }
}
