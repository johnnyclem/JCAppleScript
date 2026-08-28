import Foundation

/// Handles stdio-based JSON-RPC 2.0 transport for the MCP server.
///
/// Reads newline-delimited JSON from stdin and writes responses to stdout.
/// All logging goes to stderr to keep the JSON-RPC channel clean.
final class MCPTransport {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
    }

    /// Read the next JSON-RPC request from stdin. Returns nil on EOF.
    ///
    /// Blank lines are skipped and malformed lines are answered with a
    /// JSON-RPC parse error; neither shuts the server down.
    func readRequest() -> JSONRPCRequest? {
        while let line = readLine(strippingNewline: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            do {
                return try decoder.decode(JSONRPCRequest.self, from: Data(trimmed.utf8))
            } catch {
                log("Failed to decode request: \(error)")
                writeResponse(JSONRPCResponse(id: nil, error: .parseError))
            }
        }
        return nil
    }

    /// Write a JSON-RPC response to stdout.
    func writeResponse(_ response: JSONRPCResponse) {
        do {
            let data = try encoder.encode(response)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            print(jsonString)
            fflush(stdout)
        } catch {
            log("Failed to encode response: \(error)")
        }
    }

    /// Send a JSON-RPC notification (no id) to the client.
    func writeNotification(method: String, params: JSONValue? = nil) {
        let notification = JSONRPCRequest(id: nil, method: method, params: params)
        do {
            let data = try encoder.encode(notification)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            print(jsonString)
            fflush(stdout)
        } catch {
            log("Failed to encode notification: \(error)")
        }
    }

    /// Log a message to stderr (keeps stdout clean for JSON-RPC).
    func log(_ message: String) {
        FileHandle.standardError.write(Data("[jcas-mcp] \(message)\n".utf8))
    }
}
