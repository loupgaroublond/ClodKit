//
//  QueryAPI.swift
//  ClodKit
//
//  Public query API for sending prompts to Claude Code.
//  EXCEPTION: Entry point function + helpers + namespace are kept together.
//

import Foundation
import os

// MARK: - Query Function

/// Send a query to Claude Code.
///
/// This is the main entry point for the SDK. It creates a new session,
/// sends the prompt, and returns a ClaudeQuery that can be iterated
/// to receive response messages.
///
/// Example:
/// ```swift
/// let query = try await Clod.query("Write a function", options: options)
/// for try await message in query {
///     // Handle message
/// }
/// ```
///
/// - Parameters:
///   - prompt: The prompt to send to Claude.
///   - options: Configuration options for the query.
/// - Returns: A ClaudeQuery that yields response messages.
/// - Throws: QueryError if the query cannot be started.
public func query(
    prompt: String,
    options: QueryOptions = QueryOptions()
) async throws -> ClaudeQuery {
    // Build CLI arguments
    var arguments = buildCLIArguments(from: options)

    // Build MCP config for both external AND SDK servers
    // SDK servers are passed as {type: "sdk", name: "server_name"} which tells the CLI
    // to route MCP calls back through the control protocol to the SDK for handling.
    let hasSdkMcp = !options.sdkMcpServers.isEmpty
    let hasExternalMcp = !options.mcpServers.isEmpty
    if hasExternalMcp || hasSdkMcp {
        let sdkServerNames = Array(options.sdkMcpServers.keys)
        let configPath = try buildMCPConfigFile(external: options.mcpServers, sdkServers: sdkServerNames)
        arguments.append(contentsOf: ["--mcp-config", configPath])
    }

    // Create transport with structured arguments (no shell interpolation)
    let cliPath = options.cliPath ?? "claude"
    let transport = ProcessTransport(
        executablePath: cliPath,
        arguments: arguments,
        workingDirectory: options.workingDirectory,
        additionalEnvironment: options.environment,
        stderrHandler: options.stderrHandler
    )

    // Create session
    let session = ClaudeSession(transport: transport, logger: options.logger)

    // Register SDK MCP servers
    for (_, server) in options.sdkMcpServers {
        await session.registerMCPServer(server)
    }

    // Register hooks
    for hook in options.preToolUseHooks {
        await session.onPreToolUse(matching: hook.pattern, timeout: hook.timeout, callback: hook.callback)
    }
    for hook in options.postToolUseHooks {
        await session.onPostToolUse(matching: hook.pattern, timeout: hook.timeout, callback: hook.callback)
    }
    for hook in options.postToolUseFailureHooks {
        await session.onPostToolUseFailure(matching: hook.pattern, timeout: hook.timeout, callback: hook.callback)
    }
    for hook in options.userPromptSubmitHooks {
        await session.onUserPromptSubmit(timeout: hook.timeout, callback: hook.callback)
    }
    for hook in options.stopHooks {
        await session.onStop(timeout: hook.timeout, callback: hook.callback)
    }

    // Set permission callback
    if let canUseTool = options.canUseTool {
        await session.setCanUseTool(canUseTool)
    }

    // Start transport
    try transport.start()

    // IMPORTANT: Start message loop BEFORE sending prompt to capture all output
    // The stream must be ready before we send data or messages may be lost
    let stream = await session.startMessageLoop()

    // Initialize control protocol if we have SDK MCP servers or hooks
    let needsControlProtocol = hasSdkMcp ||
        !options.preToolUseHooks.isEmpty ||
        !options.postToolUseHooks.isEmpty ||
        !options.postToolUseFailureHooks.isEmpty ||
        !options.userPromptSubmitHooks.isEmpty ||
        !options.stopHooks.isEmpty ||
        options.canUseTool != nil

    if needsControlProtocol {
        try await session.initialize()
    }

    // Send the prompt in stream-json format
    // Format: {"type":"user","message":{"role":"user","content":"..."}}
    let promptPayload: [String: Any] = [
        "type": "user",
        "message": [
            "role": "user",
            "content": prompt
        ]
    ]
    let promptData = try JSONSerialization.data(withJSONObject: promptPayload, options: [])
    try await transport.write(promptData)

    // Close stdin if we don't need control protocol
    if !needsControlProtocol {
        await transport.endInput()
    }

    // Return query wrapping the already-started stream
    return ClaudeQuery(session: session, stream: stream)
}

// MARK: - Private Helpers

/// Build CLI arguments from options.
private func buildCLIArguments(from options: QueryOptions) -> [String] {
    var arguments = [
        "-p",
        "--output-format", "stream-json",
        "--input-format", "stream-json",
        "--verbose"
    ]

    if let model = options.model {
        arguments.append(contentsOf: ["--model", model])
    }
    if let maxTurns = options.maxTurns {
        arguments.append(contentsOf: ["--max-turns", String(maxTurns)])
    }
    if let maxThinkingTokens = options.maxThinkingTokens {
        arguments.append(contentsOf: ["--max-thinking-tokens", String(maxThinkingTokens)])
    }
    if let permissionMode = options.permissionMode {
        arguments.append(contentsOf: ["--permission-mode", permissionMode.rawValue])
    }
    // If canUseTool callback is provided, tell CLI to use stdio for permission prompts
    // This enables the control protocol to send can_use_tool requests to the SDK
    if options.canUseTool != nil {
        arguments.append(contentsOf: ["--permission-prompt-tool", "stdio"])
    }
    if let systemPrompt = options.systemPrompt {
        arguments.append(contentsOf: ["--system-prompt", systemPrompt])
    }
    if let appendSystemPrompt = options.appendSystemPrompt {
        arguments.append(contentsOf: ["--append-system-prompt", appendSystemPrompt])
    }
    if let allowedTools = options.allowedTools, !allowedTools.isEmpty {
        arguments.append(contentsOf: ["--allowed-tools", allowedTools.joined(separator: ",")])
    }
    if let blockedTools = options.blockedTools, !blockedTools.isEmpty {
        for tool in blockedTools {
            arguments.append(contentsOf: ["--disallowed-tools", tool])
        }
    }
    for directory in options.additionalDirectories {
        arguments.append(contentsOf: ["--add-dir", directory])
    }
    if let resume = options.resume {
        arguments.append(contentsOf: ["--resume", resume])
    }

    return arguments
}

/// Build MCP config file for external and SDK MCP servers.
/// - Parameters:
///   - external: External MCP server configurations (stdio, http, sse).
///   - sdkServers: Names of SDK MCP servers (handled in-process via control protocol).
/// - Returns: Path to the temporary config file.
private func buildMCPConfigFile(external: [String: MCPServerConfig], sdkServers: [String] = []) throws -> String {
    var mcpServers: [String: Any] = [:]

    // Add external servers with their full config
    for (name, config) in external {
        mcpServers[name] = config.toDictionary()
    }

    // Add SDK servers with type: "sdk" - this tells the CLI to route MCP calls
    // back through the control protocol to the SDK for handling
    for name in sdkServers {
        mcpServers[name] = ["type": "sdk", "name": name]
    }

    let config: [String: Any] = ["mcpServers": mcpServers]

    // Serialize to JSON
    let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])

    // Write to temp file
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "mcp-config-\(UUID().uuidString).json"
    let filePath = tempDir.appendingPathComponent(fileName)

    try data.write(to: filePath)

    return filePath.path
}

// MARK: - Query Error

/// Errors that can occur when starting a query.
public enum QueryError: Error, Sendable, Equatable {
    /// The CLI failed to start.
    case launchFailed(String)

    /// Failed to build MCP config.
    case mcpConfigFailed(String)

    /// Invalid options.
    case invalidOptions(String)
}

extension QueryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return "Failed to launch Claude CLI: \(reason)"
        case .mcpConfigFailed(let reason):
            return "Failed to build MCP config: \(reason)"
        case .invalidOptions(let reason):
            return "Invalid query options: \(reason)"
        }
    }
}

// MARK: - ClodKit Namespace

/// Namespace for ClodKit SDK functions.
/// "It's just a turf!"
public enum Clod {
    /// Send a query to Claude Code.
    ///
    /// Example:
    /// ```swift
    /// let query = try await Clod.query("Write a function", options: options)
    /// for try await message in query {
    ///     // Handle message
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prompt: The prompt to send to Claude.
    ///   - options: Configuration options for the query.
    /// - Returns: A ClaudeQuery that yields response messages.
    /// - Throws: QueryError if the query cannot be started.
    public static func query(
        prompt: String,
        options: QueryOptions = QueryOptions()
    ) async throws -> ClaudeQuery {
        try await ClodKit.query(prompt: prompt, options: options)
    }
}
