//
//  SDKMCPServer.swift
//  ClaudeCodeSDK
//
//  In-process MCP server that hosts SDK-defined tools.
//

import Foundation

// MARK: - SDKMCPServer

/// In-process MCP server for SDK tools.
///
/// This class allows you to define custom MCP tools that run in-process
/// rather than in a separate server process. The tools are registered
/// with the CLI via the control protocol.
///
/// Thread-safe: All properties are immutable and Sendable.
public final class SDKMCPServer: Sendable {
    /// The server name (used as identifier).
    public let name: String

    /// The server version.
    public let version: String

    /// Tools indexed by name.
    private let tools: [String: MCPTool]

    /// Creates a new SDK MCP server with the specified tools.
    /// - Parameters:
    ///   - name: The server name.
    ///   - version: The server version (default "1.0.0").
    ///   - tools: Array of tools to register.
    public init(name: String, version: String = "1.0.0", tools: [MCPTool]) {
        self.name = name
        self.version = version
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    /// Get tool definitions for tools/list response.
    /// - Returns: Array of tool definition dictionaries.
    public func listTools() -> [[String: Any]] {
        tools.values.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "inputSchema": tool.inputSchema.toDictionary()
            ]
        }
    }

    /// Get a specific tool by name.
    /// - Parameter name: The tool name.
    /// - Returns: The tool if found, nil otherwise.
    public func getTool(named name: String) -> MCPTool? {
        tools[name]
    }

    /// Call a tool by name.
    /// - Parameters:
    ///   - name: The tool name.
    ///   - arguments: Arguments to pass to the tool handler.
    /// - Returns: The tool result.
    /// - Throws: MCPServerError.toolNotFound if tool doesn't exist.
    public func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        guard let tool = tools[name] else {
            throw MCPServerError.toolNotFound(name)
        }
        return try await tool.handler(arguments)
    }

    /// Get server capabilities for initialize response.
    public var capabilities: [String: Any] {
        ["tools": ["listChanged": false]]
    }

    /// Get server info for initialize response.
    public var serverInfo: [String: Any] {
        ["name": name, "version": version]
    }

    /// List of all tool names.
    public var toolNames: [String] {
        Array(tools.keys)
    }

    /// Number of registered tools.
    public var toolCount: Int {
        tools.count
    }
}

// MARK: - MCPServerError

/// Errors from MCP server operations.
public enum MCPServerError: Error, Sendable, Equatable {
    /// The requested tool was not found.
    case toolNotFound(String)

    /// Invalid arguments were passed to a tool.
    case invalidArguments(String)

    /// Server is not initialized.
    case notInitialized(String)

    /// Unknown method in JSONRPC request.
    case unknownMethod(String)
}

extension MCPServerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments(let reason):
            return "Invalid arguments: \(reason)"
        case .notInitialized(let server):
            return "Server not initialized: \(server)"
        case .unknownMethod(let method):
            return "Unknown method: \(method)"
        }
    }
}
