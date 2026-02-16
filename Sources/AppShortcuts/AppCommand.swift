import Foundation

/// A parameter for an app command.
public struct CommandParameter: Sendable, Codable {
    /// The name of the parameter.
    public let name: String

    /// A human-readable description.
    public let description: String

    /// Whether the parameter is required.
    public let required: Bool

    /// The type of the parameter (string, integer, boolean, etc.)
    public let type: ParameterType

    /// Optional default value.
    public let defaultValue: String?

    /// Optional list of allowed values (for enum-like parameters).
    public let allowedValues: [String]?

    public init(
        name: String,
        description: String,
        required: Bool = true,
        type: ParameterType = .string,
        defaultValue: String? = nil,
        allowedValues: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.required = required
        self.type = type
        self.defaultValue = defaultValue
        self.allowedValues = allowedValues
    }
}

/// The type of a command parameter.
public enum ParameterType: String, Sendable, Codable {
    case string
    case integer
    case boolean
    case filePath
    case date
    case array
}

/// A command that can be sent to an application via AppleScript.
public struct AppCommand: Sendable {
    /// Unique identifier for this command (e.g. "messages.send_message").
    public let id: String

    /// Human-readable name (e.g. "Send Message").
    public let name: String

    /// Description of what this command does.
    public let description: String

    /// The category of this command.
    public let category: String

    /// Parameters this command accepts.
    public let parameters: [CommandParameter]

    /// A closure that generates the AppleScript source for given arguments.
    public let scriptGenerator: @Sendable ([String: String]) -> String

    public init(
        id: String,
        name: String,
        description: String,
        category: String = "General",
        parameters: [CommandParameter],
        scriptGenerator: @escaping @Sendable ([String: String]) -> String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.parameters = parameters
        self.scriptGenerator = scriptGenerator
    }

    /// Generate the AppleScript source for this command with the given arguments.
    public func generateScript(arguments: [String: String]) -> String {
        scriptGenerator(arguments)
    }

    /// Validate that all required parameters are provided.
    public func validate(arguments: [String: String]) -> [String] {
        var errors: [String] = []
        for param in parameters where param.required {
            if arguments[param.name] == nil || arguments[param.name]?.isEmpty == true {
                if param.defaultValue == nil {
                    errors.append("Missing required parameter: \(param.name)")
                }
            }
        }
        for param in parameters {
            if let value = arguments[param.name], let allowed = param.allowedValues {
                if !allowed.contains(value) {
                    errors.append("Invalid value '\(value)' for parameter '\(param.name)'. Allowed: \(allowed.joined(separator: ", "))")
                }
            }
        }
        return errors
    }
}
