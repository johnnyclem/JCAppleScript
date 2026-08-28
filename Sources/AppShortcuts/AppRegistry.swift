import Foundation
import JCAppleScript

/// Central registry for all scriptable application definitions.
///
/// The registry holds all known application shortcut sheets and provides
/// lookup, search, and execution capabilities. It is designed to be
/// extensible: community-contributed app definitions can be registered
/// at runtime, either as ``ScriptableApp`` conformances or as JSON
/// manifests (see ``AppManifest``).
public final class AppRegistry: @unchecked Sendable {

    /// Shared singleton instance pre-loaded with built-in apps.
    public static let shared: AppRegistry = {
        let registry = AppRegistry()
        registry.registerBuiltInApps()
        return registry
    }()

    /// Thread-safe storage for registered apps.
    private let lock = NSLock()
    private var _apps: [String: AppDefinition] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a scriptable application type.
    public func register<T: ScriptableApp>(_ appType: T.Type) {
        register(AppDefinition(appType))
    }

    /// Register an app definition.
    public func register(_ definition: AppDefinition) {
        lock.lock()
        defer { lock.unlock() }
        _apps[definition.appName.lowercased()] = definition
    }

    /// Remove an app from the registry by name (case-insensitive).
    /// Returns the removed definition, or nil when not registered.
    @discardableResult
    public func unregister(named name: String) -> AppDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return _apps.removeValue(forKey: name.lowercased())
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

    // MARK: - Manifest loading

    /// Load app definitions from JSON manifest data and register them.
    ///
    /// - Returns: The definitions that were registered.
    @discardableResult
    public func loadManifest(from data: Data) throws -> [AppDefinition] {
        let definitions = try AppManifest.decode(from: data).definitions()
        for definition in definitions {
            register(definition)
        }
        return definitions
    }

    /// Load app definitions from a JSON manifest file and register them.
    @discardableResult
    public func loadManifest(contentsOf url: URL) throws -> [AppDefinition] {
        try loadManifest(from: Data(contentsOf: url))
    }

    // MARK: - Lookup

    /// Get all registered app definitions.
    public var allApps: [AppDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_apps.values)
    }

    /// Get an app by name (case-insensitive).
    public func app(named name: String) -> AppDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return _apps[name.lowercased()]
    }

    /// Get apps by category.
    public func apps(in category: AppCategory) -> [AppDefinition] {
        allApps.filter { $0.category == category }
    }

    /// Search for apps by name or description.
    public func search(_ query: String) -> [AppDefinition] {
        let q = query.lowercased()
        return allApps.filter {
            $0.appName.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    // MARK: - Command Lookup

    /// Find a command by its full ID (e.g. "messages.send_message").
    public func command(withID id: String) -> AppCommand? {
        for definition in allApps {
            if let cmd = definition.commands.first(where: { $0.id == id }) {
                return cmd
            }
        }
        return nil
    }

    /// Find all commands matching a search query across all apps.
    public func searchCommands(_ query: String) -> [(app: AppDefinition, command: AppCommand)] {
        let q = query.lowercased()
        var results: [(AppDefinition, AppCommand)] = []
        for definition in allApps {
            for cmd in definition.commands {
                if cmd.name.lowercased().contains(q) ||
                   cmd.description.lowercased().contains(q) ||
                   cmd.id.lowercased().contains(q) {
                    results.append((definition, cmd))
                }
            }
        }
        return results
    }

    /// Get all commands for a specific app.
    public func commands(forApp name: String) -> [AppCommand] {
        app(named: name)?.commands ?? []
    }

    // MARK: - Execution

    /// Execute a command by ID with the given arguments.
    ///
    /// Arguments are validated against the command's declared parameters and
    /// sanitized before script generation.
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

    /// Build a codable manifest of all registered apps.
    public func manifest() -> AppManifest {
        AppManifest(definitions: allApps.sorted { $0.appName < $1.appName })
    }

    /// Export the full registry as pretty-printed manifest JSON.
    public func exportManifestJSON() throws -> Data {
        try manifest().encode()
    }

    /// Generate a JSON-serializable manifest of all registered apps and commands.
    public func generateManifest() -> [[String: Any]] {
        return allApps.map { definition in
            [
                "name": definition.appName,
                "bundleIdentifier": definition.bundleIdentifier,
                "description": definition.description,
                "category": definition.category.rawValue,
                "isBuiltIn": definition.isBuiltIn,
                "minimumMacOSVersion": definition.minimumMacOSVersion,
                "commands": definition.commands.map { cmd in
                    [
                        "id": cmd.id,
                        "name": cmd.name,
                        "description": cmd.description,
                        "category": cmd.category,
                        "dangerous": cmd.dangerous,
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
