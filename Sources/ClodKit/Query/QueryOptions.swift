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

    /// Creates default query options.
    public init() {
        self.environment = [:]
        self.additionalDirectories = []
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
    }
}
