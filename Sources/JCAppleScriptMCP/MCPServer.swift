import Foundation
import JCAppleScript
import AppShortcuts

/// The MCP server that handles all JSON-RPC method dispatch.
final class MCPServer {
    let transport: MCPTransport
    let engine: AppleScriptEngine
    let registry: AppRegistry

    /// When true, tools that execute caller-supplied code
    /// (execute_applescript, execute_jxa, tell_application) and registry
    /// commands flagged `dangerous` are disabled. Enabled with
    /// JCAS_SAFE_MODE=1 (or "true"/"yes").
    let safeMode: Bool

    static let serverName = "jcas-mcp"
    static let serverVersion = "2.0.0"
    static let protocolVersion = "2024-11-05"

    /// Environment variable holding a colon-separated list of JSON manifest
    /// paths with additional app definitions to load at startup.
    static let manifestPathsEnvVar = "JCAS_APP_MANIFESTS"
    static let safeModeEnvVar = "JCAS_SAFE_MODE"

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.transport = MCPTransport()
        self.engine = AppleScriptEngine()
        self.registry = AppRegistry.shared
        self.safeMode = ["1", "true", "yes"].contains(
            (environment[Self.safeModeEnvVar] ?? "").lowercased()
        )
        loadExtraManifests(environment: environment)
    }

    /// Load community app manifests listed in JCAS_APP_MANIFESTS.
    private func loadExtraManifests(environment: [String: String]) {
        guard let paths = environment[Self.manifestPathsEnvVar], !paths.isEmpty else { return }
        for path in paths.split(separator: ":").map(String.init) {
            do {
                let loaded = try registry.loadManifest(contentsOf: URL(fileURLWithPath: path))
                transport.log("Loaded \(loaded.count) app(s) from manifest: \(path)")
            } catch {
                transport.log("Failed to load manifest \(path): \(error.localizedDescription)")
            }
        }
    }

    /// Run the server loop, reading requests from stdin until EOF.
    func run() {
        transport.log("Server starting (safe mode: \(safeMode ? "on" : "off"))...")
        while let request = transport.readRequest() {
            handleRequest(request)
        }
        transport.log("Server shutting down (EOF)")
    }

    // MARK: - Dispatch

    private func handleRequest(_ request: JSONRPCRequest) {
        transport.log("Received: \(request.method)")

        switch request.method {
        // Lifecycle
        case "initialize":
            handleInitialize(request)
        case "initialized", "notifications/initialized":
            // Notification from client, no response needed
            transport.log("Client initialized")
        case "ping":
            respond(to: request, result: .object([:]))

        // Tools
        case "tools/list":
            handleToolsList(request)
        case "tools/call":
            handleToolsCall(request)

        // Resources
        case "resources/list":
            handleResourcesList(request)
        case "resources/read":
            handleResourcesRead(request)

        // Notifications (no response)
        case "notifications/cancelled",
             "notifications/roots/list_changed":
            break

        default:
            respondError(to: request, error: .methodNotFound)
        }
    }

    // MARK: - Lifecycle

    private func handleInitialize(_ request: JSONRPCRequest) {
        let result: JSONValue = .object([
            "protocolVersion": .string(MCPServer.protocolVersion),
            "capabilities": .object([
                "tools": .object([:]),
                "resources": .object([:]),
            ]),
            "serverInfo": .object([
                "name": .string(MCPServer.serverName),
                "version": .string(MCPServer.serverVersion),
            ]),
        ])
        respond(to: request, result: result)
    }

    // MARK: - Tool schema helpers

    private func tool(_ name: String, _ description: String, properties: [String: JSONValue], required: [String] = []) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": .string("object"),
            "properties": .object(properties),
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        return .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object(schema),
        ])
    }

    private func prop(_ type: String, _ description: String) -> JSONValue {
        .object(["type": .string(type), "description": .string(description)])
    }

    // MARK: - Tools

    private func handleToolsList(_ request: JSONRPCRequest) {
        var tools: [JSONValue] = []

        if !safeMode {
            tools.append(tool(
                "execute_applescript",
                "Execute arbitrary AppleScript code. Use this for custom scripts not covered by app-specific commands.",
                properties: [
                    "script": prop("string", "The AppleScript source code to execute"),
                    "timeout": prop("number", "Timeout in seconds (default: 30)"),
                ],
                required: ["script"]
            ))

            tools.append(tool(
                "execute_jxa",
                "Execute JavaScript for Automation (JXA) code. Use this when JavaScript syntax is preferable to AppleScript.",
                properties: [
                    "script": prop("string", "The JXA (JavaScript) source code to execute"),
                    "timeout": prop("number", "Timeout in seconds (default: 30)"),
                ],
                required: ["script"]
            ))

            tools.append(tool(
                "tell_application",
                "Send an AppleScript command to a specific application using a 'tell' block.",
                properties: [
                    "application": prop("string", "The name of the target application"),
                    "command": prop("string", "The AppleScript command to send within the tell block"),
                ],
                required: ["application", "command"]
            ))
        }

        tools.append(tool(
            "check_script_syntax",
            "Compile a script without executing it, to verify its syntax. Returns a compile error message if the script is invalid.",
            properties: [
                "script": prop("string", "The script source code to check"),
                "language": .object([
                    "type": .string("string"),
                    "description": .string("The script language (default: AppleScript)"),
                    "enum": .array([.string("AppleScript"), .string("JavaScript")]),
                ]),
            ],
            required: ["script"]
        ))

        tools.append(tool(
            "list_running_applications",
            "Get a list of currently running (non-background) applications.",
            properties: [:]
        ))

        tools.append(tool(
            "list_registered_apps",
            "List all applications in the shortcut registry with their available commands.",
            properties: [
                "category": prop("string", "Filter by category (\(AppCategory.allCases.map(\.rawValue).joined(separator: ", ")))"),
            ]
        ))

        tools.append(tool(
            "search_commands",
            "Search for available app commands by keyword. Returns matching commands across all registered apps.",
            properties: [
                "query": prop("string", "Search keyword to match against command names and descriptions"),
            ],
            required: ["query"]
        ))

        tools.append(tool(
            "run_app_command",
            "Execute a pre-built app command from the shortcut registry. Use list_registered_apps or search_commands to discover available command IDs.",
            properties: [
                "command_id": prop("string", "The command ID (e.g. 'messages.send_message', 'reminders.create_reminder')"),
                "arguments": .object([
                    "type": .string("object"),
                    "description": .string("Key-value arguments for the command. Use list_registered_apps to see required parameters."),
                    "additionalProperties": .object(["type": .string("string")]),
                ]),
            ],
            required: ["command_id"]
        ))

        tools.append(tool(
            "preview_app_command",
            "Generate the AppleScript a registry command would run, without executing it. Useful for reviewing a command before running it.",
            properties: [
                "command_id": prop("string", "The command ID to preview"),
                "arguments": .object([
                    "type": .string("object"),
                    "description": .string("Key-value arguments for the command"),
                    "additionalProperties": .object(["type": .string("string")]),
                ]),
            ],
            required: ["command_id"]
        ))

        tools.append(tool(
            "get_app_commands",
            "Get detailed information about all commands available for a specific application, including parameters and descriptions.",
            properties: [
                "app_name": prop("string", "The name of the application (e.g. 'Messages', 'Reminders', 'Finder')"),
            ],
            required: ["app_name"]
        ))

        respond(to: request, result: .object([
            "tools": .array(tools),
        ]))
    }

    private func handleToolsCall(_ request: JSONRPCRequest) {
        guard let params = request.params,
              let toolName = params.stringValue(forKey: "name") else {
            respondError(to: request, error: .invalidParams)
            return
        }

        let arguments = params.objectValue(forKey: "arguments")

        if safeMode, ["execute_applescript", "execute_jxa", "tell_application"].contains(toolName) {
            respondToolError(to: request, message: "Tool '\(toolName)' is disabled: the server is running in safe mode (JCAS_SAFE_MODE). Only pre-built registry commands are available.")
            return
        }

        do {
            let result: String
            switch toolName {
            case "execute_applescript":
                result = try callExecuteScript(arguments, language: .appleScript)
            case "execute_jxa":
                result = try callExecuteScript(arguments, language: .javaScript)
            case "tell_application":
                result = try callTellApplication(arguments)
            case "check_script_syntax":
                result = callCheckSyntax(arguments)
            case "list_running_applications":
                result = try callListRunningApps()
            case "list_registered_apps":
                result = callListRegisteredApps(arguments)
            case "search_commands":
                result = callSearchCommands(arguments)
            case "run_app_command":
                result = try callRunAppCommand(arguments)
            case "preview_app_command":
                result = try callPreviewAppCommand(arguments)
            case "get_app_commands":
                result = callGetAppCommands(arguments)
            default:
                respondError(to: request, error: JSONRPCError(code: -32602, message: "Unknown tool: \(toolName)"))
                return
            }

            respond(to: request, result: .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(result),
                    ]),
                ]),
            ]))
        } catch {
            respondToolError(to: request, message: "Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Tool Implementations

    private func timeoutValue(_ args: JSONValue?) -> TimeInterval? {
        switch args?.objectValue(forKey: "timeout") {
        case .double(let t): return t
        case .int(let t): return TimeInterval(t)
        default: return nil
        }
    }

    private func callExecuteScript(_ args: JSONValue?, language: ScriptLanguage) throws -> String {
        guard let script = args?.stringValue(forKey: "script") else {
            throw ScriptError.invalidScriptSource
        }
        let result = try engine.execute(script, language: language, timeout: timeoutValue(args))
        return result.output.isEmpty ? "(script executed successfully with no output)" : result.output
    }

    private func callTellApplication(_ args: JSONValue?) throws -> String {
        guard let app = args?.stringValue(forKey: "application"),
              let command = args?.stringValue(forKey: "command") else {
            throw ScriptError.scriptExecutionFailed(message: "Missing 'application' or 'command' parameter", errorNumber: nil)
        }
        let result = try engine.tell(application: app, command: command)
        return result.output.isEmpty ? "(command sent successfully with no output)" : result.output
    }

    private func callCheckSyntax(_ args: JSONValue?) -> String {
        guard let script = args?.stringValue(forKey: "script") else {
            return "Missing 'script' parameter"
        }
        let language = args?.stringValue(forKey: "language")
            .flatMap { ScriptLanguage(rawValue: $0) } ?? .appleScript
        do {
            try engine.checkSyntax(script, language: language)
            return "Syntax OK (\(language.rawValue))"
        } catch {
            return "Syntax error: \(error.localizedDescription)"
        }
    }

    private func callListRunningApps() throws -> String {
        let apps = try engine.listRunningApplications()
        return apps.joined(separator: "\n")
    }

    private func callListRegisteredApps(_ args: JSONValue?) -> String {
        let apps: [AppDefinition]
        if let categoryStr = args?.stringValue(forKey: "category"),
           let category = AppCategory(rawValue: categoryStr) {
            apps = registry.apps(in: category)
        } else {
            apps = registry.allApps
        }

        var lines: [String] = []
        let sortedApps = apps.sorted { $0.appName < $1.appName }
        for app in sortedApps {
            lines.append("## \(app.appName) [\(app.category.rawValue)]")
            lines.append("   \(app.description)")
            lines.append("   Bundle: \(app.bundleIdentifier)")
            lines.append("   Commands (\(app.commands.count)):")
            for cmd in app.commands {
                let params = cmd.parameters.map { p in
                    "\(p.name)\(p.required ? "*" : "")"
                }.joined(separator: ", ")
                let dangerTag = cmd.dangerous ? " [dangerous]" : ""
                lines.append("     - \(cmd.id): \(cmd.name) (\(params))\(dangerTag)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func callSearchCommands(_ args: JSONValue?) -> String {
        guard let query = args?.stringValue(forKey: "query") else {
            return "Missing 'query' parameter"
        }
        let results = registry.searchCommands(query)
        if results.isEmpty {
            return "No commands found matching '\(query)'"
        }
        var lines: [String] = []
        for (app, cmd) in results {
            let params = cmd.parameters.map { "\($0.name)\($0.required ? "*" : ""): \($0.description)" }
            lines.append("[\(app.appName)] \(cmd.id): \(cmd.name)")
            lines.append("  \(cmd.description)")
            if !params.isEmpty {
                lines.append("  Parameters:")
                for p in params { lines.append("    - \(p)") }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func requireCommand(_ args: JSONValue?) throws -> (AppCommand, [String: String]) {
        guard let commandID = args?.stringValue(forKey: "command_id") else {
            throw ScriptError.scriptExecutionFailed(message: "Missing 'command_id' parameter", errorNumber: nil)
        }
        guard let cmd = registry.command(withID: commandID) else {
            throw ScriptError.scriptExecutionFailed(message: "Unknown command: \(commandID)", errorNumber: nil)
        }
        let arguments = args?.objectValue(forKey: "arguments")?.toStringDict() ?? [:]
        return (cmd, arguments)
    }

    private func callRunAppCommand(_ args: JSONValue?) throws -> String {
        let (cmd, arguments) = try requireCommand(args)
        if safeMode && cmd.dangerous {
            throw ScriptError.scriptExecutionFailed(
                message: "Command '\(cmd.id)' executes arbitrary code and is disabled in safe mode (JCAS_SAFE_MODE)",
                errorNumber: nil
            )
        }
        let result = try registry.executeCommand(cmd.id, arguments: arguments, engine: engine)
        return result.output.isEmpty ? "(command executed successfully with no output)" : result.output
    }

    private func callPreviewAppCommand(_ args: JSONValue?) throws -> String {
        let (cmd, arguments) = try requireCommand(args)
        let errors = cmd.validate(arguments: arguments)
        var lines: [String] = []
        if !errors.isEmpty {
            lines.append("Validation errors (script shown with sanitized/default values):")
            for error in errors { lines.append("  - \(error)") }
            lines.append("")
        }
        lines.append("Generated script for '\(cmd.id)':")
        lines.append("```applescript")
        lines.append(cmd.generateScript(arguments: arguments))
        lines.append("```")
        return lines.joined(separator: "\n")
    }

    private func callGetAppCommands(_ args: JSONValue?) -> String {
        guard let appName = args?.stringValue(forKey: "app_name") else {
            return "Missing 'app_name' parameter"
        }
        guard let app = registry.app(named: appName) else {
            let available = registry.allApps.map { $0.appName }.sorted().joined(separator: ", ")
            return "Unknown app: '\(appName)'. Available apps: \(available)"
        }

        var lines: [String] = [
            "# \(app.appName)",
            "\(app.description)",
            "Bundle ID: \(app.bundleIdentifier)",
            "Category: \(app.category.rawValue)",
            "",
        ]

        let grouped = Dictionary(grouping: app.commands, by: { $0.category })
        for (category, cmds) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("## \(category)")
            for cmd in cmds {
                lines.append("### \(cmd.name) (\(cmd.id))\(cmd.dangerous ? " [dangerous]" : "")")
                lines.append(cmd.description)
                if !cmd.parameters.isEmpty {
                    lines.append("Parameters:")
                    for p in cmd.parameters {
                        var desc = "  - \(p.name) (\(p.type.rawValue))\(p.required ? " [required]" : " [optional]"): \(p.description)"
                        if let def = p.defaultValue { desc += " (default: \(def))" }
                        if let allowed = p.allowedValues { desc += " (values: \(allowed.joined(separator: ", ")))" }
                        lines.append(desc)
                    }
                }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Resources

    private func handleResourcesList(_ request: JSONRPCRequest) {
        var resources: [JSONValue] = []

        // Each registered app is a resource
        for app in registry.allApps.sorted(by: { $0.appName < $1.appName }) {
            resources.append(.object([
                "uri": .string("jcas://apps/\(app.appName.lowercased().replacingOccurrences(of: " ", with: "-"))"),
                "name": .string("\(app.appName) Commands"),
                "description": .string("AppleScript command reference for \(app.appName): \(app.description)"),
                "mimeType": .string("text/plain"),
            ]))
        }

        // Registry manifest resource
        resources.append(.object([
            "uri": .string("jcas://registry/manifest"),
            "name": .string("App Registry Manifest"),
            "description": .string("Complete JSON manifest of all registered apps and commands"),
            "mimeType": .string("application/json"),
        ]))

        respond(to: request, result: .object([
            "resources": .array(resources),
        ]))
    }

    private func handleResourcesRead(_ request: JSONRPCRequest) {
        guard let uri = request.params?.stringValue(forKey: "uri") else {
            respondError(to: request, error: .invalidParams)
            return
        }

        if uri == "jcas://registry/manifest" {
            do {
                let data = try registry.exportManifestJSON()
                let json = String(data: data, encoding: .utf8) ?? "[]"
                respond(to: request, result: .object([
                    "contents": .array([
                        .object([
                            "uri": .string(uri),
                            "mimeType": .string("application/json"),
                            "text": .string(json),
                        ]),
                    ]),
                ]))
            } catch {
                respondError(to: request, error: JSONRPCError(code: -32603, message: "Failed to serialize manifest: \(error.localizedDescription)"))
            }
            return
        }

        if uri.hasPrefix("jcas://apps/") {
            let appSlug = String(uri.dropFirst("jcas://apps/".count))
            let appName = appSlug.replacingOccurrences(of: "-", with: " ")
            if let app = registry.app(named: appName) {
                let content = callGetAppCommands(.object(["app_name": .string(app.appName)]))
                respond(to: request, result: .object([
                    "contents": .array([
                        .object([
                            "uri": .string(uri),
                            "mimeType": .string("text/plain"),
                            "text": .string(content),
                        ]),
                    ]),
                ]))
                return
            }
        }

        respondError(to: request, error: JSONRPCError(code: -32602, message: "Resource not found: \(uri)"))
    }

    // MARK: - Helpers

    private func respond(to request: JSONRPCRequest, result: JSONValue) {
        let response = JSONRPCResponse(id: request.id, result: result)
        transport.writeResponse(response)
    }

    private func respondError(to request: JSONRPCRequest, error: JSONRPCError) {
        let response = JSONRPCResponse(id: request.id, error: error)
        transport.writeResponse(response)
    }

    /// Report a tool-level failure as an isError result (per MCP spec, tool
    /// failures are results, not protocol errors).
    private func respondToolError(to request: JSONRPCRequest, message: String) {
        respond(to: request, result: .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(message),
                ]),
            ]),
            "isError": .bool(true),
        ]))
    }
}
