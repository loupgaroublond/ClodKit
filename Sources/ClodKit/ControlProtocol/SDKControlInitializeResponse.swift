//
//  SDKControlInitializeResponse.swift
//  ClodKit
//
//  Response type from the SDK control initialize request.
//

import Foundation

// MARK: - SDK Control Initialize Response

/// Response from the SDK control initialize request.
public struct SDKControlInitializeResponse: Sendable, Equatable, Codable {
    /// Available slash commands.
    public let commands: [SlashCommand]

    /// Available subagents.
    public let agents: [AgentInfo]

    /// Current output style.
    public let outputStyle: String

    /// Available output styles.
    public let availableOutputStyles: [String]

    /// Available models.
    public let models: [ModelInfo]

    /// Account information.
    public let account: AccountInfo

    /// Current fast mode state.
    public let fastModeState: String?

    enum CodingKeys: String, CodingKey {
        case commands, agents
        case outputStyle = "output_style"
        case availableOutputStyles = "available_output_styles"
        case models
        case account
        case fastModeState = "fast_mode_state"
    }
}

// MARK: - Slash Command

/// A slash command available in the CLI.
public struct SlashCommand: Sendable, Equatable, Codable {
    /// The command name.
    public let name: String

    /// Description of the command.
    public let description: String

    /// Hint for the command argument.
    public let argumentHint: String?

    enum CodingKeys: String, CodingKey {
        case name, description
        case argumentHint = "argument_hint"
    }

    public init(name: String, description: String, argumentHint: String? = nil) {
        self.name = name
        self.description = description
        self.argumentHint = argumentHint
    }
}

// MARK: - Model Info

/// Information about an available model.
public struct ModelInfo: Sendable, Equatable, Codable {
    /// The model value/identifier.
    public let value: String

    /// Human-readable display name.
    public let displayName: String

    /// Description of the model.
    public let description: String

    /// Whether this model supports effort levels.
    public let supportsEffort: Bool?

    /// Available effort levels for this model.
    public let supportedEffortLevels: [String]?

    /// Whether this model supports adaptive thinking.
    public let supportsAdaptiveThinking: Bool?

    enum CodingKeys: String, CodingKey {
        case value
        case displayName = "display_name"
        case description
        case supportsEffort = "supportsEffort"
        case supportedEffortLevels = "supportedEffortLevels"
        case supportsAdaptiveThinking = "supportsAdaptiveThinking"
    }

    public init(
        value: String,
        displayName: String,
        description: String,
        supportsEffort: Bool? = nil,
        supportedEffortLevels: [String]? = nil,
        supportsAdaptiveThinking: Bool? = nil
    ) {
        self.value = value
        self.displayName = displayName
        self.description = description
        self.supportsEffort = supportsEffort
        self.supportedEffortLevels = supportedEffortLevels
        self.supportsAdaptiveThinking = supportsAdaptiveThinking
    }
}

// MARK: - Account Info

/// Information about the authenticated account.
public struct AccountInfo: Sendable, Equatable, Codable {
    /// Account email address.
    public let email: String?

    /// Organization name.
    public let organization: String?

    /// Subscription type.
    public let subscriptionType: String?

    /// Token source.
    public let tokenSource: String?

    /// API key source.
    public let apiKeySource: ApiKeySource?

    enum CodingKeys: String, CodingKey {
        case email, organization
        case subscriptionType = "subscription_type"
        case tokenSource = "token_source"
        case apiKeySource = "api_key_source"
    }

    public init(
        email: String? = nil,
        organization: String? = nil,
        subscriptionType: String? = nil,
        tokenSource: String? = nil,
        apiKeySource: ApiKeySource? = nil
    ) {
        self.email = email
        self.organization = organization
        self.subscriptionType = subscriptionType
        self.tokenSource = tokenSource
        self.apiKeySource = apiKeySource
    }
}

// MARK: - Agent Info

/// Information about an available subagent that can be invoked via the Task tool.
public struct AgentInfo: Sendable, Equatable, Codable {
    /// Agent type identifier (e.g., "Explore").
    public let name: String

    /// Description of when to use this agent.
    public let description: String

    /// Model alias this agent uses. If omitted, inherits the parent's model.
    public let model: String?

    public init(name: String, description: String, model: String? = nil) {
        self.name = name
        self.description = description
        self.model = model
    }
}
