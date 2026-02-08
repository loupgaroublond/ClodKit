//
//  V2SessionAPI.swift
//  ClodKit
//
//  V2 Session API functions (unstable, may change).
//

import Foundation

// MARK: - V2 Session API

/// Create a new V2 session.
@available(*, message: "V2 Session API is unstable and may change")
public func unstable_v2_createSession(options: SDKSessionOptions) -> any SDKSession {
    V2Session(options: options, sessionIdToResume: nil)
}

/// Send a single prompt and wait for the result.
@available(*, message: "V2 Session API is unstable and may change")
public func unstable_v2_prompt(_ message: String, options: SDKSessionOptions) async throws -> SDKResultMessage {
    let session = unstable_v2_createSession(options: options)
    try await session.send(message)
    for try await msg in session.stream() {
        if msg.type == "result" {
            return SDKResultMessage(
                type: msg.type,
                subtype: "success",
                result: msg.content?.stringValue,
                sessionId: msg.sessionId
            )
        }
    }
    throw SessionError.sessionClosed
}

/// Resume an existing V2 session.
@available(*, message: "V2 Session API is unstable and may change")
public func unstable_v2_resumeSession(sessionId: String, options: SDKSessionOptions) -> any SDKSession {
    V2Session(options: options, sessionIdToResume: sessionId)
}

// MARK: - receiveResponse() Convenience

@available(*, message: "V2 Session API is unstable and may change")
extension SDKSession {
    /// Receive all response messages for the current turn.
    ///
    /// Iterates the session's stream and yields each message until a "result"
    /// message is encountered (which is also yielded), then finishes the stream.
    /// Each call returns a fresh stream scoped to the next turn, enabling
    /// multi-turn send/receive patterns.
    ///
    /// Example:
    /// ```swift
    /// try await session.send("Hello")
    /// for try await message in session.receiveResponse() {
    ///     // Yields assistant messages, then result, then finishes
    /// }
    /// ```
    ///
    /// - Returns: An async stream of messages for this turn.
    public func receiveResponse() -> AsyncThrowingStream<SDKMessage, Error> {
        let sessionStream = self.stream()
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await msg in sessionStream {
                        continuation.yield(msg)
                        if msg.type == "result" {
                            continuation.finish()
                            return
                        }
                    }
                    // Stream ended without a result message
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - V2 Session Implementation

@available(*, message: "V2 Session API is unstable and may change")
internal final class V2Session: SDKSession, @unchecked Sendable {
    private let options: SDKSessionOptions
    private var _sessionId: String?
    private let sessionIdToResume: String?
    private var queryInstance: ClaudeQuery?

    init(options: SDKSessionOptions, sessionIdToResume: String?) {
        self.options = options
        self.sessionIdToResume = sessionIdToResume
        self._sessionId = sessionIdToResume
    }

    var sessionId: String {
        get async throws {
            guard let id = _sessionId else {
                throw SessionError.notInitialized
            }
            return id
        }
    }

    func send(_ message: String) async throws {
        var opts = QueryOptions()
        opts.model = options.model
        if let path = options.pathToClaudeCodeExecutable { opts.cliPath = path }
        if let tools = options.allowedTools { opts.allowedTools = tools }
        if let blocked = options.disallowedTools { opts.blockedTools = blocked }
        if let mode = options.permissionMode { opts.permissionMode = mode }
        if let canUse = options.canUseTool { opts.canUseTool = canUse }
        if let sessionIdToResume { opts.resume = sessionIdToResume }

        let q = try await ClodKit.query(prompt: message, options: opts)
        self.queryInstance = q
        if let sid = await q.sessionId {
            self._sessionId = sid
        }
    }

    func stream() -> AsyncThrowingStream<SDKMessage, Error> {
        guard let q = queryInstance else {
            return AsyncThrowingStream { $0.finish(throwing: SessionError.notInitialized) }
        }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await msg in q {
                        if case .regular(let sdkMsg) = msg {
                            continuation.yield(sdkMsg)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func close() {
        // Query doesn't have close yet, but session does
        // This will be wired when close() is added to ClaudeQuery
    }
}
