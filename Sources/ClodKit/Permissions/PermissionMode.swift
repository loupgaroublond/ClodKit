//
//  PermissionMode.swift
//  ClodKit
//
//  Permission modes for Claude Code operations.
//

import Foundation

// MARK: - Permission Mode

/// Permission modes for Claude Code operations.
/// Controls how the CLI handles permission requests.
public enum PermissionMode: String, Codable, Sendable, CaseIterable {
    /// Default permission mode - asks for user confirmation.
    case `default` = "default"

    /// Automatically accepts edit operations.
    case acceptEdits = "acceptEdits"

    /// Bypasses all permission checks (use with caution).
    case bypassPermissions = "bypassPermissions"

    /// Plan mode - creates a plan before executing.
    case plan = "plan"
}
