//
//  NativeBackendFactory.swift
//  ClodKit
//
//  Factory for creating backends.
//

import Foundation

// MARK: - Convenience Factory

/// Factory for creating backends.
public enum NativeBackendFactory {
    /// Create a backend of the specified type.
    /// - Parameters:
    ///   - type: The backend type to create.
    ///   - enableLogging: Whether to enable debug logging.
    /// - Returns: A configured NativeBackend instance.
    /// - Note: Currently only `.native` is supported. Other types will throw.
    public static func create(
        type: BackendType = .native,
        enableLogging: Bool = false
    ) throws -> NativeBackend {
        switch type {
        case .native:
            return NativeBackend(enableLogging: enableLogging)
        case .headless, .agentSDK:
            throw NativeBackendError.notConfigured("Only .native backend type is supported in NativeClaudeCodeSDK")
        }
    }

    /// Create a native backend with default configuration.
    /// - Parameter enableLogging: Whether to enable debug logging.
    /// - Returns: A configured NativeBackend instance.
    public static func create(enableLogging: Bool = false) -> NativeBackend {
        NativeBackend(enableLogging: enableLogging)
    }

    /// Create a native backend with custom configuration.
    /// - Parameters:
    ///   - cliPath: Custom path to claude CLI.
    ///   - workingDirectory: Working directory for queries.
    ///   - environment: Additional environment variables.
    ///   - enableLogging: Whether to enable debug logging.
    /// - Returns: A configured NativeBackend instance.
    public static func create(
        cliPath: String,
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        enableLogging: Bool = false
    ) -> NativeBackend {
        NativeBackend(
            cliPath: cliPath,
            workingDirectory: workingDirectory,
            environment: environment,
            enableLogging: enableLogging
        )
    }
}
