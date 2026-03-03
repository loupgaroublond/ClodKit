//
//  McpSdkServerConfig.swift
//  ClodKit
//
//  Configuration for an SDK MCP server.
//

import Foundation

// MARK: - MCP SDK Server Config

/// Configuration for an SDK MCP server.
public struct McpSdkServerConfig: Sendable, Equatable, Codable {
    /// The server type, always "sdk".
    public let type: String

    /// The server name.
    public let name: String

    public init(name: String) {
        self.type = "sdk"
        self.name = name
    }
}
