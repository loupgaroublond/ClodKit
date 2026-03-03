//
//  SDKTaskProgressMessage.swift
//  ClodKit
//
//  Typed representation of task progress messages from CLI.
//

import Foundation

// MARK: - SDK Task Progress Message

/// Progress update for a running background task.
public struct SDKTaskProgressMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let taskId: String
    public let toolUseId: String?
    public let description: String
    public let usage: TaskUsage
    public let lastToolName: String?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case taskId = "task_id"
        case toolUseId = "tool_use_id"
        case description, usage
        case lastToolName = "last_tool_name"
        case uuid
        case sessionId = "session_id"
    }
}
