//
//  NativeClaudeCodeBackend.swift
//  ClodKit
//
//  Protocol for Claude Code execution backends.
//

import Foundation

// MARK: - Native Backend Protocol

/// Protocol for Claude Code execution backends using native Swift implementation.
/// This mirrors the ClaudeCodeBackend protocol but uses native types.
public protocol NativeClaudeCodeBackend: Sendable {
    /// Execute a single prompt and return a streaming query.
    /// - Parameters:
    ///   - prompt: The prompt text to send.
    ///   - options: Configuration options.
    /// - Returns: A ClaudeQuery for streaming responses.
    func runSinglePrompt(
        prompt: String,
        options: QueryOptions
    ) async throws -> ClaudeQuery

    /// Resume a specific session.
    /// - Parameters:
    ///   - sessionId: The session ID to resume.
    ///   - prompt: Optional prompt for the resumed session.
    ///   - options: Configuration options.
    /// - Returns: A ClaudeQuery for streaming responses.
    func resumeSession(
        sessionId: String,
        prompt: String?,
        options: QueryOptions
    ) async throws -> ClaudeQuery

    /// Cancel any ongoing operations.
    func cancel()

    /// Validate that the backend is properly configured.
    /// - Returns: true if the backend is ready to use.
    func validateSetup() async throws -> Bool
}
