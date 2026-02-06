//
//  HookMatcherConfig.swift
//  ClaudeCodeSDK
//
//  Configuration for hook matching.
//

import Foundation

// MARK: - Hook Matcher Configuration

/// Configuration for hook matching, sent during initialization.
/// Determines which hooks are invoked for which tools.
public struct HookMatcherConfig: Codable, Sendable, Equatable {
    /// Regex pattern to match tool names. Nil matches all tools.
    public let matcher: String?

    /// Callback IDs registered for this matcher.
    public let hookCallbackIds: [String]

    /// Timeout for hook execution in seconds.
    public let timeout: TimeInterval?

    public init(matcher: String? = nil, hookCallbackIds: [String], timeout: TimeInterval? = nil) {
        self.matcher = matcher
        self.hookCallbackIds = hookCallbackIds
        self.timeout = timeout
    }

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["hookCallbackIds": hookCallbackIds]
        if let matcher { dict["matcher"] = matcher }
        if let timeout { dict["timeout"] = timeout }
        return dict
    }
}
