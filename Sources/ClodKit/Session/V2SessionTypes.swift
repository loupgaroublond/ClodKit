//
//  V2SessionTypes.swift
//  ClodKit
//
//  V2 Session API types (unstable, may change).
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

// MARK: - SDK Session Options

/// Options for creating a V2 SDK session.
@available(*, message: "V2 Session API is unstable and may change")
public struct SDKSessionOptions: Sendable {
    /// The model to use (required).
    public let model: String

    /// Path to the Claude Code executable.
    public var pathToClaudeCodeExecutable: String?

    /// Additional arguments for the executable.
    public var executableArgs: [String]?

    /// Environment variables for the process.
    public var env: [String: String]?

    /// Tools allowed for this session.
    public var allowedTools: [String]?

    /// Tools blocked for this session.
    public var disallowedTools: [String]?

    /// Permission callback for tool use requests.
    public var canUseTool: CanUseToolCallback?

    /// Permission mode for the session.
    public var permissionMode: PermissionMode?

    public init(model: String) {
        self.model = model
    }
}

// MARK: - SDK Result Message

/// A result message from a V2 SDK session.
@available(*, message: "V2 Session API is unstable and may change")
public struct SDKResultMessage: Sendable, Equatable, Codable {
    /// The message type.
    public let type: String

    /// The result subtype (e.g., "success", "error").
    public let subtype: String

    /// The result content.
    public let result: String?

    /// The session ID.
    public let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case type, subtype, result, sessionId = "session_id"
    }

    public init(type: String, subtype: String, result: String? = nil, sessionId: String? = nil) {
        self.type = type
        self.subtype = subtype
        self.result = result
        self.sessionId = sessionId
    }
}
