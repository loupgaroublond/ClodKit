//
//  HookInputTypes.swift
//  ClodKit
//
//  All hook input types and the HookInput discriminated union.
//  EXCEPTION: These types form a discriminated union pattern and are kept together.
//

import Foundation

// MARK: - Base Hook Input

/// Common fields present in all hook inputs.
public struct BaseHookInput: Sendable, Equatable {
    /// The session identifier.
    public let sessionId: String

    /// Path to the session transcript file.
    public let transcriptPath: String

    /// Current working directory.
    public let cwd: String

    /// Current permission mode (e.g., "default", "acceptEdits").
    public let permissionMode: String

    /// The hook event type being invoked.
    public let hookEventName: HookEvent

    public init(
        sessionId: String,
        transcriptPath: String,
        cwd: String,
        permissionMode: String,
        hookEventName: HookEvent
    ) {
        self.sessionId = sessionId
        self.transcriptPath = transcriptPath
        self.cwd = cwd
        self.permissionMode = permissionMode
        self.hookEventName = hookEventName
    }
}

// MARK: - PreToolUse Input

/// Input for PreToolUse hook, invoked before tool execution.
public struct PreToolUseInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the tool being invoked.
    public let toolName: String

    /// Input parameters for the tool.
    public let toolInput: [String: JSONValue]

    /// Unique identifier for this tool use.
    public let toolUseId: String

    public init(base: BaseHookInput, toolName: String, toolInput: [String: JSONValue], toolUseId: String) {
        self.base = base
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolUseId = toolUseId
    }
}

// MARK: - PostToolUse Input

/// Input for PostToolUse hook, invoked after successful tool execution.
public struct PostToolUseInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the tool that was invoked.
    public let toolName: String

    /// Input parameters that were passed to the tool.
    public let toolInput: [String: JSONValue]

    /// Response from the tool execution.
    public let toolResponse: JSONValue

    /// Unique identifier for this tool use.
    public let toolUseId: String

    public init(base: BaseHookInput, toolName: String, toolInput: [String: JSONValue], toolResponse: JSONValue, toolUseId: String) {
        self.base = base
        self.toolName = toolName
        self.toolInput = toolInput
        self.toolResponse = toolResponse
        self.toolUseId = toolUseId
    }
}

// MARK: - PostToolUseFailure Input

/// Input for PostToolUseFailure hook, invoked after tool execution fails.
public struct PostToolUseFailureInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the tool that failed.
    public let toolName: String

    /// Input parameters that were passed to the tool.
    public let toolInput: [String: JSONValue]

    /// Error message from the failure.
    public let error: String

    /// Whether this was an interrupt-triggered failure.
    public let isInterrupt: Bool

    /// Unique identifier for this tool use.
    public let toolUseId: String

    public init(base: BaseHookInput, toolName: String, toolInput: [String: JSONValue], error: String, isInterrupt: Bool, toolUseId: String) {
        self.base = base
        self.toolName = toolName
        self.toolInput = toolInput
        self.error = error
        self.isInterrupt = isInterrupt
        self.toolUseId = toolUseId
    }
}

// MARK: - UserPromptSubmit Input

/// Input for UserPromptSubmit hook, invoked when user submits a prompt.
public struct UserPromptSubmitInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// The prompt text submitted by the user.
    public let prompt: String

    public init(base: BaseHookInput, prompt: String) {
        self.base = base
        self.prompt = prompt
    }
}

// MARK: - Stop Input

/// Input for Stop hook, invoked when agent execution stops.
public struct StopInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Whether the stop hook is currently active.
    public let stopHookActive: Bool

    public init(base: BaseHookInput, stopHookActive: Bool) {
        self.base = base
        self.stopHookActive = stopHookActive
    }
}

// MARK: - SubagentStart Input

/// Input for SubagentStart hook, invoked when a subagent starts.
public struct SubagentStartInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Identifier for the subagent.
    public let agentId: String

    /// Type of the subagent.
    public let agentType: String

    public init(base: BaseHookInput, agentId: String, agentType: String) {
        self.base = base
        self.agentId = agentId
        self.agentType = agentType
    }
}

// MARK: - SubagentStop Input

/// Input for SubagentStop hook, invoked when a subagent stops.
public struct SubagentStopInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Whether the stop hook is currently active.
    public let stopHookActive: Bool

    /// Path to the subagent's transcript.
    public let agentTranscriptPath: String

    public init(base: BaseHookInput, stopHookActive: Bool, agentTranscriptPath: String) {
        self.base = base
        self.stopHookActive = stopHookActive
        self.agentTranscriptPath = agentTranscriptPath
    }
}

// MARK: - PreCompact Input

/// Input for PreCompact hook, invoked before conversation compaction.
public struct PreCompactInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// What triggered the compaction.
    public let trigger: String

    /// Custom instructions for compaction.
    public let customInstructions: String?

    public init(base: BaseHookInput, trigger: String, customInstructions: String?) {
        self.base = base
        self.trigger = trigger
        self.customInstructions = customInstructions
    }
}

// MARK: - PermissionRequest Input

/// Input for PermissionRequest hook, invoked when permission is requested.
public struct PermissionRequestInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the tool requesting permission.
    public let toolName: String

    /// Input parameters for the tool.
    public let toolInput: [String: JSONValue]

    /// Suggested permission responses.
    public let permissionSuggestions: [String]

    public init(base: BaseHookInput, toolName: String, toolInput: [String: JSONValue], permissionSuggestions: [String]) {
        self.base = base
        self.toolName = toolName
        self.toolInput = toolInput
        self.permissionSuggestions = permissionSuggestions
    }
}

// MARK: - SessionStart Input

/// Input for SessionStart hook, invoked when a session starts.
public struct SessionStartInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Source of the session start.
    public let source: String

    public init(base: BaseHookInput, source: String) {
        self.base = base
        self.source = source
    }
}

// MARK: - SessionEnd Input

/// Input for SessionEnd hook, invoked when a session ends.
public struct SessionEndInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Reason for session ending.
    public let reason: String

    public init(base: BaseHookInput, reason: String) {
        self.base = base
        self.reason = reason
    }
}

// MARK: - Notification Input

/// Input for Notification hook, invoked for agent status messages.
public struct NotificationInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// The notification message.
    public let message: String

    /// Type of notification.
    public let notificationType: String

    /// Optional title for the notification.
    public let title: String?

    public init(base: BaseHookInput, message: String, notificationType: String, title: String?) {
        self.base = base
        self.message = message
        self.notificationType = notificationType
        self.title = title
    }
}

// MARK: - Hook Input (Discriminated Union)

/// Generic hook input that can be used for type-erased callbacks.
public enum HookInput: Sendable {
    case preToolUse(PreToolUseInput)
    case postToolUse(PostToolUseInput)
    case postToolUseFailure(PostToolUseFailureInput)
    case userPromptSubmit(UserPromptSubmitInput)
    case stop(StopInput)
    case subagentStart(SubagentStartInput)
    case subagentStop(SubagentStopInput)
    case preCompact(PreCompactInput)
    case permissionRequest(PermissionRequestInput)
    case sessionStart(SessionStartInput)
    case sessionEnd(SessionEndInput)
    case notification(NotificationInput)

    /// The hook event type for this input.
    public var eventType: HookEvent {
        switch self {
        case .preToolUse: return .preToolUse
        case .postToolUse: return .postToolUse
        case .postToolUseFailure: return .postToolUseFailure
        case .userPromptSubmit: return .userPromptSubmit
        case .stop: return .stop
        case .subagentStart: return .subagentStart
        case .subagentStop: return .subagentStop
        case .preCompact: return .preCompact
        case .permissionRequest: return .permissionRequest
        case .sessionStart: return .sessionStart
        case .sessionEnd: return .sessionEnd
        case .notification: return .notification
        }
    }

    /// The base input fields.
    public var base: BaseHookInput {
        switch self {
        case .preToolUse(let input): return input.base
        case .postToolUse(let input): return input.base
        case .postToolUseFailure(let input): return input.base
        case .userPromptSubmit(let input): return input.base
        case .stop(let input): return input.base
        case .subagentStart(let input): return input.base
        case .subagentStop(let input): return input.base
        case .preCompact(let input): return input.base
        case .permissionRequest(let input): return input.base
        case .sessionStart(let input): return input.base
        case .sessionEnd(let input): return input.base
        case .notification(let input): return input.base
        }
    }
}
