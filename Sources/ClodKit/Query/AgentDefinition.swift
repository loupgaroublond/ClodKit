//
//  AgentDefinition.swift
//  ClodKit
//
//  Agent definition type for configuring delegated agents.
//

import Foundation

// MARK: - Agent Definition

/// Configuration for a delegated agent.
public struct AgentDefinition: Sendable, Equatable, Codable {
    /// Description of the agent's purpose.
    public let description: String

    /// Tools the agent is allowed to use.
    public var tools: [String]?

    /// Tools the agent is not allowed to use.
    public var disallowedTools: [String]?

    /// System prompt for the agent.
    public let prompt: String

    /// Model to use for the agent.
    public var model: AgentModel?

    /// MCP server name references available to the agent.
    public var mcpServers: [String]?

    /// Critical system reminder (experimental).
    public var criticalSystemReminderExperimental: String?

    /// Skills available to the agent.
    public var skills: [String]?

    /// Maximum number of turns for the agent.
    public var maxTurns: Int?

    enum CodingKeys: String, CodingKey {
        case description, tools
        case disallowedTools = "disallowed_tools"
        case prompt, model
        case mcpServers = "mcp_servers"
        case criticalSystemReminderExperimental = "criticalSystemReminder_EXPERIMENTAL"
        case skills
        case maxTurns = "max_turns"
    }

    /// Creates a new agent definition.
    /// - Parameters:
    ///   - description: Description of the agent's purpose.
    ///   - prompt: System prompt for the agent.
    ///   - tools: Tools the agent is allowed to use.
    ///   - disallowedTools: Tools the agent is not allowed to use.
    ///   - model: Model to use for the agent.
    ///   - mcpServers: MCP server name references.
    ///   - criticalSystemReminderExperimental: Critical system reminder (experimental).
    ///   - skills: Skills available to the agent.
    ///   - maxTurns: Maximum number of turns.
    public init(
        description: String,
        prompt: String,
        tools: [String]? = nil,
        disallowedTools: [String]? = nil,
        model: AgentModel? = nil,
        mcpServers: [String]? = nil,
        criticalSystemReminderExperimental: String? = nil,
        skills: [String]? = nil,
        maxTurns: Int? = nil
    ) {
        self.description = description
        self.prompt = prompt
        self.tools = tools
        self.disallowedTools = disallowedTools
        self.model = model
        self.mcpServers = mcpServers
        self.criticalSystemReminderExperimental = criticalSystemReminderExperimental
        self.skills = skills
        self.maxTurns = maxTurns
    }
}

// MARK: - Agent Model

/// Model selection for delegated agents.
public enum AgentModel: String, Codable, Sendable {
    case sonnet
    case opus
    case haiku
    case inherit
}
