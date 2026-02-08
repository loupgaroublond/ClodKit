//
//  ToolArgs.swift
//  ClodKit
//
//  Type-safe argument extraction for MCP tool handlers.
//

import Foundation

// MARK: - ToolArgs

/// Type-safe wrapper for extracting tool arguments.
///
/// Safety: `@unchecked Sendable` is correct because `raw` is immutable (`let`)
/// and only accessed for reading via typed extraction methods.
public struct ToolArgs: @unchecked Sendable {
    private let raw: [String: Any]

    /// Creates a new ToolArgs wrapper.
    /// - Parameter raw: The raw argument dictionary.
    public init(_ raw: [String: Any]) {
        self.raw = raw
    }

    /// Extract a required typed value.
    /// - Parameter key: The argument key.
    /// - Returns: The typed value.
    /// - Throws: `ToolArgError.missingRequired` if key is absent,
    ///           `ToolArgError.typeMismatch` if value has wrong type.
    public func require<T>(_ key: String) throws -> T {
        guard let value = raw[key] else {
            throw ToolArgError.missingRequired(key: key)
        }
        guard let typed = value as? T else {
            throw ToolArgError.typeMismatch(
                key: key,
                expected: String(describing: T.self),
                actual: String(describing: type(of: value))
            )
        }
        return typed
    }

    /// Extract an optional typed value.
    /// - Parameter key: The argument key.
    /// - Returns: The typed value, or nil if absent or wrong type.
    public func get<T>(_ key: String) -> T? {
        raw[key] as? T
    }

    /// Extract a typed value with a default.
    /// - Parameters:
    ///   - key: The argument key.
    ///   - defaultValue: Default value if key is absent or wrong type.
    /// - Returns: The typed value, or the default.
    public func get<T>(_ key: String, default defaultValue: T) -> T {
        (raw[key] as? T) ?? defaultValue
    }

    /// Access the underlying dictionary.
    public var rawDictionary: [String: Any] { raw }
}

// MARK: - ToolArgError

/// Errors from tool argument extraction.
public enum ToolArgError: Error, Sendable, Equatable {
    /// A required argument was missing.
    case missingRequired(key: String)

    /// An argument had the wrong type.
    case typeMismatch(key: String, expected: String, actual: String)
}

extension ToolArgError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingRequired(let key):
            return "Missing required argument: \(key)"
        case .typeMismatch(let key, let expected, let actual):
            return "Argument '\(key)' expected \(expected), got \(actual)"
        }
    }
}
