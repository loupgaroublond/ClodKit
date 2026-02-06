//
//  MCPServerRouter.swift
//  ClaudeCodeSDK
//
//  Actor routing JSONRPC messages to in-process SDK MCP servers.
//

import Foundation

/// Actor routing MCP messages to in-process SDK servers.
///
/// This actor manages a collection of SDKMCPServer instances and routes
/// incoming JSONRPC messages to the appropriate server based on the
/// server name in the request.
public actor MCPServerRouter {
    /// Registered servers by name.
    private var servers: [String: SDKMCPServer] = [:]

    /// Servers that have completed initialization.
    private var initialized: Set<String> = []

    /// Creates a new MCP server router.
    public init() {}

    // MARK: - Server Management

    /// Register an SDK MCP server.
    /// - Parameter server: The server to register.
    public func registerServer(_ server: SDKMCPServer) {
        servers[server.name] = server
    }

    /// Unregister an SDK MCP server.
    /// - Parameter name: The name of the server to unregister.
    public func unregisterServer(name: String) {
        servers.removeValue(forKey: name)
        initialized.remove(name)
    }

    /// Get registered server names for CLI config.
    /// - Returns: Array of registered server names.
    public func getServerNames() -> [String] {
        Array(servers.keys)
    }

    /// Check if a server is registered.
    /// - Parameter name: The server name to check.
    /// - Returns: True if the server is registered.
    public func hasServer(name: String) -> Bool {
        servers[name] != nil
    }

    /// Check if a server has been initialized.
    /// - Parameter name: The server name to check.
    /// - Returns: True if the server has been initialized.
    public func isInitialized(name: String) -> Bool {
        initialized.contains(name)
    }

    // MARK: - Message Routing

    /// Route a JSONRPC message to the appropriate server.
    /// - Parameter request: The MCP message request containing server name and JSONRPC message.
    /// - Returns: The JSONRPC response message.
    public func route(_ request: MCPMessageRequest) async -> JSONRPCMessage {
        guard let server = servers[request.serverName] else {
            return createErrorResponse(
                id: request.message.id,
                code: JSONRPCError.methodNotFound,
                message: "Server not found: \(request.serverName)"
            )
        }

        let message = request.message
        guard let method = message.method else {
            return createErrorResponse(
                id: message.id,
                code: JSONRPCError.invalidRequest,
                message: "Missing method in request"
            )
        }

        switch method {
        case "initialize":
            return handleInitialize(server: server, id: message.id)

        case "notifications/initialized":
            initialized.insert(request.serverName)
            // Notifications don't require a response, but we return an empty success
            return createSuccessResponse(id: message.id, result: .object([:]))

        case "tools/list":
            return handleToolsList(server: server, id: message.id)

        case "tools/call":
            return await handleToolsCall(server: server, message: message)

        default:
            return createErrorResponse(
                id: message.id,
                code: JSONRPCError.methodNotFound,
                message: "Method not found: \(method)"
            )
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(server: SDKMCPServer, id: JSONValue?) -> JSONRPCMessage {
        let result: [String: JSONValue] = [
            "protocolVersion": .string("2024-11-05"),
            "capabilities": JSONValue.from(server.capabilities),
            "serverInfo": JSONValue.from(server.serverInfo)
        ]
        return createSuccessResponse(id: id, result: .object(result))
    }

    private func handleToolsList(server: SDKMCPServer, id: JSONValue?) -> JSONRPCMessage {
        let tools = server.listTools()
        let toolsValue = tools.map { JSONValue.from($0) }
        return createSuccessResponse(id: id, result: .object(["tools": .array(toolsValue)]))
    }

    private func handleToolsCall(server: SDKMCPServer, message: JSONRPCMessage) async -> JSONRPCMessage {
        // Extract tool name from params
        guard let params = message.params,
              case .object(let paramsDict) = params,
              let nameValue = paramsDict["name"],
              case .string(let toolName) = nameValue else {
            return createErrorResponse(
                id: message.id,
                code: JSONRPCError.invalidParams,
                message: "Invalid params: missing tool name"
            )
        }

        // Extract arguments (optional)
        let arguments: [String: Any]
        if let argsValue = paramsDict["arguments"],
           case .object(let argsDict) = argsValue {
            arguments = argsDict.mapValues { $0.toAny() }
        } else {
            arguments = [:]
        }

        // Call the tool
        do {
            let result = try await server.callTool(name: toolName, arguments: arguments)
            let contentValue = result.content.map { JSONValue.from($0.toDictionary()) }
            var resultDict: [String: JSONValue] = [
                "content": .array(contentValue)
            ]
            if result.isError {
                resultDict["isError"] = .bool(true)
            }
            return createSuccessResponse(id: message.id, result: .object(resultDict))
        } catch let error as MCPServerError {
            return createErrorResponse(
                id: message.id,
                code: -32000,  // Server error
                message: error.localizedDescription
            )
        } catch {
            return createErrorResponse(
                id: message.id,
                code: JSONRPCError.internalError,
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Response Helpers

    private func createSuccessResponse(id: JSONValue?, result: JSONValue) -> JSONRPCMessage {
        JSONRPCMessage(
            jsonrpc: "2.0",
            id: id,
            result: result
        )
    }

    private func createErrorResponse(id: JSONValue?, code: Int, message: String) -> JSONRPCMessage {
        JSONRPCMessage(
            jsonrpc: "2.0",
            id: id,
            error: JSONRPCError(code: code, message: message)
        )
    }
}

