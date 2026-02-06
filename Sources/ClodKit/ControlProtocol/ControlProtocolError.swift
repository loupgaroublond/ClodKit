//
//  ControlProtocolError.swift
//  ClodKit
//
//  Errors that can occur during control protocol operations.
//

import Foundation

// MARK: - Control Protocol Errors

/// Errors that can occur during control protocol operations.
public enum ControlProtocolError: Error, Sendable, Equatable {
    /// Request timed out waiting for response.
    case timeout(requestId: String)

    /// Request was cancelled.
    case cancelled(requestId: String)

    /// Response indicated an error.
    case responseError(requestId: String, message: String)

    /// Unknown subtype in message.
    case unknownSubtype(String)

    /// Invalid message format.
    case invalidMessage(String)
}
