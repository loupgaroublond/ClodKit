//
//  QueryOptions.swift
//  ClodKit
//
//  Configuration options for Claude Code queries.
//

import Foundation
import os

// MARK: - Query Options

/// Configuration options for Claude Code queries.
public struct QueryOptions: Sendable {
    /// The model to use (e.g., "claude-sonnet-4-20250514").
    public var model: String?

    /// Maximum number of agent turns.
    public var maxTurns: Int?

    /// Maximum thinking tokens for extended thinking.
    public var maxThinkingTokens: Int?

    /// Permission mode for tool execution.
    public var permissionMode: PermissionMode?

    /// System prompt to use.
    public var systemPrompt: String?

    /// System prompt to append to the existing system prompt.
    public var appendSystemPrompt: String?

    /// Working directory for the session.
    public var workingDirectory: URL?

    /// Additional environment variables.
    public var environment: [String: String]

    /// Path to the claude CLI executable.
    public var cliPath: String?

    /// Logger for debugging.
    public var logger: Logger?

    /// Tools allowed for this query.
    public var allowedTools: [String]?

    /// Tools blocked for this query.
    public var blockedTools: [String]?

    /// Additional directories Claude can access.
    public var additionalDirectories: [String]

    /// Session ID to resume.
    public var resume: String?

    /// Agent name for delegated agent queries.
    public var agent: String?

    /// Whether to persist the session (default true).
    public var persistSession: Bool = true

    /// Session ID to use for the query.
    public var sessionId: String?

    /// Enable debug mode.
    public var debug: Bool = false

    /// Path to write debug output.
    public var debugFile: String?

    /// Maximum budget in USD for the query.
    public var maxBudgetUsd: Double?

    /// Fork the session instead of continuing in-place.
    public var forkSession: Bool = false

    /// Enable file checkpointing for rewind support.
    public var enableFileCheckpointing: Bool = false

    /// Continue a previous conversation.
    public var continueConversation: Bool = false

    /// Beta features to enable.
    public var betas: [String] = []

    /// Structured output format specification.
    public var outputFormat: OutputFormat?

    /// Agent definitions for delegated agents.
    public var agents: [String: AgentDefinition]?

    // MARK: - MCP Servers

    /// External MCP server configurations.
    public var mcpServers: [String: MCPServerConfig]

    /// SDK MCP servers (in-process tools).
    public var sdkMcpServers: [String: SDKMCPServer]

    // MARK: - Hooks

    /// Pre-tool-use hooks.
    public var preToolUseHooks: [PreToolUseHookConfig]

    /// Post-tool-use hooks.
    public var postToolUseHooks: [PostToolUseHookConfig]

    /// Post-tool-use failure hooks.
    public var postToolUseFailureHooks: [PostToolUseFailureHookConfig]

    /// User prompt submit hooks.
    public var userPromptSubmitHooks: [UserPromptSubmitHookConfig]

    /// Stop hooks.
    public var stopHooks: [StopHookConfig]

    /// Setup hooks.
    public var setupHooks: [SetupHookConfig]

    /// Teammate idle hooks.
    public var teammateIdleHooks: [TeammateIdleHookConfig]

    /// Task completed hooks.
    public var taskCompletedHooks: [TaskCompletedHookConfig]

    /// Session start hooks.
    public var sessionStartHooks: [SessionStartHookConfig]

    /// Session end hooks.
    public var sessionEndHooks: [SessionEndHookConfig]

    /// Subagent start hooks.
    public var subagentStartHooks: [SubagentStartHookConfig]

    /// Subagent stop hooks.
    public var subagentStopHooks: [SubagentStopHookConfig]

    /// Pre-compact hooks.
    public var preCompactHooks: [PreCompactHookConfig]

    /// Permission request hooks.
    public var permissionRequestHooks: [PermissionRequestHookConfig]

    /// Notification hooks.
    public var notificationHooks: [NotificationHookConfig]

    /// Elicitation hooks.
    public var elicitationHooks: [ElicitationHookConfig]

    /// Elicitation result hooks.
    public var elicitationResultHooks: [ElicitationResultHookConfig]

    /// Config change hooks.
    public var configChangeHooks: [ConfigChangeHookConfig]

    /// Worktree create hooks.
    public var worktreeCreateHooks: [WorktreeCreateHookConfig]

    /// Worktree remove hooks.
    public var worktreeRemoveHooks: [WorktreeRemoveHookConfig]

    // MARK: - Permission Callback

    /// Permission callback for tool use requests.
    public var canUseTool: CanUseToolCallback?

    // MARK: - Process Spawning

    /// Custom function for spawning the Claude Code process.
    public var spawnClaudeCodeProcess: SpawnFunction?

    // MARK: - Sandbox

    /// Sandbox settings for CLI process execution.
    public var sandbox: SandboxSettings?

    // MARK: - Stderr Handler

    /// Callback for stderr output from the CLI process.
    /// Called incrementally as stderr data is received.
    public var stderrHandler: (@Sendable (String) -> Void)?

    // MARK: - New Fields (SDK v0.2.63)

    /// Additional arguments to pass to the JavaScript runtime executable.
    public var executableArgs: [String]?

    /// Additional CLI arguments to pass to Claude Code.
    /// Keys are argument names (without --), values are argument values. Use nil for boolean flags.
    public var extraArgs: [String: String?]?

    /// Fallback model to use if the primary model fails or is unavailable.
    public var fallbackModel: String?

    /// Controls Claude's thinking/reasoning behavior.
    public var thinking: ThinkingConfig?

    /// Controls how much effort Claude puts into its response ('low'|'medium'|'high'|'max').
    public var effort: String?

    /// Plugins to load for this session.
    public var plugins: [SdkPluginConfig]?

    /// Enable prompt suggestions. When true, a prompt_suggestion message is emitted after each turn.
    public var promptSuggestions: Bool?

    /// When resuming, only resume messages up to and including the message with this UUID.
    public var resumeSessionAt: String?

    /// Control which filesystem settings to load ('user', 'project', 'local').
    public var settingSources: [String]?

    /// Enforce strict validation of MCP server configurations.
    public var strictMcpConfig: Bool?

    /// Include partial/streaming message events in the output.
    public var includePartialMessages: Bool?

    /// Callback for handling MCP elicitation requests.
    public var onElicitation: (@Sendable (ElicitationRequest) async throws -> ElicitationResult)?

    /// Tools explicitly disallowed for this query.
    public var disallowedTools: [String]?

    /// Tools configuration: either an explicit list or a preset.
    public var tools: ToolsConfig?

    /// Creates default query options.
    public init() {
        self.environment = [:]
        self.additionalDirectories = []
        self.betas = []
        self.mcpServers = [:]
        self.sdkMcpServers = [:]
        self.preToolUseHooks = []
        self.postToolUseHooks = []
        self.postToolUseFailureHooks = []
        self.userPromptSubmitHooks = []
        self.stopHooks = []
        self.setupHooks = []
        self.teammateIdleHooks = []
        self.taskCompletedHooks = []
        self.sessionStartHooks = []
        self.sessionEndHooks = []
        self.subagentStartHooks = []
        self.subagentStopHooks = []
        self.preCompactHooks = []
        self.permissionRequestHooks = []
        self.notificationHooks = []
        self.elicitationHooks = []
        self.elicitationResultHooks = []
        self.configChangeHooks = []
        self.worktreeCreateHooks = []
        self.worktreeRemoveHooks = []
    }
}

// MARK: - Thinking Config

/// Controls Claude's thinking/reasoning behavior.
public enum ThinkingConfig: Sendable, Equatable, Codable {
    /// Claude decides when and how much to think (Opus 4.6+).
    case adaptive

    /// Fixed thinking token budget (older models).
    case enabled(budgetTokens: Int?)

    /// No extended thinking.
    case disabled

    private enum CodingKeys: String, CodingKey {
        case type
        case budgetTokens = "budget_tokens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "adaptive":
            self = .adaptive
        case "enabled":
            let budget = try container.decodeIfPresent(Int.self, forKey: .budgetTokens)
            self = .enabled(budgetTokens: budget)
        case "disabled":
            self = .disabled
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: container.codingPath,
                                      debugDescription: "Unknown thinking type: \(type)")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .adaptive:
            try container.encode("adaptive", forKey: .type)
        case .enabled(let budget):
            try container.encode("enabled", forKey: .type)
            if let budget { try container.encode(budget, forKey: .budgetTokens) }
        case .disabled:
            try container.encode("disabled", forKey: .type)
        }
    }
}

// MARK: - SDK Plugin Config

/// Configuration for a local plugin.
public struct SdkPluginConfig: Sendable, Equatable, Codable {
    /// Plugin type. Currently only 'local' is supported.
    public let type: String

    /// Absolute or relative path to the plugin directory.
    public let path: String

    public init(type: String = "local", path: String) {
        self.type = type
        self.path = path
    }
}

// MARK: - Tools Config

/// Tools configuration: either an explicit list or a preset.
public enum ToolsConfig: Sendable, Equatable {
    /// Explicit list of tool names.
    case list([String])

    /// Use Claude Code's preset tools.
    case claudeCodePreset
}

// MARK: - Elicitation Types

/// An elicitation request from an MCP server asking for user input.
public struct ElicitationRequest: Sendable, Equatable, Codable {
    /// Name of the MCP server requesting elicitation.
    public let serverName: String

    /// Message to display to the user.
    public let message: String

    /// Elicitation mode: 'form' for structured input, 'url' for browser-based auth.
    public let mode: String?

    /// URL to open (only for 'url' mode).
    public let url: String?

    /// Elicitation ID for correlating URL elicitations with completion notifications.
    public let elicitationId: String?

    /// JSON Schema for the requested input (only for 'form' mode).
    public let requestedSchema: JSONValue?

    enum CodingKeys: String, CodingKey {
        case serverName = "server_name"
        case message, mode, url
        case elicitationId = "elicitation_id"
        case requestedSchema = "requested_schema"
    }

    public init(
        serverName: String,
        message: String,
        mode: String? = nil,
        url: String? = nil,
        elicitationId: String? = nil,
        requestedSchema: JSONValue? = nil
    ) {
        self.serverName = serverName
        self.message = message
        self.mode = mode
        self.url = url
        self.elicitationId = elicitationId
        self.requestedSchema = requestedSchema
    }
}

/// Result of an elicitation request.
public struct ElicitationResult: Sendable, Equatable, Codable {
    /// The user's action: 'accept', 'decline', or 'cancel'.
    public let action: String

    /// Form content provided by the user (for 'accept' action in 'form' mode).
    public let content: JSONValue?

    public init(action: String, content: JSONValue? = nil) {
        self.action = action
        self.content = content
    }

    /// Accept the elicitation with optional form content.
    public static func accept(content: JSONValue? = nil) -> ElicitationResult {
        ElicitationResult(action: "accept", content: content)
    }

    /// Decline the elicitation.
    public static func decline() -> ElicitationResult {
        ElicitationResult(action: "decline")
    }

    /// Cancel the elicitation.
    public static func cancel() -> ElicitationResult {
        ElicitationResult(action: "cancel")
    }
}

// MARK: - Output Format

/// Structured output format specification for JSON schema output.
public struct OutputFormat: Sendable, Equatable, Codable {
    /// The format type (e.g., "json_schema").
    public let type: String

    /// The JSON schema definition.
    public let schema: JSONValue

    /// Creates an output format specification.
    /// - Parameters:
    ///   - type: The format type (default "json_schema").
    ///   - schema: The JSON schema definition.
    public init(type: String = "json_schema", schema: JSONValue) {
        self.type = type
        self.schema = schema
    }
}
