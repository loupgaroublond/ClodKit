//
//  ControlResponses.swift
//  ClodKit
//
//  Control protocol response types and FullControlResponsePayload discriminated union.
//  EXCEPTION: Response types form a discriminated union pattern and are kept together.
//

import Foundation

// MARK: - Success Response Payload

/// Success response payload.
public struct SuccessResponsePayload: Codable, Sendable, Equatable {
    public let subtype: String
    public let requestId: String
    public let response: JSONValue?

    enum CodingKeys: String, CodingKey {
        case subtype
        case requestId = "request_id"
        case response
    }

    public init(requestId: String, response: JSONValue? = nil) {
        self.subtype = "success"
        self.requestId = requestId
        self.response = response
    }
}

// MARK: - Error Response Payload

/// Error response payload.
public struct ErrorResponsePayload: Codable, Sendable, Equatable {
    public let subtype: String
    public let requestId: String
    public let error: String
    public let pendingPermissionRequests: [String]?

    enum CodingKeys: String, CodingKey {
        case subtype
        case requestId = "request_id"
        case error
        case pendingPermissionRequests = "pending_permission_requests"
    }

    public init(requestId: String, error: String, pendingPermissionRequests: [String]? = nil) {
        self.subtype = "error"
        self.requestId = requestId
        self.error = error
        self.pendingPermissionRequests = pendingPermissionRequests
    }
}

// MARK: - Full Control Response Payload (Discriminated Union)

/// Discriminated union for control response payloads.
public enum FullControlResponsePayload: Codable, Sendable, Equatable {
    case success(requestId: String, response: JSONValue?)
    case error(requestId: String, error: String, pendingPermissionRequests: [String]?)

    enum CodingKeys: String, CodingKey {
        case subtype
        case requestId = "request_id"
        case response
        case error
        case pendingPermissionRequests = "pending_permission_requests"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let subtype = try container.decode(String.self, forKey: .subtype)
        let requestId = try container.decode(String.self, forKey: .requestId)

        switch subtype {
        case "success":
            let response = try container.decodeIfPresent(JSONValue.self, forKey: .response)
            self = .success(requestId: requestId, response: response)
        case "error":
            let error = try container.decode(String.self, forKey: .error)
            let pending = try container.decodeIfPresent([String].self, forKey: .pendingPermissionRequests)
            self = .error(requestId: requestId, error: error, pendingPermissionRequests: pending)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unknown control response subtype: \(subtype)"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .success(let requestId, let response):
            try container.encode("success", forKey: .subtype)
            try container.encode(requestId, forKey: .requestId)
            try container.encodeIfPresent(response, forKey: .response)
        case .error(let requestId, let error, let pending):
            try container.encode("error", forKey: .subtype)
            try container.encode(requestId, forKey: .requestId)
            try container.encode(error, forKey: .error)
            try container.encodeIfPresent(pending, forKey: .pendingPermissionRequests)
        }
    }

    /// The request ID from this response.
    public var requestId: String {
        switch self {
        case .success(let requestId, _): return requestId
        case .error(let requestId, _, _): return requestId
        }
    }
}

// MARK: - MCP Set Servers Result

/// Result of setting MCP servers configuration.
public struct McpSetServersResult: Sendable, Equatable, Codable {
    /// Server names that were added.
    public let added: [String]

    /// Server names that were removed.
    public let removed: [String]

    /// Errors encountered per server name.
    public let errors: [String: String]

    public init(added: [String] = [], removed: [String] = [], errors: [String: String] = [:]) {
        self.added = added
        self.removed = removed
        self.errors = errors
    }
}

// MARK: - Rewind Files Result

/// Result of a rewind files operation.
public struct RewindFilesResult: Sendable, Equatable, Codable {
    /// Whether the rewind can be performed.
    public let canRewind: Bool

    /// Error message if rewind cannot be performed.
    public let error: String?

    /// Files that were changed.
    public let filesChanged: [String]?

    /// Number of line insertions.
    public let insertions: Int?

    /// Number of line deletions.
    public let deletions: Int?

    enum CodingKeys: String, CodingKey {
        case canRewind = "can_rewind"
        case error
        case filesChanged = "files_changed"
        case insertions
        case deletions
    }

    public init(
        canRewind: Bool,
        error: String? = nil,
        filesChanged: [String]? = nil,
        insertions: Int? = nil,
        deletions: Int? = nil
    ) {
        self.canRewind = canRewind
        self.error = error
        self.filesChanged = filesChanged
        self.insertions = insertions
        self.deletions = deletions
    }
}

// MARK: - Full Control Response

/// Full control response with typed payload.
public struct FullControlResponse: Codable, Sendable, Equatable {
    public let type: String
    public let response: FullControlResponsePayload

    public init(response: FullControlResponsePayload) {
        self.type = "control_response"
        self.response = response
    }
}
