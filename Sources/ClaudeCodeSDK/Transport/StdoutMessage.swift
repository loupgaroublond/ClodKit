//
//  StdoutMessage.swift
//  ClaudeCodeSDK
//
//  Message types received from CLI stdout.
//

import Foundation

// MARK: - Stdout Message Types

/// Message types received from CLI stdout.
/// The CLI sends JSON-line messages that are parsed into these variants.
public enum StdoutMessage: Sendable {
    /// Regular SDK message (user, assistant, result, system).
    case regular(SDKMessage)

    /// Control request from CLI to SDK (e.g., can_use_tool, hook_callback).
    case controlRequest(ControlRequest)

    /// Control response from CLI (response to SDK-initiated request).
    case controlResponse(ControlResponse)

    /// Request to cancel a pending control operation.
    case controlCancelRequest(ControlCancelRequest)

    /// Keep-alive message to maintain connection.
    case keepAlive
}
