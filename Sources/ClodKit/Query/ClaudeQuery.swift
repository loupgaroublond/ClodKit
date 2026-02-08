//
//  ClaudeQuery.swift
//  ClodKit
//
//  AsyncSequence wrapper for Claude Code queries with control methods.
//

import Foundation

/// AsyncSequence wrapper providing iteration and control methods for a Claude query.
///
/// ClaudeQuery wraps a ClaudeSession and provides:
/// - AsyncSequence iteration over messages
/// - Control methods (interrupt, setModel, etc.)
/// - Session information (sessionId)
///
/// Example usage:
/// ```swift
/// let query = try await ClaudeCode.query("Write a function", options: options)
/// for try await message in query {
///     // Handle message
/// }
/// ```
public final class ClaudeQuery: AsyncSequence, Sendable {
    /// The element type yielded by iteration.
    public typealias Element = StdoutMessage

    /// The underlying session.
    private let session: ClaudeSession

    /// The message stream from the session.
    private let underlyingStream: AsyncThrowingStream<StdoutMessage, Error>

    /// Creates a new ClaudeQuery wrapping a session.
    /// - Parameters:
    ///   - session: The ClaudeSession to wrap.
    ///   - stream: The message stream from the session.
    internal init(session: ClaudeSession, stream: AsyncThrowingStream<StdoutMessage, Error>) {
        self.session = session
        self.underlyingStream = stream
    }

    /// Creates an async iterator for the query.
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: underlyingStream)
    }

    /// AsyncIterator for ClaudeQuery.
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<StdoutMessage, Error>.Iterator

        init(stream: AsyncThrowingStream<StdoutMessage, Error>) {
            self.iterator = stream.makeAsyncIterator()
        }

        /// Returns the next message from the query.
        public mutating func next() async throws -> StdoutMessage? {
            try await iterator.next()
        }
    }

    // MARK: - Control Methods

    /// Interrupt the current operation.
    /// - Throws: If the interrupt request fails.
    public func interrupt() async throws {
        try await session.interrupt()
    }

    /// Change the model mid-query.
    /// - Parameter model: The model name, or nil to reset.
    /// - Throws: If the request fails.
    public func setModel(_ model: String?) async throws {
        try await session.setModel(model)
    }

    /// Change the permission mode.
    /// - Parameter mode: The new permission mode.
    /// - Throws: If the request fails.
    public func setPermissionMode(_ mode: PermissionMode) async throws {
        try await session.setPermissionMode(mode)
    }

    /// Set the maximum thinking tokens.
    /// - Parameter tokens: The token limit, or nil to reset.
    /// - Throws: If the request fails.
    public func setMaxThinkingTokens(_ tokens: Int?) async throws {
        try await session.setMaxThinkingTokens(tokens)
    }

    /// Rewind files to a previous checkpoint.
    /// - Parameters:
    ///   - messageId: The user message ID to rewind to.
    ///   - dryRun: If true, only report what would change.
    /// - Returns: The response payload.
    /// - Throws: If the request fails.
    public func rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> FullControlResponsePayload {
        try await session.rewindFiles(to: messageId, dryRun: dryRun)
    }

    /// Get MCP server status.
    /// - Returns: The response payload.
    /// - Throws: If the request fails.
    public func mcpStatus() async throws -> FullControlResponsePayload {
        try await session.mcpStatus()
    }

    /// Reconnect an MCP server.
    /// - Parameter name: The server name to reconnect.
    /// - Throws: If the request fails.
    public func reconnectMcpServer(name: String) async throws {
        try await session.reconnectMcpServer(name: name)
    }

    /// Toggle an MCP server enabled/disabled.
    /// - Parameters:
    ///   - name: The server name.
    ///   - enabled: Whether to enable or disable.
    /// - Throws: If the request fails.
    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        try await session.toggleMcpServer(name: name, enabled: enabled)
    }

    /// Get the initialization result from the control protocol.
    /// - Returns: The decoded initialization response.
    /// - Throws: If the session has not been initialized or decoding fails.
    public func initializationResult() async throws -> SDKControlInitializeResponse {
        try await session.initializationResult()
    }

    /// Set MCP servers configuration.
    /// - Parameter servers: Server configurations keyed by name.
    /// - Returns: The result of setting servers.
    /// - Throws: If the request fails.
    public func setMcpServers(_ servers: [String: MCPServerConfig]) async throws -> McpSetServersResult {
        try await session.setMcpServers(servers)
    }

    /// Stream input messages to the query.
    /// - Parameter stream: An async sequence of user messages.
    /// - Throws: If writing fails.
    public func streamInput<S: AsyncSequence>(_ stream: S) async throws where S.Element == SDKUserMessage {
        for try await message in stream {
            let data = try JSONEncoder().encode(message)
            try await session.writeToTransport(data)
        }
    }

    /// Close the query and terminate the session.
    public func close() async {
        await session.close()
    }

    /// Rewind files to a previous checkpoint.
    /// - Parameters:
    ///   - messageId: The user message ID to rewind to.
    ///   - dryRun: If true, only report what would change.
    /// - Returns: The rewind files result.
    /// - Throws: If the request fails.
    public func rewindFilesTyped(to messageId: String, dryRun: Bool = false) async throws -> RewindFilesResult {
        let response = try await session.rewindFiles(to: messageId, dryRun: dryRun)
        switch response {
        case .success(_, let jsonValue):
            guard let jsonValue else {
                return RewindFilesResult(canRewind: false, error: "No response data")
            }
            let data = try JSONEncoder().encode(jsonValue)
            return try JSONDecoder().decode(RewindFilesResult.self, from: data)
        case .error(_, let error, _):
            throw QueryError.invalidOptions(error)
        }
    }

    /// The current session ID (if available).
    public var sessionId: String? {
        get async { await session.currentSessionId }
    }
}
