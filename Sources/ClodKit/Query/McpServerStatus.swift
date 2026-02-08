//
//  McpServerStatus.swift
//  ClodKit
//
//  MCP server status types for server introspection.
//

import Foundation

// MARK: - MCP Server Status

/// Status information for an MCP server.
public struct McpServerStatus: Sendable, Equatable, Codable {
    /// The server name.
    public let name: String

    /// Connection status ("connected", "failed", "needs-auth", "pending", "disabled").
    public let status: String

    /// Server info from the MCP protocol.
    public let serverInfo: McpServerInfo?

    /// Error message if the server is in a failed state.
    public let error: String?

    /// Server configuration.
    public let config: JSONValue?

    /// Server scope ("project", "user", "local", "claudeai", "managed").
    public let scope: String?

    /// Tools provided by this server.
    public let tools: [McpToolInfo]?

    enum CodingKeys: String, CodingKey {
        case name, status
        case serverInfo = "server_info"
        case error, config, scope, tools
    }

    public init(
        name: String,
        status: String,
        serverInfo: McpServerInfo? = nil,
        error: String? = nil,
        config: JSONValue? = nil,
        scope: String? = nil,
        tools: [McpToolInfo]? = nil
    ) {
        self.name = name
        self.status = status
        self.serverInfo = serverInfo
        self.error = error
        self.config = config
        self.scope = scope
        self.tools = tools
    }
}

// MARK: - MCP Server Info

/// Server information from the MCP protocol handshake.
public struct McpServerInfo: Sendable, Equatable, Codable {
    /// The server name.
    public let name: String

    /// The server version.
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

// MARK: - MCP Tool Info

/// Information about a tool provided by an MCP server.
public struct McpToolInfo: Sendable, Equatable, Codable {
    /// The tool name.
    public let name: String

    /// Description of the tool.
    public let description: String?

    /// Tool annotations for safety and behavior classification.
    public let annotations: McpToolAnnotations?

    public init(name: String, description: String? = nil, annotations: McpToolAnnotations? = nil) {
        self.name = name
        self.description = description
        self.annotations = annotations
    }
}

// MARK: - MCP Tool Annotations

/// Annotations describing tool behavior characteristics.
public struct McpToolAnnotations: Sendable, Equatable, Codable {
    /// Whether the tool only reads data.
    public let readOnly: Bool?

    /// Whether the tool performs destructive operations.
    public let destructive: Bool?

    /// Whether the tool accesses external resources.
    public let openWorld: Bool?

    enum CodingKeys: String, CodingKey {
        case readOnly = "read_only"
        case destructive
        case openWorld = "open_world"
    }

    public init(readOnly: Bool? = nil, destructive: Bool? = nil, openWorld: Bool? = nil) {
        self.readOnly = readOnly
        self.destructive = destructive
        self.openWorld = openWorld
    }
}
