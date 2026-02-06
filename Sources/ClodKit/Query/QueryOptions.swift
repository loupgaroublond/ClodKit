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

    // MARK: - Permission Callback

    /// Permission callback for tool use requests.
    public var canUseTool: CanUseToolCallback?

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
    }
}
