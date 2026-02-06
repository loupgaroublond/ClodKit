//
//  JSONLineParser.swift
//  ClaudeCodeSDK
//
//  Parse newline-delimited JSON from CLI stdout, handling incomplete buffers.
//

import Foundation

// MARK: - JSON Line Parser

/// Parses JSON lines from CLI output.
/// Handles incomplete buffers, malformed JSON, and empty lines gracefully.
public struct JSONLineParser: Sendable {
    private let decoder: JSONDecoder

    public init() {
        // Don't use .convertFromSnakeCase - types have explicit CodingKeys
        self.decoder = JSONDecoder()
    }

    /// Parse a complete JSON line from buffer.
    /// - Parameter buffer: The data buffer to parse from.
    /// - Returns: Parsed message and remaining buffer, or nil if incomplete.
    public func parseLine(from buffer: Data) -> (StdoutMessage, Data)? {
        // Find the first newline character
        guard let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) else {
            // No complete line yet
            return nil
        }

        let lineData = buffer[buffer.startIndex..<newlineIndex]
        let remaining = buffer[buffer.index(after: newlineIndex)...]

        // Skip empty lines
        guard !lineData.isEmpty else {
            // Recursively try the remaining buffer
            if remaining.isEmpty {
                return nil
            }
            return parseLine(from: Data(remaining))
        }

        // Try to parse the line
        do {
            let message = try parseMessage(from: Data(lineData))
            return (message, Data(remaining))
        } catch {
            // Malformed JSON - skip this line and try the next
            if remaining.isEmpty {
                return nil
            }
            return parseLine(from: Data(remaining))
        }
    }

    /// Parse all complete messages from a buffer.
    /// - Parameter buffer: The data buffer to parse from.
    /// - Returns: Array of parsed messages and the remaining buffer.
    public func parseAllLines(from buffer: Data) -> ([StdoutMessage], Data) {
        var messages: [StdoutMessage] = []
        var currentBuffer = buffer

        while let (message, remaining) = parseLine(from: currentBuffer) {
            messages.append(message)
            currentBuffer = remaining
        }

        return (messages, currentBuffer)
    }

    // MARK: - Private Parsing

    private func parseMessage(from data: Data) throws -> StdoutMessage {
        // Peek at type field to determine message kind
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            throw JSONLineParserError.missingType
        }

        switch type {
        case "control_request":
            let request = try decoder.decode(ControlRequest.self, from: data)
            return .controlRequest(request)

        case "control_response":
            let response = try decoder.decode(ControlResponse.self, from: data)
            return .controlResponse(response)

        case "control_cancel_request":
            let cancelRequest = try decoder.decode(ControlCancelRequest.self, from: data)
            return .controlCancelRequest(cancelRequest)

        case "keep_alive":
            return .keepAlive

        default:
            // Regular SDK message (user, assistant, result, system)
            let message = try decoder.decode(SDKMessage.self, from: data)
            return .regular(message)
        }
    }
}

// MARK: - Parser Errors

/// Errors that can occur during JSON line parsing.
public enum JSONLineParserError: Error, Sendable, Equatable {
    /// The JSON object is missing the required 'type' field.
    case missingType

    /// The 'type' field has an unknown value.
    case unknownType(String)

    /// The JSON is malformed.
    case malformedJSON(String)
}
