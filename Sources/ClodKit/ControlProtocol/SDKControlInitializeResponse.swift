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

    /// Current output style.
    public let outputStyle: String

    /// Available output styles.
    public let availableOutputStyles: [String]

    /// Available models.
    public let models: [ModelInfo]

    /// Account information.
    public let account: AccountInfo

    enum CodingKeys: String, CodingKey {
        case commands
        case outputStyle = "output_style"
        case availableOutputStyles = "available_output_styles"
        case models
        case account
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
    public let argumentHint: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case argumentHint = "argument_hint"
    }

    public init(name: String, description: String, argumentHint: String = "") {
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

    enum CodingKeys: String, CodingKey {
        case value
        case displayName = "display_name"
        case description
    }

    public init(value: String, displayName: String, description: String) {
        self.value = value
        self.displayName = displayName
        self.description = description
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
    public let apiKeySource: String?

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
        apiKeySource: String? = nil
    ) {
        self.email = email
        self.organization = organization
        self.subscriptionType = subscriptionType
        self.tokenSource = tokenSource
        self.apiKeySource = apiKeySource
    }
}
