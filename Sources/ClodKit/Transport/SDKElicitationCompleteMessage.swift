//
//  SDKElicitationCompleteMessage.swift
//  ClodKit
//
//  Typed representation of elicitation complete messages from CLI.
//

import Foundation

// MARK: - SDK Elicitation Complete Message

/// Notification that an MCP elicitation has completed.
public struct SDKElicitationCompleteMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let mcpServerName: String
    public let elicitationId: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case mcpServerName = "mcp_server_name"
        case elicitationId = "elicitation_id"
        case uuid
        case sessionId = "session_id"
    }
}
