//
//  McpSSEServerConfig.swift
//  ClodKit
//
//  Configuration for an SSE MCP server.
//

import Foundation

// MARK: - MCP SSE Server Config

/// Configuration for a Server-Sent Events MCP server.
public struct McpSSEServerConfig: Sendable, Equatable, Codable {
    /// The server type, always "sse".
    public let type: String

    /// The SSE server URL.
    public let url: String

    /// Optional HTTP headers.
    public let headers: [String: String]?

    public init(url: String, headers: [String: String]? = nil) {
        self.type = "sse"
        self.url = url
        self.headers = headers
    }
}
