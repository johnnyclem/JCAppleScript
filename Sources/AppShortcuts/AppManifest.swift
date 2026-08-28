import Foundation

/// JSON manifest representation of app definitions, used to share command
/// sheets between tools and to load community-contributed apps at runtime.
///
/// A manifest is a JSON array of app objects. Commands defined in a manifest
/// use declarative script templates with `${param}` placeholders; argument
/// values are sanitized before substitution (see
/// ``AppCommand/init(id:name:description:category:parameters:dangerous:scriptTemplate:)``).
public struct AppManifest: Codable, Sendable {
    public var apps: [App]

    public init(apps: [App]) {
        self.apps = apps
    }

    public struct App: Codable, Sendable {
        public var name: String
        public var bundleIdentifier: String
        public var description: String
        public var category: String
        public var isBuiltIn: Bool?
        public var minimumMacOSVersion: String?
        public var commands: [Command]

        public init(
            name: String,
            bundleIdentifier: String,
            description: String,
            category: String,
            isBuiltIn: Bool? = nil,
            minimumMacOSVersion: String? = nil,
            commands: [Command]
        ) {
            self.name = name
            self.bundleIdentifier = bundleIdentifier
            self.description = description
            self.category = category
            self.isBuiltIn = isBuiltIn
            self.minimumMacOSVersion = minimumMacOSVersion
            self.commands = commands
        }
    }

    public struct Command: Codable, Sendable {
        public var id: String
        public var name: String
        public var description: String
        public var category: String?
        public var dangerous: Bool?
        /// AppleScript template with `${param}` placeholders. Required when
        /// importing; nil on export for commands built from Swift closures.
        public var script: String?
        public var parameters: [CommandParameter]

        public init(
            id: String,
            name: String,
            description: String,
            category: String? = nil,
            dangerous: Bool? = nil,
            script: String? = nil,
            parameters: [CommandParameter] = []
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.category = category
            self.dangerous = dangerous
            self.script = script
            self.parameters = parameters
        }
    }

    /// Errors thrown while decoding or converting a manifest.
    public enum ManifestError: Error, LocalizedError, Sendable {
        case unknownCategory(String)
        case missingScript(commandID: String)

        public var errorDescription: String? {
            switch self {
            case .unknownCategory(let raw):
                let valid = AppCategory.allCases.map(\.rawValue).joined(separator: ", ")
                return "Unknown app category '\(raw)'. Valid categories: \(valid)"
            case .missingScript(let commandID):
                return "Command '\(commandID)' has no script template; manifest commands must define 'script'"
            }
        }
    }

    // MARK: - Decoding

    /// Decode a manifest from JSON data. Accepts either a top-level array of
    /// apps or an object with an "apps" key.
    public static func decode(from data: Data) throws -> AppManifest {
        let decoder = JSONDecoder()
        if let manifest = try? decoder.decode(AppManifest.self, from: data) {
            return manifest
        }
        let apps = try decoder.decode([App].self, from: data)
        return AppManifest(apps: apps)
    }

    /// Encode the manifest to pretty-printed JSON.
    public func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    // MARK: - Conversion

    /// Convert the manifest into app definitions with template-backed commands.
    public func definitions() throws -> [AppDefinition] {
        try apps.map { app in
            guard let category = AppCategory(rawValue: app.category) else {
                throw ManifestError.unknownCategory(app.category)
            }
            let commands = try app.commands.map { cmd -> AppCommand in
                guard let script = cmd.script, !script.isEmpty else {
                    throw ManifestError.missingScript(commandID: cmd.id)
                }
                return AppCommand(
                    id: cmd.id,
                    name: cmd.name,
                    description: cmd.description,
                    category: cmd.category ?? "General",
                    parameters: cmd.parameters,
                    dangerous: cmd.dangerous ?? false,
                    scriptTemplate: script
                )
            }
            return AppDefinition(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                description: app.description,
                category: category,
                isBuiltIn: app.isBuiltIn ?? false,
                minimumMacOSVersion: app.minimumMacOSVersion ?? "13.0",
                commands: commands
            )
        }
    }

    /// Build a manifest from app definitions.
    public init(definitions: [AppDefinition]) {
        self.apps = definitions.map { def in
            App(
                name: def.appName,
                bundleIdentifier: def.bundleIdentifier,
                description: def.description,
                category: def.category.rawValue,
                isBuiltIn: def.isBuiltIn,
                minimumMacOSVersion: def.minimumMacOSVersion,
                commands: def.commands.map { cmd in
                    Command(
                        id: cmd.id,
                        name: cmd.name,
                        description: cmd.description,
                        category: cmd.category,
                        dangerous: cmd.dangerous,
                        script: cmd.scriptTemplate,
                        parameters: cmd.parameters
                    )
                }
            )
        }
    }
}
