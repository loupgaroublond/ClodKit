//
//  McpServerConfigUnions.swift
//  ClodKit
//
//  Union types for MCP server configurations.
//

import Foundation

// MARK: - McpServerConfig

/// Union of all MCP server config types, including those with non-serializable instances.
public enum McpServerConfig: Sendable, Equatable, Codable {
    case stdio(McpStdioServerConfig)
    case sse(McpSSEServerConfig)
    case http(McpHttpServerConfig)
    case sdk(McpSdkServerConfig)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "stdio"
        switch type {
        case "stdio":
            self = .stdio(try McpStdioServerConfig(from: decoder))
        case "sse":
            self = .sse(try McpSSEServerConfig(from: decoder))
        case "http":
            self = .http(try McpHttpServerConfig(from: decoder))
        case "sdk":
            self = .sdk(try McpSdkServerConfig(from: decoder))
        default:
            self = .stdio(try McpStdioServerConfig(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .stdio(let config): try config.encode(to: encoder)
        case .sse(let config): try config.encode(to: encoder)
        case .http(let config): try config.encode(to: encoder)
        case .sdk(let config): try config.encode(to: encoder)
        }
    }
}

// MARK: - McpServerConfigForProcessTransport

/// MCP server config types that can be used with the process transport.
public enum McpServerConfigForProcessTransport: Sendable, Equatable, Codable {
    case stdio(McpStdioServerConfig)
    case sse(McpSSEServerConfig)
    case http(McpHttpServerConfig)
    case sdk(McpSdkServerConfig)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "stdio"
        switch type {
        case "stdio":
            self = .stdio(try McpStdioServerConfig(from: decoder))
        case "sse":
            self = .sse(try McpSSEServerConfig(from: decoder))
        case "http":
            self = .http(try McpHttpServerConfig(from: decoder))
        case "sdk":
            self = .sdk(try McpSdkServerConfig(from: decoder))
        default:
            self = .stdio(try McpStdioServerConfig(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .stdio(let config): try config.encode(to: encoder)
        case .sse(let config): try config.encode(to: encoder)
        case .http(let config): try config.encode(to: encoder)
        case .sdk(let config): try config.encode(to: encoder)
        }
    }
}

// MARK: - McpServerStatusConfig

/// Union of MCP server configs that can appear in server status responses.
public enum McpServerStatusConfig: Sendable, Equatable, Codable {
    case stdio(McpStdioServerConfig)
    case sse(McpSSEServerConfig)
    case http(McpHttpServerConfig)
    case sdk(McpSdkServerConfig)
    case claudeAIProxy(McpClaudeAIProxyServerConfig)

    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "stdio"
        switch type {
        case "stdio":
            self = .stdio(try McpStdioServerConfig(from: decoder))
        case "sse":
            self = .sse(try McpSSEServerConfig(from: decoder))
        case "http":
            self = .http(try McpHttpServerConfig(from: decoder))
        case "sdk":
            self = .sdk(try McpSdkServerConfig(from: decoder))
        case "claudeai-proxy":
            self = .claudeAIProxy(try McpClaudeAIProxyServerConfig(from: decoder))
        default:
            self = .stdio(try McpStdioServerConfig(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .stdio(let config): try config.encode(to: encoder)
        case .sse(let config): try config.encode(to: encoder)
        case .http(let config): try config.encode(to: encoder)
        case .sdk(let config): try config.encode(to: encoder)
        case .claudeAIProxy(let config): try config.encode(to: encoder)
        }
    }
}
