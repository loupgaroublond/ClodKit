//
//  SDKUserMessage.swift
//  ClodKit
//
//  User message type for streaming input to a query.
//

import Foundation

// MARK: - SDK User Message

/// A user message for streaming input to an active query.
public struct SDKUserMessage: Sendable, Equatable, Codable {
    /// The message type (always "user").
    public let type: String

    /// The message content.
    public let message: UserMessageContent

    /// Creates a new user message with text content.
    /// - Parameter content: The text content of the message.
    public init(content: String) {
        self.type = "user"
        self.message = UserMessageContent(role: "user", content: content)
    }
}

// MARK: - User Message Content

/// Content of a user message.
public struct UserMessageContent: Sendable, Equatable, Codable {
    /// The role (always "user").
    public let role: String

    /// The text content.
    public let content: String

    public init(role: String = "user", content: String) {
        self.role = role
        self.content = content
    }
}
