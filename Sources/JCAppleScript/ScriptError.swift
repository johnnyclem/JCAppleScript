import Foundation

/// Errors that can occur during AppleScript execution.
public enum ScriptError: Error, Sendable {
    case scriptCompilationFailed(message: String, errorNumber: Int?)
    case scriptExecutionFailed(message: String, errorNumber: Int?)
    case fileNotFound(path: String)
    case invalidScriptSource
    case processExecutionFailed(exitCode: Int32, stderr: String)
    case timeout

    public var localizedDescription: String {
        switch self {
        case .scriptCompilationFailed(let message, let errorNumber):
            let num = errorNumber.map { " (\($0))" } ?? ""
            return "AppleScript compilation failed\(num): \(message)"
        case .scriptExecutionFailed(let message, let errorNumber):
            let num = errorNumber.map { " (\($0))" } ?? ""
            return "AppleScript execution failed\(num): \(message)"
        case .fileNotFound(let path):
            return "Script file not found: \(path)"
        case .invalidScriptSource:
            return "Could not read script source"
        case .processExecutionFailed(let exitCode, let stderr):
            return "osascript process exited with code \(exitCode): \(stderr)"
        case .timeout:
            return "Script execution timed out"
        }
    }
}
