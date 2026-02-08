//
//  SDKStatusMessage.swift
//  ClodKit
//
//  Typed representation of system status messages from CLI.
//

import Foundation

// MARK: - SDK Status Message

/// Typed representation of a system status message.
/// Decode from SDKMessage.rawJSON when subtype is "status".
public struct SDKStatusMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let status: String?
    public let permissionMode: String?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype, status
        case permissionMode = "permission_mode"
        case uuid
        case sessionId = "session_id"
    }
}

// MARK: - SDK Status

/// Known status values for system status messages.
public enum SDKStatus: String, Codable, Sendable {
    case compacting
}
