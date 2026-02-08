//
//  SDKToolProgressMessage.swift
//  ClodKit
//
//  Typed representation of tool progress messages from CLI.
//

import Foundation

// MARK: - SDK Tool Progress Message

/// Periodic progress update during tool execution.
public struct SDKToolProgressMessage: Sendable, Equatable, Codable {
    public let type: String
    public let toolUseId: String
    public let toolName: String
    public let parentToolUseId: String?
    public let elapsedTimeSeconds: Double
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type
        case toolUseId = "tool_use_id"
        case toolName = "tool_name"
        case parentToolUseId = "parent_tool_use_id"
        case elapsedTimeSeconds = "elapsed_time_seconds"
        case uuid
        case sessionId = "session_id"
    }
}
