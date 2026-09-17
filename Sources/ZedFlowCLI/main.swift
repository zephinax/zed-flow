import Foundation
import ZedFlowKit

@main
struct ZedFlowCLI {
    struct SimpleMessage: Codable {
        let success: Bool
        let message: String
    }

    static func main() async {
        let rawArgs = Array(CommandLine.arguments.dropFirst())

        guard let command = rawArgs.first else {
            printHelp()
            exit(0)
        }

        let isJSON = rawArgs.contains("--json")
        let argsWithoutJson = rawArgs.filter { $0 != "--json" }
        let nonFlagArgs = argsWithoutJson.filter { !$0.hasPrefix("--") }

        let client = IPCClient()

        do {
            switch command.lowercased() {
            case "help", "--help", "-h":
                printHelp()
                exit(0)

            case "ping":
                let response = try await client.send(request: IPCRequest(command: .ping))
                if isJSON {
                    printJSON(SimpleMessage(success: true, message: response.message ?? "pong"))
                } else {
                    print(response.message ?? "pong")
                }
                exit(0)

            // MARK: - Discovery & Inspection

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

            case "status", "inspect", "get", "show":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow status <name> [--json]", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let response = try await client.send(request: IPCRequest(command: .status, name: name))
                guard response.success, let script = response.script else {
                    printError(response.message ?? "Script '\(name)' not found.", isJSON: isJSON)
                    exit(1)
                }

                if isJSON {
                    printJSON(script)
                } else {
                    printStatus(script, execution: response.execution)
                }
                exit(0)

            // MARK: - Registration & Script Configuration

            case "add":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow add <path> [--name <name>] [--interpreter <type>] [--schedule <spec>]", isJSON: isJSON)
                    exit(64)
                }
                let path = nonFlagArgs[1]
                let name = parseFlagValue("--name", in: argsWithoutJson)
                let interpreter = parseFlagValue("--interpreter", in: argsWithoutJson)
                let customPath = parseFlagValue("--custom", in: argsWithoutJson)
                let schedule = parseFlagValue("--schedule", in: argsWithoutJson)

                let request = IPCRequest(
                    command: .add,
                    name: name,
                    path: path,
                    interpreter: interpreter,
                    customInterpreterPath: customPath,
                    schedule: schedule
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

            case "remove", "rm", "delete":
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

            case "rename":
                guard nonFlagArgs.count >= 3 else {
                    printError("Usage: zedflow rename <old-name> <new-name>", isJSON: isJSON)
                    exit(64)
                }
                let oldName = nonFlagArgs[1]
                let newName = nonFlagArgs[2]
                let request = IPCRequest(command: .update, name: oldName, newName: newName)
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Script renamed successfully.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to rename script.", isJSON: isJSON)
                    exit(1)
                }

            case "enable":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow enable <name>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let request = IPCRequest(command: .update, name: name, isEnabled: true)
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Script enabled.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to enable script.", isJSON: isJSON)
                    exit(1)
                }

            case "disable":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow disable <name>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let request = IPCRequest(command: .update, name: name, isEnabled: false)
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Script disabled.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to disable script.", isJSON: isJSON)
                    exit(1)
                }

            case "schedule":
                guard nonFlagArgs.count >= 3 else {
                    printError("Usage: zedflow schedule <name> <manual | interval <minutes> | daily <HH:mm>>", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let scheduleType = nonFlagArgs[2].lowercased()
                let scheduleSpec: String
                if scheduleType == "manual" {
                    scheduleSpec = "manual"
                } else if scheduleType == "interval" {
                    guard nonFlagArgs.count >= 4 else {
                        printError("Usage: zedflow schedule <name> interval <minutes>", isJSON: isJSON)
                        exit(64)
                    }
                    scheduleSpec = "interval:\(nonFlagArgs[3])"
                } else if scheduleType == "daily" {
                    guard nonFlagArgs.count >= 4 else {
                        printError("Usage: zedflow schedule <name> daily <HH:mm>", isJSON: isJSON)
                        exit(64)
                    }
                    scheduleSpec = "daily:\(nonFlagArgs[3])"
                } else {
                    scheduleSpec = scheduleType
                }

                let request = IPCRequest(command: .update, name: name, schedule: scheduleSpec)
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Schedule updated.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to update schedule.", isJSON: isJSON)
                    exit(1)
                }

            case "notify":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow notify <name> [--success <true|false>] [--failure <true|false>]", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let notifySuccess = parseBoolFlagValue("--success", in: argsWithoutJson)
                let notifyFailure = parseBoolFlagValue("--failure", in: argsWithoutJson)

                let request = IPCRequest(
                    command: .update,
                    name: name,
                    notifyOnSuccess: notifySuccess,
                    notifyOnFailure: notifyFailure
                )
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Notification settings updated.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to update notification settings.", isJSON: isJSON)
                    exit(1)
                }

            case "edit", "update", "config", "set":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow edit <name> [options]", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let newName = parseFlagValue("--name", in: argsWithoutJson)
                let path = parseFlagValue("--path", in: argsWithoutJson)
                let interpreter = parseFlagValue("--interpreter", in: argsWithoutJson)
                let customPath = parseFlagValue("--custom", in: argsWithoutJson)
                let schedule = parseFlagValue("--schedule", in: argsWithoutJson)
                let isEnabled: Bool? = argsWithoutJson.contains("--enable") ? true : (argsWithoutJson.contains("--disable") ? false : nil)
                let notifySuccess = parseBoolFlagValue("--notify-success", in: argsWithoutJson)
                let notifyFailure = parseBoolFlagValue("--notify-failure", in: argsWithoutJson)

                let request = IPCRequest(
                    command: .update,
                    name: name,
                    newName: newName,
                    path: path,
                    interpreter: interpreter,
                    customInterpreterPath: customPath,
                    isEnabled: isEnabled,
                    schedule: schedule,
                    notifyOnSuccess: notifySuccess,
                    notifyOnFailure: notifyFailure
                )
                let response = try await client.send(request: request)
                if response.success {
                    if isJSON, let script = response.script {
                        printJSON(script)
                    } else {
                        print(response.message ?? "Script updated successfully.")
                    }
                    exit(0)
                } else {
                    printError(response.message ?? "Failed to update script.", isJSON: isJSON)
                    exit(1)
                }

            // MARK: - Action Management

            case "action", "actions":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow action <list | add | update | remove | reorder> [arguments]", isJSON: isJSON)
                    exit(64)
                }
                let subAction = nonFlagArgs[1].lowercased()

                switch subAction {
                case "list", "ls":
                    guard nonFlagArgs.count >= 3 else {
                        printError("Usage: zedflow action list <script>", isJSON: isJSON)
                        exit(64)
                    }
                    let scriptName = nonFlagArgs[2]
                    let response = try await client.send(request: IPCRequest(command: .status, name: scriptName))
                    guard response.success, let script = response.script else {
                        printError(response.message ?? "Script '\(scriptName)' not found.", isJSON: isJSON)
                        exit(1)
                    }

                    if isJSON {
                        printJSON(script.actions)
                    } else if script.actions.isEmpty {
                        print("No actions configured for '\(script.name)'.")
                    } else {
                        printActionList(script.actions, scriptName: script.name)
                    }
                    exit(0)

                case "add":
                    guard nonFlagArgs.count >= 4 else {
                        printError("Usage: zedflow action add <script> <action-name> [--icon <icon>] [--args <arg1> <arg2>...]", isJSON: isJSON)
                        exit(64)
                    }
                    let scriptName = nonFlagArgs[2]
                    let actionName = nonFlagArgs[3]
                    let icon = parseFlagValue("--icon", in: argsWithoutJson) ?? "bolt"
                    let actionArgs = parseArgsList(after: "--args", in: argsWithoutJson)

                    let request = IPCRequest(
                        command: .actionAdd,
                        name: scriptName,
                        action: actionName,
                        actionIcon: icon,
                        actionArgs: actionArgs
                    )
                    let response = try await client.send(request: request)
                    if response.success {
                        if isJSON, let script = response.script {
                            printJSON(script)
                        } else {
                            print(response.message ?? "Action added.")
                        }
                        exit(0)
                    } else {
                        printError(response.message ?? "Failed to add action.", isJSON: isJSON)
                        exit(1)
                    }

                case "update", "edit":
                    guard nonFlagArgs.count >= 4 else {
                        printError("Usage: zedflow action update <script> <action-name> [--name <new-name>] [--icon <icon>] [--args <arg1> <arg2>...]", isJSON: isJSON)
                        exit(64)
                    }
                    let scriptName = nonFlagArgs[2]
                    let actionName = nonFlagArgs[3]
                    let newName = parseFlagValue("--name", in: argsWithoutJson)
                    let newIcon = parseFlagValue("--icon", in: argsWithoutJson)
                    let actionArgs = parseArgsList(after: "--args", in: argsWithoutJson)

                    let request = IPCRequest(
                        command: .actionUpdate,
                        name: scriptName,
                        newName: nil,
                        action: actionName,
                        newActionName: newName,
                        actionIcon: newIcon,
                        actionArgs: actionArgs
                    )
                    let response = try await client.send(request: request)
                    if response.success {
                        if isJSON, let script = response.script {
                            printJSON(script)
                        } else {
                            print(response.message ?? "Action updated.")
                        }
                        exit(0)
                    } else {
                        printError(response.message ?? "Failed to update action.", isJSON: isJSON)
                        exit(1)
                    }

                case "remove", "rm", "delete":
                    guard nonFlagArgs.count >= 4 else {
                        printError("Usage: zedflow action remove <script> <action-name>", isJSON: isJSON)
                        exit(64)
                    }
                    let scriptName = nonFlagArgs[2]
                    let actionName = nonFlagArgs[3]
                    let request = IPCRequest(command: .actionRemove, name: scriptName, action: actionName)
                    let response = try await client.send(request: request)
                    if response.success {
                        if isJSON, let script = response.script {
                            printJSON(script)
                        } else {
                            print(response.message ?? "Action removed.")
                        }
                        exit(0)
                    } else {
                        printError(response.message ?? "Failed to remove action.", isJSON: isJSON)
                        exit(1)
                    }

                case "reorder", "move":
                    guard nonFlagArgs.count >= 5, let targetPosition = Int(nonFlagArgs[4]) else {
                        printError("Usage: zedflow action reorder <script> <action-name> <1-based-position>", isJSON: isJSON)
                        exit(64)
                    }
                    let scriptName = nonFlagArgs[2]
                    let actionName = nonFlagArgs[3]
                    let targetIndex = max(0, targetPosition - 1) // convert 1-based CLI to 0-based index

                    let request = IPCRequest(
                        command: .actionReorder,
                        name: scriptName,
                        action: actionName,
                        targetIndex: targetIndex
                    )
                    let response = try await client.send(request: request)
                    if response.success {
                        if isJSON, let script = response.script {
                            printJSON(script)
                        } else {
                            print(response.message ?? "Action reordered.")
                        }
                        exit(0)
                    } else {
                        printError(response.message ?? "Failed to reorder action.", isJSON: isJSON)
                        exit(1)
                    }

                default:
                    printError("Unknown action command '\(subAction)'. Valid subcommands: list, add, update, remove, reorder.", isJSON: isJSON)
                    exit(64)
                }

            // MARK: - Execution (Secondary Capability)

            case "run":
                guard nonFlagArgs.count >= 2 else {
                    printError("Usage: zedflow run <name> [action] [--async]", isJSON: isJSON)
                    exit(64)
                }
                let name = nonFlagArgs[1]
                let actionName = parseFlagValue("--action", in: argsWithoutJson) ?? (nonFlagArgs.count >= 3 ? nonFlagArgs[2] : nil)
                let isAsync = rawArgs.contains("--async")

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

    // MARK: - Flag Parsing Helpers

    static func parseFlagValue(_ flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }
        let val = args[index + 1]
        return val.hasPrefix("--") ? nil : val
    }

    static func parseBoolFlagValue(_ flag: String, in args: [String]) -> Bool? {
        guard let val = parseFlagValue(flag, in: args)?.lowercased() else { return nil }
        if val == "true" || val == "1" || val == "yes" { return true }
        if val == "false" || val == "0" || val == "no" { return false }
        return nil
    }

    static func parseArgsList(after flag: String, in args: [String]) -> [String]? {
        guard let index = args.firstIndex(of: flag) else { return nil }
        let knownCLIFlags: Set<String> = ["--icon", "--name", "--json", "--interpreter", "--schedule", "--custom", "--enable", "--disable", "--success", "--failure"]
        var collected: [String] = []
        for i in (index + 1)..<args.count {
            let item = args[i]
            if knownCLIFlags.contains(item) { break }
            collected.append(item)
        }
        return collected
    }

    // MARK: - Help & Formatting

    static func printHelp() {
        let help = """
        ZedFlow CLI - Configuration & Management Interface for ZedFlow

        The primary purpose of this CLI is automated and interactive configuration
        of scripts, actions, schedules, and settings in ZedFlow.

        USAGE:
          zedflow <command> [arguments] [options]

        DISCOVERY & INSPECTION:
          list, ls                     List all configured scripts, actions, schedules
          status <name>                Inspect complete configuration and status of a script
          inspect <name>               Alias for status
          ping                         Check connection to ZedFlow.app

        SCRIPT CONFIGURATION:
          add <path> [options]         Register a script in ZedFlow
                                       Options: [--name <name>] [--interpreter <type>] [--schedule <spec>]
          remove, rm <name>            Remove a script from ZedFlow
          rename <old> <new>           Rename a script
          enable <name>                Enable a script
          disable <name>               Disable a script
          schedule <name> <spec>       Configure schedule: manual | interval <mins> | daily <HH:mm>
          notify <name> [options]      Configure notifications: [--success <true|false>] [--failure <true|false>]
          edit <name> [options]        Update script configuration:
                                       [--name <new>] [--path <path>] [--interpreter <type>]
                                       [--custom <path>] [--enable|--disable] [--schedule <spec>]
                                       [--notify-success <bool>] [--notify-failure <bool>]

        ACTION MANAGEMENT:
          action list <script>         List all actions defined on a script
          action add <script> <name>   Add an action with flags/arguments and SF Symbol icon
                                       Options: [--icon <icon>] [--args <arg1> <arg2>...]
          action update <script> <act> Edit action name, icon, or arguments
                                       Options: [--name <new>] [--icon <icon>] [--args <arg1>...]
          action remove <script> <act> Remove an action from a script
          action reorder <script> <act> <position>
                                       Move an action to a 1-based position

        EXECUTION & HISTORY:
          run <name> [action]          Run a script or specific action and stream output
                                       Options: [--action <action>] [--async]
          stop <name>                  Stop a running script
          history <name>               Show previous execution history

        GLOBAL OPTIONS:
          --json                       Output in machine-readable JSON format for AI agents
          --help, -h                   Show this help information

        EXIT CODES:
          0                            Success (or executed script exit code 0)
          1                            Operation failed / general error
          2                            ZedFlow.app is not running
          64                           Usage error / invalid arguments
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

        var colWidths = headers.map { $0.count }
        for row in rows {
            for (i, cell) in row.enumerated() {
                colWidths[i] = max(colWidths[i], cell.count)
            }
        }

        func formatRow(_ cells: [String]) -> String {
            cells.enumerated().map { i, cell in
                cell.padding(toLength: colWidths[i], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }

        print(formatRow(headers))
        print(colWidths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
        for (idx, s) in scripts.enumerated() {
            print(formatRow(rows[idx]))
            if !s.actions.isEmpty {
                let actionList = s.actions.map { act in
                    let args = act.arguments.isEmpty ? "" : " [\(act.arguments.joined(separator: " "))]"
                    return "\(act.name)\(args)"
                }.joined(separator: ", ")
                print("  ↳ Actions: \(actionList)")
            }
        }
    }

    static func printActionList(_ actions: [ScriptActionDTO], scriptName: String) {
        print("Actions for '\(scriptName)':")
        for (i, act) in actions.enumerated() {
            let args = act.arguments.isEmpty ? "(no arguments)" : act.arguments.map { "\"\($0)\"" }.joined(separator: " ")
            print("  \(i + 1). \(act.name) (icon: \(act.systemImage))")
            print("     Arguments: \(args)")
        }
    }

    static func printStatus(_ script: ScriptDTO, execution: ScriptExecution?) {
        let status = script.isRunning ? "running" : (script.lastStatus?.rawValue ?? "idle")
        print("Name:           \(script.name)")
        print("Status:         \(status)")
        print("Path:           \(script.path)")
        print("Runtime:        \(script.interpreter)\(script.customInterpreterPath.map { " (\($0))" } ?? "")")
        print("Schedule:       \(script.schedule)")
        print("Enabled:        \(script.isEnabled ? "yes" : "no")")
        print("Notifications:  Success: \(script.notifyOnSuccess ? "yes" : "no"), Failure: \(script.notifyOnFailure ? "yes" : "no")")

        if script.actions.isEmpty {
            print("Actions:        (none)")
        } else {
            let list = script.actions.enumerated().map { i, a in
                let args = a.arguments.isEmpty ? "" : " [\(a.arguments.joined(separator: " "))]"
                return "\(a.name)\(args)"
            }.joined(separator: ", ")
            print("Actions:        \(list)")
        }

        if let exec = execution {
            var details = "\(exec.startTime)"
            if let act = exec.actionName {
                details += " (action: \(act))"
            }
            if let dur = exec.duration {
                details += String(format: " (duration: %.2fs", dur)
            }
            if let code = exec.exitCode {
                details += ", exit: \(code))"
            } else {
                details += ")"
            }
            print("Last Run:       \(details)")
        }
    }

    static func printHistoryTable(_ history: [ScriptExecution]) {
        let headers = ["DATE", "STATUS", "DURATION", "EXIT"]
        var rows: [[String]] = []
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        for h in history {
            var dateStr = formatter.string(from: h.startTime)
            if let act = h.actionName, !act.isEmpty {
                dateStr += " (\(act))"
            }
            let status = h.status.rawValue
            let duration = h.duration.map { String(format: "%.2fs", $0) } ?? "-"
            let exit = h.exitCode.map { "\($0)" } ?? "-"
            rows.append([dateStr, status, duration, exit])
        }

        var colWidths = headers.map { $0.count }
        for row in rows {
            for (i, cell) in row.enumerated() {
                colWidths[i] = max(colWidths[i], cell.count)
            }
        }

        func formatRow(_ cells: [String]) -> String {
            cells.enumerated().map { i, cell in
                cell.padding(toLength: colWidths[i], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }

        print(formatRow(headers))
        print(colWidths.map { String(repeating: "-", count: $0) }.joined(separator: "  "))
        for r in rows {
            print(formatRow(r))
        }
    }
}
