//
//  FileEditOutput.swift
//  ClodKit
//
//  Output type for the FileEdit tool.
//

import Foundation

// MARK: - File Edit Output

/// Output from a file edit operation.
public struct FileEditOutput: Sendable, Equatable, Codable {
    /// The file path that was edited.
    public let filePath: String

    /// The original string that was replaced.
    public let oldString: String

    /// The new string that replaced it.
    public let newString: String

    /// The original file contents before editing.
    public let originalFile: String

    /// Diff patch showing the changes.
    public let structuredPatch: [StructuredPatchHunk]

    /// Whether the user modified the proposed changes.
    public let userModified: Bool

    /// Whether all occurrences were replaced.
    public let replaceAll: Bool

    /// Git diff information.
    public let gitDiff: GitDiff?

    enum CodingKeys: String, CodingKey {
        case filePath = "filePath"
        case oldString = "oldString"
        case newString = "newString"
        case originalFile = "originalFile"
        case structuredPatch = "structuredPatch"
        case userModified = "userModified"
        case replaceAll = "replaceAll"
        case gitDiff = "gitDiff"
    }

    public init(
        filePath: String,
        oldString: String,
        newString: String,
        originalFile: String,
        structuredPatch: [StructuredPatchHunk],
        userModified: Bool,
        replaceAll: Bool,
        gitDiff: GitDiff? = nil
    ) {
        self.filePath = filePath
        self.oldString = oldString
        self.newString = newString
        self.originalFile = originalFile
        self.structuredPatch = structuredPatch
        self.userModified = userModified
        self.replaceAll = replaceAll
        self.gitDiff = gitDiff
    }
}

// MARK: - Structured Patch Hunk

/// A single hunk in a structured diff patch.
public struct StructuredPatchHunk: Sendable, Equatable, Codable {
    public let oldStart: Int
    public let oldLines: Int
    public let newStart: Int
    public let newLines: Int
    public let lines: [String]

    enum CodingKeys: String, CodingKey {
        case oldStart = "oldStart"
        case oldLines = "oldLines"
        case newStart = "newStart"
        case newLines = "newLines"
        case lines
    }

    public init(oldStart: Int, oldLines: Int, newStart: Int, newLines: Int, lines: [String]) {
        self.oldStart = oldStart
        self.oldLines = oldLines
        self.newStart = newStart
        self.newLines = newLines
        self.lines = lines
    }
}
