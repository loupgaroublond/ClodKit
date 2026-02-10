//
//  SDKSession.swift
//  ClodKit
//
//  V2 Session protocol (unstable, may change).
//

import Foundation

// MARK: - SDK Session Protocol

/// Protocol for a V2 SDK session.
@available(*, message: "V2 Session API is unstable and may change")
public protocol SDKSession: Sendable {
    /// The session ID.
    var sessionId: String { get async throws }

    /// Send a message to the session.
    func send(_ message: String) async throws

    /// Stream messages from the session.
    func stream() -> AsyncThrowingStream<SDKMessage, Error>

    /// Close the session.
    func close()
}
