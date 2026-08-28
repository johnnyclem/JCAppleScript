import Foundation
import AppShortcuts

let arguments = CommandLine.arguments.dropFirst()

switch arguments.first {
case "--version", "-v":
    print("\(MCPServer.serverName) \(MCPServer.serverVersion)")

case "--manifest":
    // Print the full app registry as JSON and exit (for tooling / the
    // community registry site).
    do {
        let data = try AppRegistry.shared.exportManifestJSON()
        print(String(data: data, encoding: .utf8) ?? "[]")
    } catch {
        FileHandle.standardError.write(Data("Failed to export manifest: \(error.localizedDescription)\n".utf8))
        exit(1)
    }

case "--help", "-h":
    print("""
    \(MCPServer.serverName) - MCP server exposing AppleScript automation for macOS apps

    Usage: jcas-mcp [option]

    Options:
      (none)       Run the MCP server on stdio (JSON-RPC 2.0, newline-delimited)
      --manifest   Print the app registry as JSON and exit
      --version    Print the server version and exit
      --help       Show this help

    Environment:
      \(MCPServer.safeModeEnvVar)=1            Disable tools that execute arbitrary code
      \(MCPServer.manifestPathsEnvVar)=a.json:b.json  Load extra app manifests at startup
    """)

case .some(let unknown):
    FileHandle.standardError.write(Data("Unknown option: \(unknown) (try --help)\n".utf8))
    exit(64)

case nil:
    // Disable stdout buffering so JSON-RPC messages are sent immediately
    setbuf(stdout, nil)
    let server = MCPServer()
    server.run()
}
