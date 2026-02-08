//
//  HookOutputTypes.swift
//  ClodKit
//
//  All hook output types and the HookOutput struct.
//  EXCEPTION: These types form a discriminated union pattern and are kept together.
//

import Foundation

// MARK: - PreToolUse Hook Output

/// Output specific to PreToolUse hooks.
public struct PreToolUseHookOutput: Sendable {
    /// Permission decision (allow, deny, ask).
    public var permissionDecision: PermissionDecision?

    /// Reason for the permission decision.
    public var permissionDecisionReason: String?

    /// Modified tool input (if changing the input).
    public var updatedInput: [String: JSONValue]?

    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(
        permissionDecision: PermissionDecision? = nil,
        permissionDecisionReason: String? = nil,
        updatedInput: [String: JSONValue]? = nil,
        additionalContext: String? = nil
    ) {
        self.permissionDecision = permissionDecision
        self.permissionDecisionReason = permissionDecisionReason
        self.updatedInput = updatedInput
        self.additionalContext = additionalContext
    }

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["hookEventName": "PreToolUse"]
        if let decision = permissionDecision { dict["permissionDecision"] = decision.rawValue }
        if let reason = permissionDecisionReason { dict["permissionDecisionReason"] = reason }
        if let input = updatedInput { dict["updatedInput"] = input.mapValues { $0.toAny() } }
        if let context = additionalContext { dict["additionalContext"] = context }
        return dict
    }
}

// MARK: - PostToolUse Hook Output

/// Output specific to PostToolUse hooks.
public struct PostToolUseHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    /// Modified MCP tool output (if changing the result).
    public var updatedMCPToolOutput: JSONValue?

    public init(
        additionalContext: String? = nil,
        updatedMCPToolOutput: JSONValue? = nil
    ) {
        self.additionalContext = additionalContext
        self.updatedMCPToolOutput = updatedMCPToolOutput
    }

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["hookEventName": "PostToolUse"]
        if let context = additionalContext { dict["additionalContext"] = context }
        if let output = updatedMCPToolOutput { dict["updatedMCPToolOutput"] = output.toAny() }
        return dict
    }
}

// MARK: - Setup Hook Output

/// Output specific to Setup hooks.
public struct SetupHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(additionalContext: String? = nil) {
        self.additionalContext = additionalContext
    }
}

// MARK: - SessionStart Hook Output

/// Output specific to SessionStart hooks.
public struct SessionStartHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(additionalContext: String? = nil) {
        self.additionalContext = additionalContext
    }
}

// MARK: - SubagentStart Hook Output

/// Output specific to SubagentStart hooks.
public struct SubagentStartHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(additionalContext: String? = nil) {
        self.additionalContext = additionalContext
    }
}

// MARK: - PostToolUseFailure Hook Output

/// Output specific to PostToolUseFailure hooks.
public struct PostToolUseFailureHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(additionalContext: String? = nil) {
        self.additionalContext = additionalContext
    }
}

// MARK: - Notification Hook Output

/// Output specific to Notification hooks.
public struct NotificationHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(additionalContext: String? = nil) {
        self.additionalContext = additionalContext
    }
}

// MARK: - UserPromptSubmit Hook Output

/// Output specific to UserPromptSubmit hooks.
public struct UserPromptSubmitHookOutput: Sendable {
    /// Additional context to provide to the model.
    public var additionalContext: String?

    public init(additionalContext: String? = nil) {
        self.additionalContext = additionalContext
    }
}

// MARK: - Hook Specific Output (Discriminated Union)

/// Hook-specific output types.
public enum HookSpecificOutput: Sendable {
    /// Output for PreToolUse hooks.
    case preToolUse(PreToolUseHookOutput)

    /// Output for PostToolUse hooks.
    case postToolUse(PostToolUseHookOutput)

    /// Output for Setup hooks.
    case setup(SetupHookOutput)

    /// Output for SessionStart hooks.
    case sessionStart(SessionStartHookOutput)

    /// Output for SubagentStart hooks.
    case subagentStart(SubagentStartHookOutput)

    /// Output for PostToolUseFailure hooks.
    case postToolUseFailure(PostToolUseFailureHookOutput)

    /// Output for Notification hooks.
    case notification(NotificationHookOutput)

    /// Output for UserPromptSubmit hooks.
    case userPromptSubmit(UserPromptSubmitHookOutput)

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        switch self {
        case .preToolUse(let output):
            return output.toDictionary()
        case .postToolUse(let output):
            return output.toDictionary()
        case .setup(let output):
            var dict: [String: Any] = ["hookEventName": "Setup"]
            if let context = output.additionalContext { dict["additionalContext"] = context }
            return dict
        case .sessionStart(let output):
            var dict: [String: Any] = ["hookEventName": "SessionStart"]
            if let context = output.additionalContext { dict["additionalContext"] = context }
            return dict
        case .subagentStart(let output):
            var dict: [String: Any] = ["hookEventName": "SubagentStart"]
            if let context = output.additionalContext { dict["additionalContext"] = context }
            return dict
        case .postToolUseFailure(let output):
            var dict: [String: Any] = ["hookEventName": "PostToolUseFailure"]
            if let context = output.additionalContext { dict["additionalContext"] = context }
            return dict
        case .notification(let output):
            var dict: [String: Any] = ["hookEventName": "Notification"]
            if let context = output.additionalContext { dict["additionalContext"] = context }
            return dict
        case .userPromptSubmit(let output):
            var dict: [String: Any] = ["hookEventName": "UserPromptSubmit"]
            if let context = output.additionalContext { dict["additionalContext"] = context }
            return dict
        }
    }
}

// MARK: - Async Hook Output

/// Output for hooks that run asynchronously.
public struct AsyncHookOutput: Sendable {
    /// Always true for async outputs.
    public let isAsync: Bool

    /// Optional timeout for the async operation.
    public let asyncTimeout: TimeInterval?

    public init(asyncTimeout: TimeInterval? = nil) {
        self.isAsync = true
        self.asyncTimeout = asyncTimeout
    }
}

// MARK: - Hook JSON Output (Sync/Async Union)

/// Discriminated union for hook outputs that can be either synchronous or asynchronous.
public enum HookJSONOutput: Sendable {
    /// A synchronous hook output.
    case sync(HookOutput)

    /// An asynchronous hook output.
    case async(AsyncHookOutput)
}

// MARK: - Hook Output

/// Output returned from hook callbacks.
/// Controls whether execution continues and provides optional modifications.
public struct HookOutput: Sendable {
    /// Whether to continue execution. Default is true.
    public var shouldContinue: Bool = true

    /// Whether to suppress output from the transcript.
    public var suppressOutput: Bool = false

    /// Reason for stopping (when shouldContinue is false).
    public var stopReason: String?

    /// System message to inject.
    public var systemMessage: String?

    /// Feedback reason for Claude.
    public var reason: String?

    /// Hook-specific output data.
    public var hookSpecificOutput: HookSpecificOutput?

    public init(
        shouldContinue: Bool = true,
        suppressOutput: Bool = false,
        stopReason: String? = nil,
        systemMessage: String? = nil,
        reason: String? = nil,
        hookSpecificOutput: HookSpecificOutput? = nil
    ) {
        self.shouldContinue = shouldContinue
        self.suppressOutput = suppressOutput
        self.stopReason = stopReason
        self.systemMessage = systemMessage
        self.reason = reason
        self.hookSpecificOutput = hookSpecificOutput
    }

    /// Convert to dictionary for JSON serialization to CLI.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["continue": shouldContinue]
        if suppressOutput { dict["suppressOutput"] = true }
        if let stopReason { dict["stopReason"] = stopReason }
        if let systemMessage { dict["systemMessage"] = systemMessage }
        if let reason { dict["reason"] = reason }
        if let hookSpecificOutput { dict["hookSpecificOutput"] = hookSpecificOutput.toDictionary() }
        return dict
    }

    // MARK: - Convenience Initializers

    /// Create an output that allows the operation to continue.
    public static func `continue`() -> HookOutput {
        HookOutput(shouldContinue: true)
    }

    /// Create an output that stops execution.
    public static func stop(reason: String? = nil) -> HookOutput {
        HookOutput(shouldContinue: false, stopReason: reason)
    }

    /// Create an output that allows PreToolUse with a permission decision.
    public static func allow(
        updatedInput: [String: JSONValue]? = nil,
        additionalContext: String? = nil
    ) -> HookOutput {
        var output = PreToolUseHookOutput()
        output.permissionDecision = .allow
        output.updatedInput = updatedInput
        output.additionalContext = additionalContext
        return HookOutput(hookSpecificOutput: .preToolUse(output))
    }

    /// Create an output that denies PreToolUse.
    public static func deny(reason: String? = nil) -> HookOutput {
        var output = PreToolUseHookOutput()
        output.permissionDecision = .deny
        output.permissionDecisionReason = reason
        return HookOutput(hookSpecificOutput: .preToolUse(output))
    }

    /// Create an output that asks the user for permission.
    public static func ask(reason: String? = nil) -> HookOutput {
        var output = PreToolUseHookOutput()
        output.permissionDecision = .ask
        output.permissionDecisionReason = reason
        return HookOutput(hookSpecificOutput: .preToolUse(output))
    }
}
