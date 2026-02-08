//
//  PermissionResult.swift
//  ClodKit
//
//  Result from a permission callback.
//

import Foundation

// MARK: - Permission Result

/// Result from a permission callback.
/// Determines whether the tool can execute and any modifications.
public enum PermissionResult: Sendable {
    /// Allow the tool to execute, optionally with modifications.
    /// - Parameters:
    ///   - updatedInput: Modified tool input (if changing the input).
    ///   - permissionUpdates: Permission rule changes to apply.
    ///   - toolUseID: The tool use ID to echo back.
    case allow(updatedInput: [String: JSONValue]? = nil, permissionUpdates: [PermissionUpdate]? = nil, toolUseID: String? = nil)

    /// Deny the tool execution.
    /// - Parameters:
    ///   - message: Message explaining the denial.
    ///   - interrupt: Whether to interrupt the entire execution.
    ///   - toolUseID: The tool use ID to echo back.
    case deny(message: String, interrupt: Bool = false, toolUseID: String? = nil)

    /// Convert to dictionary for JSON serialization to CLI.
    public func toDictionary() -> [String: Any] {
        switch self {
        case .allow(let updatedInput, let updates, let toolUseID):
            var dict: [String: Any] = ["behavior": "allow"]
            if let updatedInput {
                dict["updatedInput"] = updatedInput.mapValues { $0.toAny() }
            }
            if let updates {
                dict["updatedPermissions"] = updates.map { $0.toDictionary() }
            }
            if let toolUseID {
                dict["toolUseId"] = toolUseID
            }
            return dict

        case .deny(let message, let interrupt, let toolUseID):
            var dict: [String: Any] = [
                "behavior": "deny",
                "message": message,
                "interrupt": interrupt
            ]
            if let toolUseID {
                dict["toolUseId"] = toolUseID
            }
            return dict
        }
    }

    // MARK: - Convenience Initializers

    /// Create an allow result with no modifications.
    public static func allowTool(toolUseID: String? = nil) -> PermissionResult {
        .allow(updatedInput: nil, permissionUpdates: nil, toolUseID: toolUseID)
    }

    /// Create an allow result with modified input.
    public static func allowTool(updatedInput: [String: JSONValue], toolUseID: String? = nil) -> PermissionResult {
        .allow(updatedInput: updatedInput, permissionUpdates: nil, toolUseID: toolUseID)
    }

    /// Create an allow result with permission updates.
    public static func allowTool(permissionUpdates: [PermissionUpdate], toolUseID: String? = nil) -> PermissionResult {
        .allow(updatedInput: nil, permissionUpdates: permissionUpdates, toolUseID: toolUseID)
    }

    /// Create a deny result with just a message.
    public static func denyTool(_ message: String, toolUseID: String? = nil) -> PermissionResult {
        .deny(message: message, interrupt: false, toolUseID: toolUseID)
    }

    /// Create a deny result that interrupts execution.
    public static func denyToolAndInterrupt(_ message: String, toolUseID: String? = nil) -> PermissionResult {
        .deny(message: message, interrupt: true, toolUseID: toolUseID)
    }
}

// MARK: - Permission Callback Type

/// Type alias for the permission callback function.
/// Called when a tool requests permission to execute.
///
/// - Parameters:
///   - toolName: Name of the tool requesting permission.
///   - input: The input parameters for the tool.
///   - context: Context including suggestions and metadata.
/// - Returns: Permission result indicating allow or deny.
public typealias CanUseToolCallback = @Sendable (
    _ toolName: String,
    _ input: [String: JSONValue],
    _ context: ToolPermissionContext
) async throws -> PermissionResult
