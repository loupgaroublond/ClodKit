//
//  SpawnTypes.swift
//  ClodKit
//
//  Protocol and options for spawning CLI processes.
//

import Foundation

// MARK: - Spawned Process

/// A spawned subprocess that can be monitored and killed.
public protocol SpawnedProcess: Sendable {
    /// The exit code of the process, or nil if still running.
    var exitCode: Int32? { get }

    /// Whether the process has been killed.
    var isKilled: Bool { get }

    /// Kill the process with the given signal.
    /// - Parameter signal: The signal to send (e.g., SIGTERM).
    /// - Returns: Whether the kill signal was sent successfully.
    func kill(signal: Int32) -> Bool
}

// MARK: - Spawn Options

/// Options for spawning a new process.
public struct SpawnOptions: Sendable {
    /// The command to execute.
    public let command: String

    /// Arguments to pass to the command.
    public let args: [String]

    /// Working directory for the process.
    public let cwd: String?

    /// Environment variables for the process.
    public let env: [String: String]

    public init(command: String, args: [String] = [], cwd: String? = nil, env: [String: String] = [:]) {
        self.command = command
        self.args = args
        self.cwd = cwd
        self.env = env
    }
}

// MARK: - Spawn Function

/// Function type for spawning a Claude Code process.
public typealias SpawnFunction = @Sendable (SpawnOptions) async throws -> any SpawnedProcess
