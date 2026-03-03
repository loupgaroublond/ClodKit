//
//  SubscribePollingTypes.swift
//  ClodKit
//
//  Input and output types for the SubscribePolling and UnsubscribePolling tools.
//

import Foundation

// MARK: - Subscribe Polling Input

/// Input for the SubscribePolling tool.
public struct SubscribePollingInput: Sendable, Equatable, Codable {
    /// The type of subscription: "tool" to poll a tool, "resource" to poll a resource URI.
    public let type: String

    /// The MCP server name.
    public let server: String

    /// The tool to call periodically (required when type is "tool").
    public let toolName: String?

    /// Arguments to pass to the tool on each call.
    public let arguments: [String: JSONValue]?

    /// The resource URI to poll (required when type is "resource").
    public let uri: String?

    /// Polling interval in milliseconds (minimum 1000ms, default 5000ms).
    public let intervalMs: Int

    /// Optional reason for subscribing.
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case type, server
        case toolName = "toolName"
        case arguments, uri
        case intervalMs = "intervalMs"
        case reason
    }

    public init(
        type: String,
        server: String,
        toolName: String? = nil,
        arguments: [String: JSONValue]? = nil,
        uri: String? = nil,
        intervalMs: Int,
        reason: String? = nil
    ) {
        self.type = type
        self.server = server
        self.toolName = toolName
        self.arguments = arguments
        self.uri = uri
        self.intervalMs = intervalMs
        self.reason = reason
    }
}

// MARK: - Subscribe Polling Output

/// Output from the SubscribePolling tool.
public struct SubscribePollingOutput: Sendable, Equatable, Codable {
    /// Whether the subscription was successful.
    public let subscribed: Bool

    /// Unique identifier for this subscription.
    public let subscriptionId: String

    enum CodingKeys: String, CodingKey {
        case subscribed
        case subscriptionId = "subscriptionId"
    }

    public init(subscribed: Bool, subscriptionId: String) {
        self.subscribed = subscribed
        self.subscriptionId = subscriptionId
    }
}

// MARK: - Unsubscribe Polling Input

/// Input for the UnsubscribePolling tool.
public struct UnsubscribePollingInput: Sendable, Equatable, Codable {
    /// The subscription ID to unsubscribe.
    public let subscriptionId: String?

    /// The MCP server name.
    public let server: String?

    /// The target to unsubscribe.
    public let target: String?

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscriptionId"
        case server, target
    }

    public init(subscriptionId: String? = nil, server: String? = nil, target: String? = nil) {
        self.subscriptionId = subscriptionId
        self.server = server
        self.target = target
    }
}

// MARK: - Unsubscribe Polling Output

/// Output from the UnsubscribePolling tool.
public struct UnsubscribePollingOutput: Sendable, Equatable, Codable {
    /// Whether the unsubscription was successful.
    public let unsubscribed: Bool

    public init(unsubscribed: Bool) {
        self.unsubscribed = unsubscribed
    }
}
