//
//  AgentInput.swift
//  ClodKit
//
//  Input type for the agent/subagent tool.
//

import Foundation

// MARK: - Agent Input

/// Input for creating a subagent.
public struct AgentInput: Sendable, Equatable, Codable {
    /// Description of the agent's purpose.
    public let description: String

    /// The prompt to send to the agent.
    public let prompt: String

    /// The subagent type (e.g., "Explore", "Code").
    public let subagentType: String

    /// The model to use for the agent.
    public var model: String?

    /// Session ID to resume.
    public var resume: String?

    /// Whether to run in the background.
    public var runInBackground: Bool?

    /// Maximum number of turns.
    public var maxTurns: Int?

    /// Agent name.
    public var name: String?

    /// Team name for the agent.
    public var teamName: String?

    /// Permission mode raw value.
    public var mode: String?

    enum CodingKeys: String, CodingKey {
        case description, prompt, subagentType = "subagent_type", model
        case resume, runInBackground = "run_in_background", maxTurns = "max_turns"
        case name, teamName = "team_name", mode
    }

    public init(
        description: String,
        prompt: String,
        subagentType: String,
        model: String? = nil,
        resume: String? = nil,
        runInBackground: Bool? = nil,
        maxTurns: Int? = nil,
        name: String? = nil,
        teamName: String? = nil,
        mode: String? = nil
    ) {
        self.description = description
        self.prompt = prompt
        self.subagentType = subagentType
        self.model = model
        self.resume = resume
        self.runInBackground = runInBackground
        self.maxTurns = maxTurns
        self.name = name
        self.teamName = teamName
        self.mode = mode
    }
}
