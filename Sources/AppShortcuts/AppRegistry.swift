import Foundation
import JCAppleScript

/// Central registry for all scriptable application definitions.
///
/// The registry holds all known application shortcut sheets and provides
/// lookup, search, and execution capabilities. It is designed to be
/// extensible: community-contributed app definitions can be registered
/// at runtime.
public final class AppRegistry: Sendable {

    /// Shared singleton instance pre-loaded with built-in apps.
    public static let shared: AppRegistry = {
        let registry = AppRegistry()
        registry.registerBuiltInApps()
        return registry
    }()

    /// Thread-safe storage for registered apps.
    private let lock = NSLock()
    private var _apps: [String: any ScriptableApp.Type] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a scriptable application.
    public func register<T: ScriptableApp>(_ appType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        _apps[T.appName.lowercased()] = appType
    }

    /// Register all built-in macOS application shortcut sheets.
    private func registerBuiltInApps() {
        register(MessagesApp.self)
        register(RemindersApp.self)
        register(FinderApp.self)
        register(SafariApp.self)
        register(MailApp.self)
        register(CalendarApp.self)
        register(NotesApp.self)
        register(MusicApp.self)
        register(TerminalApp.self)
        register(SystemSettingsApp.self)
        register(XcodeApp.self)
        register(SpeechRecognitionApp.self)
    }

    // MARK: - Lookup

    /// Get all registered application types.
    public var allApps: [any ScriptableApp.Type] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_apps.values)
    }

    /// Get an app by name (case-insensitive).
    public func app(named name: String) -> (any ScriptableApp.Type)? {
        lock.lock()
        defer { lock.unlock() }
        return _apps[name.lowercased()]
    }

    /// Get apps by category.
    public func apps(in category: AppCategory) -> [any ScriptableApp.Type] {
        lock.lock()
        defer { lock.unlock() }
        return _apps.values.filter { $0.category == category }
    }

    /// Search for apps by name or description.
    public func search(_ query: String) -> [any ScriptableApp.Type] {
        let q = query.lowercased()
        lock.lock()
        defer { lock.unlock() }
        return _apps.values.filter {
            $0.appName.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    // MARK: - Command Lookup

    /// Find a command by its full ID (e.g. "messages.send_message").
    public func command(withID id: String) -> AppCommand? {
        for appType in allApps {
            if let cmd = appType.commands.first(where: { $0.id == id }) {
                return cmd
            }
        }
        return nil
    }

    /// Find all commands matching a search query across all apps.
    public func searchCommands(_ query: String) -> [(app: any ScriptableApp.Type, command: AppCommand)] {
        let q = query.lowercased()
        var results: [(any ScriptableApp.Type, AppCommand)] = []
        for appType in allApps {
            for cmd in appType.commands {
                if cmd.name.lowercased().contains(q) ||
                   cmd.description.lowercased().contains(q) ||
                   cmd.id.lowercased().contains(q) {
                    results.append((appType, cmd))
                }
            }
        }
        return results
    }

    /// Get all commands for a specific app.
    public func commands(forApp name: String) -> [AppCommand] {
        guard let appType = app(named: name) else { return [] }
        return appType.commands
    }

    // MARK: - Execution

    /// Execute a command by ID with the given arguments.
    public func executeCommand(
        _ commandID: String,
        arguments: [String: String],
        engine: AppleScriptEngine = .shared
    ) throws -> ScriptResult {
        guard let cmd = command(withID: commandID) else {
            throw ScriptError.scriptExecutionFailed(
                message: "Unknown command: \(commandID)",
                errorNumber: nil
            )
        }

        let errors = cmd.validate(arguments: arguments)
        if !errors.isEmpty {
            throw ScriptError.scriptExecutionFailed(
                message: errors.joined(separator: "; "),
                errorNumber: nil
            )
        }

        let script = cmd.generateScript(arguments: arguments)
        return try engine.execute(script)
    }

    // MARK: - Manifest (for registry site / JSON export)

    /// Generate a JSON-serializable manifest of all registered apps and commands.
    public func generateManifest() -> [[String: Any]] {
        return allApps.map { appType in
            [
                "name": appType.appName,
                "bundleIdentifier": appType.bundleIdentifier,
                "description": appType.description,
                "category": appType.category.rawValue,
                "isBuiltIn": appType.isBuiltIn,
                "minimumMacOSVersion": appType.minimumMacOSVersion,
                "commands": appType.commands.map { cmd in
                    [
                        "id": cmd.id,
                        "name": cmd.name,
                        "description": cmd.description,
                        "category": cmd.category,
                        "parameters": cmd.parameters.map { param in
                            [
                                "name": param.name,
                                "description": param.description,
                                "required": param.required,
                                "type": param.type.rawValue,
                                "defaultValue": param.defaultValue as Any,
                                "allowedValues": param.allowedValues as Any,
                            ] as [String: Any]
                        }
                    ] as [String: Any]
                }
            ] as [String: Any]
        }
    }
}
