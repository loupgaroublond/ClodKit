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
        self.betas = []
        self.mcpServers = [:]
        self.sdkMcpServers = [:]
        self.preToolUseHooks = []
        self.postToolUseHooks = []
        self.postToolUseFailureHooks = []
        self.userPromptSubmitHooks = []
        self.stopHooks = []
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
