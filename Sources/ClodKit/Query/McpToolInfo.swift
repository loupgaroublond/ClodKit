//
//  McpToolInfo.swift
//  ClodKit
//
//  MCP tool metadata types for tool introspection.
//

import Foundation

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
