//
//  ControlRequests.swift
//  ClodKit
//
//  Control protocol request types and ControlRequestPayload discriminated union.
//  EXCEPTION: Request types form a discriminated union pattern and are kept together.
//

import Foundation

// MARK: - Request Payload Types (SDK -> CLI)

/// Initialize request to configure the SDK session.
public struct InitializeRequest: Codable, Sendable, Equatable {
    public static let subtype = "initialize"
    public let subtype: String
    public let hooks: [String: [HookMatcherConfig]]?
    public let sdkMcpServers: [String]?
    public let systemPrompt: String?
    public let appendSystemPrompt: String?

    enum CodingKeys: String, CodingKey {
        case subtype
        case hooks
        case sdkMcpServers = "sdk_mcp_servers"
        case systemPrompt = "system_prompt"
        case appendSystemPrompt = "append_system_prompt"
    }

    public init(
        hooks: [String: [HookMatcherConfig]]? = nil,
        sdkMcpServers: [String]? = nil,
        systemPrompt: String? = nil,
        appendSystemPrompt: String? = nil
    ) {
        self.subtype = Self.subtype
        self.hooks = hooks
        self.sdkMcpServers = sdkMcpServers
        self.systemPrompt = systemPrompt
        self.appendSystemPrompt = appendSystemPrompt
    }
}

/// Set permission mode request.
public struct SetPermissionModeRequest: Codable, Sendable, Equatable {
    public static let subtype = "set_permission_mode"
    public let subtype: String
    public let mode: PermissionMode

    public init(mode: PermissionMode) {
        self.subtype = Self.subtype
        self.mode = mode
    }
}

/// Set model request.
public struct SetModelRequest: Codable, Sendable, Equatable {
    public static let subtype = "set_model"
    public let subtype: String
    public let model: String?

    public init(model: String?) {
        self.subtype = Self.subtype
        self.model = model
    }
}

/// Set max thinking tokens request.
public struct SetMaxThinkingTokensRequest: Codable, Sendable, Equatable {
    public static let subtype = "set_max_thinking_tokens"
    public let subtype: String
    public let maxThinkingTokens: Int?

    enum CodingKeys: String, CodingKey {
        case subtype
        case maxThinkingTokens = "max_thinking_tokens"
    }

    public init(maxThinkingTokens: Int?) {
        self.subtype = Self.subtype
        self.maxThinkingTokens = maxThinkingTokens
    }
}

/// Rewind files request for undoing changes.
public struct RewindFilesRequest: Codable, Sendable, Equatable {
    public static let subtype = "rewind_files"
    public let subtype: String
    public let userMessageId: String
    public let dryRun: Bool?

    enum CodingKeys: String, CodingKey {
        case subtype
        case userMessageId = "user_message_id"
        case dryRun = "dry_run"
    }

    public init(userMessageId: String, dryRun: Bool? = nil) {
        self.subtype = Self.subtype
        self.userMessageId = userMessageId
        self.dryRun = dryRun
    }
}

/// MCP reconnect request.
public struct MCPReconnectRequest: Codable, Sendable, Equatable {
    public static let subtype = "mcp_reconnect"
    public let subtype: String
    public let serverName: String

    enum CodingKeys: String, CodingKey {
        case subtype
        case serverName = "server_name"
    }

    public init(serverName: String) {
        self.subtype = Self.subtype
        self.serverName = serverName
    }
}

/// MCP toggle request.
public struct MCPToggleRequest: Codable, Sendable, Equatable {
    public static let subtype = "mcp_toggle"
    public let subtype: String
    public let serverName: String
    public let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case subtype
        case serverName = "server_name"
        case enabled
    }

    public init(serverName: String, enabled: Bool) {
        self.subtype = Self.subtype
        self.serverName = serverName
        self.enabled = enabled
    }
}

/// Set MCP servers configuration request.
public struct SetMcpServersRequest: Codable, Sendable, Equatable {
    public static let subtype = "mcp_set_servers"
    public let subtype: String
    public let servers: [String: JSONValue]

    public init(servers: [String: JSONValue]) {
        self.subtype = Self.subtype
        self.servers = servers
    }
}

/// MCP message request for JSONRPC communication.
public struct MCPMessageRequest: Codable, Sendable, Equatable {
    public static let subtype = "mcp_message"
    public let subtype: String
    public let serverName: String
    public let message: JSONRPCMessage

    enum CodingKeys: String, CodingKey {
        case subtype
        case serverName = "server_name"
        case message
    }

    public init(serverName: String, message: JSONRPCMessage) {
        self.subtype = Self.subtype
        self.serverName = serverName
        self.message = message
    }
}

// MARK: - Request Payload Types (CLI -> SDK)

/// Can use tool permission check request from CLI.
public struct CanUseToolRequest: Codable, Sendable, Equatable {
    public static let subtype = "can_use_tool"
    public let subtype: String
    public let toolName: String
    public let input: [String: JSONValue]
    public let permissionSuggestions: [PermissionUpdate]?
    public let blockedPath: String?
    public let decisionReason: String?
    public let toolUseId: String
    public let agentId: String?

    enum CodingKeys: String, CodingKey {
        case subtype
        case toolName = "tool_name"
        case input
        case permissionSuggestions = "permission_suggestions"
        case blockedPath = "blocked_path"
        case decisionReason = "decision_reason"
        case toolUseId = "tool_use_id"
        case agentId = "agent_id"
    }

    public init(
        toolName: String,
        input: [String: JSONValue],
        toolUseId: String,
        permissionSuggestions: [PermissionUpdate]? = nil,
        blockedPath: String? = nil,
        decisionReason: String? = nil,
        agentId: String? = nil
    ) {
        self.subtype = Self.subtype
        self.toolName = toolName
        self.input = input
        self.toolUseId = toolUseId
        self.permissionSuggestions = permissionSuggestions
        self.blockedPath = blockedPath
        self.decisionReason = decisionReason
        self.agentId = agentId
    }
}

/// Hook callback request from CLI.
public struct HookCallbackRequest: Codable, Sendable, Equatable {
    public static let subtype = "hook_callback"
    public let subtype: String
    public let callbackId: String
    public let input: [String: JSONValue]
    public let toolUseId: String?

    enum CodingKeys: String, CodingKey {
        case subtype
        case callbackId = "callback_id"
        case input
        case toolUseId = "tool_use_id"
    }

    public init(callbackId: String, input: [String: JSONValue], toolUseId: String? = nil) {
        self.subtype = Self.subtype
        self.callbackId = callbackId
        self.input = input
        self.toolUseId = toolUseId
    }
}

// MARK: - Discriminated Union for Request Payloads

/// Discriminated union for all control request payloads.
public enum ControlRequestPayload: Codable, Sendable, Equatable {
    // SDK -> CLI requests
    case initialize(InitializeRequest)
    case interrupt
    case setPermissionMode(SetPermissionModeRequest)
    case setModel(SetModelRequest)
    case setMaxThinkingTokens(SetMaxThinkingTokensRequest)
    case rewindFiles(RewindFilesRequest)
    case mcpStatus
    case mcpReconnect(MCPReconnectRequest)
    case mcpToggle(MCPToggleRequest)
    case setMcpServers(SetMcpServersRequest)
    case mcpMessage(MCPMessageRequest)

    // CLI -> SDK requests
    case canUseTool(CanUseToolRequest)
    case hookCallback(HookCallbackRequest)

    private enum CodingKeys: String, CodingKey {
        case subtype
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let subtype = try container.decode(String.self, forKey: .subtype)

        switch subtype {
        case "initialize":
            self = .initialize(try InitializeRequest(from: decoder))
        case "interrupt":
            self = .interrupt
        case "set_permission_mode":
            self = .setPermissionMode(try SetPermissionModeRequest(from: decoder))
        case "set_model":
            self = .setModel(try SetModelRequest(from: decoder))
        case "set_max_thinking_tokens":
            self = .setMaxThinkingTokens(try SetMaxThinkingTokensRequest(from: decoder))
        case "rewind_files":
            self = .rewindFiles(try RewindFilesRequest(from: decoder))
        case "mcp_status":
            self = .mcpStatus
        case "mcp_reconnect":
            self = .mcpReconnect(try MCPReconnectRequest(from: decoder))
        case "mcp_toggle":
            self = .mcpToggle(try MCPToggleRequest(from: decoder))
        case "mcp_set_servers":
            self = .setMcpServers(try SetMcpServersRequest(from: decoder))
        case "mcp_message":
            self = .mcpMessage(try MCPMessageRequest(from: decoder))
        case "can_use_tool":
            self = .canUseTool(try CanUseToolRequest(from: decoder))
        case "hook_callback":
            self = .hookCallback(try HookCallbackRequest(from: decoder))
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unknown control request subtype: \(subtype)"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .initialize(let req):
            try req.encode(to: encoder)
        case .interrupt:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("interrupt", forKey: .subtype)
        case .setPermissionMode(let req):
            try req.encode(to: encoder)
        case .setModel(let req):
            try req.encode(to: encoder)
        case .setMaxThinkingTokens(let req):
            try req.encode(to: encoder)
        case .rewindFiles(let req):
            try req.encode(to: encoder)
        case .mcpStatus:
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("mcp_status", forKey: .subtype)
        case .mcpReconnect(let req):
            try req.encode(to: encoder)
        case .mcpToggle(let req):
            try req.encode(to: encoder)
        case .setMcpServers(let req):
            try req.encode(to: encoder)
        case .mcpMessage(let req):
            try req.encode(to: encoder)
        case .canUseTool(let req):
            try req.encode(to: encoder)
        case .hookCallback(let req):
            try req.encode(to: encoder)
        }
    }

    /// The subtype string for this payload.
    public var subtype: String {
        switch self {
        case .initialize: return "initialize"
        case .interrupt: return "interrupt"
        case .setPermissionMode: return "set_permission_mode"
        case .setModel: return "set_model"
        case .setMaxThinkingTokens: return "set_max_thinking_tokens"
        case .rewindFiles: return "rewind_files"
        case .mcpStatus: return "mcp_status"
        case .mcpReconnect: return "mcp_reconnect"
        case .mcpToggle: return "mcp_toggle"
        case .setMcpServers: return "mcp_set_servers"
        case .mcpMessage: return "mcp_message"
        case .canUseTool: return "can_use_tool"
        case .hookCallback: return "hook_callback"
        }
    }
}

// MARK: - Full Control Request Type

/// Full control request with typed payload.
public struct FullControlRequest: Codable, Sendable, Equatable {
    public let type: String
    public let requestId: String
    public let request: ControlRequestPayload

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case request
    }

    public init(requestId: String, request: ControlRequestPayload) {
        self.type = "control_request"
        self.requestId = requestId
        self.request = request
    }
}
