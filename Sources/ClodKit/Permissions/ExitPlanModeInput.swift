//
//  ExitPlanModeInput.swift
//  ClodKit
//
//  Input types for exiting plan mode (SDK v0.2.34 schema).
//

import Foundation

// MARK: - Allowed Prompt

/// A prompt that is allowed to execute when exiting plan mode.
public struct AllowedPrompt: Sendable, Equatable, Codable {
    /// The tool name (currently always "Bash").
    public let tool: String

    /// The prompt/command to allow.
    public let prompt: String

    public init(tool: String, prompt: String) {
        self.tool = tool
        self.prompt = prompt
    }
}

// MARK: - Exit Plan Mode Input

/// Input for exiting plan mode, matching SDK v0.2.34 schema.
public struct ExitPlanModeInput: Sendable, Equatable, Codable {
    /// Prompts that are allowed to execute.
    public var allowedPrompts: [AllowedPrompt]?

    /// Whether to push changes to remote.
    public var pushToRemote: Bool?

    /// Remote session ID.
    public var remoteSessionId: String?

    /// Remote session URL.
    public var remoteSessionUrl: String?

    /// Remote session title.
    public var remoteSessionTitle: String?

    /// Additional properties not covered by the schema.
    public var additionalProperties: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case allowedPrompts = "allowed_prompts"
        case pushToRemote = "push_to_remote"
        case remoteSessionId = "remote_session_id"
        case remoteSessionUrl = "remote_session_url"
        case remoteSessionTitle = "remote_session_title"
        case additionalProperties = "additional_properties"
    }

    public init(
        allowedPrompts: [AllowedPrompt]? = nil,
        pushToRemote: Bool? = nil,
        remoteSessionId: String? = nil,
        remoteSessionUrl: String? = nil,
        remoteSessionTitle: String? = nil,
        additionalProperties: [String: JSONValue]? = nil
    ) {
        self.allowedPrompts = allowedPrompts
        self.pushToRemote = pushToRemote
        self.remoteSessionId = remoteSessionId
        self.remoteSessionUrl = remoteSessionUrl
        self.remoteSessionTitle = remoteSessionTitle
        self.additionalProperties = additionalProperties
    }
}
