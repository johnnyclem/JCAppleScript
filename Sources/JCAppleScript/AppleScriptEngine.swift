import Foundation
#if canImport(Glibc)
import Glibc
#endif

/// The OSA language a script is written in.
public enum ScriptLanguage: String, Sendable, Codable, CaseIterable {
    /// Classic AppleScript.
    case appleScript = "AppleScript"
    /// JavaScript for Automation (JXA).
    case javaScript = "JavaScript"
}

/// Core engine for executing AppleScript (and JXA) via osascript.
///
/// This engine uses the `osascript` command-line tool under the hood, which means
/// it works without requiring AppKit or entitlements for Apple Events. The trade-off
/// is that execution happens in a subprocess rather than in-process.
public final class AppleScriptEngine: Sendable {

    /// Default shared instance.
    public static let shared = AppleScriptEngine()

    /// Default timeout for script execution in seconds.
    public let defaultTimeout: TimeInterval

    private static let osascriptPath = "/usr/bin/osascript"
    private static let osacompilePath = "/usr/bin/osacompile"

    /// Grace period between SIGTERM and SIGKILL when a script times out.
    private static let terminationGracePeriod: TimeInterval = 2

    public init(defaultTimeout: TimeInterval = 30) {
        self.defaultTimeout = defaultTimeout
    }

    // MARK: - Execute raw script source

    /// Execute an AppleScript (or JXA) command string.
    ///
    /// - Parameters:
    ///   - source: The script source code to execute.
    ///   - language: The OSA language of the source (default: AppleScript).
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func execute(
        _ source: String,
        language: ScriptLanguage = .appleScript,
        timeout: TimeInterval? = nil
    ) throws -> ScriptResult {
        try runOSAProcess(
            executable: Self.osascriptPath,
            arguments: ["-l", language.rawValue, "-e", source],
            timeout: timeout ?? defaultTimeout
        )
    }

    // MARK: - Execute with variable substitution

    /// Execute an AppleScript template with variable substitution.
    ///
    /// Placeholders in the source (`$0`, `$1`, `$2`, etc.) are replaced with the
    /// corresponding values from the `variables` array. Values are substituted
    /// literally; if a placeholder sits inside a quoted AppleScript string,
    /// pass the value through ``AppleScriptString/escape(_:)`` first (or place
    /// the whole placeholder outside quotes and pass
    /// ``AppleScriptString/quoted(_:)``) so untrusted input cannot inject
    /// script.
    ///
    /// - Parameters:
    ///   - source: AppleScript source with `$N` placeholders.
    ///   - variables: Values to substitute for placeholders.
    ///   - language: The OSA language of the source (default: AppleScript).
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func execute(
        _ source: String,
        variables: [String],
        language: ScriptLanguage = .appleScript,
        timeout: TimeInterval? = nil
    ) throws -> ScriptResult {
        let resolved = Self.substituteVariables(in: source, with: variables)
        return try execute(resolved, language: language, timeout: timeout)
    }

    // MARK: - Execute script file

    /// Execute a script file (.scpt, .applescript, or .js for JXA).
    ///
    /// - Parameters:
    ///   - path: Path to the script file.
    ///   - variables: Optional variables for placeholder substitution.
    ///   - language: The OSA language. When nil, it is inferred from the file
    ///     extension (`.js` / `.jxa` run as JavaScript, everything else as
    ///     AppleScript).
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func executeFile(
        at path: String,
        variables: [String] = [],
        language: ScriptLanguage? = nil,
        timeout: TimeInterval? = nil
    ) throws -> ScriptResult {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ScriptError.fileNotFound(path: path)
        }

        let effectiveLanguage = language ?? Self.inferLanguage(fromPath: path)

        if variables.isEmpty {
            // Run the file directly via osascript. Compiled scripts (.scpt)
            // carry their own language, so only pass -l for plain source.
            var arguments: [String] = []
            if !path.hasSuffix(".scpt") && !path.hasSuffix(".scptd") {
                arguments += ["-l", effectiveLanguage.rawValue]
            }
            arguments.append(path)
            return try runOSAProcess(
                executable: Self.osascriptPath,
                arguments: arguments,
                timeout: timeout ?? defaultTimeout
            )
        } else {
            // Read file, substitute variables, then execute
            guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
                throw ScriptError.invalidScriptSource
            }
            return try execute(source, variables: variables, language: effectiveLanguage, timeout: timeout)
        }
    }

    // MARK: - Tell application

    /// Send a command to an application using AppleScript's `tell` block.
    ///
    /// The application name is escaped before being embedded. The command is
    /// raw AppleScript and is the caller's responsibility.
    ///
    /// - Parameters:
    ///   - application: The name of the target application.
    ///   - command: The AppleScript command(s) to send.
    ///   - timeout: Optional timeout override.
    /// - Returns: The result of execution.
    public func tell(application: String, command: String, timeout: TimeInterval? = nil) throws -> ScriptResult {
        let source = """
        tell application \(AppleScriptString.quoted(application))
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
        return result.output.isEmpty ? [] : result.output.components(separatedBy: ", ")
    }

    // MARK: - Syntax check

    /// Check whether a script compiles, without executing it.
    ///
    /// Uses `osacompile` to compile the source to a throwaway file. Throws
    /// ``ScriptError/scriptCompilationFailed(message:errorNumber:)`` when the
    /// source does not compile.
    public func checkSyntax(_ source: String, language: ScriptLanguage = .appleScript) throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("jcas-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceExtension = language == .javaScript ? "js" : "applescript"
        let sourceURL = tempDir.appendingPathComponent("check.\(sourceExtension)")
        let outputURL = tempDir.appendingPathComponent("check.scpt")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)

        do {
            _ = try runOSAProcess(
                executable: Self.osacompilePath,
                arguments: ["-l", language.rawValue, "-o", outputURL.path, sourceURL.path],
                timeout: defaultTimeout
            )
        } catch let ScriptError.processExecutionFailed(_, stderr) {
            throw ScriptError.scriptCompilationFailed(
                message: Self.cleanCompilerMessage(stderr, sourcePath: sourceURL.path),
                errorNumber: Self.parseErrorNumber(from: stderr)
            )
        }
    }

    // MARK: - Async variants

    /// Async variant of ``execute(_:language:timeout:)``.
    public func execute(
        _ source: String,
        language: ScriptLanguage = .appleScript,
        timeout: TimeInterval? = nil
    ) async throws -> ScriptResult {
        try await runOffActor { try self.execute(source, language: language, timeout: timeout) }
    }

    /// Async variant of ``executeFile(at:variables:language:timeout:)``.
    public func executeFile(
        at path: String,
        variables: [String] = [],
        language: ScriptLanguage? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> ScriptResult {
        try await runOffActor { try self.executeFile(at: path, variables: variables, language: language, timeout: timeout) }
    }

    /// Async variant of ``tell(application:command:timeout:)``.
    public func tell(application: String, command: String, timeout: TimeInterval? = nil) async throws -> ScriptResult {
        try await runOffActor { try self.tell(application: application, command: command, timeout: timeout) }
    }

    private func runOffActor(_ work: @escaping @Sendable () throws -> ScriptResult) async throws -> ScriptResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    // MARK: - Process execution

    /// Run an OSA tool to completion, draining stdout/stderr concurrently and
    /// enforcing a wall-clock timeout with SIGTERM → SIGKILL escalation.
    private func runOSAProcess(
        executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) throws -> ScriptResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        let terminated = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in terminated.signal() }

        try process.run()

        // Drain both pipes on background threads. Reading only after exit
        // deadlocks once a script writes more than the ~64KB pipe buffer.
        let readers = DispatchGroup()
        let stdoutBox = DataBox()
        let stderrBox = DataBox()
        DispatchQueue.global(qos: .userInitiated).async(group: readers) {
            stdoutBox.data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        }
        DispatchQueue.global(qos: .userInitiated).async(group: readers) {
            stderrBox.data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }

        if terminated.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if terminated.wait(timeout: .now() + Self.terminationGracePeriod) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = terminated.wait(timeout: .now() + Self.terminationGracePeriod)
            }
            readers.wait()
            throw ScriptError.timeout
        }
        readers.wait()

        let stdout = String(data: stdoutBox.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrBox.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus != 0 {
            throw ScriptError.processExecutionFailed(exitCode: process.terminationStatus, stderr: stderr)
        }

        return ScriptResult(output: stdout)
    }

    /// Thread-safe box for pipe reader results.
    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var _data = Data()
        var data: Data {
            get { lock.lock(); defer { lock.unlock() }; return _data }
            set { lock.lock(); defer { lock.unlock() }; _data = newValue }
        }
    }

    // MARK: - Helpers

    /// Substitute `$N` placeholders with values. Higher indices are replaced
    /// first so `$1` never corrupts `$10`.
    static func substituteVariables(in source: String, with variables: [String]) -> String {
        var result = source
        for index in variables.indices.reversed() {
            result = result.replacingOccurrences(of: "$\(index)", with: variables[index])
        }
        return result
    }

    static func inferLanguage(fromPath path: String) -> ScriptLanguage {
        let ext = (path as NSString).pathExtension.lowercased()
        return (ext == "js" || ext == "jxa") ? .javaScript : .appleScript
    }

    /// Extract a trailing AppleScript error number like "(-2741)" from
    /// compiler/interpreter stderr.
    static func parseErrorNumber(from stderr: String) -> Int? {
        guard let open = stderr.range(of: "(", options: .backwards),
              let close = stderr.range(of: ")", options: .backwards),
              open.upperBound <= close.lowerBound else { return nil }
        return Int(stderr[open.upperBound..<close.lowerBound])
    }

    /// Strip the temporary file path prefix from an osacompile diagnostic.
    static func cleanCompilerMessage(_ stderr: String, sourcePath: String) -> String {
        stderr.replacingOccurrences(of: sourcePath + ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
