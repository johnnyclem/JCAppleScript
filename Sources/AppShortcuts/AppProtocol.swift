import Foundation

/// Protocol that all application shortcut sheets must conform to.
///
/// Each conforming type represents a macOS application and its available
/// AppleScript commands. Community contributors implement this protocol
/// to add support for new applications.
public protocol ScriptableApp: Sendable {
    /// The bundle identifier of the application (e.g. "com.apple.Messages").
    static var bundleIdentifier: String { get }

    /// The display name of the application (e.g. "Messages").
    static var appName: String { get }

    /// A brief description of the application.
    static var description: String { get }

    /// The category of the application (e.g. "Communication", "Productivity").
    static var category: AppCategory { get }

    /// Whether the app is a built-in macOS application.
    static var isBuiltIn: Bool { get }

    /// The minimum macOS version that supports scripting for this app.
    static var minimumMacOSVersion: String { get }

    /// The list of commands this application supports.
    static var commands: [AppCommand] { get }
}

/// Default implementations for common properties.
extension ScriptableApp {
    public static var isBuiltIn: Bool { true }
    public static var minimumMacOSVersion: String { "13.0" }
}

/// Categories for scriptable applications.
public enum AppCategory: String, Sendable, Codable, CaseIterable {
    case communication = "Communication"
    case productivity = "Productivity"
    case utilities = "Utilities"
    case media = "Media"
    case development = "Development"
    case internet = "Internet"
    case system = "System"
    case creative = "Creative"
    case other = "Other"
}
