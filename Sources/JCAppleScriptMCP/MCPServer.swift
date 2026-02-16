import Foundation
import JCAppleScript
import AppShortcuts

/// The MCP server that handles all JSON-RPC method dispatch.
final class MCPServer {
    let transport: MCPTransport
    let engine: AppleScriptEngine
    let registry: AppRegistry
    private var initialized = false

    static let serverName = "jcas-mcp"
    static let serverVersion = "1.0.0"
    static let protocolVersion = "2024-11-05"

    init() {
        self.transport = MCPTransport()
        self.engine = AppleScriptEngine()
        self.registry = AppRegistry.shared
    }

    /// Run the server loop, reading requests from stdin until EOF.
    func run() {
        transport.log("Server starting...")
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
        case "initialized":
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
        initialized = true
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

    // MARK: - Tools

    private func handleToolsList(_ request: JSONRPCRequest) {
        var tools: [JSONValue] = []

        // 1. Generic execute_applescript tool
        tools.append(.object([
            "name": .string("execute_applescript"),
            "description": .string("Execute arbitrary AppleScript code. Use this for custom scripts not covered by app-specific commands."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([
                    "script": .object([
                        "type": .string("string"),
                        "description": .string("The AppleScript source code to execute"),
                    ]),
                    "timeout": .object([
                        "type": .string("number"),
                        "description": .string("Timeout in seconds (default: 30)"),
                    ]),
                ]),
                "required": .array([.string("script")]),
            ]),
        ]))

        // 2. Generic tell_application tool
        tools.append(.object([
            "name": .string("tell_application"),
            "description": .string("Send an AppleScript command to a specific application using a 'tell' block."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([
                    "application": .object([
                        "type": .string("string"),
                        "description": .string("The name of the target application"),
                    ]),
                    "command": .object([
                        "type": .string("string"),
                        "description": .string("The AppleScript command to send within the tell block"),
                    ]),
                ]),
                "required": .array([.string("application"), .string("command")]),
            ]),
        ]))

        // 3. List running applications
        tools.append(.object([
            "name": .string("list_running_applications"),
            "description": .string("Get a list of currently running (non-background) applications."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([:]),
            ]),
        ]))

        // 4. List registered apps
        tools.append(.object([
            "name": .string("list_registered_apps"),
            "description": .string("List all applications in the shortcut registry with their available commands."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([
                    "category": .object([
                        "type": .string("string"),
                        "description": .string("Filter by category (Communication, Productivity, Utilities, Media, Development, Internet, System)"),
                    ]),
                ]),
            ]),
        ]))

        // 5. Search commands
        tools.append(.object([
            "name": .string("search_commands"),
            "description": .string("Search for available app commands by keyword. Returns matching commands across all registered apps."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([
                    "query": .object([
                        "type": .string("string"),
                        "description": .string("Search keyword to match against command names and descriptions"),
                    ]),
                ]),
                "required": .array([.string("query")]),
            ]),
        ]))

        // 6. Run app command
        tools.append(.object([
            "name": .string("run_app_command"),
            "description": .string("Execute a pre-built app command from the shortcut registry. Use list_registered_apps or search_commands to discover available command IDs."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([
                    "command_id": .object([
                        "type": .string("string"),
                        "description": .string("The command ID (e.g. 'messages.send_message', 'reminders.create_reminder')"),
                    ]),
                    "arguments": .object([
                        "type": .string("object"),
                        "description": .string("Key-value arguments for the command. Use list_registered_apps to see required parameters."),
                        "additionalProperties": .object([
                            "type": .string("string"),
                        ]),
                    ]),
                ]),
                "required": .array([.string("command_id")]),
            ]),
        ]))

        // 7. Get app commands (detailed)
        tools.append(.object([
            "name": .string("get_app_commands"),
            "description": .string("Get detailed information about all commands available for a specific application, including parameters and descriptions."),
            "inputSchema": .object([
                "type": .string("object"),
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("The name of the application (e.g. 'Messages', 'Reminders', 'Finder')"),
                    ]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
        ]))

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

        do {
            let result: String
            switch toolName {
            case "execute_applescript":
                result = try callExecuteAppleScript(arguments)
            case "tell_application":
                result = try callTellApplication(arguments)
            case "list_running_applications":
                result = try callListRunningApps()
            case "list_registered_apps":
                result = callListRegisteredApps(arguments)
            case "search_commands":
                result = callSearchCommands(arguments)
            case "run_app_command":
                result = try callRunAppCommand(arguments)
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
            respond(to: request, result: .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string("Error: \(error)"),
                    ]),
                ]),
                "isError": .bool(true),
            ]))
        }
    }

    // MARK: - Tool Implementations

    private func callExecuteAppleScript(_ args: JSONValue?) throws -> String {
        guard let script = args?.stringValue(forKey: "script") else {
            throw ScriptError.invalidScriptSource
        }
        var timeout: TimeInterval? = nil
        if case .double(let t) = args?.objectValue(forKey: "timeout") {
            timeout = t
        } else if case .int(let t) = args?.objectValue(forKey: "timeout") {
            timeout = TimeInterval(t)
        }
        let result = try engine.execute(script, timeout: timeout)
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

    private func callListRunningApps() throws -> String {
        let apps = try engine.listRunningApplications()
        return apps.joined(separator: "\n")
    }

    private func callListRegisteredApps(_ args: JSONValue?) -> String {
        let apps: [any ScriptableApp.Type]
        if let categoryStr = args?.stringValue(forKey: "category"),
           let category = AppCategory(rawValue: categoryStr) {
            apps = registry.apps(in: category)
        } else {
            apps = registry.allApps
        }

        var lines: [String] = []
        let sortedApps = apps.sorted { $0.appName < $1.appName }
        for appType in sortedApps {
            lines.append("## \(appType.appName) [\(appType.category.rawValue)]")
            lines.append("   \(appType.description)")
            lines.append("   Bundle: \(appType.bundleIdentifier)")
            lines.append("   Commands (\(appType.commands.count)):")
            for cmd in appType.commands {
                let params = cmd.parameters.map { p in
                    "\(p.name)\(p.required ? "*" : "")"
                }.joined(separator: ", ")
                lines.append("     - \(cmd.id): \(cmd.name) (\(params))")
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
        for (appType, cmd) in results {
            let params = cmd.parameters.map { "\($0.name)\($0.required ? "*" : ""): \($0.description)" }
            lines.append("[\(appType.appName)] \(cmd.id): \(cmd.name)")
            lines.append("  \(cmd.description)")
            if !params.isEmpty {
                lines.append("  Parameters:")
                for p in params { lines.append("    - \(p)") }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func callRunAppCommand(_ args: JSONValue?) throws -> String {
        guard let commandID = args?.stringValue(forKey: "command_id") else {
            throw ScriptError.scriptExecutionFailed(message: "Missing 'command_id' parameter", errorNumber: nil)
        }
        let arguments = args?.objectValue(forKey: "arguments")?.toStringDict() ?? [:]
        let result = try registry.executeCommand(commandID, arguments: arguments, engine: engine)
        return result.output.isEmpty ? "(command executed successfully with no output)" : result.output
    }

    private func callGetAppCommands(_ args: JSONValue?) -> String {
        guard let appName = args?.stringValue(forKey: "app_name") else {
            return "Missing 'app_name' parameter"
        }
        guard let appType = registry.app(named: appName) else {
            let available = registry.allApps.map { $0.appName }.sorted().joined(separator: ", ")
            return "Unknown app: '\(appName)'. Available apps: \(available)"
        }

        var lines: [String] = [
            "# \(appType.appName)",
            "\(appType.description)",
            "Bundle ID: \(appType.bundleIdentifier)",
            "Category: \(appType.category.rawValue)",
            "",
        ]

        let grouped = Dictionary(grouping: appType.commands, by: { $0.category })
        for (category, cmds) in grouped.sorted(by: { $0.key < $1.key }) {
            lines.append("## \(category)")
            for cmd in cmds {
                lines.append("### \(cmd.name) (\(cmd.id))")
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
        for appType in registry.allApps.sorted(by: { $0.appName < $1.appName }) {
            resources.append(.object([
                "uri": .string("jcas://apps/\(appType.appName.lowercased().replacingOccurrences(of: " ", with: "-"))"),
                "name": .string("\(appType.appName) Commands"),
                "description": .string("AppleScript command reference for \(appType.appName): \(appType.description)"),
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
            let manifest = registry.generateManifest()
            if let data = try? JSONSerialization.data(withJSONObject: manifest, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                respond(to: request, result: .object([
                    "contents": .array([
                        .object([
                            "uri": .string(uri),
                            "mimeType": .string("application/json"),
                            "text": .string(json),
                        ]),
                    ]),
                ]))
            }
            return
        }

        if uri.hasPrefix("jcas://apps/") {
            let appSlug = String(uri.dropFirst("jcas://apps/".count))
            let appName = appSlug.replacingOccurrences(of: "-", with: " ")
            if let appType = registry.app(named: appName) {
                let content = callGetAppCommands(.object(["app_name": .string(appType.appName)]))
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
}
