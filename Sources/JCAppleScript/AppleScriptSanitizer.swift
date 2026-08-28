import Foundation

/// Utilities for safely embedding untrusted values in AppleScript source code.
///
/// AppleScript string literals delimit with double quotes and support the
/// escape sequences `\\`, `\"`, `\n`, `\r`, and `\t` (AppleScript 2.0+).
/// Any value that originates outside the program (user input, MCP tool
/// arguments, file contents) must be escaped before being interpolated
/// inside a quoted AppleScript string, otherwise a value containing a
/// double quote can break out of the literal and inject arbitrary script.
public enum AppleScriptString {

    /// Escape a value for safe inclusion *inside* a double-quoted
    /// AppleScript string literal.
    ///
    /// Escapes backslashes, double quotes, and control characters that are
    /// not valid inside an AppleScript string literal.
    public static func escape(_ value: String) -> String {
        var result = String()
        result.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "\\": result.append("\\\\")
            case "\"": result.append("\\\"")
            case "\n": result.append("\\n")
            case "\r": result.append("\\r")
            case "\t": result.append("\\t")
            default: result.append(character)
            }
        }
        return result
    }

    /// Return the value as a complete double-quoted AppleScript string
    /// literal, with the contents escaped.
    public static func quoted(_ value: String) -> String {
        "\"\(escape(value))\""
    }

    /// Validate that a value is a plain integer and return its canonical
    /// form, or nil when it is not an integer.
    ///
    /// Use this for values that are interpolated *outside* of quotes
    /// (indexes, counts, volumes), where escaping alone cannot prevent
    /// injection.
    public static func integer(_ value: String) -> String? {
        guard let parsed = Int(value.trimmingCharacters(in: .whitespaces)) else { return nil }
        return String(parsed)
    }

    /// Normalize a value to an AppleScript boolean literal ("true"/"false"),
    /// or nil when the value is not recognizably boolean.
    public static func boolean(_ value: String) -> String? {
        switch value.trimmingCharacters(in: .whitespaces).lowercased() {
        case "true", "yes", "1": return "true"
        case "false", "no", "0": return "false"
        default: return nil
        }
    }
}
