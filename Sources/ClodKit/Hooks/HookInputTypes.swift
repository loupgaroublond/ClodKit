//
//  HookInputTypes.swift
//  ClodKit
//
//  All hook input types and the HookInput discriminated union.
//  EXCEPTION: These types form a discriminated union pattern and are kept together.
//

import Foundation

// MARK: - Exit Reason

/// Reasons a session can end.
public enum ExitReason: String, Codable, Sendable, CaseIterable {
    case clear
    case logout
    case promptInputExit = "prompt_input_exit"
    case other
    case bypassPermissionsDisabled = "bypass_permissions_disabled"
}

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

    /// The last assistant message before stopping.
    public let lastAssistantMessage: String?

    public init(base: BaseHookInput, stopHookActive: Bool, lastAssistantMessage: String? = nil) {
        self.base = base
        self.stopHookActive = stopHookActive
        self.lastAssistantMessage = lastAssistantMessage
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

    /// Identifier for the subagent.
    public let agentId: String

    /// Type of the subagent.
    public let agentType: String

    /// The last assistant message before stopping.
    public let lastAssistantMessage: String?

    public init(base: BaseHookInput, stopHookActive: Bool, agentTranscriptPath: String, agentId: String, agentType: String, lastAssistantMessage: String? = nil) {
        self.base = base
        self.stopHookActive = stopHookActive
        self.agentTranscriptPath = agentTranscriptPath
        self.agentId = agentId
        self.agentType = agentType
        self.lastAssistantMessage = lastAssistantMessage
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

    /// Type of agent (e.g., "main", "task").
    public let agentType: String?

    /// Model being used for this session.
    public let model: String?

    public init(base: BaseHookInput, source: String, agentType: String? = nil, model: String? = nil) {
        self.base = base
        self.source = source
        self.agentType = agentType
        self.model = model
    }
}

// MARK: - SessionEnd Input

/// Input for SessionEnd hook, invoked when a session ends.
public struct SessionEndInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Reason for session ending.
    public let reason: ExitReason

    public init(base: BaseHookInput, reason: ExitReason) {
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

// MARK: - Setup Input

/// Input for Setup hook, invoked when the session is being set up.
public struct SetupInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// What triggered the setup ('init' or 'maintenance').
    public let trigger: String

    public init(base: BaseHookInput, trigger: String) {
        self.base = base
        self.trigger = trigger
    }
}

// MARK: - TeammateIdle Input

/// Input for TeammateIdle hook, invoked when a teammate becomes idle.
public struct TeammateIdleInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the idle teammate.
    public let teammateName: String

    /// Name of the team.
    public let teamName: String

    public init(base: BaseHookInput, teammateName: String, teamName: String) {
        self.base = base
        self.teammateName = teammateName
        self.teamName = teamName
    }
}

// MARK: - TaskCompleted Input

/// Input for TaskCompleted hook, invoked when a task is completed.
public struct TaskCompletedInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Identifier for the completed task.
    public let taskId: String

    /// Subject/title of the completed task.
    public let taskSubject: String

    /// Description of the completed task.
    public let taskDescription: String?

    /// Name of the teammate that completed the task.
    public let teammateName: String?

    /// Name of the team.
    public let teamName: String?

    public init(
        base: BaseHookInput,
        taskId: String,
        taskSubject: String,
        taskDescription: String? = nil,
        teammateName: String? = nil,
        teamName: String? = nil
    ) {
        self.base = base
        self.taskId = taskId
        self.taskSubject = taskSubject
        self.taskDescription = taskDescription
        self.teammateName = teammateName
        self.teamName = teamName
    }
}

// MARK: - Elicitation Input

/// Input for Elicitation hook, invoked when an MCP server requests user input.
public struct ElicitationInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the MCP server making the request.
    public let mcpServerName: String

    /// The message or prompt from the MCP server.
    public let message: String

    /// Mode of elicitation ('form' or 'url').
    public let mode: String?

    /// URL for URL-mode elicitation.
    public let url: String?

    /// Unique identifier for this elicitation request.
    public let elicitationId: String?

    /// JSON schema for the requested data.
    public let requestedSchema: [String: JSONValue]?

    public init(
        base: BaseHookInput,
        mcpServerName: String,
        message: String,
        mode: String? = nil,
        url: String? = nil,
        elicitationId: String? = nil,
        requestedSchema: [String: JSONValue]? = nil
    ) {
        self.base = base
        self.mcpServerName = mcpServerName
        self.message = message
        self.mode = mode
        self.url = url
        self.elicitationId = elicitationId
        self.requestedSchema = requestedSchema
    }
}

// MARK: - ElicitationResult Input

/// Input for ElicitationResult hook, invoked when an elicitation request receives a result.
public struct ElicitationResultInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the MCP server that made the request.
    public let mcpServerName: String

    /// Unique identifier for the elicitation request.
    public let elicitationId: String?

    /// Mode of elicitation ('form' or 'url').
    public let mode: String?

    /// The user's action ('accept', 'decline', or 'cancel').
    public let action: String

    /// The content submitted by the user (for accepted form elicitations).
    public let content: [String: JSONValue]?

    public init(
        base: BaseHookInput,
        mcpServerName: String,
        elicitationId: String? = nil,
        mode: String? = nil,
        action: String,
        content: [String: JSONValue]? = nil
    ) {
        self.base = base
        self.mcpServerName = mcpServerName
        self.elicitationId = elicitationId
        self.mode = mode
        self.action = action
        self.content = content
    }
}

// MARK: - ConfigChange Input

/// Input for ConfigChange hook, invoked when the configuration changes.
public struct ConfigChangeInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Source of the configuration change.
    public let source: String

    /// Path to the configuration file that changed.
    public let filePath: String?

    public init(base: BaseHookInput, source: String, filePath: String? = nil) {
        self.base = base
        self.source = source
        self.filePath = filePath
    }
}

// MARK: - WorktreeCreate Input

/// Input for WorktreeCreate hook, invoked when a worktree is created.
public struct WorktreeCreateInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Name of the worktree being created.
    public let name: String

    public init(base: BaseHookInput, name: String) {
        self.base = base
        self.name = name
    }
}

// MARK: - WorktreeRemove Input

/// Input for WorktreeRemove hook, invoked when a worktree is removed.
public struct WorktreeRemoveInput: Sendable {
    /// Common hook input fields.
    public let base: BaseHookInput

    /// Path to the worktree being removed.
    public let worktreePath: String

    public init(base: BaseHookInput, worktreePath: String) {
        self.base = base
        self.worktreePath = worktreePath
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
    case setup(SetupInput)
    case teammateIdle(TeammateIdleInput)
    case taskCompleted(TaskCompletedInput)
    case elicitation(ElicitationInput)
    case elicitationResult(ElicitationResultInput)
    case configChange(ConfigChangeInput)
    case worktreeCreate(WorktreeCreateInput)
    case worktreeRemove(WorktreeRemoveInput)

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
        case .setup: return .setup
        case .teammateIdle: return .teammateIdle
        case .taskCompleted: return .taskCompleted
        case .elicitation: return .elicitation
        case .elicitationResult: return .elicitationResult
        case .configChange: return .configChange
        case .worktreeCreate: return .worktreeCreate
        case .worktreeRemove: return .worktreeRemove
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
        case .setup(let input): return input.base
        case .teammateIdle(let input): return input.base
        case .taskCompleted(let input): return input.base
        case .elicitation(let input): return input.base
        case .elicitationResult(let input): return input.base
        case .configChange(let input): return input.base
        case .worktreeCreate(let input): return input.base
        case .worktreeRemove(let input): return input.base
        }
    }
}
