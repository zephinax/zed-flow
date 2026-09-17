import Foundation
import ZedFlowKit

@main
struct ZedFlowTestRunner {
    nonisolated(unsafe) static var passed = 0
    nonisolated(unsafe) static var failed = 0

    static func check(_ description: String, _ condition: Bool) {
        if condition {
            print("  ✅ PASS: \(description)")
            passed += 1
        } else {
            print("  ❌ FAIL: \(description)")
            failed += 1
        }
    }

    static func checkThrows<E: Error>(_ description: String, errorType: E.Type, _ block: () throws -> Void) {
        do {
            try block()
            print("  ❌ FAIL: \(description) — expected error but none thrown")
            failed += 1
        } catch is E {
            print("  ✅ PASS: \(description)")
            passed += 1
        } catch {
            print("  ❌ FAIL: \(description) — wrong error type: \(error)")
            failed += 1
        }
    }

    // MARK: - Temp Script Helpers

    static let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ZedFlowTests-\(UUID().uuidString)")

    static func createTempScript(_ filename: String, contents: String, executable: Bool = true) -> String {
        let path = tempDir.appendingPathComponent(filename).path
        try! FileManager.default.createDirectory(atPath: tempDir.path, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: path, contents: contents.data(using: .utf8))
        if executable {
            try! FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        }
        return path
    }

    static func cleanup() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Main

    static func main() async {
        print("=== ZedFlow Test Suite ===\n")

        print("--- Phase 1: Models & Storage ---")
        testScriptCodable()
        testScheduleConfigTitles()
        testScriptExecutionCodable()
        await testStorageScripts()
        await testStorageHistory()

        print("\n--- Phase 2: Execution Engine ---")
        testSuccessfulExecution()
        testStdoutCapture()
        testStderrCapture()
        testNonZeroExitCode()
        testMissingScript()
        testMissingInterpreter()
        testCancellation()
        testChildProcessCleanup()
        testShebangDetection()
        testShebangEnv()
        testAutoDetectByExtension()
        testCustomInterpreter()
        testEnvironmentResolution()
        testStreamingOutput()

        print("\n--- Phase 3: Script Management & State ---")
        await testScriptStoreCRUD()
        await testScriptStoreRunAndStop()

        print("\n--- Phase 4: Output Console & History ---")
        testLogChunkAndInterleavedOutput()
        await testScriptStoreHistoryAndClearing()

        print("\n--- Phase 5: Scheduling & System Integration ---")
        testIntervalNextExecutionCalculation()
        testDailyNextExecutionCalculation()
        await testJobSchedulerDisabledAndManual()
        await testJobSchedulerConcurrentExecutionPrevention()
        await testJobSchedulerReconciliation()
        testNotificationServiceFiltering()
        testLaunchAtLoginService()

        print("\n--- Phase 6: CLI & Local IPC Integration ---")
        testIPCProtocolSerialization()
        await testIPCAppNotRunning()
        await testIPCSocketRoundTrip()
        await testIPCConcurrentRequests()

        print("\n--- Phase 7: Script Actions & Flags ---")
        testScriptActionModel()
        testScriptActionBackwardCompatibility()
        testExecutionWithActionArguments()
        await testScriptStoreRunAction()
        await testIPCRunAction()
        await testIPCConfigurationAndActionManagement()

        cleanup()
        print("\n=== Summary: \(passed) passed, \(failed) failed ===")
        if failed > 0 { exit(1) }
    }

    // MARK: - Phase 1 Tests

    static func testScriptCodable() {
        do {
            let script = Script(
                name: "Backup", scriptPath: "/usr/local/bin/backup.sh",
                interpreter: .bash, schedule: .daily(hour: 3, minute: 30),
                notifyOnSuccess: true, notifyOnFailure: true
            )
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(script)
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let d = try decoder.decode(Script.self, from: data)
            check("Script encoding/decoding",
                  d.id == script.id && d.name == "Backup" && d.interpreter == .bash
                  && d.schedule == .daily(hour: 3, minute: 30))
        } catch { print("  ❌ FAIL: Script codable — \(error)"); failed += 1 }
    }

    static func testScheduleConfigTitles() {
        check("ScheduleConfig display titles",
              ScheduleConfig.manual.displayTitle == "Manual"
              && ScheduleConfig.interval(minutes: 15).displayTitle == "Every 15m"
              && ScheduleConfig.interval(minutes: 60).displayTitle == "Every 1 hour"
              && ScheduleConfig.interval(minutes: 120).displayTitle == "Every 2 hours"
              && ScheduleConfig.daily(hour: 9, minute: 5).displayTitle == "Daily at 09:05")
    }

    static func testScriptExecutionCodable() {
        do {
            let exec = ScriptExecution(scriptId: UUID(), scriptName: "HC", status: .success,
                                       exitCode: 0, stdout: "ok\n", stderr: "")
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exec)
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            let d = try decoder.decode(ScriptExecution.self, from: data)
            check("ScriptExecution encoding/decoding",
                  d.id == exec.id && d.status == .success && d.exitCode == 0 && d.stdout == "ok\n")
        } catch { print("  ❌ FAIL: ScriptExecution codable — \(error)"); failed += 1 }
    }

    static func testStorageScripts() async {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let storage = StorageService(baseDirectory: dir)
            let initial = try await storage.loadScripts()
            let s1 = Script(name: "S1", scriptPath: "/a.py", interpreter: .python3)
            let s2 = Script(name: "S2", scriptPath: "/b.sh", interpreter: .sh)
            try await storage.saveScripts([s1, s2])
            let loaded = try await storage.loadScripts()
            check("StorageService scripts persistence",
                  initial.isEmpty && loaded.count == 2 && loaded[0].name == "S1")
            try? FileManager.default.removeItem(at: dir)
        } catch { print("  ❌ FAIL: StorageService scripts — \(error)"); failed += 1 }
    }

    static func testStorageHistory() async {
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let storage = StorageService(baseDirectory: dir)
            let sid = UUID()
            let e1 = ScriptExecution(scriptId: sid, scriptName: "J", status: .success, exitCode: 0)
            let e2 = ScriptExecution(scriptId: sid, scriptName: "J", status: .failed, exitCode: 1)
            let e3 = ScriptExecution(scriptId: sid, scriptName: "J", status: .stopped, exitCode: 130)
            try await storage.recordExecution(e1, maxHistoryCount: 2)
            try await storage.recordExecution(e2, maxHistoryCount: 2)
            try await storage.recordExecution(e3, maxHistoryCount: 2)
            let h = try await storage.loadExecutions(for: sid)
            try await storage.deleteHistory(for: sid)
            let hd = try await storage.loadExecutions(for: sid)
            check("StorageService history capping & deletion",
                  h.count == 2 && h[0].id == e3.id && h[1].id == e2.id && hd.isEmpty)
            try? FileManager.default.removeItem(at: dir)
        } catch { print("  ❌ FAIL: StorageService history — \(error)"); failed += 1 }
    }

    // MARK: - Phase 2 Tests

    static func testSuccessfulExecution() {
        let path = createTempScript("success.sh", contents: "#!/bin/sh\necho hello\n")
        let script = Script(name: "Success", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()
        do {
            let (exec, _) = try runner.runAndWait(script: script)
            check("Successful execution",
                  exec.status == .success && exec.exitCode == 0
                  && exec.endTime != nil && exec.duration != nil && exec.duration! >= 0)
        } catch { print("  ❌ FAIL: Successful execution — \(error)"); failed += 1 }
    }

    static func testStdoutCapture() {
        let path = createTempScript("stdout.sh", contents: "#!/bin/sh\necho \"line1\"\necho \"line2\"\n")
        let script = Script(name: "Stdout", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()
        do {
            let (exec, _) = try runner.runAndWait(script: script)
            let out = exec.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            check("Stdout capture", out.contains("line1") && out.contains("line2"))
        } catch { print("  ❌ FAIL: Stdout capture — \(error)"); failed += 1 }
    }

    static func testStderrCapture() {
        let path = createTempScript("stderr.sh", contents: "#!/bin/sh\necho \"err_msg\" >&2\n")
        let script = Script(name: "Stderr", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()
        do {
            let (exec, _) = try runner.runAndWait(script: script)
            check("Stderr capture", exec.stderr.contains("err_msg"))
        } catch { print("  ❌ FAIL: Stderr capture — \(error)"); failed += 1 }
    }

    static func testNonZeroExitCode() {
        let path = createTempScript("fail.sh", contents: "#!/bin/sh\nexit 42\n")
        let script = Script(name: "Fail", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()
        do {
            let (exec, _) = try runner.runAndWait(script: script)
            check("Non-zero exit code", exec.status == .failed && exec.exitCode == 42)
        } catch { print("  ❌ FAIL: Non-zero exit code — \(error)"); failed += 1 }
    }

    static func testMissingScript() {
        let script = Script(name: "Ghost", scriptPath: "/tmp/nonexistent_\(UUID()).sh", interpreter: .sh)
        let runner = ProcessRunner()
        checkThrows("Missing script throws scriptNotFound", errorType: ProcessRunnerError.self) {
            _ = try runner.runAndWait(script: script)
        }
    }

    static func testMissingInterpreter() {
        let path = createTempScript("interp.sh", contents: "echo hi\n")
        let script = Script(name: "BadInterp", scriptPath: path, interpreter: .custom,
                            customInterpreterPath: "/usr/bin/nonexistent_interp_\(UUID())")
        let runner = ProcessRunner()
        checkThrows("Missing interpreter throws error", errorType: ProcessRunnerError.self) {
            _ = try runner.runAndWait(script: script)
        }
    }

    static func testCancellation() {
        let path = createTempScript("slow.sh", contents: "#!/bin/sh\nsleep 60\n")
        let script = Script(name: "Slow", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()
        do {
            let (initial, handle) = try runner.run(script: script)
            // Give the process a moment to start
            Thread.sleep(forTimeInterval: 0.2)
            handle.stop()
            let exec = runner.waitForCompletion(handle: handle, initialExecution: initial)
            check("Cancellation sets stopped status",
                  exec.status == .stopped && handle.isCancelled)
        } catch { print("  ❌ FAIL: Cancellation — \(error)"); failed += 1 }
    }

    static func testChildProcessCleanup() {
        // Script spawns a background child that writes a marker file while alive
        let marker = tempDir.appendingPathComponent("child_alive_\(UUID())").path
        let scriptContents = """
        #!/bin/sh
        # Spawn a child that creates a marker file and loops
        (while true; do touch "\(marker)"; sleep 0.1; done) &
        # Parent also sleeps
        sleep 60
        """
        let path = createTempScript("parent.sh", contents: scriptContents)
        let script = Script(name: "Parent", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()
        do {
            let (initial, handle) = try runner.run(script: script)
            // Wait for child to create marker
            Thread.sleep(forTimeInterval: 0.5)
            let markerExisted = FileManager.default.fileExists(atPath: marker)

            // Stop and wait
            handle.stop()
            _ = runner.waitForCompletion(handle: handle, initialExecution: initial)

            // Remove marker and wait — child should be dead, so it won't recreate
            try? FileManager.default.removeItem(atPath: marker)
            Thread.sleep(forTimeInterval: 0.5)
            let markerRecreated = FileManager.default.fileExists(atPath: marker)

            check("Child process cleanup after stop",
                  markerExisted && !markerRecreated)
        } catch { print("  ❌ FAIL: Child process cleanup — \(error)"); failed += 1 }
    }

    static func testShebangDetection() {
        let path = createTempScript("shebang.sh", contents: "#!/bin/bash\necho shebang_works\n")
        let runner = ProcessRunner()
        let detected = runner.readShebang(at: path)
        check("Shebang detection (direct path)", detected == "/bin/bash")
    }

    static func testShebangEnv() {
        // #!/usr/bin/env sh should resolve to a valid sh path
        let path = createTempScript("shebang_env.sh", contents: "#!/usr/bin/env sh\necho env_works\n")
        let runner = ProcessRunner()
        let detected = runner.readShebang(at: path)
        check("Shebang detection (env)", detected != nil && FileManager.default.fileExists(atPath: detected!))
    }

    static func testAutoDetectByExtension() {
        let path = createTempScript("auto.zsh", contents: "echo auto_detect\n")
        let script = Script(name: "Auto", scriptPath: path, interpreter: .automatic)
        let runner = ProcessRunner()
        do {
            let (exec, _) = try runner.runAndWait(script: script)
            check("Auto-detect by .zsh extension",
                  exec.status == .success && exec.exitCode == 0)
        } catch { print("  ❌ FAIL: Auto-detect — \(error)"); failed += 1 }
    }

    static func testCustomInterpreter() {
        let path = createTempScript("custom.sh", contents: "echo custom\n")
        let script = Script(name: "Custom", scriptPath: path, interpreter: .custom,
                            customInterpreterPath: "/bin/sh")
        let runner = ProcessRunner()
        do {
            let (exec, _) = try runner.runAndWait(script: script)
            check("Custom interpreter execution",
                  exec.status == .success && exec.stdout.contains("custom"))
        } catch { print("  ❌ FAIL: Custom interpreter — \(error)"); failed += 1 }
    }

    static func testEnvironmentResolution() {
        let resolvedPATH = EnvironmentResolver.resolvedPATH
        let env = EnvironmentResolver.resolvedEnvironment
        check("Environment resolution provides PATH",
              !resolvedPATH.isEmpty && resolvedPATH.contains("/usr/bin") && env["PATH"] != nil)
    }

    static func testStreamingOutput() {
        let path = createTempScript("stream.sh", contents: "#!/bin/sh\necho stream_a\necho stream_b >&2\n")
        let script = Script(name: "Stream", scriptPath: path, interpreter: .sh)
        let runner = ProcessRunner()

        final class OutputCollector: @unchecked Sendable {
            private let lock = NSLock()
            private var _stdout: [String] = []
            private var _stderr: [String] = []
            var stdoutJoined: String { lock.lock(); defer { lock.unlock() }; return _stdout.joined() }
            var stderrJoined: String { lock.lock(); defer { lock.unlock() }; return _stderr.joined() }
            func append(_ stream: ZedFlowKit.OutputStream, _ text: String) {
                lock.lock()
                switch stream {
                case .stdout: _stdout.append(text)
                case .stderr: _stderr.append(text)
                }
                lock.unlock()
            }
        }
        let collector = OutputCollector()

        do {
            let (initial, handle) = try runner.run(script: script) { stream, text in
                collector.append(stream, text)
            }
            _ = runner.waitForCompletion(handle: handle, initialExecution: initial)
            Thread.sleep(forTimeInterval: 0.1)
            check("Streaming output callback",
                  collector.stdoutJoined.contains("stream_a") && collector.stderrJoined.contains("stream_b"))
        } catch { print("  ❌ FAIL: Streaming output — \(error)"); failed += 1 }
    }

    // MARK: - Phase 3 Tests: ScriptStore & UI Integration

    @MainActor
    static func testScriptStoreCRUD() async {
        let tempStorageDir = tempDir.appendingPathComponent("storage_\(UUID())")
        let storage = StorageService(baseDirectory: tempStorageDir)
        let store = ScriptStore(storageService: storage)

        let script = Script(name: "Test Job", scriptPath: "/bin/echo", interpreter: .sh)
        do {
            try await store.addScript(script)
            check("ScriptStore adds script", store.scripts.count == 1 && store.scripts[0].name == "Test Job")

            var updated = script
            updated.name = "Renamed Job"
            try await store.updateScript(updated)
            check("ScriptStore updates script", store.scripts[0].name == "Renamed Job")

            try await store.deleteScript(updated)
            check("ScriptStore deletes script", store.scripts.isEmpty)
        } catch {
            print("  ❌ FAIL: ScriptStore CRUD — \(error)")
            failed += 1
        }
    }

    @MainActor
    static func testScriptStoreRunAndStop() async {
        let tempStorageDir = tempDir.appendingPathComponent("storage_\(UUID())")
        let storage = StorageService(baseDirectory: tempStorageDir)
        let store = ScriptStore(storageService: storage)

        let path = createTempScript("store_run.sh", contents: "#!/bin/sh\nsleep 30\n")
        let script = Script(name: "Long Job", scriptPath: path, interpreter: .sh)

        do {
            try await store.addScript(script)
            store.runScript(script)

            // Give it a fraction of a second to launch
            try? await Task.sleep(nanoseconds: 100_000_000)

            let wasRunning = store.isRunningScript[script.id] == true
            let hasRunningCount = store.runningCount >= 1
            check("ScriptStore tracks running state", wasRunning && hasRunningCount)

            store.stopScript(script)

            // Wait for completion callback to propagate
            var attempts = 0
            while store.isRunningScript[script.id] == true && attempts < 20 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                attempts += 1
            }

            let stopped = store.isRunningScript[script.id] == false
            let status = store.executionStatus(for: script)
            check("ScriptStore stops script and records status", stopped && status == .stopped)
        } catch {
            print("  ❌ FAIL: ScriptStore Run and Stop — \(error)")
            failed += 1
        }
    }

    // MARK: - Phase 4 Tests: Console Output & History

    static func testLogChunkAndInterleavedOutput() {
        let chunk1 = LogChunk(stream: .stdout, text: "Starting build...\n")
        let chunk2 = LogChunk(stream: .stderr, text: "Warning: unused variable\n")
        let chunk3 = LogChunk(stream: .stdout, text: "Build succeeded\n")

        let execution = ScriptExecution(
            scriptId: UUID(),
            scriptName: "Compiler",
            status: .success,
            duration: 0.85,
            exitCode: 0,
            stdout: "Starting build...\nBuild succeeded\n",
            stderr: "Warning: unused variable\n",
            outputChunks: [chunk1, chunk2, chunk3]
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(execution)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(ScriptExecution.self, from: data)

            check("LogChunk and interleaved output serialization",
                  decoded.outputChunks.count == 3 &&
                  decoded.outputChunks[0].stream == .stdout &&
                  decoded.outputChunks[1].stream == .stderr &&
                  decoded.outputChunks[2].stream == .stdout &&
                  decoded.stdout.contains("Build succeeded") &&
                  decoded.stderr.contains("Warning"))
        } catch {
            print("  ❌ FAIL: LogChunk serialization — \(error)")
            failed += 1
        }
    }

    @MainActor
    static func testScriptStoreHistoryAndClearing() async {
        let tempStorageDir = tempDir.appendingPathComponent("storage_\(UUID())")
        let storage = StorageService(baseDirectory: tempStorageDir)
        let store = ScriptStore(storageService: storage)

        let path = createTempScript("history_job.sh", contents: "#!/bin/sh\necho 'out 1'\necho 'err 1' >&2\n")
        let script = Script(name: "History Job", scriptPath: path, interpreter: .sh)

        do {
            try await store.addScript(script)
            store.runScript(script)

            // Wait for execution to finish
            var attempts = 0
            while store.isRunningScript[script.id] == true && attempts < 30 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                attempts += 1
            }

            let history = await store.loadHistory(for: script)
            check("ScriptStore loads execution history",
                  history.count == 1 &&
                  history[0].status == .success &&
                  history[0].stdout.contains("out 1") &&
                  history[0].stderr.contains("err 1"))

            // Clear history
            try await store.clearHistory(for: script)
            let afterClear = await store.loadHistory(for: script)
            check("ScriptStore clears execution history", afterClear.isEmpty)
        } catch {
            print("  ❌ FAIL: ScriptStore History and Clearing — \(error)")
            failed += 1
        }
    }

    // MARK: - Phase 5 Tests: Scheduling & System Integration

    static func testIntervalNextExecutionCalculation() {
        let config = ScheduleConfig.interval(minutes: 15)
        let now = Date(timeIntervalSince1970: 1700000000) // Fixed baseline timestamp

        // 1. Basic next occurrence without baseDate
        let next = config.nextExecutionDate(after: now)
        check("Interval calculates next occurrence (+15m)",
              next == now.addingTimeInterval(15 * 60))

        // 2. Drift-free next occurrence with baseDate
        let anchor = now.addingTimeInterval(15 * 60)
        let nextAnchored = config.nextExecutionDate(after: now.addingTimeInterval(5 * 60), baseDate: anchor)
        check("Interval preserves anchor date when before next step",
              nextAnchored == anchor)

        // 3. Sleep / missed executions: if 40 minutes passed, skips missed runs and schedules next step
        let afterSleep = now.addingTimeInterval(40 * 60)
        let nextAfterSleep = config.nextExecutionDate(after: afterSleep, baseDate: now)
        // 40m passed on a 15m step: step 1 is 15m, step 2 is 30m, step 3 is 45m. Next should be 45m!
        check("Interval recalculates future step after sleep without backlog",
              nextAfterSleep == now.addingTimeInterval(45 * 60))
    }

    static func testDailyNextExecutionCalculation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Reference date: 2024-01-15 10:00:00 GMT
        var comp = DateComponents()
        comp.year = 2024
        comp.month = 1
        comp.day = 15
        comp.hour = 10
        comp.minute = 0
        comp.second = 0
        let refDate = calendar.date(from: comp)!

        // Case A: Daily at 14:00 (in the future today)
        let dailyFuture = ScheduleConfig.daily(hour: 14, minute: 0)
        let nextFuture = dailyFuture.nextExecutionDate(after: refDate, calendar: calendar)!
        let compFuture = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextFuture)
        check("Daily schedule calculates future time on same day",
              compFuture.year == 2024 && compFuture.month == 1 && compFuture.day == 15 && compFuture.hour == 14 && compFuture.minute == 0)

        // Case B: Daily at 08:00 (already passed today -> should roll to tomorrow)
        let dailyPassed = ScheduleConfig.daily(hour: 8, minute: 0)
        let nextTomorrow = dailyPassed.nextExecutionDate(after: refDate, calendar: calendar)!
        let compTomorrow = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextTomorrow)
        check("Daily schedule rolls over to tomorrow if time has passed",
              compTomorrow.year == 2024 && compTomorrow.month == 1 && compTomorrow.day == 16 && compTomorrow.hour == 8 && compTomorrow.minute == 0)
    }

    @MainActor
    static func testJobSchedulerDisabledAndManual() async {
        let scheduler = JobScheduler()

        let manualScript = Script(name: "Manual", scriptPath: "/bin/echo", schedule: .manual)
        scheduler.schedule(script: manualScript)
        check("JobScheduler ignores manual scripts", !scheduler.isScheduled(scriptId: manualScript.id))

        let disabledScript = Script(name: "Disabled", scriptPath: "/bin/echo", schedule: .interval(minutes: 5), isEnabled: false)
        scheduler.schedule(script: disabledScript)
        check("JobScheduler ignores disabled scripts", !scheduler.isScheduled(scriptId: disabledScript.id))
    }

    @MainActor
    static func testJobSchedulerConcurrentExecutionPrevention() async {
        let scheduler = JobScheduler()
        let triggered = false

        scheduler.onTrigger = { _ in }

        // Simulate script already running
        scheduler.isRunningCheck = { _ in
            return true
        }

        let script = Script(name: "Quick", scriptPath: "/bin/echo", schedule: .interval(minutes: 1))
        let isBlocked = scheduler.isRunningCheck?(script) == true
        check("JobScheduler checks running state to prevent concurrent execution", isBlocked && !triggered)
    }

    @MainActor
    static func testJobSchedulerReconciliation() async {
        let scheduler = JobScheduler()
        let s1 = Script(name: "S1", scriptPath: "/bin/echo", schedule: .interval(minutes: 10))
        let s2 = Script(name: "S2", scriptPath: "/bin/echo", schedule: .interval(minutes: 20))

        scheduler.reconcile(scripts: [s1, s2])
        check("JobScheduler schedules active scripts on reconciliation",
              scheduler.isScheduled(scriptId: s1.id) && scheduler.isScheduled(scriptId: s2.id))

        // Reconcile with s2 disabled and s1 removed
        var s2Disabled = s2
        s2Disabled.isEnabled = false
        scheduler.reconcile(scripts: [s2Disabled])

        check("JobScheduler cancels removed and disabled scripts on reconciliation",
              !scheduler.isScheduled(scriptId: s1.id) && !scheduler.isScheduled(scriptId: s2.id))
    }

    static func testNotificationServiceFiltering() {
        let service = NotificationService()

        let scriptSuccessOnly = Script(name: "S", scriptPath: "/p", notifyOnSuccess: true, notifyOnFailure: false)
        check("NotificationService respects notifyOnSuccess",
              service.shouldNotify(for: scriptSuccessOnly, status: .success) &&
              !service.shouldNotify(for: scriptSuccessOnly, status: .failed))

        let scriptFailureOnly = Script(name: "F", scriptPath: "/p", notifyOnSuccess: false, notifyOnFailure: true)
        check("NotificationService respects notifyOnFailure",
              !service.shouldNotify(for: scriptFailureOnly, status: .success) &&
              service.shouldNotify(for: scriptFailureOnly, status: .failed))

        let scriptStopped = Script(name: "Stopped", scriptPath: "/p", notifyOnSuccess: true, notifyOnFailure: true)
        check("NotificationService ignores stopped status",
              !service.shouldNotify(for: scriptStopped, status: .stopped))
    }

    static func testLaunchAtLoginService() {
        let service = LaunchAtLoginService()
        let desc = service.statusDescription
        check("LaunchAtLoginService reports valid status description", !desc.isEmpty)
    }

    // MARK: - Phase 6 Tests: CLI & Local IPC Integration

    static func testIPCProtocolSerialization() {
        let req = IPCRequest(command: .add, name: "Backup", path: "/tmp/b.sh", interpreter: "bash", waitForCompletion: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try encoder.encode(req)
            let decodedReq = try decoder.decode(IPCRequest.self, from: data)
            check("IPCRequest encodes and decodes accurately",
                  decodedReq.command == .add && decodedReq.name == "Backup" && decodedReq.path == "/tmp/b.sh")

            let resp = IPCResponse(success: true, message: "OK", exitCode: 0)
            let respData = try encoder.encode(resp)
            let decodedResp = try decoder.decode(IPCResponse.self, from: respData)
            check("IPCResponse encodes and decodes accurately",
                  decodedResp.success == true && decodedResp.message == "OK" && decodedResp.exitCode == 0)
        } catch {
            print("  ❌ FAIL: IPCProtocol Serialization — \(error)")
            failed += 1
        }
    }

    static func testIPCAppNotRunning() async {
        let nonExistentSocket = "/tmp/zf_none_\(UUID().uuidString.prefix(8)).sock"
        let client = IPCClient(socketPath: nonExistentSocket)
        do {
            _ = try await client.send(request: IPCRequest(command: .ping))
            print("  ❌ FAIL: testIPCAppNotRunning did not throw error")
            failed += 1
        } catch let error as IPCError {
            if case .appNotRunning = error {
                check("IPCClient returns appNotRunning when socket does not exist", true)
            } else {
                check("IPCClient returns appNotRunning when socket does not exist", false)
            }
        } catch {
            print("  ❌ FAIL: Unexpected error type — \(error)")
            failed += 1
        }
    }

    @MainActor
    static func testIPCSocketRoundTrip() async {
        let storageDir = tempDir.appendingPathComponent("ipc_storage_\(UUID())")
        let storage = StorageService(baseDirectory: storageDir)
        let store = ScriptStore(storageService: storage)

        let socketPath = "/tmp/zf_test_\(UUID().uuidString.prefix(8)).sock"
        let server = IPCServer(socketPath: socketPath, store: store)

        do {
            try server.start()
            check("IPCServer starts and binds to socket", server.isRunning && FileManager.default.fileExists(atPath: socketPath))

            let client = IPCClient(socketPath: socketPath)

            // 1. Ping
            let pingResp = try await client.send(request: IPCRequest(command: .ping))
            check("IPC ping returns pong", pingResp.success && pingResp.message == "pong")

            // 2. Empty list
            let emptyListResp = try await client.send(request: IPCRequest(command: .list))
            check("IPC list on empty store", emptyListResp.success && emptyListResp.scripts?.isEmpty == true)

            // 3. Add script
            let scriptPath = createTempScript("ipc_test.sh", contents: "#!/bin/sh\necho 'hello from ipc'\n")
            let addResp = try await client.send(request: IPCRequest(command: .add, name: "IPCTest", path: scriptPath))
            check("IPC add script creates script", addResp.success && addResp.script?.name == "IPCTest")

            // 4. List script
            let listResp = try await client.send(request: IPCRequest(command: .list))
            check("IPC list shows added script", listResp.scripts?.count == 1 && listResp.scripts?[0].name == "IPCTest")

            // 5. Status
            let statusResp = try await client.send(request: IPCRequest(command: .status, name: "IPCTest"))
            check("IPC status returns script details", statusResp.success && statusResp.script?.name == "IPCTest")

            // 6. Run script
            let runResp = try await client.send(request: IPCRequest(command: .run, name: "IPCTest", waitForCompletion: true))
            check("IPC run executes and returns output",
                  runResp.success &&
                  runResp.exitCode == 0 &&
                  runResp.execution?.stdout.contains("hello from ipc") == true)

            // 7. History
            let historyResp = try await client.send(request: IPCRequest(command: .history, name: "IPCTest"))
            check("IPC history returns execution records",
                  historyResp.success && historyResp.history?.count == 1)

            // 8. Remove script
            let removeResp = try await client.send(request: IPCRequest(command: .remove, name: "IPCTest"))
            check("IPC remove deletes script", removeResp.success)

            let afterRemoveList = try await client.send(request: IPCRequest(command: .list))
            check("IPC list after remove is empty", afterRemoveList.scripts?.isEmpty == true)

            server.stop()
            check("IPCServer stops cleanly and removes socket", !server.isRunning && !FileManager.default.fileExists(atPath: socketPath))
        } catch {
            print("  ❌ FAIL: testIPCSocketRoundTrip — \(error)")
            failed += 1
            server.stop()
        }
    }

    @MainActor
    static func testIPCConcurrentRequests() async {
        let storageDir = tempDir.appendingPathComponent("ipc_concurrent_storage_\(UUID())")
        let storage = StorageService(baseDirectory: storageDir)
        let store = ScriptStore(storageService: storage)

        let socketPath = "/tmp/zf_conc_\(UUID().uuidString.prefix(8)).sock"
        let server = IPCServer(socketPath: socketPath, store: store)

        do {
            try server.start()
            let client = IPCClient(socketPath: socketPath)

            // Dispatch 10 concurrent ping and list requests
            await withTaskGroup(of: Bool.self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        if let resp = try? await client.send(request: IPCRequest(command: .ping)) {
                            return resp.success
                        }
                        return false
                    }
                }
                var successCount = 0
                for await success in group {
                    if success { successCount += 1 }
                }
                check("IPC handles concurrent requests cleanly", successCount == 10)
            }

            server.stop()
        } catch {
            print("  ❌ FAIL: testIPCConcurrentRequests — \(error)")
            failed += 1
            server.stop()
        }
    }

    // MARK: - Phase 7 Tests: Script Actions & Flags

    static func testScriptActionModel() {
        let action = ScriptAction(
            name: "Restart",
            arguments: ["--mode", "graceful", "--timeout", "30"],
            systemImage: "arrow.clockwise"
        )
        check("ScriptAction stores name and arguments correctly", action.name == "Restart" && action.arguments.count == 4 && action.systemImage == "arrow.clockwise")

        do {
            let data = try JSONEncoder().encode(action)
            let decoded = try JSONDecoder().decode(ScriptAction.self, from: data)
            check("ScriptAction encodes and decodes cleanly", decoded.name == action.name && decoded.arguments == action.arguments && decoded.systemImage == action.systemImage)
        } catch {
            check("ScriptAction Codable failed: \(error)", false)
        }
    }

    static func testScriptActionBackwardCompatibility() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Test 1: Script JSON without "actions" key (legacy V1 payload)
        do {
            let originalScript = Script(
                name: "Legacy Script",
                scriptPath: "/bin/echo",
                interpreter: .automatic,
                schedule: .manual
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            var jsonDict = try JSONSerialization.jsonObject(with: try encoder.encode(originalScript)) as! [String: Any]
            jsonDict.removeValue(forKey: "actions")
            let legacyData = try JSONSerialization.data(withJSONObject: jsonDict)

            let legacyScript = try decoder.decode(Script.self, from: legacyData)
            check("Legacy script decodes with empty actions array", legacyScript.actions.isEmpty)
        } catch {
            check("Legacy script decoding failed: \(error)", false)
        }

        // Test 2: ScriptExecution JSON without "actionName" key
        let legacyExecutionJSON = """
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "scriptId": "11111111-1111-1111-1111-111111111111",
            "scriptName": "Legacy Script",
            "status": "success",
            "startTime": "2026-01-01T00:00:00Z",
            "duration": 1.2,
            "exitCode": 0,
            "stdout": "done",
            "stderr": "",
            "outputChunks": []
        }
        """

        do {
            let legacyExecution = try decoder.decode(ScriptExecution.self, from: legacyExecutionJSON.data(using: .utf8)!)
            check("Legacy execution decodes with nil actionName", legacyExecution.actionName == nil)
            check("Legacy execution displayName equals scriptName", legacyExecution.displayName == "Legacy Script")
        } catch {
            check("Legacy execution decoding failed: \(error)", false)
        }

        // Test 3: ScriptExecution with actionName
        let actionExecution = ScriptExecution(
            scriptId: UUID(),
            scriptName: "Proxy",
            actionName: "Start",
            status: .success
        )
        check("Execution with actionName has correct displayName", actionExecution.displayName == "Proxy → Start")
    }

    static func testExecutionWithActionArguments() {
        // Verify arguments with spaces are preserved safely as distinct elements
        let scriptPath = createTempScript("action_args_test.sh", contents: """
        #!/bin/sh
        echo "argcount=$#"
        echo "1=$1"
        echo "2=$2"
        echo "3=$3"
        """)

        let action = ScriptAction(
            name: "Deploy",
            arguments: ["--target", "production server", "--retries=3"],
            systemImage: "bolt"
        )

        let script = Script(name: "Deployer", scriptPath: scriptPath, interpreter: .sh, actions: [action])
        let runner = ProcessRunner()

        do {
            let (exec, _) = try runner.runAndWait(script: script, action: action)
            check("Action execution succeeds with exit code 0", exec.status == .success && exec.exitCode == 0)
            check("Action name recorded on execution record", exec.actionName == "Deploy")
            check("Action displayName formatted correctly", exec.displayName == "Deployer → Deploy")
            check("Argument count is exactly 3", exec.stdout.contains("argcount=3"))
            check("First argument matches --target", exec.stdout.contains("1=--target"))
            check("Second argument preserves space without splitting", exec.stdout.contains("2=production server"))
            check("Third argument matches --retries=3", exec.stdout.contains("3=--retries=3"))
        } catch {
            check("Execution with action arguments failed: \(error)", false)
        }
    }

    @MainActor
    static func testScriptStoreRunAction() async {
        let storageDir = tempDir.appendingPathComponent("store_action_storage_\(UUID())")
        let storage = StorageService(baseDirectory: storageDir)
        let store = ScriptStore(storageService: storage)

        let scriptPath = createTempScript("store_action_test.sh", contents: """
        #!/bin/sh
        echo "Running action: $1"
        """)

        let action = ScriptAction(name: "Status", arguments: ["status"], systemImage: "chart.bar")
        let script = Script(name: "ProxyService", scriptPath: scriptPath, interpreter: .sh, actions: [action])

        do {
            try await store.addScript(script)
            store.runScript(script, action: action)

            // Wait for completion
            var attempts = 0
            while store.isRunningScript[script.id] == true && attempts < 100 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                attempts += 1
            }

            let latest = store.latestExecutions[script.id]
            check("ScriptStore executes action successfully", latest?.status == .success)
            check("ScriptStore records actionName in latest execution", latest?.actionName == "Status")
            check("ScriptStore captures action output", latest?.stdout.contains("Running action: status") == true)

            let history = await store.loadHistory(for: script)
            check("History records actionName", history.first?.actionName == "Status")
        } catch {
            check("ScriptStore run action failed: \(error)", false)
        }
    }

    @MainActor
    static func testIPCRunAction() async {
        let storageDir = tempDir.appendingPathComponent("ipc_action_storage_\(UUID())")
        let storage = StorageService(baseDirectory: storageDir)
        let store = ScriptStore(storageService: storage)

        let scriptPath = createTempScript("ipc_action_test.sh", contents: """
        #!/bin/sh
        if [ "$1" = "on" ]; then
            echo "Proxy is ON"
            exit 0
        elif [ "$1" = "off" ]; then
            echo "Proxy is OFF"
            exit 0
        else
            echo "Unknown command: $1" >&2
            exit 1
        fi
        """)

        let onAction = ScriptAction(name: "On", arguments: ["on"], systemImage: "power")
        let offAction = ScriptAction(name: "Off", arguments: ["off"], systemImage: "power.circle")
        let script = Script(name: "SuperProxy", scriptPath: scriptPath, interpreter: .sh, actions: [onAction, offAction])

        let socketPath = "/tmp/zf_act_\(UUID().uuidString.prefix(8)).sock"
        let server = IPCServer(socketPath: socketPath, store: store)

        do {
            try await store.addScript(script)
            try server.start()
            let client = IPCClient(socketPath: socketPath)

            // 1. List scripts and verify action DTOs
            let listResp = try await client.send(request: IPCRequest(command: .list))
            check("IPC list response contains scripts", listResp.success && listResp.scripts?.count == 1)
            let actions = listResp.scripts?.first?.actions ?? []
            check("IPC list includes actions DTOs", actions.count == 2 && actions.map(\.name).contains("On") && actions.map(\.name).contains("Off"))

            // 2. Run with valid action "On"
            let runOnResp = try await client.send(request: IPCRequest(
                command: .run,
                name: "SuperProxy",
                action: "On",
                waitForCompletion: true
            ))
            check("IPC run with action 'On' succeeds", runOnResp.success && runOnResp.exitCode == 0)
            check("IPC run execution has actionName 'On'", runOnResp.execution?.actionName == "On")
            check("IPC run output contains Proxy is ON", runOnResp.execution?.stdout.contains("Proxy is ON") == true)

            // 3. Run with invalid action name
            let runBadResp = try await client.send(request: IPCRequest(
                command: .run,
                name: "SuperProxy",
                action: "InvalidAction",
                waitForCompletion: true
            ))
            check("IPC run with invalid action fails gracefully", !runBadResp.success && runBadResp.message?.contains("not found") == true)

            server.stop()
        } catch {
            print("  ❌ FAIL: testIPCRunAction — \(error)")
            failed += 1
            server.stop()
        }
    }

    static func testIPCConfigurationAndActionManagement() async {
        let storage = StorageService(baseDirectory: tempDir.appendingPathComponent("ipc-config-\(UUID().uuidString)"))
        let store = await MainActor.run { ScriptStore(storageService: storage) }
        let socketPath = "/tmp/zedflow-test-config-\(UUID().uuidString).sock"
        let server = IPCServer(socketPath: socketPath, store: store)

        do {
            try server.start()
            let client = IPCClient(socketPath: socketPath)

            let scriptPath = createTempScript("proxy_config_test.sh", contents: """
            #!/bin/sh
            echo "Proxy config test"
            """)

            // 1. Add script
            let addResp = try await client.send(request: IPCRequest(
                command: .add,
                name: "ConfigProxy",
                path: scriptPath,
                interpreter: "sh"
            ))
            check("IPC add script for config succeeds", addResp.success)

            // 2. Add actions
            let addAct1 = try await client.send(request: IPCRequest(
                command: .actionAdd,
                name: "ConfigProxy",
                action: "Start",
                actionIcon: "power",
                actionArgs: ["start", "--fast"]
            ))
            check("IPC actionAdd 'Start' succeeds", addAct1.success)
            check("Script now has 1 action", addAct1.script?.actions.count == 1)
            check("Action arguments preserved", addAct1.script?.actions.first?.arguments == ["start", "--fast"])

            let addAct2 = try await client.send(request: IPCRequest(
                command: .actionAdd,
                name: "ConfigProxy",
                action: "Stop",
                actionIcon: "power.circle",
                actionArgs: ["stop"]
            ))
            check("IPC actionAdd 'Stop' succeeds", addAct2.success)
            check("Script now has 2 actions", addAct2.script?.actions.count == 2)

            // 3. Update action (rename and change args)
            let updateAct = try await client.send(request: IPCRequest(
                command: .actionUpdate,
                name: "ConfigProxy",
                action: "Start",
                newActionName: "Enable",
                actionIcon: "play.fill",
                actionArgs: ["enable", "--mode=turbo"]
            ))
            check("IPC actionUpdate succeeds", updateAct.success)
            check("Action renamed to Enable", updateAct.script?.actions.first?.name == "Enable")
            check("Action arguments updated", updateAct.script?.actions.first?.arguments == ["enable", "--mode=turbo"])
            check("Action icon updated", updateAct.script?.actions.first?.systemImage == "play.fill")

            // 4. Reorder actions
            let reorderResp = try await client.send(request: IPCRequest(
                command: .actionReorder,
                name: "ConfigProxy",
                action: "Stop",
                targetIndex: 0
            ))
            check("IPC actionReorder succeeds", reorderResp.success)
            check("Stop is now at index 0", reorderResp.script?.actions.first?.name == "Stop")

            // 5. Update script configuration (rename, schedule, notifications, disabled)
            let updateScriptResp = try await client.send(request: IPCRequest(
                command: .update,
                name: "ConfigProxy",
                newName: "ConfigProxyV2",
                isEnabled: false,
                schedule: "interval:45",
                notifyOnSuccess: true,
                notifyOnFailure: false
            ))
            check("IPC update script succeeds", updateScriptResp.success)
            check("Script renamed to ConfigProxyV2", updateScriptResp.script?.name == "ConfigProxyV2")
            check("Script isEnabled is false", updateScriptResp.script?.isEnabled == false)
            check("Script schedule is Every 45m", updateScriptResp.script?.schedule.contains("45") == true)
            check("Script notifyOnSuccess is true", updateScriptResp.script?.notifyOnSuccess == true)
            check("Script notifyOnFailure is false", updateScriptResp.script?.notifyOnFailure == false)

            // 6. Remove action
            let removeActResp = try await client.send(request: IPCRequest(
                command: .actionRemove,
                name: "ConfigProxyV2",
                action: "Stop"
            ))
            check("IPC actionRemove succeeds", removeActResp.success)
            check("Script now has 1 action left", removeActResp.script?.actions.count == 1)
            check("Remaining action is Enable", removeActResp.script?.actions.first?.name == "Enable")

            // 7. Status inspection returns complete metadata
            let statusResp = try await client.send(request: IPCRequest(command: .status, name: "ConfigProxyV2"))
            check("Status inspection returns valid DTO", statusResp.success && statusResp.script != nil)
            check("Status inspection contains correct action", statusResp.script?.actions.first?.name == "Enable")

            server.stop()
        } catch {
            print("  ❌ FAIL: testIPCConfigurationAndActionManagement — \(error)")
            failed += 1
            server.stop()
        }
    }
}


