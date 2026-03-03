//
//  SDKResultError.swift
//  ClodKit
//
//  Typed representation of error result messages from CLI.
//

import Foundation

// MARK: - SDK Result Error

/// An error result message from the CLI.
public struct SDKResultError: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let durationMs: Int
    public let durationApiMs: Int
    public let isError: Bool
    public let numTurns: Int
    public let stopReason: String?
    public let totalCostUsd: Double
    public let usage: ModelUsage
    public let modelUsage: [String: ModelUsage]
    public let permissionDenials: [SDKPermissionDenial]
    public let errors: [String]
    public let fastModeState: String?
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case durationMs = "duration_ms"
        case durationApiMs = "duration_api_ms"
        case isError = "is_error"
        case numTurns = "num_turns"
        case stopReason = "stop_reason"
        case totalCostUsd = "total_cost_usd"
        case usage
        case modelUsage = "modelUsage"
        case permissionDenials = "permission_denials"
        case errors
        case fastModeState = "fast_mode_state"
        case uuid
        case sessionId = "session_id"
    }
}
