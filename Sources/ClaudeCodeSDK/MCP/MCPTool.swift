//
//  MCPTool.swift
//  ClaudeCodeSDK
//
//  Definition for an SDK MCP tool.
//

import Foundation

// MARK: - MCPTool

/// Definition for an SDK MCP tool.
public struct MCPTool: Sendable {
    /// The tool name.
    public let name: String

    /// Description of what the tool does.
    public let description: String

    /// JSON Schema defining the tool's input parameters.
    public let inputSchema: JSONSchema

    /// Handler that executes when the tool is called.
    public let handler: @Sendable ([String: Any]) async throws -> MCPToolResult

    /// Creates a new MCP tool definition.
    /// - Parameters:
    ///   - name: The tool name.
    ///   - description: Description of what the tool does.
    ///   - inputSchema: JSON Schema defining the tool's input parameters.
    ///   - handler: Handler that executes when the tool is called.
    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        handler: @escaping @Sendable ([String: Any]) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.handler = handler
    }

    /// Returns tool definition as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        [
            "name": name,
            "description": description,
            "inputSchema": inputSchema.toDictionary()
        ]
    }
}
