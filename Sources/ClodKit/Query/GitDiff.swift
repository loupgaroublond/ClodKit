//
//  GitDiff.swift
//  ClodKit
//
//  Shared git diff type for file operation outputs.
//

import Foundation

// MARK: - Git Diff

/// Git diff information for a file operation.
public struct GitDiff: Sendable, Equatable, Codable {
    /// The filename that was changed.
    public let filename: String

    /// The status of the change ("modified" or "added").
    public let status: String

    /// Number of lines added.
    public let additions: Int

    /// Number of lines deleted.
    public let deletions: Int

    /// Total number of changes.
    public let changes: Int

    /// The diff patch content.
    public let patch: String

    public init(
        filename: String,
        status: String,
        additions: Int,
        deletions: Int,
        changes: Int,
        patch: String
    ) {
        self.filename = filename
        self.status = status
        self.additions = additions
        self.deletions = deletions
        self.changes = changes
        self.patch = patch
    }
}
