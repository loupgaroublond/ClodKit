//
//  PermissionUpdate.swift
//  ClodKit
//
//  Permission update for rule changes.
//  EXCEPTION: Nested enums are semantically part of the parent and are kept together.
//

import Foundation

// MARK: - Permission Update

/// Permission update for rule changes.
/// Represents changes to permission rules or settings.
public struct PermissionUpdate: Codable, Sendable, Equatable {

    /// Type of permission update.
    public enum UpdateType: String, Codable, Sendable {
        /// Add new permission rules.
        case addRules

        /// Replace all permission rules.
        case replaceRules

        /// Remove specific permission rules.
        case removeRules

        /// Set the permission mode.
        case setMode

        /// Add allowed directories.
        case addDirectories

        /// Remove allowed directories.
        case removeDirectories
    }

    /// Permission behavior for a rule.
    public enum Behavior: String, Codable, Sendable {
        /// Allow the action.
        case allow

        /// Deny the action.
        case deny

        /// Ask the user.
        case ask
    }

    /// Destination for permission changes.
    public enum Destination: String, Codable, Sendable {
        /// User-wide settings.
        case userSettings

        /// Project-level settings.
        case projectSettings

        /// Local (machine-specific) settings.
        case localSettings

        /// Session-only (temporary).
        case session
    }

    /// The type of update to perform.
    public let type: UpdateType

    /// Rules to add, replace, or remove (for rule operations).
    public let rules: [PermissionRule]?

    /// Behavior for the rules.
    public let behavior: Behavior?

    /// Mode to set (for setMode).
    public let mode: PermissionMode?

    /// Directories to add or remove (for directory operations).
    public let directories: [String]?

    /// Where to apply the changes.
    public let destination: Destination?

    public init(
        type: UpdateType,
        rules: [PermissionRule]? = nil,
        behavior: Behavior? = nil,
        mode: PermissionMode? = nil,
        directories: [String]? = nil,
        destination: Destination? = nil
    ) {
        self.type = type
        self.rules = rules
        self.behavior = behavior
        self.mode = mode
        self.directories = directories
        self.destination = destination
    }

    /// Convert to dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type.rawValue]
        if let rules { dict["rules"] = rules.map { $0.toDictionary() } }
        if let behavior { dict["behavior"] = behavior.rawValue }
        if let mode { dict["mode"] = mode.rawValue }
        if let directories { dict["directories"] = directories }
        if let destination { dict["destination"] = destination.rawValue }
        return dict
    }

    // MARK: - Convenience Initializers

    /// Create an update to add rules.
    public static func addRules(_ rules: [PermissionRule], behavior: Behavior, destination: Destination = .session) -> PermissionUpdate {
        PermissionUpdate(type: .addRules, rules: rules, behavior: behavior, destination: destination)
    }

    /// Create an update to replace all rules.
    public static func replaceRules(_ rules: [PermissionRule], behavior: Behavior, destination: Destination = .session) -> PermissionUpdate {
        PermissionUpdate(type: .replaceRules, rules: rules, behavior: behavior, destination: destination)
    }

    /// Create an update to remove rules.
    public static func removeRules(_ rules: [PermissionRule], destination: Destination = .session) -> PermissionUpdate {
        PermissionUpdate(type: .removeRules, rules: rules, destination: destination)
    }

    /// Create an update to set the permission mode.
    public static func setMode(_ mode: PermissionMode, destination: Destination = .session) -> PermissionUpdate {
        PermissionUpdate(type: .setMode, mode: mode, destination: destination)
    }

    /// Create an update to add directories.
    public static func addDirectories(_ directories: [String], destination: Destination = .session) -> PermissionUpdate {
        PermissionUpdate(type: .addDirectories, directories: directories, destination: destination)
    }

    /// Create an update to remove directories.
    public static func removeDirectories(_ directories: [String], destination: Destination = .session) -> PermissionUpdate {
        PermissionUpdate(type: .removeDirectories, directories: directories, destination: destination)
    }
}
