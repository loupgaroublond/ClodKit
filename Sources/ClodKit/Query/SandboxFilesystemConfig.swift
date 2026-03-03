//
//  SandboxFilesystemConfig.swift
//  ClodKit
//
//  Filesystem configuration for the sandbox.
//

import Foundation

// MARK: - Sandbox Filesystem Config

/// Filesystem configuration within a sandbox.
public struct SandboxFilesystemConfig: Sendable, Equatable, Codable {
    /// Paths allowed for writing.
    public var allowWrite: [String]?

    /// Paths denied for writing.
    public var denyWrite: [String]?

    /// Paths denied for reading.
    public var denyRead: [String]?

    public init(
        allowWrite: [String]? = nil,
        denyWrite: [String]? = nil,
        denyRead: [String]? = nil
    ) {
        self.allowWrite = allowWrite
        self.denyWrite = denyWrite
        self.denyRead = denyRead
    }

    enum CodingKeys: String, CodingKey {
        case allowWrite = "allow_write"
        case denyWrite = "deny_write"
        case denyRead = "deny_read"
    }
}
