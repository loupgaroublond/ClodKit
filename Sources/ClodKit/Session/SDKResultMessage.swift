//
//  SDKResultMessage.swift
//  ClodKit
//
//  V2 Session result message (unstable, may change).
//

import Foundation

// MARK: - SDK Result Message

/// A result message from a V2 SDK session.
@available(*, message: "V2 Session API is unstable and may change")
public struct SDKResultMessage: Sendable, Equatable, Codable {
    /// The message type.
    public let type: String

    /// The result subtype (e.g., "success", "error").
    public let subtype: String

    /// The result content.
    public let result: String?

    /// The session ID.
    public let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case type, subtype, result, sessionId = "session_id"
    }

    public init(type: String, subtype: String, result: String? = nil, sessionId: String? = nil) {
        self.type = type
        self.subtype = subtype
        self.result = result
        self.sessionId = sessionId
    }
}
