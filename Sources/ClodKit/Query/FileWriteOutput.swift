//
//  FileWriteOutput.swift
//  ClodKit
//
//  Output type for the FileWrite tool.
//

import Foundation

// MARK: - File Write Output

/// Output from a file write operation.
public struct FileWriteOutput: Sendable, Equatable, Codable {
    /// Whether a new file was created or an existing file was updated.
    public let type: String

    /// The path to the file that was written.
    public let filePath: String

    /// The content that was written to the file.
    public let content: String

    /// Diff patch showing the changes.
    public let structuredPatch: [StructuredPatchHunk]

    /// The original file content before the write (nil for new files).
    public let originalFile: String?

    /// Git diff information.
    public let gitDiff: GitDiff?

    enum CodingKeys: String, CodingKey {
        case type
        case filePath = "filePath"
        case content
        case structuredPatch = "structuredPatch"
        case originalFile = "originalFile"
        case gitDiff = "gitDiff"
    }

    public init(
        type: String,
        filePath: String,
        content: String,
        structuredPatch: [StructuredPatchHunk],
        originalFile: String?,
        gitDiff: GitDiff? = nil
    ) {
        self.type = type
        self.filePath = filePath
        self.content = content
        self.structuredPatch = structuredPatch
        self.originalFile = originalFile
        self.gitDiff = gitDiff
    }
}
