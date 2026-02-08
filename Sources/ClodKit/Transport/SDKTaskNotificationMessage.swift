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
    public let status: String
    public let outputFile: String
    public let summary: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case taskId = "task_id"
        case status
        case outputFile = "output_file"
        case summary, uuid
        case sessionId = "session_id"
    }
}
