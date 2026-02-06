//
//  NativeBackend.swift
//  ClaudeCodeSDK
//
//  Native Swift backend implementation using the native query API.
//

import Foundation
import os

// MARK: - Native Backend Implementation

/// Native Swift implementation of the Claude Code backend.
/// Uses the native query API with ProcessTransport.
///
/// Safety: `@unchecked Sendable` is correct because all mutable state
/// (`activeQuery`) is protected by NSLock. Immutable properties (`logger`,
/// `cliPath`, `workingDirectory`, `environment`) are set once at init.
public final class NativeBackend: NativeClaudeCodeBackend, @unchecked Sendable {
    /// Logger for debugging.
    private let logger: Logger?

    /// Current active query (for cancellation). Protected by `lock`.
    private var activeQuery: ClaudeQuery?

    /// Lock protecting mutable state.
    private let lock = NSLock()

    /// Custom CLI path (optional).
    private let cliPath: String?

    /// Working directory for queries.
    private let workingDirectory: URL?

    /// Additional environment variables.
    private let environment: [String: String]

    /// Creates a new native backend.
    /// - Parameters:
    ///   - cliPath: Custom path to claude CLI (default: "claude").
    ///   - workingDirectory: Working directory for queries.
    ///   - environment: Additional environment variables.
    ///   - enableLogging: Whether to enable debug logging.
    public init(
        cliPath: String? = nil,
        workingDirectory: URL? = nil,
        environment: [String: String] = [:],
        enableLogging: Bool = false
    ) {
        self.cliPath = cliPath
        self.workingDirectory = workingDirectory
        self.environment = environment

        if enableLogging {
            self.logger = Logger(subsystem: "com.claudecodesdk.NativeBackend", category: "NativeBackend")
        } else {
            self.logger = nil
        }
    }

    // MARK: - NativeClaudeCodeBackend Protocol

    public func runSinglePrompt(
        prompt: String,
        options: QueryOptions
    ) async throws -> ClaudeQuery {
        logger?.info("Running single prompt")

        var opts = options
        applyDefaultOptions(&opts)

        let claudeQuery = try await query(prompt: prompt, options: opts)

        lock.withLock {
            activeQuery = claudeQuery
        }

        return claudeQuery
    }

    public func resumeSession(
        sessionId: String,
        prompt: String?,
        options: QueryOptions
    ) async throws -> ClaudeQuery {
        logger?.info("Resuming session: \(sessionId)")

        var opts = options
        applyDefaultOptions(&opts)
        opts.resume = sessionId

        let promptText = prompt ?? ""
        let claudeQuery = try await query(prompt: promptText, options: opts)

        lock.withLock {
            activeQuery = claudeQuery
        }

        return claudeQuery
    }

    public func cancel() {
        logger?.info("Cancelling active query")

        let queryToCancel = lock.withLock { activeQuery }

        if let claudeQuery = queryToCancel {
            Task {
                try? await claudeQuery.interrupt()
            }
        }
    }

    public func validateSetup() async throws -> Bool {
        logger?.info("Validating native backend setup")

        let cli = cliPath ?? "claude"

        // Use 'which' command to check if claude exists
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", "which \(cli)"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let isValid = process.terminationStatus == 0

            if isValid {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    logger?.info("Claude CLI found at: \(path)")
                }
            } else {
                logger?.warning("Claude CLI not found in PATH")
            }

            return isValid
        } catch {
            logger?.error("Error validating setup: \(error.localizedDescription)")
            throw NativeBackendError.validationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func applyDefaultOptions(_ options: inout QueryOptions) {
        if options.cliPath == nil {
            options.cliPath = cliPath
        }
        if options.workingDirectory == nil {
            options.workingDirectory = workingDirectory
        }
        if options.logger == nil {
            options.logger = logger
        }

        // Merge environment
        for (key, value) in environment {
            if options.environment[key] == nil {
                options.environment[key] = value
            }
        }
    }
}

// MARK: - Native Backend Error

/// Errors that can occur with the native backend.
public enum NativeBackendError: Error, Sendable, Equatable {
    /// Backend validation failed.
    case validationFailed(String)

    /// The backend is not configured properly.
    case notConfigured(String)

    /// An operation was cancelled.
    case cancelled
}

extension NativeBackendError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let reason):
            return "Backend validation failed: \(reason)"
        case .notConfigured(let reason):
            return "Backend not configured: \(reason)"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}
