import Foundation

/// Resolves the user's interactive shell environment so that GUI-launched processes
/// can find interpreters installed via Homebrew, pyenv, nvm, cargo, etc.
public struct EnvironmentResolver: Sendable {

    /// Cached resolved environment. Computed once per app session.
    private static let _resolvedEnvironment: [String: String] = {
        resolveFromLoginShell()
    }()

    /// Returns the user's full shell environment, including PATH.
    public static var resolvedEnvironment: [String: String] {
        _resolvedEnvironment
    }

    /// Returns the resolved PATH string.
    public static var resolvedPATH: String {
        _resolvedEnvironment["PATH"] ?? fallbackPATH
    }

    /// A reasonable fallback PATH when we can't probe the user's shell.
    public static let fallbackPATH: String = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/bin",
        "/sbin",
    ].joined(separator: ":")

    // MARK: - Shell Probing

    /// Launches the user's default login shell with `-l -c env` to capture
    /// the fully initialized environment (with .zprofile, .bash_profile, etc.).
    private static func resolveFromLoginShell() -> [String: String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        // -l  = login shell (sources profile files)
        // -i  = interactive (sources rc files — needed for nvm, pyenv, etc.)
        // -c  = run command and exit
        process.arguments = ["-l", "-c", "env"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return buildFallbackEnvironment()
        }

        guard process.terminationStatus == 0 else {
            return buildFallbackEnvironment()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return buildFallbackEnvironment()
        }

        return parseEnvOutput(output)
    }

    /// Parses the output of `env` into a dictionary.
    /// Handles multi-line values by only splitting on the first `=`.
    static func parseEnvOutput(_ output: String) -> [String: String] {
        var env: [String: String] = [:]
        for line in output.components(separatedBy: "\n") {
            guard let eqIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<eqIndex])
            let value = String(line[line.index(after: eqIndex)...])
            guard !key.isEmpty else { continue }
            env[key] = value
        }

        // Always ensure common paths are present even if the user's
        // profile doesn't include them.
        if let path = env["PATH"] {
            env["PATH"] = augmentPATH(path)
        } else {
            env["PATH"] = fallbackPATH
        }

        return env
    }

    /// Ensures that critical system paths are present in PATH.
    private static func augmentPATH(_ existingPATH: String) -> String {
        let existing = Set(existingPATH.components(separatedBy: ":"))
        let critical = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        let missing = critical.filter { !existing.contains($0) }
        if missing.isEmpty {
            return existingPATH
        }
        return existingPATH + ":" + missing.joined(separator: ":")
    }

    private static func buildFallbackEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = fallbackPATH
        return env
    }
}
