//
//  SDKTaskStartedMessage.swift
//  ClodKit
//
//  Typed representation of task started messages from CLI.
//

import Foundation

// MARK: - SDK Task Started Message

/// Notification that a background task has started.
public struct SDKTaskStartedMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let taskId: String
    public let toolUseId: String?
    public let description: String
    public let taskType: String?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case taskId = "task_id"
        case toolUseId = "tool_use_id"
        case description
        case taskType = "task_type"
        case uuid
        case sessionId = "session_id"
    }
}
