//
//  McpStdioServerConfig.swift
//  ClodKit
//
//  Configuration for a stdio MCP server.
//

import Foundation

// MARK: - MCP Stdio Server Config

/// Configuration for a stdio MCP server.
public struct McpStdioServerConfig: Sendable, Equatable, Codable {
    /// The server type, always "stdio".
    public let type: String

    /// The command to run to start the server.
    public let command: String

    /// Arguments to pass to the command.
    public let args: [String]?

    /// Environment variables for the server.
    public let env: [String: String]?

    public init(command: String, args: [String]? = nil, env: [String: String]? = nil) {
        self.type = "stdio"
        self.command = command
        self.args = args
        self.env = env
    }
}
