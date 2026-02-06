//
//  HookConfigs.swift
//  ClaudeCodeSDK
//
//  Hook configuration types for query options.
//  EXCEPTION: Parallel configuration structs are kept together.
//

import Foundation

// MARK: - PreToolUse Hook Config

/// Configuration for a pre-tool-use hook.
public struct PreToolUseHookConfig: Sendable {
    /// Optional regex pattern to match tool names.
    public let pattern: String?

    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<PreToolUseInput>

    /// Creates a pre-tool-use hook configuration.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout in seconds (default 60).
    ///   - callback: The callback to invoke.
    public init(
        pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PreToolUseInput>
    ) {
        self.pattern = pattern
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - PostToolUse Hook Config

/// Configuration for a post-tool-use hook.
public struct PostToolUseHookConfig: Sendable {
    /// Optional regex pattern to match tool names.
    public let pattern: String?

    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<PostToolUseInput>

    /// Creates a post-tool-use hook configuration.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout in seconds (default 60).
    ///   - callback: The callback to invoke.
    public init(
        pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PostToolUseInput>
    ) {
        self.pattern = pattern
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - PostToolUseFailure Hook Config

/// Configuration for a post-tool-use failure hook.
public struct PostToolUseFailureHookConfig: Sendable {
    /// Optional regex pattern to match tool names.
    public let pattern: String?

    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<PostToolUseFailureInput>

    /// Creates a post-tool-use failure hook configuration.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout in seconds (default 60).
    ///   - callback: The callback to invoke.
    public init(
        pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PostToolUseFailureInput>
    ) {
        self.pattern = pattern
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - UserPromptSubmit Hook Config

/// Configuration for a user-prompt-submit hook.
public struct UserPromptSubmitHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<UserPromptSubmitInput>

    /// Creates a user-prompt-submit hook configuration.
    /// - Parameters:
    ///   - timeout: Timeout in seconds (default 60).
    ///   - callback: The callback to invoke.
    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<UserPromptSubmitInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - Stop Hook Config

/// Configuration for a stop hook.
public struct StopHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<StopInput>

    /// Creates a stop hook configuration.
    /// - Parameters:
    ///   - timeout: Timeout in seconds (default 60).
    ///   - callback: The callback to invoke.
    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<StopInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}
