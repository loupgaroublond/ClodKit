//
//  PermissionRule.swift
//  ClaudeCodeSDK
//
//  A permission rule for a specific tool.
//

import Foundation

// MARK: - Permission Rule

/// A permission rule for a specific tool.
public struct PermissionRule: Codable, Sendable, Equatable {
    /// Name of the tool this rule applies to.
    public let toolName: String

    /// Content/pattern for the rule (optional).
    public let ruleContent: String?

    public init(toolName: String, ruleContent: String? = nil) {
        self.toolName = toolName
        self.ruleContent = ruleContent
    }

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["toolName": toolName]
        if let ruleContent { dict["ruleContent"] = ruleContent }
        return dict
    }

    // MARK: - Convenience Initializers

    /// Create a rule for a tool with no specific content.
    public static func tool(_ name: String) -> PermissionRule {
        PermissionRule(toolName: name)
    }

    /// Create a rule for a tool with specific content.
    public static func tool(_ name: String, content: String) -> PermissionRule {
        PermissionRule(toolName: name, ruleContent: content)
    }
}
