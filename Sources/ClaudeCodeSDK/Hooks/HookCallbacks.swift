//
//  HookCallbacks.swift
//  ClaudeCodeSDK
//
//  Hook callback types and PermissionDecision enum.
//  EXCEPTION: Typealiases and the enum they reference are kept together.
//

import Foundation

// MARK: - Permission Decision

/// Permission decision for PreToolUse hooks.
public enum PermissionDecision: String, Codable, Sendable {
    /// Allow the tool to execute.
    case allow

    /// Deny the tool execution.
    case deny

    /// Ask the user for permission.
    case ask
}

// MARK: - Hook Callback Types

/// Type alias for hook callback functions.
/// Takes hook-specific input and returns a HookOutput.
public typealias HookCallback<Input: Sendable> = @Sendable (Input) async throws -> HookOutput

/// Type-erased hook callback that can handle any HookInput.
public typealias AnyHookCallback = @Sendable (HookInput, String?) async throws -> HookOutput
