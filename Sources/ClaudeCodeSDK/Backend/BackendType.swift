//
//  BackendType.swift
//  ClaudeCodeSDK
//
//  Backend types available in the SDK.
//

import Foundation

// MARK: - Backend Type

/// Backend types available in the SDK.
/// The native backend uses native Swift subprocess management.
public enum BackendType: String, Codable, Sendable {
    /// Native Swift subprocess implementation.
    /// Uses ProcessTransport with bidirectional control protocol.
    case native

    /// Traditional headless mode using `claude -p` CLI (legacy).
    case headless

    /// Node.js-based wrapper around @anthropic-ai/claude-agent-sdk (legacy).
    case agentSDK
}
