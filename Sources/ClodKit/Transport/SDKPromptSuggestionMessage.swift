//
//  SDKPromptSuggestionMessage.swift
//  ClodKit
//
//  Typed representation of prompt suggestion messages from CLI.
//

import Foundation

// MARK: - SDK Prompt Suggestion Message

/// Predicted next user prompt, emitted after each turn when promptSuggestions is enabled.
public struct SDKPromptSuggestionMessage: Sendable, Equatable, Codable {
    public let type: String
    public let suggestion: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, suggestion, uuid
        case sessionId = "session_id"
    }
}
