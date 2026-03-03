//
//  McpHttpServerConfig.swift
//  ClodKit
//
//  Configuration for an HTTP MCP server.
//

import Foundation

// MARK: - MCP HTTP Server Config

/// Configuration for an HTTP MCP server.
public struct McpHttpServerConfig: Sendable, Equatable, Codable {
    /// The server type, always "http".
    public let type: String

    /// The HTTP server URL.
    public let url: String

    /// Optional HTTP headers.
    public let headers: [String: String]?

    public init(url: String, headers: [String: String]? = nil) {
        self.type = "http"
        self.url = url
        self.headers = headers
    }
}
