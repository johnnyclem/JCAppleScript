import Foundation

// Disable stdout buffering so JSON-RPC messages are sent immediately
setbuf(stdout, nil)

let server = MCPServer()
server.run()
