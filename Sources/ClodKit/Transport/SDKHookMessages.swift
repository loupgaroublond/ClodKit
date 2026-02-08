//
//  SDKHookMessages.swift
//  ClodKit
//
//  Typed representations of hook lifecycle messages from CLI.
//

import Foundation

// MARK: - SDK Hook Started Message

/// Sent when a hook begins execution.
public struct SDKHookStartedMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let hookId: String
    public let hookName: String
    public let hookEvent: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case hookId = "hook_id"
        case hookName = "hook_name"
        case hookEvent = "hook_event"
        case uuid
        case sessionId = "session_id"
    }
}

// MARK: - SDK Hook Progress Message

/// Sent during hook execution with intermediate output.
public struct SDKHookProgressMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let hookId: String
    public let hookName: String
    public let hookEvent: String
    public let stdout: String
    public let stderr: String
    public let output: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case hookId = "hook_id"
        case hookName = "hook_name"
        case hookEvent = "hook_event"
        case stdout, stderr, output, uuid
        case sessionId = "session_id"
    }
}

// MARK: - SDK Hook Response Message

/// Sent when a hook completes execution.
public struct SDKHookResponseMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let hookId: String
    public let hookName: String
    public let hookEvent: String
    public let output: String
    public let stdout: String
    public let stderr: String
    public let exitCode: Int?
    public let outcome: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case hookId = "hook_id"
        case hookName = "hook_name"
        case hookEvent = "hook_event"
        case output, stdout, stderr
        case exitCode = "exit_code"
        case outcome, uuid
        case sessionId = "session_id"
    }
}
