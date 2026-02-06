//
//  MCPToolResult.swift
//  ClodKit
//
//  Result from MCP tool execution.
//  EXCEPTION: Result contains content types, kept together.
//

import Foundation

// MARK: - MCPToolResult

/// Result from MCP tool execution.
public struct MCPToolResult: Sendable, Equatable {
    /// Content returned by the tool.
    public let content: [MCPContent]

    /// Whether this result represents an error.
    public let isError: Bool

    /// Creates a new tool result.
    /// - Parameters:
    ///   - content: Content returned by the tool.
    ///   - isError: Whether this result represents an error.
    public init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }

    /// Creates a text result.
    /// - Parameter text: The text content.
    /// - Returns: A tool result containing the text.
    public static func text(_ text: String) -> MCPToolResult {
        MCPToolResult(content: [.text(text)])
    }

    /// Creates an error result.
    /// - Parameter message: The error message.
    /// - Returns: A tool result representing an error.
    public static func error(_ message: String) -> MCPToolResult {
        MCPToolResult(content: [.text(message)], isError: true)
    }

    /// Returns the result as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "content": content.map { $0.toDictionary() }
        ]
        if isError {
            dict["isError"] = true
        }
        return dict
    }
}

// MARK: - MCPContent

/// MCP content types for tool results.
public enum MCPContent: Sendable, Equatable {
    /// Text content.
    case text(String)

    /// Image content with base64 data and MIME type.
    case image(data: Data, mimeType: String)

    /// Resource content with URI and optional text.
    case resource(uri: String, mimeType: String?, text: String?)

    /// Returns the content as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        switch self {
        case .text(let text):
            return ["type": "text", "text": text]
        case .image(let data, let mimeType):
            return ["type": "image", "data": data.base64EncodedString(), "mimeType": mimeType]
        case .resource(let uri, let mimeType, let text):
            var dict: [String: Any] = ["type": "resource", "uri": uri]
            if let mimeType { dict["mimeType"] = mimeType }
            if let text { dict["text"] = text }
            return dict
        }
    }
}
