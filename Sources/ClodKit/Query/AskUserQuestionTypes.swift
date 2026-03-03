//
//  AskUserQuestionTypes.swift
//  ClodKit
//
//  Input and output types for the AskUserQuestion tool.
//

import Foundation

// MARK: - Ask User Question Option

/// A single answer option for a user question.
public struct AskUserQuestionOption: Sendable, Equatable, Codable {
    /// The display text for this option.
    public let label: String

    /// Explanation of what this option means.
    public let description: String

    public init(label: String, description: String) {
        self.label = label
        self.description = description
    }
}

// MARK: - Ask User Question Item

/// A single question to ask the user.
public struct AskUserQuestionItem: Sendable, Equatable, Codable {
    /// The complete question to ask the user.
    public let question: String

    /// Very short label displayed as a chip/tag (max 12 chars).
    public let header: String

    /// The available choices for this question.
    public let options: [AskUserQuestionOption]

    /// Whether the user can select multiple options.
    public let multiSelect: Bool

    public init(question: String, header: String, options: [AskUserQuestionOption], multiSelect: Bool) {
        self.question = question
        self.header = header
        self.options = options
        self.multiSelect = multiSelect
    }
}

// MARK: - Ask User Question Input

/// Input for the AskUserQuestion tool.
public struct AskUserQuestionInput: Sendable, Equatable, Codable {
    /// Questions to ask the user (1-4 questions).
    public let questions: [AskUserQuestionItem]

    public init(questions: [AskUserQuestionItem]) {
        self.questions = questions
    }
}

// MARK: - Ask User Question Output

/// Output from the AskUserQuestion tool.
public struct AskUserQuestionOutput: Sendable, Equatable, Codable {
    /// The questions that were asked.
    public let questions: [AskUserQuestionItem]

    /// The answers provided by the user (question text -> answer string).
    public let answers: [String: String]

    public init(questions: [AskUserQuestionItem], answers: [String: String]) {
        self.questions = questions
        self.answers = answers
    }
}
