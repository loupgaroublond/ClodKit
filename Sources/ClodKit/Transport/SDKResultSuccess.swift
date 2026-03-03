//
//  SDKResultSuccess.swift
//  ClodKit
//
//  Typed representation of successful result messages from CLI.
//

import Foundation

// MARK: - SDK Result Success

/// A successful result message from the CLI.
public struct SDKResultSuccess: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let durationMs: Int
    public let durationApiMs: Int
    public let isError: Bool
    public let numTurns: Int
    public let result: String
    public let stopReason: String?
    public let totalCostUsd: Double
    public let usage: ModelUsage
    public let modelUsage: [String: ModelUsage]
    public let permissionDenials: [SDKPermissionDenial]
    public let fastModeState: String?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case durationMs = "duration_ms"
        case durationApiMs = "duration_api_ms"
        case isError = "is_error"
        case numTurns = "num_turns"
        case result
        case stopReason = "stop_reason"
        case totalCostUsd = "total_cost_usd"
        case usage
        case modelUsage = "modelUsage"
        case permissionDenials = "permission_denials"
        case fastModeState = "fast_mode_state"
        case uuid
        case sessionId = "session_id"
    }
}

// MARK: - SDK Permission Denial

/// A tool use that was denied by the permission system.
public struct SDKPermissionDenial: Sendable, Equatable, Codable {
    public let toolName: String
    public let toolUseId: String
    public let toolInput: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case toolUseId = "tool_use_id"
        case toolInput = "tool_input"
    }
}
