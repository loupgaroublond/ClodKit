//
//  ParamBuilder.swift
//  ClodKit
//
//  Result builder DSL and convenience functions for type-safe tool construction.
//

import Foundation

// MARK: - ParamBuilder

/// Result builder for tool parameters.
@resultBuilder
public struct ParamBuilder {
    public static func buildBlock(_ params: ToolParam...) -> [ToolParam] { params }
    public static func buildOptional(_ component: [ToolParam]?) -> [ToolParam] { component ?? [] }
    public static func buildEither(first component: [ToolParam]) -> [ToolParam] { component }
    public static func buildEither(second component: [ToolParam]) -> [ToolParam] { component }
    public static func buildArray(_ components: [[ToolParam]]) -> [ToolParam] { components.flatMap { $0 } }
}

// MARK: - Convenience Functions

/// Creates a tool parameter.
/// - Parameters:
///   - name: The parameter name.
///   - description: Description of the parameter.
///   - type: The parameter type (default: `.string`).
///   - required: Whether this parameter is required (default: `true`).
/// - Returns: A new ToolParam.
public func param(_ name: String, _ description: String, type: ParamType = .string, required: Bool = true) -> ToolParam {
    ToolParam(name: name, description: description, type: type, required: required)
}

/// Creates a string parameter.
public func stringParam(_ name: String, _ description: String, required: Bool = true) -> ToolParam {
    ToolParam(name: name, description: description, type: .string, required: required)
}

/// Creates a number parameter.
public func numberParam(_ name: String, _ description: String, required: Bool = true) -> ToolParam {
    ToolParam(name: name, description: description, type: .number, required: required)
}

/// Creates an integer parameter.
public func intParam(_ name: String, _ description: String, required: Bool = true) -> ToolParam {
    ToolParam(name: name, description: description, type: .integer, required: required)
}

/// Creates a boolean parameter.
public func boolParam(_ name: String, _ description: String, required: Bool = true) -> ToolParam {
    ToolParam(name: name, description: description, type: .boolean, required: required)
}

// MARK: - Schema Builder

/// Builds a JSONSchema from an array of tool parameters.
/// - Parameter params: The parameter definitions.
/// - Returns: A JSONSchema representing the parameters.
public func buildSchema(from params: [ToolParam]) -> JSONSchema {
    var properties: [String: PropertySchema] = [:]
    var required: [String] = []
    for p in params {
        properties[p.name] = PropertySchema(type: p.type.rawValue, description: p.description)
        if p.required { required.append(p.name) }
    }
    return JSONSchema(
        type: "object",
        properties: properties,
        required: required.isEmpty ? nil : required
    )
}
