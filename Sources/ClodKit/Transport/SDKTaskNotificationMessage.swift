//
//  SDKTaskNotificationMessage.swift
//  ClodKit
//
//  Typed representation of task notification messages from CLI.
//

import Foundation

// MARK: - SDK Task Notification Message

/// Notification when a background task completes, fails, or stops.
public struct SDKTaskNotificationMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let taskId: String
    public let toolUseId: String?
    public let status: String
    public let outputFile: String
    public let summary: String
    public let usage: TaskUsage?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case taskId = "task_id"
        case toolUseId = "tool_use_id"
        case status
        case outputFile = "output_file"
        case summary, usage, uuid
        case sessionId = "session_id"
    }
}

// MARK: - Task Usage

/// Token and tool usage statistics for a task.
public struct TaskUsage: Sendable, Equatable, Codable {
    public let totalTokens: Int
    public let toolUses: Int
    public let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case toolUses = "tool_uses"
        case durationMs = "duration_ms"
    }
}
