import Foundation

/// A concrete, instance-based description of a scriptable application and
/// its commands.
///
/// Built-in apps are defined as ``ScriptableApp`` conformances and converted
/// to definitions at registration time; community apps can also be loaded
/// dynamically from JSON manifests (see ``AppManifest``).
public struct AppDefinition: Sendable {
    /// The display name of the application (e.g. "Messages").
    public let appName: String

    /// The bundle identifier of the application (e.g. "com.apple.Messages").
    public let bundleIdentifier: String

    /// A brief description of the application.
    public let description: String

    /// The category of the application.
    public let category: AppCategory

    /// Whether the app is a built-in macOS application.
    public let isBuiltIn: Bool

    /// The minimum macOS version that supports scripting for this app.
    public let minimumMacOSVersion: String

    /// The list of commands this application supports.
    public let commands: [AppCommand]

    public init(
        appName: String,
        bundleIdentifier: String,
        description: String,
        category: AppCategory,
        isBuiltIn: Bool = false,
        minimumMacOSVersion: String = "13.0",
        commands: [AppCommand]
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.description = description
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.minimumMacOSVersion = minimumMacOSVersion
        self.commands = commands
    }

    /// Build a definition from a ``ScriptableApp`` conformance.
    public init<T: ScriptableApp>(_ appType: T.Type) {
        self.init(
            appName: T.appName,
            bundleIdentifier: T.bundleIdentifier,
            description: T.description,
            category: T.category,
            isBuiltIn: T.isBuiltIn,
            minimumMacOSVersion: T.minimumMacOSVersion,
            commands: T.commands
        )
    }
}
