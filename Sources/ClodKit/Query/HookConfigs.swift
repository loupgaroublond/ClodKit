//
//  HookConfigs.swift
//  ClodKit
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

// MARK: - Setup Hook Config

/// Configuration for a setup hook.
public struct SetupHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<SetupInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<SetupInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - TeammateIdle Hook Config

/// Configuration for a teammate-idle hook.
public struct TeammateIdleHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<TeammateIdleInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<TeammateIdleInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - TaskCompleted Hook Config

/// Configuration for a task-completed hook.
public struct TaskCompletedHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<TaskCompletedInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<TaskCompletedInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - SessionStart Hook Config

/// Configuration for a session-start hook.
public struct SessionStartHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<SessionStartInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<SessionStartInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - SessionEnd Hook Config

/// Configuration for a session-end hook.
public struct SessionEndHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<SessionEndInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<SessionEndInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - SubagentStart Hook Config

/// Configuration for a subagent-start hook.
public struct SubagentStartHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<SubagentStartInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<SubagentStartInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - SubagentStop Hook Config

/// Configuration for a subagent-stop hook.
public struct SubagentStopHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<SubagentStopInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<SubagentStopInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - PreCompact Hook Config

/// Configuration for a pre-compact hook.
public struct PreCompactHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<PreCompactInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PreCompactInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - PermissionRequest Hook Config

/// Configuration for a permission-request hook.
public struct PermissionRequestHookConfig: Sendable {
    /// Optional regex pattern to match tool names.
    public let pattern: String?

    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<PermissionRequestInput>

    public init(
        pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PermissionRequestInput>
    ) {
        self.pattern = pattern
        self.timeout = timeout
        self.callback = callback
    }
}

// MARK: - Notification Hook Config

/// Configuration for a notification hook.
public struct NotificationHookConfig: Sendable {
    /// Timeout for the callback in seconds.
    public let timeout: TimeInterval

    /// The callback to invoke.
    public let callback: HookCallback<NotificationInput>

    public init(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<NotificationInput>
    ) {
        self.timeout = timeout
        self.callback = callback
    }
}
