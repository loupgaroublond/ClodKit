//
//  SDKSessionInfo.swift
//  ClodKit
//
//  Session metadata returned by listSessions.
//

import Foundation

// MARK: - SDK Session Info

/// Session metadata returned by listSessions.
public struct SDKSessionInfo: Sendable, Equatable, Codable {
    /// Unique session identifier (UUID).
    public let sessionId: String

    /// Display title for the session.
    public let summary: String

    /// Last modified time in milliseconds since epoch.
    public let lastModified: Double

    /// Session file size in bytes.
    public let fileSize: Int

    /// User-set session title via /rename.
    public let customTitle: String?

    /// First meaningful user prompt in the session.
    public let firstPrompt: String?

    /// Git branch at the end of the session.
    public let gitBranch: String?

    /// Working directory for the session.
    public let cwd: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "sessionId"
        case summary
        case lastModified = "lastModified"
        case fileSize = "fileSize"
        case customTitle = "customTitle"
        case firstPrompt = "firstPrompt"
        case gitBranch = "gitBranch"
        case cwd
    }

    public init(
        sessionId: String,
        summary: String,
        lastModified: Double,
        fileSize: Int,
        customTitle: String? = nil,
        firstPrompt: String? = nil,
        gitBranch: String? = nil,
        cwd: String? = nil
    ) {
        self.sessionId = sessionId
        self.summary = summary
        self.lastModified = lastModified
        self.fileSize = fileSize
        self.customTitle = customTitle
        self.firstPrompt = firstPrompt
        self.gitBranch = gitBranch
        self.cwd = cwd
    }
}

// MARK: - Session Message

/// A message returned by getSessionMessages for reading historical session data.
public struct SessionMessage: Sendable, Equatable, Codable {
    public let type: String
    public let uuid: String
    public let sessionId: String
    public let message: JSONValue
    public let parentToolUseId: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type, uuid
        case sessionId = "session_id"
        case message
        case parentToolUseId = "parent_tool_use_id"
    }

    public init(type: String, uuid: String, sessionId: String, message: JSONValue, parentToolUseId: JSONValue? = nil) {
        self.type = type
        self.uuid = uuid
        self.sessionId = sessionId
        self.message = message
        self.parentToolUseId = parentToolUseId
    }
}

// MARK: - Get Session Messages Options

/// Options for retrieving session messages.
public struct GetSessionMessagesOptions: Sendable, Equatable, Codable {
    /// Project directory to find the session in.
    public let dir: String?

    /// Maximum number of messages to return.
    public let limit: Int?

    /// Number of messages to skip from the start.
    public let offset: Int?

    public init(dir: String? = nil, limit: Int? = nil, offset: Int? = nil) {
        self.dir = dir
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - List Sessions Options

/// Options for listing sessions.
public struct ListSessionsOptions: Sendable, Equatable, Codable {
    /// Directory to list sessions for.
    public let dir: String?

    /// Maximum number of sessions to return.
    public let limit: Int?

    public init(dir: String? = nil, limit: Int? = nil) {
        self.dir = dir
        self.limit = limit
    }
}
