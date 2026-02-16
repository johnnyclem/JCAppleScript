import Foundation

/// Core engine for executing AppleScript commands via osascript.
///
/// This engine uses the `osascript` command-line tool under the hood, which means
/// it works without requiring AppKit or entitlements for Apple Events. The trade-off
/// is that execution happens in a subprocess rather than in-process.
public final class AppleScriptEngine: Sendable {

    /// Default shared instance.
    public static let shared = AppleScriptEngine()

    /// Default timeout for script execution in seconds.
    public let defaultTimeout: TimeInterval

    public init(defaultTimeout: TimeInterval = 30) {
        self.defaultTimeout = defaultTimeout
    }

    // MARK: - Execute raw AppleScript source

    /// Execute an AppleScript command string.
    ///
    /// - Parameters:
    ///   - source: The AppleScript source code to execute.
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func execute(_ source: String, timeout: TimeInterval? = nil) throws -> ScriptResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let effectiveTimeout = timeout ?? defaultTimeout
        let deadline = Date().addingTimeInterval(effectiveTimeout)

        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                throw ScriptError.timeout
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            throw ScriptError.processExecutionFailed(exitCode: process.terminationStatus, stderr: stderr)
        }

        return ScriptResult(output: stdout)
    }

    // MARK: - Execute with variable substitution

    /// Execute an AppleScript template with variable substitution.
    ///
    /// Placeholders in the source (`$0`, `$1`, `$2`, etc.) are replaced with the
    /// corresponding values from the `variables` array.
    ///
    /// - Parameters:
    ///   - source: AppleScript source with `$N` placeholders.
    ///   - variables: Values to substitute for placeholders.
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func execute(_ source: String, variables: [String], timeout: TimeInterval? = nil) throws -> ScriptResult {
        let resolved = substituteVariables(in: source, with: variables)
        return try execute(resolved, timeout: timeout)
    }

    // MARK: - Execute script file

    /// Execute an AppleScript file (.scpt or .applescript).
    ///
    /// - Parameters:
    ///   - path: Path to the script file.
    ///   - variables: Optional variables for placeholder substitution.
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func executeFile(at path: String, variables: [String] = [], timeout: TimeInterval? = nil) throws -> ScriptResult {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ScriptError.fileNotFound(path: path)
        }

        if variables.isEmpty {
            // Run the file directly via osascript
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [path]
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()

            let effectiveTimeout = timeout ?? defaultTimeout
            let deadline = Date().addingTimeInterval(effectiveTimeout)

            while process.isRunning {
                if Date() > deadline {
                    process.terminate()
                    throw ScriptError.timeout
                }
                Thread.sleep(forTimeInterval: 0.05)
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus != 0 {
                throw ScriptError.processExecutionFailed(exitCode: process.terminationStatus, stderr: stderr)
            }

            return ScriptResult(output: stdout)
        } else {
            // Read file, substitute variables, then execute
            guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
                throw ScriptError.invalidScriptSource
            }
            return try execute(source, variables: variables, timeout: timeout)
        }
    }

    // MARK: - Tell application

    /// Send a command to an application using AppleScript's `tell` block.
    ///
    /// - Parameters:
    ///   - application: The name of the target application.
    ///   - command: The AppleScript command(s) to send.
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func tell(application: String, command: String, timeout: TimeInterval? = nil) throws -> ScriptResult {
        let source = """
        tell application "\(application)"
            \(command)
        end tell
        """
        return try execute(source, timeout: timeout)
    }

    // MARK: - List running applications

    /// Get a list of currently running applications.
    public func listRunningApplications() throws -> [String] {
        let source = """
        tell application "System Events"
            get name of every process whose background only is false
        end tell
        """
        let result = try execute(source)
        return result.output.components(separatedBy: ", ")
    }

    // MARK: - Private helpers

    private func substituteVariables(in source: String, with variables: [String]) -> String {
        var result = source
        for (index, value) in variables.enumerated() {
            let placeholder = "$\(index)"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return result
    }
}
