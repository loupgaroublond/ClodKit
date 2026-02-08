//
//  ClaudeSession.swift
//  ClodKit
//
//  Actor managing a Claude Code session with control protocol.
//

import Foundation
import os

// MARK: - ClaudeSession

/// Actor managing a Claude Code session with full control protocol support.
///
/// ClaudeSession integrates all SDK components:
/// - Transport for subprocess communication
/// - ControlProtocolHandler for bidirectional control messages
/// - HookRegistry for pre/post tool use hooks
/// - MCPServerRouter for SDK MCP tools
///
/// Example usage:
/// ```swift
/// let transport = ProcessTransport(cliPath: "/path/to/claude", arguments: [...])
/// let session = ClaudeSession(transport: transport)
///
/// // Configure before starting
/// await session.setCanUseTool { toolName, input, context in
///     return .allowTool()
/// }
///
/// // Initialize and start message loop
/// try await session.initialize()
/// for try await message in session.startMessageLoop() {
///     // Handle messages
/// }
/// ```
public actor ClaudeSession {
    /// The transport for CLI communication.
    private let transport: Transport

    /// Control protocol handler for bidirectional communication.
    private let controlHandler: ControlProtocolHandler

    /// Registry for hook callbacks.
    private let hookRegistry: HookRegistry

    /// Router for SDK MCP servers.
    private let mcpRouter: MCPServerRouter

    /// Logger for debugging.
    private let logger: Logger?

    /// Session ID from the CLI.
    private var sessionId: String?

    /// Whether the session has been initialized.
    private var isInitialized = false

    /// User-provided permission callback.
    private var canUseToolCallback: CanUseToolCallback?

    /// Creates a new Claude session.
    /// - Parameters:
    ///   - transport: The transport for CLI communication.
    ///   - logger: Optional logger for debugging.
    public init(transport: Transport, logger: Logger? = nil) {
        self.transport = transport
        self.logger = logger
        self.controlHandler = ControlProtocolHandler(transport: transport)
        self.hookRegistry = HookRegistry()
        self.mcpRouter = MCPServerRouter()
    }

    // MARK: - Configuration

    /// Set the permission callback for tool use requests.
    /// - Parameter callback: Callback invoked when CLI requests permission.
    public func setCanUseTool(_ callback: @escaping CanUseToolCallback) {
        canUseToolCallback = callback
    }

    /// Register an SDK MCP server.
    /// - Parameter server: The server to register.
    public func registerMCPServer(_ server: SDKMCPServer) async {
        await mcpRouter.registerServer(server)
    }

    /// Register a pre-tool-use hook.
    /// - Parameters:
    ///   - pattern: Optional tool name pattern to match.
    ///   - timeout: Callback timeout in seconds.
    ///   - callback: Hook callback.
    public func onPreToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PreToolUseInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onPreToolUse(matching: pattern, timeout: timeout, callback: callback)
    }

    /// Register a post-tool-use hook.
    /// - Parameters:
    ///   - pattern: Optional tool name pattern to match.
    ///   - timeout: Callback timeout in seconds.
    ///   - callback: Hook callback.
    public func onPostToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PostToolUseInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onPostToolUse(matching: pattern, timeout: timeout, callback: callback)
    }

    /// Register a post-tool-use failure hook.
    /// - Parameters:
    ///   - pattern: Optional tool name pattern to match.
    ///   - timeout: Callback timeout in seconds.
    ///   - callback: Hook callback.
    public func onPostToolUseFailure(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PostToolUseFailureInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onPostToolUseFailure(matching: pattern, timeout: timeout, callback: callback)
    }

    /// Register a user-prompt-submit hook.
    /// - Parameters:
    ///   - timeout: Callback timeout in seconds.
    ///   - callback: Hook callback.
    public func onUserPromptSubmit(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (UserPromptSubmitInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onUserPromptSubmit(timeout: timeout, callback: callback)
    }

    /// Register a stop hook.
    /// - Parameters:
    ///   - timeout: Callback timeout in seconds.
    ///   - callback: Hook callback.
    public func onStop(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (StopInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onStop(timeout: timeout, callback: callback)
    }

    /// Register a setup hook.
    public func onSetup(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SetupInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onSetup(timeout: timeout, callback: callback)
    }

    /// Register a teammate-idle hook.
    public func onTeammateIdle(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (TeammateIdleInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onTeammateIdle(timeout: timeout, callback: callback)
    }

    /// Register a task-completed hook.
    public func onTaskCompleted(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (TaskCompletedInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onTaskCompleted(timeout: timeout, callback: callback)
    }

    /// Register a session-start hook.
    public func onSessionStart(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SessionStartInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onSessionStart(timeout: timeout, callback: callback)
    }

    /// Register a session-end hook.
    public func onSessionEnd(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SessionEndInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onSessionEnd(timeout: timeout, callback: callback)
    }

    /// Register a subagent-start hook.
    public func onSubagentStart(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SubagentStartInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onSubagentStart(timeout: timeout, callback: callback)
    }

    /// Register a subagent-stop hook.
    public func onSubagentStop(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SubagentStopInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onSubagentStop(timeout: timeout, callback: callback)
    }

    /// Register a pre-compact hook.
    public func onPreCompact(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PreCompactInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onPreCompact(timeout: timeout, callback: callback)
    }

    /// Register a permission-request hook.
    public func onPermissionRequest(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PermissionRequestInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onPermissionRequest(matching: pattern, timeout: timeout, callback: callback)
    }

    /// Register a notification hook.
    public func onNotification(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (NotificationInput) async throws -> HookOutput
    ) async {
        await hookRegistry.onNotification(timeout: timeout, callback: callback)
    }

    // MARK: - Session Lifecycle

    /// Initialize the session and set up control protocol handlers.
    /// - Throws: If initialization fails.
    public func initialize() async throws {
        guard !isInitialized else { return }

        // Set up can_use_tool handler
        await controlHandler.setCanUseToolHandler { [weak self] request in
            guard let self else {
                return .allowTool()
            }
            return await self.handleCanUseToolRequest(request)
        }

        // Set up hook callback handler
        await controlHandler.setHookCallbackHandler { [weak self] request in
            guard let self else {
                throw SessionError.sessionClosed
            }
            return try await self.hookRegistry.invokeCallback(
                callbackId: request.callbackId,
                rawInput: request.input
            )
        }

        // Set up MCP message handler
        await controlHandler.setMCPMessageHandler { [weak self] serverName, message in
            guard let self else {
                throw SessionError.sessionClosed
            }
            let mcpRequest = MCPMessageRequest(serverName: serverName, message: message)
            return await self.mcpRouter.route(mcpRequest)
        }

        // Send initialize control request
        let hookConfig = await hookRegistry.getHookConfig()
        let mcpServers = await mcpRouter.getServerNames()
        let _ = try await controlHandler.initialize(
            hooks: hookConfig,
            sdkMcpServers: mcpServers.isEmpty ? nil : mcpServers
        )

        isInitialized = true
        logger?.info("Session initialized")
    }

    /// Handle a can_use_tool request from the CLI.
    private func handleCanUseToolRequest(_ request: CanUseToolRequest) async -> PermissionResult {
        guard let callback = canUseToolCallback else {
            // No callback registered - allow by default
            return .allowTool()
        }

        // Build context from request
        let context = ToolPermissionContext(
            suggestions: [],  // Could be populated from request if available
            blockedPath: request.blockedPath,
            decisionReason: nil,
            agentId: request.agentId
        )

        do {
            return try await callback(request.toolName, request.input, context)
        } catch {
            logger?.error("Permission callback threw error: \(error.localizedDescription)")
            // On error, deny for safety
            return .denyTool("Permission callback error: \(error.localizedDescription)")
        }
    }

    // MARK: - Message Processing

    /// Start the message loop and return an async stream of messages.
    /// - Returns: AsyncThrowingStream of SDK messages.
    public func startMessageLoop() -> AsyncThrowingStream<StdoutMessage, Error> {
        // Capture dependencies that don't require actor isolation
        let transport = self.transport
        let controlHandler = self.controlHandler
        let logger = self.logger

        // Create a weak reference wrapper to avoid keeping the session alive
        let weakSession = WeakSessionRef(self)

        return AsyncThrowingStream { continuation in
            guard weakSession.session != nil else {
                // Session was deallocated before stream could start - throw error
                continuation.finish(throwing: SessionError.sessionClosed)
                return
            }

            Task {
                // Run message loop with periodic session validity checks
                await ClaudeSession.runMessageLoop(
                    weakSession: weakSession,
                    transport: transport,
                    controlHandler: controlHandler,
                    logger: logger,
                    continuation: continuation
                )
            }
        }
    }

    /// Static message loop that doesn't hold the session alive.
    /// Uses weak reference to session for validity checking and state updates.
    private static func runMessageLoop(
        weakSession: WeakSessionRef,
        transport: Transport,
        controlHandler: ControlProtocolHandler,
        logger: Logger?,
        continuation: AsyncThrowingStream<StdoutMessage, Error>.Continuation
    ) async {
        // Check if session is already gone
        guard weakSession.session != nil else {
            continuation.finish(throwing: SessionError.sessionClosed)
            return
        }

        // Track if we've finished the stream
        let finished = FinishedFlag()

        // Track if we've received a result and closed stdin
        // Like TypeScript SDK, we close stdin after first result to signal CLI to exit
        var hasReceivedResult = false

        // Start a monitoring task that checks session validity periodically
        // and closes the transport if the session is deallocated
        let monitorTask = Task {
            while !Task.isCancelled && !finished.value {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                if weakSession.session == nil && !finished.value {
                    // Session was deallocated - close transport to unblock the message loop
                    transport.close()
                    return
                }
            }
        }

        defer {
            monitorTask.cancel()
        }

        do {
            for try await message in transport.readMessages() {
                // Check if session was deallocated during iteration
                guard let session = weakSession.session else {
                    finished.value = true
                    continuation.finish(throwing: SessionError.sessionClosed)
                    return
                }

                switch message {
                case .regular(let sdkMessage):
                    // Extract session ID from init message
                    if sdkMessage.type == "system",
                       let data = sdkMessage.data,
                       case .object(let obj) = data,
                       case .string(let subtype) = obj["subtype"],
                       subtype == "init",
                       case .string(let sessId) = obj["session_id"] {
                        await session.setSessionId(sessId)
                        logger?.info("Session ID: \(sessId)")
                    }

                    // Close stdin after first result message (like TypeScript SDK)
                    // This signals to the CLI that we're done and it should exit
                    if sdkMessage.type == "result" && !hasReceivedResult {
                        hasReceivedResult = true
                        logger?.debug("Received result message, closing stdin")
                        await transport.endInput()
                    }

                    continuation.yield(message)

                case .controlRequest(let request):
                    await controlHandler.handleControlRequest(request)

                case .controlResponse(let response):
                    await controlHandler.handleControlResponse(response)

                case .controlCancelRequest(let cancel):
                    await controlHandler.handleCancelRequest(cancel)

                case .keepAlive:
                    // Ignore keepalive messages
                    break
                }
            }
        } catch {
            finished.value = true
            // Check if this was due to session deallocation
            if weakSession.session == nil {
                continuation.finish(throwing: SessionError.sessionClosed)
            } else {
                logger?.error("Message loop error: \(error.localizedDescription)")
                continuation.finish(throwing: error)
            }
            return
        }

        finished.value = true
        // Final check if session was deallocated
        if weakSession.session == nil {
            continuation.finish(throwing: SessionError.sessionClosed)
        } else {
            continuation.finish()
        }
    }

    /// Internal method to set session ID (called from static runMessageLoop).
    fileprivate func setSessionId(_ id: String) {
        sessionId = id
    }

    // MARK: - Control Methods

    /// Interrupt the current operation.
    /// - Throws: If the interrupt request fails.
    public func interrupt() async throws {
        let _ = try await controlHandler.interrupt()
    }

    /// Change the model mid-query.
    /// - Parameter model: The model name, or nil to reset.
    /// - Throws: If the request fails.
    public func setModel(_ model: String?) async throws {
        let _ = try await controlHandler.setModel(model)
    }

    /// Change the permission mode.
    /// - Parameter mode: The new permission mode.
    /// - Throws: If the request fails.
    public func setPermissionMode(_ mode: PermissionMode) async throws {
        let _ = try await controlHandler.setPermissionMode(mode)
    }

    /// Set the maximum thinking tokens.
    /// - Parameter tokens: The token limit, or nil to reset.
    /// - Throws: If the request fails.
    public func setMaxThinkingTokens(_ tokens: Int?) async throws {
        let _ = try await controlHandler.setMaxThinkingTokens(tokens)
    }

    /// Rewind files to a previous checkpoint.
    /// - Parameters:
    ///   - messageId: The user message ID to rewind to.
    ///   - dryRun: If true, only report what would change.
    /// - Returns: The response payload.
    /// - Throws: If the request fails.
    public func rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> FullControlResponsePayload {
        try await controlHandler.rewindFiles(userMessageId: messageId, dryRun: dryRun)
    }

    /// Get MCP server status.
    /// - Returns: The response payload.
    /// - Throws: If the request fails.
    public func mcpStatus() async throws -> FullControlResponsePayload {
        try await controlHandler.mcpStatus()
    }

    /// Reconnect an MCP server.
    /// - Parameter name: The server name to reconnect.
    /// - Throws: If the request fails.
    public func reconnectMcpServer(name: String) async throws {
        let _ = try await controlHandler.mcpReconnect(serverName: name)
    }

    /// Toggle an MCP server enabled/disabled.
    /// - Parameters:
    ///   - name: The server name.
    ///   - enabled: Whether to enable or disable.
    /// - Throws: If the request fails.
    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        let _ = try await controlHandler.mcpToggle(serverName: name, enabled: enabled)
    }

    /// Close the session.
    public func close() {
        transport.close()
    }

    /// The current session ID (if available).
    public var currentSessionId: String? { sessionId }

    /// Whether the session has been initialized.
    public var initialized: Bool { isInitialized }
}

// MARK: - Session Errors

/// Errors that can occur during session operations.
public enum SessionError: Error, Sendable, Equatable {
    /// The session has been closed.
    case sessionClosed

    /// The session has not been initialized.
    case notInitialized

    /// An initialization error occurred.
    case initializationFailed(String)
}

extension SessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sessionClosed:
            return "Session has been closed"
        case .notInitialized:
            return "Session has not been initialized"
        case .initializationFailed(let reason):
            return "Session initialization failed: \(reason)"
        }
    }
}

// MARK: - Weak Reference Wrapper

/// Wrapper to hold a weak reference to ClaudeSession.
/// Used by runMessageLoop to avoid keeping the session alive.
///
/// Safety: `@unchecked Sendable` is correct because:
/// - Weak reference reads/writes are atomic in Swift's runtime
/// - ClaudeSession is an actor, so any actual use is actor-isolated
/// - The weak reference can only transition from non-nil to nil (when session deallocates)
private final class WeakSessionRef: @unchecked Sendable {
    weak var session: ClaudeSession?

    init(_ session: ClaudeSession) {
        self.session = session
    }
}

/// Thread-safe flag for tracking finished state.
/// Used to coordinate between the message loop and the monitor task.
///
/// Safety: `@unchecked Sendable` is correct because all mutable state
/// (`_value`) is protected by NSLock. All access goes through the lock.
private final class FinishedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Bool = false

    var value: Bool {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
