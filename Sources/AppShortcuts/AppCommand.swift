import Foundation
import JCAppleScript

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

    /// Whether this command executes caller-controlled code (shell commands,
    /// JavaScript, etc.). Dangerous commands are blocked when the MCP server
    /// runs in safe mode.
    public let dangerous: Bool

    /// The declarative script template this command was built from, when it
    /// was defined via a template (e.g. loaded from a JSON manifest).
    /// `${param}` placeholders are replaced with sanitized argument values.
    public let scriptTemplate: String?

    /// A closure that generates the AppleScript source for given arguments.
    /// Arguments have already been sanitized (see `sanitizedArguments`).
    public let scriptGenerator: @Sendable ([String: String]) -> String

    public init(
        id: String,
        name: String,
        description: String,
        category: String = "General",
        parameters: [CommandParameter],
        dangerous: Bool = false,
        scriptGenerator: @escaping @Sendable ([String: String]) -> String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.parameters = parameters
        self.dangerous = dangerous
        self.scriptTemplate = nil
        self.scriptGenerator = scriptGenerator
    }

    /// Create a command from a declarative script template.
    ///
    /// `${param}` placeholders in the template are replaced with the sanitized
    /// value of the corresponding argument (or the parameter's default value).
    /// Placeholders for absent optional parameters are replaced with an empty
    /// string. This is how manifest-defined commands are constructed.
    public init(
        id: String,
        name: String,
        description: String,
        category: String = "General",
        parameters: [CommandParameter],
        dangerous: Bool = false,
        scriptTemplate: String
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.parameters = parameters
        self.dangerous = dangerous
        self.scriptTemplate = scriptTemplate
        let parameterNames = parameters.map(\.name)
        self.scriptGenerator = { args in
            var script = scriptTemplate
            for paramName in parameterNames {
                script = script.replacingOccurrences(of: "${\(paramName)}", with: args[paramName] ?? "")
            }
            return script
        }
    }

    /// Generate the AppleScript source for this command with the given arguments.
    ///
    /// Arguments are sanitized before being handed to the script generator:
    /// string-like values are escaped for inclusion in quoted AppleScript
    /// literals, integers and booleans are validated/normalized, values not
    /// in a parameter's allowed list are dropped, and arguments that do not
    /// correspond to a declared parameter are discarded.
    public func generateScript(arguments: [String: String]) -> String {
        scriptGenerator(sanitizedArguments(from: arguments))
    }

    /// Sanitize raw argument values according to the declared parameter types.
    public func sanitizedArguments(from arguments: [String: String]) -> [String: String] {
        var sanitized: [String: String] = [:]
        for param in parameters {
            guard let raw = arguments[param.name] ?? param.defaultValue else { continue }
            if let allowed = param.allowedValues, !allowed.contains(raw) {
                // Fall back to the default when the raw value is not permitted.
                if let def = param.defaultValue, allowed.contains(def) {
                    sanitized[param.name] = def
                }
                continue
            }
            switch param.type {
            case .integer:
                if let value = AppleScriptString.integer(raw) {
                    sanitized[param.name] = value
                } else if let def = param.defaultValue, let value = AppleScriptString.integer(def) {
                    sanitized[param.name] = value
                }
            case .boolean:
                if let value = AppleScriptString.boolean(raw) {
                    sanitized[param.name] = value
                } else if let def = param.defaultValue, let value = AppleScriptString.boolean(def) {
                    sanitized[param.name] = value
                }
            case .string, .filePath, .date, .array:
                sanitized[param.name] = AppleScriptString.escape(raw)
            }
        }
        return sanitized
    }

    /// Validate that all required parameters are provided and well-typed.
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
            guard let value = arguments[param.name], !value.isEmpty else { continue }
            if let allowed = param.allowedValues, !allowed.contains(value) {
                errors.append("Invalid value '\(value)' for parameter '\(param.name)'. Allowed: \(allowed.joined(separator: ", "))")
                continue
            }
            switch param.type {
            case .integer where AppleScriptString.integer(value) == nil:
                errors.append("Parameter '\(param.name)' must be an integer, got '\(value)'")
            case .boolean where AppleScriptString.boolean(value) == nil:
                errors.append("Parameter '\(param.name)' must be a boolean (true/false), got '\(value)'")
            default:
                break
            }
        }
        return errors
    }
}
