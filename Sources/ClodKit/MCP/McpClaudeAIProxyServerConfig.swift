//
//  McpClaudeAIProxyServerConfig.swift
//  ClodKit
//
//  Configuration for a Claude AI proxy MCP server.
//

import Foundation

// MARK: - MCP Claude AI Proxy Server Config

/// Configuration for a Claude AI proxy MCP server.
public struct McpClaudeAIProxyServerConfig: Sendable, Equatable, Codable {
    /// The server type, always "claudeai-proxy".
    public let type: String

    /// The proxy URL.
    public let url: String

    /// The server identifier.
    public let id: String

    public init(url: String, id: String) {
        self.type = "claudeai-proxy"
        self.url = url
        self.id = id
    }
}
