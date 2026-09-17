import Foundation
import ZedFlowKit

@main
struct ZedFlowCLI {
    struct SimpleMessage: Codable {
        let success: Bool
        let message: String
    }

    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())

        guard let command = args.first else {
            printHelp()
            exit(0)
        }

        let isJSON = args.contains("--json")
        let nonFlagArgs = args.filter { !$0.hasPrefix("--") }

        let client = IPCClient()

        do {
            switch command.lowercased() {
            case "help", "--help", "-h":
                printHelp()
                exit(0)

            case "ping":
                let response = try await client.send(request: IPCRequest(command: .ping))
                print(response.message ?? "pong")
                exit(0)

            case "list", "ls":
                let response = try await client.send(request: IPCRequest(command: .list))
                guard response.success, let scripts = response.scripts else {
                    printError(response.message ?? "Failed to list scripts", isJSON: isJSON)
                    exit(1)
                }

                if isJSON {
                    printJSON(scripts)
                } else if scripts.isEmpty {
                    print("No scripts configured in ZedFlow.")
                } else {
                    printTable(scripts)
                }
                exit(0)

            case "add":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow add <path> [--name <name>] [--interpreter <type>]", isJSON: isJSON)
                    exit(64)
                }
                let path = nonFlagArgs[1]
                let name = parseFlagValue("--name", in: args)
                let interpreter = parseFlagValue("--interpreter", in: args)

                let request = IPCRequest(
                    command: .add,
                    name: name,
                    path: path,
                    interpreter: interpreter
                )
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Script added successfully.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to add script.", isJSON: isJSON)
                    exit(1)
                }

            case "remove", "rm":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow remove <name>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let response = try await client.send(request: IPCRequest(command: .remove, name: name))
                if response.success {
                    if isJSON {
                        printJSON(SimpleMessage(success: true, message: response.message ?? "Script removed."))
                    } else {
                        print(response.message ?? "Script removed.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to remove script.", isJSON: isJSON)
                    exit(1)
                }

            case "run":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow run <name> [action] [--async]", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let actionName = parseFlagValue("--action", in: args) ?? (nonFlagArgs.count >= 3 ? nonFlagArgs[2] : nil)
                let isAsync = args.contains("--async")

                let request = IPCRequest(
                    command: .run,
                    name: name,
                    action: actionName,
                    waitForCompletion: !isAsync
                )
                let response = try await client.send(request: request)

                if isAsync {
                    if isJSON {
                        printJSON(SimpleMessage(success: response.success, message: response.message ?? "Script started."))
                    } else {
                        print(response.message ?? "Script started.")
                    }
                    exit(response.success ? 0 : 1)
                }

                // Synchronous run output
                if isJSON {
                    if let execution = response.execution {
                        printJSON(execution)
                    } else {
                        printJSON(SimpleMessage(success: response.success, message: response.message ?? "Script finished."))
                    }
                    exit(response.exitCode ?? (response.success ? 0 : 1))
                } else {
                    if let exec = response.execution {
                        if !exec.stdout.isEmpty {
                            FileHandle.standardOutput.write(exec.stdout.data(using: .utf8) ?? Data())
                        }
                        if !exec.stderr.isEmpty {
                            FileHandle.standardError.write(exec.stderr.data(using: .utf8) ?? Data())
                        }
                        exit(exec.exitCode ?? (exec.status == .success ? 0 : 1))
                    } else {
                        if response.success {
                            print(response.message ?? "Completed")
                            exit(0)
                        } else {
                            printError(response.message ?? "Script failed", isJSON: false)
                            exit(response.exitCode ?? 1)
                        }
                    }
                }

            case "stop":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow stop <name>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let response = try await client.send(request: IPCRequest(command: .stop, name: name))
                if response.success {
                    if isJSON {
                        printJSON(SimpleMessage(success: true, message: response.message ?? "Stopped."))
                    } else {
                        print(response.message ?? "Stopped.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to stop script.", isJSON: isJSON)
                    exit(1)
                }

            case "status":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow status <name>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let response = try await client.send(request: IPCRequest(command: .status, name: name))
                guard response.success, let script = response.script else {
                    printError(response.message ?? "Script not found.", isJSON: isJSON)
                    exit(1)
                }

                if isJSON {
                    printJSON(script)
                } else {
                    printStatus(script, execution: response.execution)
                }
                exit(0)

            case "history":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow history <name>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let response = try await client.send(request: IPCRequest(command: .history, name: name))
                guard response.success, let history = response.history else {
                    printError(response.message ?? "Failed to load history.", isJSON: isJSON)
                    exit(1)
                }

                if isJSON {
                    printJSON(history)
                } else if history.isEmpty {
                    print("No execution history recorded for '\(name)'.")
                } else {
                    printHistoryTable(history)
                }
                exit(0)

            default:
                printError("Unknown command '\(command)'. Run 'zedflow help' for usage.", isJSON: isJSON)
                exit(64)
            }
        } catch let error as IPCError {
            switch error {
            case .appNotRunning:
                printError("ZedFlow is not running. Please launch ZedFlow.app first.", isJSON: isJSON)
                exit(2)
            default:
                printError(error.localizedDescription, isJSON: isJSON)
                exit(1)
            }
        } catch {
            printError(error.localizedDescription, isJSON: isJSON)
            exit(1)
        }
    }

    // MARK: - Helpers

    static func parseFlagValue(_ flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }
        let val = args[index + 1]
        return val.hasPrefix("--") ? nil : val
    }

    static func printHelp() {
        let help = """
        ZedFlow CLI - Control and run local scripts via ZedFlow

        USAGE:
          zedflow <command> [arguments] [options]

        COMMANDS:
          list                 List all configured scripts and their actions
          add <path>           Add a script reference to ZedFlow
                               Options: [--name <name>] [--interpreter <auto|zsh|bash|sh|python3>]
          remove <name>        Remove a script from ZedFlow
          run <name> [action]  Run a script or specific action and return its output and exit code
                               Options: [--action <action>] [--async]
          stop <name>          Stop a running script
          status <name>        Show the current status and latest execution of a script
          history <name>       Show previous execution records of a script
          ping                 Check connection to ZedFlow.app

        GLOBAL OPTIONS:
          --json               Output response in machine-readable JSON format
          --help, -h           Show this help information

        EXIT CODES:
          0                    Success (or script exit code 0)
          1                    Command or script failure
          2                    ZedFlow.app is not running
          64                   Invalid arguments / usage error
        """
        print(help)
    }

    static func printError(_ message: String, isJSON: Bool) {
        if isJSON {
            let errorObj = ["error": message, "success": "false"]
            if let data = try? JSONSerialization.data(withJSONObject: errorObj, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                FileHandle.standardError.write(str.data(using: .utf8)!)
                FileHandle.standardError.write("\n".data(using: .utf8)!)
                return
            }
        }
        FileHandle.standardError.write("Error: \(message)\n".data(using: .utf8)!)
    }

    static func printJSON<T: Encodable>(_ object: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(object), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    static func printTable(_ scripts: [ScriptDTO]) {
        let headers = ["NAME", "STATUS", "SCHEDULE", "PATH"]
        var rows: [[String]] = []
        for s in scripts {
            let status = s.isRunning ? "running" : (s.lastStatus?.rawValue ?? "idle")
            rows.append([s.name, status, s.schedule, s.path])
        }

        var colWidths = [4, 6, 8, 4]
        for row in rows {
            for (i, val) in row.enumerated() {
                colWidths[i] = max(colWidths[i], val.count)
            }
        }

        let formatRow = { (items: [String]) -> String in
            items.enumerated().map { i, val in
                val.padding(toLength: colWidths[i] + 2, withPad: " ", startingAt: 0)
            }.joined()
        }

        print(formatRow(headers))
        print(String(repeating: "-", count: colWidths.reduce(0, +) + (colWidths.count * 2)))
        for (i, row) in rows.enumerated() {
            print(formatRow(row))
            let s = scripts[i]
            if !s.actions.isEmpty {
                let actionDescs = s.actions.map { action in
                    let argsStr = action.arguments.isEmpty ? "" : " [\(action.arguments.joined(separator: " "))]"
                    return "\(action.name)\(argsStr)"
                }.joined(separator: ", ")
                print("  ↳ Actions: \(actionDescs)")
            }
        }
    }

    static func printStatus(_ script: ScriptDTO, execution: ScriptExecution?) {
        let status = script.isRunning ? "running" : (script.lastStatus?.rawValue ?? "idle")
        print("Name:       \(script.name)")
        print("Status:     \(status)")
        print("Path:       \(script.path)")
        print("Runtime:    \(script.interpreter)")
        print("Schedule:   \(script.schedule)")
        print("Enabled:    \(script.isEnabled ? "yes" : "no")")

        if !script.actions.isEmpty {
            let actionList = script.actions.map { action in
                let argsStr = action.arguments.isEmpty ? "" : " [\(action.arguments.joined(separator: " "))]"
                return "\(action.name)\(argsStr)"
            }.joined(separator: ", ")
            print("Actions:    \(actionList)")
        }

        if let exec = execution {
            let durationText: String
            if let d = exec.duration {
                durationText = String(format: "%.2fs", d)
            } else {
                durationText = "—"
            }
            let exitText = exec.exitCode.map { "\($0)" } ?? "—"
            var actionInfo = ""
            if let action = exec.actionName, !action.isEmpty {
                actionInfo = " (action: \(action))"
            }
            print("Last Run:   \(exec.startTime)\(actionInfo) (duration: \(durationText), exit: \(exitText))")
        }
    }

    static func printHistoryTable(_ history: [ScriptExecution]) {
        let headers = ["DATE", "STATUS", "DURATION", "EXIT"]
        var rows: [[String]] = []
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .medium

        for h in history {
            var dateStr = df.string(from: h.startTime)
            if let action = h.actionName, !action.isEmpty {
                dateStr += " (\(action))"
            }
            let durationStr = h.duration.map { String(format: "%.2fs", $0) } ?? "—"
            let exitStr = h.exitCode.map { "\($0)" } ?? "—"
            rows.append([dateStr, h.status.rawValue, durationStr, exitStr])
        }

        var colWidths = [4, 6, 8, 4]
        for row in rows {
            for (i, val) in row.enumerated() {
                colWidths[i] = max(colWidths[i], val.count)
            }
        }

        let formatRow = { (items: [String]) -> String in
            items.enumerated().map { i, val in
                val.padding(toLength: colWidths[i] + 2, withPad: " ", startingAt: 0)
            }.joined()
        }

        print(formatRow(headers))
        print(String(repeating: "-", count: colWidths.reduce(0, +) + (colWidths.count * 2)))
        for row in rows {
            print(formatRow(row))
        }
    }
}
