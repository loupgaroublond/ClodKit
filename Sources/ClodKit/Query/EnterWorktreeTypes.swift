//
//  EnterWorktreeTypes.swift
//  ClodKit
//
//  Input and output types for the EnterWorktree tool.
//

import Foundation

// MARK: - Enter Worktree Input

/// Input for the EnterWorktree tool.
public struct EnterWorktreeInput: Sendable, Equatable, Codable {
    /// Optional name for the worktree.
    public let name: String?

    public init(name: String? = nil) {
        self.name = name
    }
}

// MARK: - Enter Worktree Output

/// Output from the EnterWorktree tool.
public struct EnterWorktreeOutput: Sendable, Equatable, Codable {
    /// Path to the created worktree.
    public let worktreePath: String

    /// Branch for the created worktree.
    public let worktreeBranch: String?

    /// Status message.
    public let message: String

    enum CodingKeys: String, CodingKey {
        case worktreePath = "worktreePath"
        case worktreeBranch = "worktreeBranch"
        case message
    }

    public init(worktreePath: String, worktreeBranch: String? = nil, message: String) {
        self.worktreePath = worktreePath
        self.worktreeBranch = worktreeBranch
        self.message = message
    }
}
