//
//  ToolParam.swift
//  ClodKit
//
//  Parameter definitions for type-safe tool construction.
//

import Foundation

// MARK: - ToolParam

/// A parameter definition for a tool.
public struct ToolParam: Sendable {
    /// The parameter name.
    public let name: String

    /// Description of the parameter.
    public let description: String

    /// The parameter type.
    public let type: ParamType

    /// Whether this parameter is required.
    public let required: Bool

    /// Creates a new tool parameter.
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - description: Description of the parameter.
    ///   - type: The parameter type.
    ///   - required: Whether this parameter is required.
    public init(name: String, description: String, type: ParamType, required: Bool = true) {
        self.name = name
        self.description = description
        self.type = type
        self.required = required
    }
}

// MARK: - ParamType

/// JSON Schema types for tool parameters.
public enum ParamType: String, Sendable {
    case string
    case number
    case integer
    case boolean
    case array
    case object
}
