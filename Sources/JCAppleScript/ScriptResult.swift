import Foundation

/// The result of an AppleScript execution.
public struct ScriptResult: Sendable {
    /// The raw string output from the script.
    public let output: String

    /// Whether the script executed successfully.
    public let success: Bool

    /// Optional error message if execution failed.
    public let errorMessage: String?

    public init(output: String, success: Bool = true, errorMessage: String? = nil) {
        self.output = output
        self.success = success
        self.errorMessage = errorMessage
    }
}
