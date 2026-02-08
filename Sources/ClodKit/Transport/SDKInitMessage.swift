//
//  SDKInitMessage.swift
//  ClodKit
//
//  Typed representation of system init messages from CLI.
//

import Foundation

// MARK: - SDK Init Message

/// Typed representation of a system init message.
/// Decode from SDKMessage.rawJSON when subtype is "init".
public struct SDKInitMessage: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let sessionId: String
    public let apiKeySource: String?
    public let cwd: String?
    public let model: String?
    public let permissionMode: String?
    public let uuid: String?
    public let agents: [String]?
    public let betas: [String]?
    public let claudeCodeVersion: String?
    public let outputStyle: String?
    public let skills: [String]?
    public let plugins: [PluginInfo]?

    enum CodingKeys: String, CodingKey {
        case type, subtype
        case sessionId = "session_id"
        case apiKeySource = "api_key_source"
        case cwd, model
        case permissionMode = "permission_mode"
        case uuid, agents, betas
        case claudeCodeVersion = "claude_code_version"
        case outputStyle = "output_style"
        case skills, plugins
    }
}

// MARK: - Plugin Info

/// Information about a loaded plugin.
public struct PluginInfo: Sendable, Equatable, Codable {
    public let name: String
    public let path: String
}
