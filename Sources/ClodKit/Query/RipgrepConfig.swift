//
//  RipgrepConfig.swift
//  ClodKit
//
//  Configuration for the ripgrep command.
//

import Foundation

// MARK: - Ripgrep Config

/// Configuration for the ripgrep command.
public struct RipgrepConfig: Sendable, Equatable, Codable {
    /// The ripgrep command path.
    public let command: String

    /// Additional arguments for ripgrep.
    public var args: [String]?

    public init(command: String, args: [String]? = nil) {
        self.command = command
        self.args = args
    }
}
