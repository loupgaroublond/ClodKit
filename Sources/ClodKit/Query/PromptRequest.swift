//
//  PromptRequest.swift
//  ClodKit
//
//  Types for prompt requests and responses.
//

import Foundation

// MARK: - Prompt Request

/// A prompt request with user-selectable options.
public struct PromptRequest: Sendable, Equatable, Codable {
    /// Request ID. Presence marks the line as a prompt request.
    public let prompt: String

    /// The prompt message to display to the user.
    public let message: String

    /// Available options for the user to choose from.
    public let options: [PromptRequestOption]

    public init(prompt: String, message: String, options: [PromptRequestOption]) {
        self.prompt = prompt
        self.message = message
        self.options = options
    }
}

// MARK: - Prompt Request Option

/// A single selectable option in a prompt request.
public struct PromptRequestOption: Sendable, Equatable, Codable {
    /// Unique key for this option, returned in the response.
    public let key: String

    /// Display text for this option.
    public let label: String

    /// Optional description shown below the label.
    public let description: String?

    public init(key: String, label: String, description: String? = nil) {
        self.key = key
        self.label = label
        self.description = description
    }
}

// MARK: - Prompt Response

/// Response to a prompt request.
public struct PromptResponse: Sendable, Equatable, Codable {
    /// The request ID from the corresponding prompt request.
    public let promptResponse: String

    /// The key of the selected option.
    public let selected: String

    enum CodingKeys: String, CodingKey {
        case promptResponse = "prompt_response"
        case selected
    }

    public init(promptResponse: String, selected: String) {
        self.promptResponse = promptResponse
        self.selected = selected
    }
}
