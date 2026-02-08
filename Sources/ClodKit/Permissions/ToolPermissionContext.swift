//
//  ToolPermissionContext.swift
//  ClodKit
//
//  Context provided to permission callbacks.
//

import Foundation

// MARK: - Tool Permission Context

/// Context provided to permission callbacks.
/// Contains suggestions and metadata about the permission request.
public struct ToolPermissionContext: Sendable {
    /// Suggested permission updates from the CLI.
    public let suggestions: [PermissionUpdate]

    /// Path that triggered the permission request (if applicable).
    public let blockedPath: String?

    /// Reason provided for the permission decision.
    public let decisionReason: String?

    /// Agent ID making the request (for subagent tracking).
    public let agentId: String?

    /// The tool use ID for this permission request.
    public let toolUseID: String

    public init(
        suggestions: [PermissionUpdate] = [],
        blockedPath: String? = nil,
        decisionReason: String? = nil,
        agentId: String? = nil,
        toolUseID: String
    ) {
        self.suggestions = suggestions
        self.blockedPath = blockedPath
        self.decisionReason = decisionReason
        self.agentId = agentId
        self.toolUseID = toolUseID
    }
}
