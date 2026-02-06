//
//  MCPServerConfig.swift
//  ClodKit
//
//  Configuration for an external MCP server.
//

import Foundation

// MARK: - MCP Server Configuration

/// Configuration for an external MCP server.
public struct MCPServerConfig: Sendable, Equatable {
    /// The command to run to start the server.
    public let command: String

    /// Arguments to pass to the command.
    public let args: [String]

    /// Environment variables for the server.
    public let env: [String: String]?

    /// Creates an MCP server configuration.
    /// - Parameters:
    ///   - command: The command to run.
    ///   - args: Arguments for the command.
    ///   - env: Optional environment variables.
    public init(command: String, args: [String] = [], env: [String: String]? = nil) {
        self.command = command
        self.args = args
        self.env = env
    }

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["command": command]
        if !args.isEmpty {
            dict["args"] = args
        }
        if let env = env, !env.isEmpty {
            dict["env"] = env
        }
        return dict
    }
}
