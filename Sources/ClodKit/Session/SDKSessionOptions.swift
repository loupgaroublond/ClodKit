//
//  SDKSessionOptions.swift
//  ClodKit
//
//  V2 Session configuration options (unstable, may change).
//

import Foundation

// MARK: - SDK Session Options

/// Options for creating a V2 SDK session.
@available(*, message: "V2 Session API is unstable and may change")
public struct SDKSessionOptions: Sendable {
    /// The model to use (required).
    public let model: String

    /// Path to the Claude Code executable.
    public var pathToClaudeCodeExecutable: String?

    /// Additional arguments for the executable.
    public var executableArgs: [String]?

    /// Environment variables for the process.
    public var env: [String: String]?

    /// Tools allowed for this session.
    public var allowedTools: [String]?

    /// Tools blocked for this session.
    public var disallowedTools: [String]?

    /// Permission callback for tool use requests.
    public var canUseTool: CanUseToolCallback?

    /// Permission mode for the session.
    public var permissionMode: PermissionMode?

    public init(model: String) {
        self.model = model
    }
}
