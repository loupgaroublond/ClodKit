//
//  BashOutput.swift
//  ClodKit
//
//  Output type for the Bash tool.
//

import Foundation

// MARK: - Bash Output

/// Output from a Bash command execution.
public struct BashOutput: Sendable, Equatable, Codable {
    /// The standard output of the command.
    public let stdout: String

    /// The standard error output of the command.
    public let stderr: String

    /// Path to raw output file for large MCP tool outputs.
    public let rawOutputPath: String?

    /// Whether the command was interrupted.
    public let interrupted: Bool

    /// Flag to indicate if stdout contains image data.
    public let isImage: Bool?

    /// ID of the background task if command is running in background.
    public let backgroundTaskId: String?

    /// True if the user manually backgrounded the command with Ctrl+B.
    public let backgroundedByUser: Bool?

    /// Flag to indicate if sandbox mode was overridden.
    public let dangerouslyDisableSandbox: Bool?

    /// Semantic interpretation for non-error exit codes with special meaning.
    public let returnCodeInterpretation: String?

    /// Whether the command is expected to produce no output on success.
    public let noOutputExpected: Bool?

    /// Structured content blocks.
    public let structuredContent: [JSONValue]?

    /// Path to the persisted full output in tool-results dir.
    public let persistedOutputPath: String?

    /// Total size of the output in bytes.
    public let persistedOutputSize: Int?

    enum CodingKeys: String, CodingKey {
        case stdout, stderr
        case rawOutputPath = "rawOutputPath"
        case interrupted
        case isImage = "isImage"
        case backgroundTaskId = "backgroundTaskId"
        case backgroundedByUser = "backgroundedByUser"
        case dangerouslyDisableSandbox = "dangerouslyDisableSandbox"
        case returnCodeInterpretation = "returnCodeInterpretation"
        case noOutputExpected = "noOutputExpected"
        case structuredContent = "structuredContent"
        case persistedOutputPath = "persistedOutputPath"
        case persistedOutputSize = "persistedOutputSize"
    }

    public init(
        stdout: String,
        stderr: String,
        interrupted: Bool,
        rawOutputPath: String? = nil,
        isImage: Bool? = nil,
        backgroundTaskId: String? = nil,
        backgroundedByUser: Bool? = nil,
        dangerouslyDisableSandbox: Bool? = nil,
        returnCodeInterpretation: String? = nil,
        noOutputExpected: Bool? = nil,
        structuredContent: [JSONValue]? = nil,
        persistedOutputPath: String? = nil,
        persistedOutputSize: Int? = nil
    ) {
        self.stdout = stdout
        self.stderr = stderr
        self.interrupted = interrupted
        self.rawOutputPath = rawOutputPath
        self.isImage = isImage
        self.backgroundTaskId = backgroundTaskId
        self.backgroundedByUser = backgroundedByUser
        self.dangerouslyDisableSandbox = dangerouslyDisableSandbox
        self.returnCodeInterpretation = returnCodeInterpretation
        self.noOutputExpected = noOutputExpected
        self.structuredContent = structuredContent
        self.persistedOutputPath = persistedOutputPath
        self.persistedOutputSize = persistedOutputSize
    }
}
