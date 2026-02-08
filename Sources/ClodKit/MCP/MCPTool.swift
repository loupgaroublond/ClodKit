//
//  MCPTool.swift
//  ClodKit
//
//  Definition for an SDK MCP tool.
//

import Foundation

// MARK: - MCPToolAnnotations

/// Annotations providing hints about tool behavior.
public struct MCPToolAnnotations: Sendable, Equatable, Codable {
    /// Human-readable title for the tool.
    public var title: String?

    /// Whether this tool only reads data (no side effects).
    public var readOnlyHint: Bool?

    /// Whether this tool may perform destructive operations.
    public var destructiveHint: Bool?

    /// Whether calling this tool repeatedly with the same args has no additional effect.
    public var idempotentHint: Bool?

    /// Whether this tool interacts with the outside world.
    public var openWorldHint: Bool?

    /// Creates new tool annotations.
    public init(
        title: String? = nil,
        readOnlyHint: Bool? = nil,
        destructiveHint: Bool? = nil,
        idempotentHint: Bool? = nil,
        openWorldHint: Bool? = nil
    ) {
        self.title = title
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }

    /// Returns annotations as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let title { dict["title"] = title }
        if let readOnlyHint { dict["readOnlyHint"] = readOnlyHint }
        if let destructiveHint { dict["destructiveHint"] = destructiveHint }
        if let idempotentHint { dict["idempotentHint"] = idempotentHint }
        if let openWorldHint { dict["openWorldHint"] = openWorldHint }
        return dict
    }
}

// MARK: - MCPTool

/// Definition for an SDK MCP tool.
public struct MCPTool: Sendable {
    /// The tool name.
    public let name: String

    /// Description of what the tool does.
    public let description: String

    /// JSON Schema defining the tool's input parameters.
    public let inputSchema: JSONSchema

    /// Optional annotations providing hints about tool behavior.
    public let annotations: MCPToolAnnotations?

    /// Handler that executes when the tool is called.
    public let handler: @Sendable ([String: Any]) async throws -> MCPToolResult

    /// Creates a new MCP tool definition.
    /// - Parameters:
    ///   - name: The tool name.
    ///   - description: Description of what the tool does.
    ///   - inputSchema: JSON Schema defining the tool's input parameters.
    ///   - annotations: Optional annotations providing hints about tool behavior.
    ///   - handler: Handler that executes when the tool is called.
    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        annotations: MCPToolAnnotations? = nil,
        handler: @escaping @Sendable ([String: Any]) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.annotations = annotations
        self.handler = handler
    }

    /// Returns tool definition as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "description": description,
            "inputSchema": inputSchema.toDictionary()
        ]
        if let annotations {
            let annotationsDict = annotations.toDictionary()
            if !annotationsDict.isEmpty {
                dict["annotations"] = annotationsDict
            }
        }
        return dict
    }
}
