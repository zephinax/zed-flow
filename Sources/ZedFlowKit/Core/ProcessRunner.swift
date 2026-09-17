import Foundation

// MARK: - ProcessRunner Error Types

/// Errors that can occur before or during script execution.
public enum ProcessRunnerError: Error, Sendable, CustomStringConvertible {
    case scriptNotFound(path: String)
    case scriptNotReadable(path: String)
    case interpreterNotFound(interpreter: String)
    case launchFailed(underlying: String)

    public var description: String {
        switch self {
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .scriptNotReadable(let path):
            return "Script is not readable: \(path)"
        case .interpreterNotFound(let interpreter):
            return "Interpreter not found: \(interpreter)"
        case .launchFailed(let underlying):
            return "Failed to launch process: \(underlying)"
        }
    }
}

// MARK: - Output Streaming

/// A callback type for receiving real-time output from a running process.
/// - Parameters:
///   - stream: Which stream produced the data (.stdout or .stderr)
///   - content: The text content received
public typealias OutputHandler = @Sendable (OutputStream, String) -> Void

/// Identifies which output stream produced data.
public enum OutputStream: Sendable {
    case stdout
    case stderr
}

// MARK: - Running Process Handle

/// A handle to a running process, allowing cancellation and status inspection.
public final class RunningProcess: @unchecked Sendable {
    let process: Process
    private let processGroup: pid_t
    private let startTime: Date
    private let lock = NSLock()
    private var _isCancelled = false

    /// Whether cancellation was requested.
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }

    init(process: Process, startTime: Date) {
        self.process = process
        self.processGroup = process.processIdentifier
        self.startTime = startTime
    }

    /// Stops the running process and its entire process group.
    /// Sends SIGTERM first, then SIGKILL after a grace period if still alive.
    public func stop() {
        lock.lock()
        _isCancelled = true
        lock.unlock()

        let pid = process.processIdentifier
        guard pid > 0, process.isRunning else { return }

        // Send SIGTERM to the entire process group (negative pid)
        kill(-pid, SIGTERM)

        // Give the process group a grace period to exit
        let deadline = DispatchTime.now() + .milliseconds(500)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline) { [weak self] in
            guard let self = self, self.process.isRunning else { return }
            // Force kill the process group if still alive
            kill(-pid, SIGKILL)
        }
    }
}

// MARK: - ProcessRunner

/// Executes local scripts using Foundation.Process with real-time output streaming,
/// process group management, and clean cancellation support.
public final class ProcessRunner: Sendable {

    public init() {}

    // MARK: - Public API

    /// Executes a script and returns the completed execution record.
    ///
    /// - Parameters:
    ///   - script: The script definition to execute.
    ///   - onOutput: Optional callback for real-time stdout/stderr streaming.
    /// - Returns: A tuple of (ScriptExecution record, RunningProcess handle).
    /// - Throws: `ProcessRunnerError` if the script or interpreter cannot be found.
    public func run(
        script: Script,
        action: ScriptAction? = nil,
        onOutput: OutputHandler? = nil
    ) throws -> (execution: ScriptExecution, handle: RunningProcess) {
        let scriptURL = URL(fileURLWithPath: script.scriptPath)
        let fm = FileManager.default

        // Validate script exists
        guard fm.fileExists(atPath: scriptURL.path) else {
            throw ProcessRunnerError.scriptNotFound(path: script.scriptPath)
        }

        // Validate script is readable
        guard fm.isReadableFile(atPath: scriptURL.path) else {
            throw ProcessRunnerError.scriptNotReadable(path: script.scriptPath)
        }

        // Resolve the interpreter binary and arguments
        var (interpreterPath, args) = try resolveInterpreter(
            for: script,
            scriptPath: scriptURL.path
        )
        if let action = action {
            args.append(contentsOf: action.arguments)
        }

        // Validate interpreter exists
        guard fm.fileExists(atPath: interpreterPath) else {
            throw ProcessRunnerError.interpreterNotFound(interpreter: interpreterPath)
        }

        // Build the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: interpreterPath)
        process.arguments = args
        process.currentDirectoryURL = scriptURL.deletingLastPathComponent()
        process.environment = EnvironmentResolver.resolvedEnvironment

        // Create a new process group so we can kill child processes cleanly.
        // This POSIX callback runs in the child process after fork() but before exec().
        // Setting pgid to 0 makes the child its own process group leader.
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        process.qualityOfService = .userInitiated

        // Set up pipes for stdout and stderr
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startTime = Date()

        // Launch the process
        do {
            try process.run()
        } catch {
            throw ProcessRunnerError.launchFailed(underlying: error.localizedDescription)
        }

        // Set the process group using the child's pid so kill(-pid) works
        // This must happen immediately after launch while child is still running
        let pid = process.processIdentifier
        setpgid(pid, pid)

        let handle = RunningProcess(process: process, startTime: startTime)

        // Create the initial execution record
        let execution = ScriptExecution(
            scriptId: script.id,
            scriptName: script.name,
            actionName: action?.name,
            status: .running,
            startTime: startTime
        )

        // Start async reading of stdout and stderr
        startStreamReading(pipe: stdoutPipe, stream: .stdout, onOutput: onOutput)
        startStreamReading(pipe: stderrPipe, stream: .stderr, onOutput: onOutput)

        return (execution, handle)
    }

    /// Waits for a running process to complete and returns the final execution record
    /// with all captured output, timing, and status information.
    ///
    /// - Parameters:
    ///   - handle: The running process handle.
    ///   - initialExecution: The execution record created at launch time.
    /// - Returns: The completed `ScriptExecution` with final status, output, and timing.
    public func waitForCompletion(
        handle: RunningProcess,
        initialExecution: ScriptExecution,
        accumulatedStdout: String = "",
        accumulatedStderr: String = "",
        outputChunks: [LogChunk] = []
    ) -> ScriptExecution {
        // Wait for the process to finish
        handle.process.waitUntilExit()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(initialExecution.startTime)
        let exitCode = handle.process.terminationStatus

        var chunks = outputChunks

        // Clean up readability handlers before reading trailing data
        if let stdoutPipe = handle.process.standardOutput as? Pipe {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
        }
        if let stderrPipe = handle.process.standardError as? Pipe {
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        // Read any remaining buffered output
        let stdoutData: Data
        let stderrData: Data
        if let stdoutPipe = handle.process.standardOutput as? Pipe {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        } else {
            stdoutData = Data()
        }
        if let stderrPipe = handle.process.standardError as? Pipe {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        } else {
            stderrData = Data()
        }

        let trailingStdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let trailingStderr = String(data: stderrData, encoding: .utf8) ?? ""

        if !trailingStdout.isEmpty {
            chunks.append(LogChunk(stream: .stdout, text: trailingStdout))
        }
        if !trailingStderr.isEmpty {
            chunks.append(LogChunk(stream: .stderr, text: trailingStderr))
        }

        let fullStdout = accumulatedStdout.isEmpty ? trailingStdout : (accumulatedStdout + trailingStdout)
        let fullStderr = accumulatedStderr.isEmpty ? trailingStderr : (accumulatedStderr + trailingStderr)

        // Determine final status using universal ZedFlow protocol
        let status = parseExecutionStatus(
            exitCode: exitCode,
            isCancelled: handle.isCancelled,
            output: fullStdout + fullStderr
        )

        return ScriptExecution(
            id: initialExecution.id,
            scriptId: initialExecution.scriptId,
            scriptName: initialExecution.scriptName,
            actionName: initialExecution.actionName,
            status: status,
            startTime: initialExecution.startTime,
            endTime: endTime,
            duration: duration,
            exitCode: exitCode,
            stdout: fullStdout,
            stderr: fullStderr,
            outputChunks: chunks
        )
    }

    /// Convenience: runs a script synchronously and returns the completed execution.
    /// Blocks the calling thread until the process exits.
    public func runAndWait(
        script: Script,
        action: ScriptAction? = nil,
        onOutput: OutputHandler? = nil
    ) throws -> (execution: ScriptExecution, handle: RunningProcess) {
        final class Accumulator: @unchecked Sendable {
            private let lock = NSLock()
            private var _stdout = ""
            private var _stderr = ""
            private var _chunks: [LogChunk] = []

            func append(stream: StreamType, text: String) {
                lock.lock()
                defer { lock.unlock() }
                switch stream {
                case .stdout:
                    _stdout += text
                    _chunks.append(LogChunk(stream: .stdout, text: text))
                case .stderr:
                    _stderr += text
                    _chunks.append(LogChunk(stream: .stderr, text: text))
                }
            }

            func snapshot() -> (stdout: String, stderr: String, chunks: [LogChunk]) {
                lock.lock()
                defer { lock.unlock() }
                return (_stdout, _stderr, _chunks)
            }
        }

        let acc = Accumulator()

        let wrappedOutput: OutputHandler?
        if let onOutput = onOutput {
            wrappedOutput = { stream, text in
                acc.append(stream: stream == .stdout ? .stdout : .stderr, text: text)
                onOutput(stream, text)
            }
        } else {
            wrappedOutput = nil
        }

        let (initialExecution, handle) = try run(script: script, action: action, onOutput: wrappedOutput)
        let snap = acc.snapshot()
        let finalExecution = waitForCompletion(
            handle: handle,
            initialExecution: initialExecution,
            accumulatedStdout: snap.stdout,
            accumulatedStderr: snap.stderr,
            outputChunks: snap.chunks
        )
        return (finalExecution, handle)
    }

    // MARK: - Interpreter Resolution

    /// Resolves the interpreter binary path and arguments for a given script.
    /// Returns (interpreterBinaryPath, [arguments including script path]).
    func resolveInterpreter(
        for script: Script,
        scriptPath: String
    ) throws -> (String, [String]) {
        switch script.interpreter {
        case .automatic:
            return try resolveAutomatic(scriptPath: scriptPath)
        case .custom:
            guard let customPath = script.customInterpreterPath, !customPath.isEmpty else {
                throw ProcessRunnerError.interpreterNotFound(interpreter: "Custom interpreter path is empty")
            }
            let resolvedPath = resolveInPATH(customPath)
            return (resolvedPath, [scriptPath])
        default:
            guard let binaryPath = script.interpreter.defaultBinaryPath else {
                throw ProcessRunnerError.interpreterNotFound(
                    interpreter: script.interpreter.rawValue
                )
            }
            return (binaryPath, [scriptPath])
        }
    }

    /// Auto-detects the interpreter from the file extension and shebang line.
    private func resolveAutomatic(scriptPath: String) throws -> (String, [String]) {
        let ext = (scriptPath as NSString).pathExtension.lowercased()

        // Try shebang first for more precise detection
        if let shebangInterpreter = readShebang(at: scriptPath) {
            return (shebangInterpreter, [scriptPath])
        }

        // Fall back to extension-based detection
        switch ext {
        case "sh":
            return ("/bin/sh", [scriptPath])
        case "bash":
            return ("/bin/bash", [scriptPath])
        case "zsh":
            return ("/bin/zsh", [scriptPath])
        case "py", "python", "python3":
            // Try to find python3 in PATH for Homebrew/pyenv installs
            let python = resolveInPATH("python3")
            return (python, [scriptPath])
        case "command":
            return ("/bin/sh", [scriptPath])
        case "":
            // No extension — try to run with sh as a safe default
            return ("/bin/sh", [scriptPath])
        default:
            // Unknown extension — try sh
            return ("/bin/sh", [scriptPath])
        }
    }

    /// Reads the shebang line from a script file and extracts the interpreter path.
    /// Handles both `#!/path/to/interpreter` and `#!/usr/bin/env interpreter`.
    public func readShebang(at path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }

        // Read just the first line (max 256 bytes is plenty for a shebang)
        let data = handle.readData(ofLength: 256)
        guard let firstChunk = String(data: data, encoding: .utf8) else { return nil }

        let firstLine: String
        if let newlineIndex = firstChunk.firstIndex(of: "\n") {
            firstLine = String(firstChunk[firstChunk.startIndex..<newlineIndex])
        } else {
            firstLine = firstChunk
        }

        guard firstLine.hasPrefix("#!") else { return nil }

        let shebang = String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        guard !shebang.isEmpty else { return nil }

        // Handle `#!/usr/bin/env interpreter`
        if shebang.hasPrefix("/usr/bin/env ") {
            let parts = shebang.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { return nil }
            let interpreterName = parts[1]
            return resolveInPATH(interpreterName)
        }

        // Handle direct path: `#!/bin/bash`, `#!/opt/homebrew/bin/python3`, etc.
        let parts = shebang.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let interpreterPath = parts.first else { return nil }
        return interpreterPath
    }

    /// Resolves a command name to its full path using the resolved PATH.
    /// If the input is already an absolute path, returns it directly.
    func resolveInPATH(_ command: String) -> String {
        // Already an absolute path
        if command.hasPrefix("/") {
            return command
        }

        let paths = EnvironmentResolver.resolvedPATH.components(separatedBy: ":")
        let fm = FileManager.default
        for dir in paths {
            let fullPath = (dir as NSString).appendingPathComponent(command)
            if fm.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }

        // Return as-is; the caller will get an interpreterNotFound error
        return command
    }

    // MARK: - Stream Reading

    /// Starts asynchronous reading from a pipe, calling the handler for each chunk.
    private func startStreamReading(
        pipe: Pipe,
        stream: OutputStream,
        onOutput: OutputHandler?
    ) {
        guard let onOutput = onOutput else { return }

        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else {
                // EOF — stop reading
                fileHandle.readabilityHandler = nil
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                onOutput(stream, text)
            }
        }
    }

    // MARK: - Universal Protocol Parser

    /// Universal protocol parser for script execution results.
    /// Supports:
    /// 1. Directive tags in output: `[zedflow:status=<active|clear|failed>]` or `@zedflow:status=<...>`
    /// 2. Standard exit codes (LSB conventions):
    ///    - 0: .success (Active / Set / OK)
    ///    - 2, 3: .clear (Clear / Inactive / Off)
    ///    - other: .failed (Error)
    func parseExecutionStatus(
        exitCode: Int32,
        isCancelled: Bool,
        output: String
    ) -> ExecutionStatus {
        if isCancelled {
            return .stopped
        }

        // Check for universal ZedFlow protocol directive: [zedflow:status=...] or @zedflow:status=...
        let lower = output.lowercased()
        if let match = lower.range(of: "\\[zedflow:status=([a-z]+)\\]", options: .regularExpression) ??
                      lower.range(of: "@zedflow:status=([a-z]+)", options: .regularExpression) {
            let matchedString = String(lower[match])
            if matchedString.contains("active") || matchedString.contains("set") || matchedString.contains("ok") || matchedString.contains("success") {
                return .success
            } else if matchedString.contains("clear") || matchedString.contains("inactive") || matchedString.contains("off") {
                return .clear
            } else if matchedString.contains("failed") || matchedString.contains("error") {
                return .failed
            }
        }

        // Universal exit code standard (0 = active/success, 2/3 = clear/inactive, other = failed)
        switch exitCode {
        case 0:
            return .success
        case 2, 3:
            return .clear
        default:
            return .failed
        }
    }
}
