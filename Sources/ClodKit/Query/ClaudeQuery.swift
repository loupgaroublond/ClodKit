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

    /// The current session ID (if available).
    public var sessionId: String? {
        get async { await session.currentSessionId }
    }
}
