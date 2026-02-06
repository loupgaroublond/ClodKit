//
//  Transport.swift
//  ClodKit
//
//  Abstract interface for CLI communication enabling mock injection for testing.
//

import Foundation

// MARK: - Transport Protocol

/// Protocol abstracting CLI communication for testability.
/// Implementations include ProcessTransport (real subprocess) and MockTransport (testing).
public protocol Transport: Sendable {
    /// Write data to the CLI's stdin.
    /// - Parameter data: The data to write.
    /// - Throws: TransportError if the write fails.
    func write(_ data: Data) async throws

    /// Stream of messages from CLI stdout.
    /// - Returns: An async throwing stream of stdout messages.
    func readMessages() -> AsyncThrowingStream<StdoutMessage, Error>

    /// Signal end of input (close stdin).
    /// Call this when no more input will be sent.
    func endInput() async

    /// Close the transport and terminate the process.
    /// After calling this, the transport should not be used.
    func close()

    /// Whether the transport is still connected.
    var isConnected: Bool { get }
}

// MARK: - Transport Errors

/// Errors that can occur during transport operations.
public enum TransportError: Error, Sendable, Equatable {
    /// The transport is not connected.
    case notConnected

    /// Failed to write data to stdin.
    case writeFailed(String)

    /// The process terminated unexpectedly.
    case processTerminated(Int32)

    /// Failed to launch the process.
    case launchFailed(String)

    /// The transport was closed.
    case closed
}
