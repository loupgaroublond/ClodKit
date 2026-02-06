//
//  HookEvent.swift
//  ClodKit
//
//  Hook event types supported by the Claude Code CLI.
//

import Foundation

// MARK: - Hook Event Types

/// Hook event types supported by the Claude Code CLI.
/// These events represent different points in the agent lifecycle where hooks can be invoked.
public enum HookEvent: String, Codable, Sendable, CaseIterable {
    /// Before a tool is executed. Can block, modify, or approve the tool use.
    case preToolUse = "PreToolUse"

    /// After a tool successfully executes.
    case postToolUse = "PostToolUse"

    /// After a tool execution fails.
    case postToolUseFailure = "PostToolUseFailure"

    /// When a user prompt is submitted.
    case userPromptSubmit = "UserPromptSubmit"

    /// When the agent stops execution.
    case stop = "Stop"

    /// When a subagent starts.
    case subagentStart = "SubagentStart"

    /// When a subagent stops.
    case subagentStop = "SubagentStop"

    /// Before conversation compaction occurs.
    case preCompact = "PreCompact"

    /// When a permission request is triggered.
    case permissionRequest = "PermissionRequest"

    /// When a session starts.
    case sessionStart = "SessionStart"

    /// When a session ends.
    case sessionEnd = "SessionEnd"

    /// Agent status notification.
    case notification = "Notification"
}
