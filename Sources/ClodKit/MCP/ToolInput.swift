//
//  ToolInput.swift
//  ClodKit
//
//  Protocol for type-safe tool input definitions.
//

import Foundation

// MARK: - ToolInput

/// Protocol for type-safe tool input definitions.
///
/// Conforming types define a structured input for an MCP tool,
/// providing automatic parsing from raw argument dictionaries.
///
/// Example:
/// ```swift
/// struct EchoInput: ToolInput {
///     let message: String
///     let count: Int
///
///     init(args: ToolArgs) throws {
///         message = try args.require("message")
///         count = args.get("count", default: 1)
///     }
///
///     func toDictionary() -> [String: Any] {
///         ["message": message, "count": count]
///     }
/// }
/// ```
public protocol ToolInput: Sendable {
    /// Initialize from raw arguments.
    /// - Parameter args: The type-safe argument wrapper.
    /// - Throws: `ToolArgError` if required arguments are missing or have wrong type.
    init(args: ToolArgs) throws

    /// Convert back to a dictionary for serialization.
    /// - Returns: Dictionary representation of the input.
    func toDictionary() -> [String: Any]
}
