//
//  MCPToolBuilder.swift
//  ClodKit
//
//  Result builder for convenient tool array construction.
//  EXCEPTION: Result builder and its convenience function are kept together.
//

import Foundation

// MARK: - MCPToolBuilder

/// Result builder for convenient tool array construction.
@resultBuilder
public struct MCPToolBuilder {
    public static func buildBlock(_ components: [MCPTool]...) -> [MCPTool] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[MCPTool]]) -> [MCPTool] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [MCPTool]?) -> [MCPTool] {
        component ?? []
    }

    public static func buildEither(first component: [MCPTool]) -> [MCPTool] {
        component
    }

    public static func buildEither(second component: [MCPTool]) -> [MCPTool] {
        component
    }

    public static func buildExpression(_ expression: MCPTool) -> [MCPTool] {
        [expression]
    }
}

// MARK: - Convenience Function

/// Creates an SDK MCP server with the specified tools using a result builder.
/// - Parameters:
///   - name: The server name.
///   - version: The server version (default "1.0.0").
///   - tools: Builder closure returning the tools.
/// - Returns: A new SDKMCPServer instance.
///
/// Example:
/// ```swift
/// let server = createSDKMCPServer(name: "my-tools", version: "1.0.0") {
///     MCPTool(
///         name: "echo",
///         description: "Echoes the input",
///         inputSchema: JSONSchema(
///             properties: ["message": .string("Message to echo")],
///             required: ["message"]
///         ),
///         handler: { args in
///             let message = args["message"] as? String ?? ""
///             return .text(message)
///         }
///     )
/// }
/// ```
public func createSDKMCPServer(
    name: String,
    version: String = "1.0.0",
    @MCPToolBuilder tools: () -> [MCPTool]
) -> SDKMCPServer {
    SDKMCPServer(name: name, version: version, tools: tools())
}
