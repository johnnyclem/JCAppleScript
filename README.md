# JCAppleScript

A Swift package for executing AppleScript from macOS applications, featuring a built-in **MCP server** that lets AI assistants control macOS apps through pre-built command shortcuts.

## Overview

JCAppleScript provides three components:

1. **JCAppleScript** (library) - Core AppleScript execution engine
2. **AppShortcuts** (library) - Registry of pre-built AppleScript commands for popular macOS apps
3. **jcas-mcp** (executable) - MCP (Model Context Protocol) server for AI-driven app automation

## Installation

### Swift Package Manager

Add JCAppleScript to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/johnnyclem/JCAppleScript.git", from: "2.0.0")
]
```

Then add the targets you need:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        "JCAppleScript",     // Core engine only
        "AppShortcuts",      // App command registry
    ]
)
```

## Quick Start

### Using the Core Engine

```swift
import JCAppleScript

let engine = AppleScriptEngine.shared

// Execute raw AppleScript
let result = try engine.execute("""
    tell application "Finder"
        display dialog "Hello from Swift!"
    end tell
""")

// Send a command to an application
let output = try engine.tell(application: "Music", command: "play")

// Execute a script file with variable substitution
let fileResult = try engine.executeFile(at: "/path/to/script.scpt", variables: ["Alice", "Hello!"])

// Execute JavaScript for Automation (JXA)
let jxa = try engine.execute("Application('Music').play()", language: .javaScript)

// Check syntax without executing
try engine.checkSyntax("tell application \"Finder\" to activate")

// All execution APIs also have async variants
let asyncResult = try await engine.execute("return 40 + 2")
```

When embedding untrusted values in script source, escape them first:

```swift
let userInput = "…"
let script = "display dialog \(AppleScriptString.quoted(userInput))"
```

### Using App Shortcuts

```swift
import AppShortcuts

let registry = AppRegistry.shared

// Execute a pre-built command
let result = try registry.executeCommand("messages.send_message", arguments: [
    "recipient": "+15551234567",
    "message": "Hello from JCAppleScript!"
])

// Discover available commands
let commands = registry.commands(forApp: "Reminders")
for cmd in commands {
    print("\(cmd.id): \(cmd.name) - \(cmd.description)")
}

// Search across all apps
let results = registry.searchCommands("send")
```

### Using the MCP Server

The `jcas-mcp` executable is a [Model Context Protocol](https://modelcontextprotocol.io) server that AI assistants (Claude, GPT, etc.) can use to control macOS applications.

It is published to the [official MCP registry](https://registry.modelcontextprotocol.io) as **`io.github.johnnyclem/jcas-mcp`**, and each GitHub release ships a prebuilt `jcas-mcp.mcpb` bundle (universal macOS binary) that can be installed directly in Claude Desktop via Settings → Extensions.

#### Setup with Claude Desktop

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "applescript": {
      "command": "/path/to/jcas-mcp"
    }
  }
}
```

Build the server:

```bash
swift build -c release
# Binary at: .build/release/jcas-mcp
```

#### Available MCP Tools

| Tool | Description |
|------|-------------|
| `execute_applescript` | Execute arbitrary AppleScript code † |
| `execute_jxa` | Execute JavaScript for Automation (JXA) code † |
| `tell_application` | Send a command to a specific app via `tell` block † |
| `check_script_syntax` | Compile a script (AppleScript or JXA) without executing it |
| `list_running_applications` | Get currently running applications |
| `list_registered_apps` | Browse all registered app command sheets |
| `search_commands` | Search for commands by keyword |
| `run_app_command` | Execute a pre-built command by ID |
| `preview_app_command` | Dry-run: show the exact script a command would execute |
| `get_app_commands` | Get detailed command info for a specific app |

† Hidden and disabled when the server runs in safe mode (see below).

#### Server Configuration

| Environment variable | Effect |
|----------------------|--------|
| `JCAS_SAFE_MODE=1` | Disables the arbitrary-code tools (`execute_applescript`, `execute_jxa`, `tell_application`) and registry commands flagged `dangerous` (e.g. `terminal.run_command`, `safari.run_javascript`). Only pre-built, sanitized registry commands remain available. |
| `JCAS_APP_MANIFESTS=a.json:b.json` | Colon-separated JSON manifest files with additional community app definitions to load at startup. |

CLI flags: `jcas-mcp --manifest` prints the full registry as JSON, `--version` prints the server version, `--help` shows usage.

#### Example AI Interaction

```
User: "Send a message to John saying I'll be late"
AI uses tool: run_app_command
  command_id: "messages.send_message"
  arguments: { "recipient": "John", "message": "I'll be late" }
```

## Supported Applications

JCAppleScript ships with command sheets for 12 built-in macOS apps:

| App | Category | Commands | Examples |
|-----|----------|----------|----------|
| **Messages** | Communication | 6 | Send message, list chats, get participants |
| **Mail** | Communication | 7 | Compose email, search, check mail, list accounts |
| **Reminders** | Productivity | 7 | Create/complete/delete reminders, search, list |
| **Calendar** | Productivity | 6 | Create events, list today's events, upcoming |
| **Notes** | Productivity | 8 | Create/search/append notes, manage folders |
| **Finder** | System | 12 | File operations, folder contents, labels, trash |
| **Safari** | Internet | 10 | Open URLs, manage tabs, run JavaScript, get page content |
| **Music** | Media | 13 | Playback control, playlists, library search, ratings |
| **Terminal** | Development | 8 | Run commands, manage windows/tabs, profiles |
| **System Settings** | System | 13 | Dark mode, volume, notifications, dialogs, system info |
| **Xcode** | Development | 20+ | Open/build/run/test projects, schemes, build logs, debugging |
| **Speech Recognition** | System | 3 | Listen for spoken phrases via the system speech engine |

## Adding Custom App Support

Implement the `ScriptableApp` protocol to add support for any scriptable macOS app:

```swift
import AppShortcuts

struct MyApp: ScriptableApp {
    static let bundleIdentifier = "com.example.myapp"
    static let appName = "MyApp"
    static let description = "My custom application"
    static let category = AppCategory.productivity

    static let commands: [AppCommand] = [
        AppCommand(
            id: "myapp.do_thing",
            name: "Do Thing",
            description: "Performs the thing",
            parameters: [
                CommandParameter(name: "input", description: "The input value"),
            ]
        ) { args in
            let input = args["input", default: ""]
            return """
            tell application "MyApp"
                do thing with "\(input)"
            end tell
            """
        },
    ]
}

// Register at runtime
AppRegistry.shared.register(MyApp.self)
```

## Community App Registry

JCAppleScript is designed to grow through community contributions. The app shortcut system uses a standard protocol (`ScriptableApp`) that makes it easy to:

- **Add new applications** - Implement `ScriptableApp` for any scriptable macOS app
- **Extend existing apps** - Submit new commands for already-registered apps
- **Share command sheets** - Export/import app definitions via JSON manifests

We're building a browsable registry (similar to npmjs.org) where you can:
- Browse applications and their supported AppleScript commands
- Submit new commands for existing apps
- Add entirely new applications to the registry
- Generate JSON manifests for integration with other tools

### Exporting and Importing the Registry

```swift
// Export all registered apps as manifest JSON
let json = try AppRegistry.shared.exportManifestJSON()

// Import community app definitions from a JSON manifest.
// Manifest commands are declarative script templates with ${param}
// placeholders; argument values are sanitized before substitution.
try AppRegistry.shared.loadManifest(contentsOf: URL(fileURLWithPath: "community.json"))
```

Example manifest:

```json
[
  {
    "name": "CoolApp",
    "bundleIdentifier": "com.example.coolapp",
    "description": "A community-contributed app",
    "category": "Productivity",
    "commands": [
      {
        "id": "coolapp.greet",
        "name": "Greet",
        "description": "Show a greeting",
        "script": "tell application \"CoolApp\"\n    greet \"${who}\"\nend tell",
        "parameters": [
          {"name": "who", "description": "Who to greet", "required": true, "type": "string"}
        ]
      }
    ]
  }
]
```

The MCP server loads extra manifests from the `JCAS_APP_MANIFESTS` environment variable at startup.

## Security Model

Registry command arguments are **sanitized before script generation**:

- String, file-path, and date arguments are escaped (`\`, `"`, and control characters) so they cannot break out of AppleScript string literals.
- Integer and boolean arguments are strictly validated/normalized — malformed values are rejected at validation and fall back to declared defaults during generation.
- Values outside a parameter's `allowedValues` list are dropped.
- Arguments that don't correspond to a declared parameter are discarded.

Commands that execute caller-supplied code (Terminal shell commands, Safari JavaScript) are flagged `dangerous` and can be disabled wholesale with `JCAS_SAFE_MODE=1`. Use the `preview_app_command` tool to inspect the exact script a command will run before executing it.

Note that `execute_applescript`, `execute_jxa`, and `tell_application` execute arbitrary code by design — only expose them to clients you trust, or run the server in safe mode.

## Architecture

```
JCAppleScript/
├── Sources/
│   ├── JCAppleScript/           # Core engine
│   │   ├── AppleScriptEngine.swift
│   │   ├── AppleScriptSanitizer.swift
│   │   ├── ScriptResult.swift
│   │   └── ScriptError.swift
│   ├── AppShortcuts/            # App command registry
│   │   ├── AppProtocol.swift    # ScriptableApp protocol
│   │   ├── AppCommand.swift     # Command & parameter types + sanitization
│   │   ├── AppDefinition.swift  # Instance-based app description
│   │   ├── AppManifest.swift    # JSON import/export
│   │   ├── AppRegistry.swift    # Central registry
│   │   └── Apps/                # Built-in app sheets
│   │       ├── MessagesApp.swift
│   │       ├── RemindersApp.swift
│   │       ├── FinderApp.swift
│   │       ├── SafariApp.swift
│   │       ├── MailApp.swift
│   │       ├── CalendarApp.swift
│   │       ├── NotesApp.swift
│   │       ├── MusicApp.swift
│   │       ├── TerminalApp.swift
│   │       └── SystemSettingsApp.swift
│   └── JCAppleScriptMCP/       # MCP server
│       ├── main.swift
│       ├── MCPServer.swift
│       ├── MCPTransport.swift
│       └── MCPTypes.swift
├── Tests/
├── Legacy/                      # Original Obj-C implementation
├── Package.swift
└── LICENSE
```

## Requirements

- macOS 13.0+
- Swift 5.9+

## Legacy

The original Objective-C implementation (2013) is preserved in the `Legacy/` directory for reference. It provided basic NSAppleScript wrapping with variable substitution. The new Swift implementation builds on those concepts while adding the MCP server, app registry, and modern Swift patterns.

## License

MIT License - Copyright (c) 2013 John Clem. See [LICENSE](LICENSE) for details.
