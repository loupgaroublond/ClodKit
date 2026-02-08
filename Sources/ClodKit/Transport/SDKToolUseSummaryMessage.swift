//
//  SDKToolUseSummaryMessage.swift
//  ClodKit
//
//  Typed representation of tool use summary messages from CLI.
//

import Foundation

// MARK: - SDK Tool Use Summary Message

/// Summary of one or more preceding tool uses.
public struct SDKToolUseSummaryMessage: Sendable, Equatable, Codable {
    public let type: String
    public let summary: String
    public let precedingToolUseIds: [String]
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, summary
        case precedingToolUseIds = "preceding_tool_use_ids"
        case uuid
        case sessionId = "session_id"
    }
}
