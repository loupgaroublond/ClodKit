//
//  SDKMessage.swift
//  ClodKit
//
//  Low-level control protocol message types.
//  EXCEPTION: These types form a cohesive unit and are kept together.
//

import Foundation

// MARK: - SDK Message

/// SDK message from CLI output (user, assistant, result, system messages).
/// This captures the full JSON payload from Claude, as different message types
/// have different fields (result has "result", assistant has "message", etc.)
public struct SDKMessage: Sendable, Equatable {
    /// The message type (user, assistant, result, system).
    public let type: String

    /// The full raw JSON payload, for accessing type-specific fields.
    public let rawJSON: [String: JSONValue]

    /// Convenience accessor for the message content.
    /// For result messages, this returns the "result" field.
    /// For assistant messages, this extracts text from message.content[0].text.
    public var content: JSONValue? {
        switch type {
        case "result":
            return rawJSON["result"]
        case "assistant":
            // Extract from message.content[0].text
            if let message = rawJSON["message"]?.objectValue,
               let contentArray = message["content"]?.arrayValue,
               let firstContent = contentArray.first?.objectValue,
               let text = firstContent["text"]?.stringValue {
                return .string(text)
            }
            return nil
        default:
            return rawJSON["content"]
        }
    }

    /// The session ID from the message, if present.
    public var sessionId: String? {
        rawJSON["session_id"]?.stringValue
    }

    /// Legacy data field - returns rawJSON as JSONValue for backwards compatibility.
    public var data: JSONValue? {
        .object(rawJSON)
    }

    /// The stop reason for result messages (e.g., "end_turn", "max_tokens").
    public var stopReason: String? {
        rawJSON["stop_reason"]?.stringValue
    }

    /// The error type for assistant messages that failed.
    public var error: SDKAssistantMessageError? {
        guard type == "assistant" else { return nil }
        guard let errorStr = rawJSON["error"]?.stringValue else { return nil }
        return SDKAssistantMessageError(rawValue: errorStr) ?? .unknown
    }

    /// Whether this is a synthetic user message injected by the SDK.
    public var isSynthetic: Bool? {
        rawJSON["isSynthetic"]?.boolValue
    }

    /// The tool use result payload for user messages that are tool results.
    public var toolUseResult: JSONValue? {
        rawJSON["tool_use_result"]
    }

    public init(type: String, rawJSON: [String: JSONValue] = [:]) {
        self.type = type
        self.rawJSON = rawJSON
    }

    // Legacy convenience init
    public init(type: String, content: JSONValue? = nil, data: JSONValue? = nil) {
        self.type = type
        var json: [String: JSONValue] = [:]
        if let content = content {
            json["content"] = content
        }
        if let data = data, let obj = data.objectValue {
            for (k, v) in obj {
                json[k] = v
            }
        }
        self.rawJSON = json
    }
}

extension SDKMessage: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let json = try container.decode([String: JSONValue].self)

        guard let type = json["type"]?.stringValue else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Missing 'type' field in SDKMessage"
            )
        }

        self.type = type
        self.rawJSON = json
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var json = rawJSON
        json["type"] = .string(type)
        try container.encode(json)
    }
}

// MARK: - Control Request

/// Control request from CLI to SDK.
public struct ControlRequest: Codable, Sendable, Equatable {
    /// The request type identifier.
    public let type: String

    /// Unique request ID for correlation.
    public let requestId: String

    /// The request payload.
    public let request: JSONValue

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case request
    }

    public init(type: String, requestId: String, request: JSONValue) {
        self.type = type
        self.requestId = requestId
        self.request = request
    }
}

// MARK: - Control Response

/// Control response from CLI.
public struct ControlResponse: Codable, Sendable, Equatable {
    /// The response type identifier.
    public let type: String

    /// The response payload.
    public let response: ControlResponsePayload

    public init(type: String, response: ControlResponsePayload) {
        self.type = type
        self.response = response
    }
}

// MARK: - Control Response Payload

/// Control response payload.
public struct ControlResponsePayload: Codable, Sendable, Equatable {
    /// The subtype (success or error).
    public let subtype: String

    /// The original request ID.
    public let requestId: String

    /// The response data (for success).
    public let response: JSONValue?

    /// Error message (for error).
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case subtype
        case requestId = "request_id"
        case response
        case error
    }

    public init(subtype: String, requestId: String, response: JSONValue? = nil, error: String? = nil) {
        self.subtype = subtype
        self.requestId = requestId
        self.response = response
        self.error = error
    }
}

// MARK: - Control Cancel Request

/// Request to cancel a pending control operation.
public struct ControlCancelRequest: Codable, Sendable, Equatable {
    /// The cancel request type identifier.
    public let type: String

    /// The request ID to cancel.
    public let requestId: String

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
    }

    public init(type: String, requestId: String) {
        self.type = type
        self.requestId = requestId
    }
}

// MARK: - SDK Assistant Message Error

/// Error types that can occur on assistant messages.
public enum SDKAssistantMessageError: String, Codable, Sendable {
    case authenticationFailed = "authentication_failed"
    case billingError = "billing_error"
    case rateLimit = "rate_limit"
    case invalidRequest = "invalid_request"
    case serverError = "server_error"
    case unknown
}
