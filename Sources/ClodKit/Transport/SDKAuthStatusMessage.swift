//
//  SDKAuthStatusMessage.swift
//  ClodKit
//
//  Typed representation of authentication status messages from CLI.
//

import Foundation

// MARK: - SDK Auth Status Message

/// Authentication status update from CLI.
public struct SDKAuthStatusMessage: Sendable, Equatable, Codable {
    public let type: String
    public let isAuthenticating: Bool
    public let output: [String]
    public let error: String?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type
        case isAuthenticating = "is_authenticating"
        case output, error, uuid
        case sessionId = "session_id"
    }
}
