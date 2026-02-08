//
//  SchemaValidator.swift
//  ClodKit
//
//  Validates tool arguments against a JSON schema.
//

import Foundation

// MARK: - SchemaValidator

/// Validates tool arguments against a JSON schema.
public struct SchemaValidator: Sendable {

    /// Validate arguments against a schema.
    /// - Parameters:
    ///   - args: The arguments dictionary to validate.
    ///   - schema: The JSON schema to validate against.
    /// - Returns: Array of validation error messages. Empty means valid.
    public static func validate(_ args: [String: Any], against schema: JSONSchema) -> [String] {
        var errors: [String] = []

        // Check required fields
        if let required = schema.required {
            for field in required {
                if args[field] == nil {
                    errors.append("Missing required field: \(field)")
                }
            }
        }

        // Check types
        if let properties = schema.properties {
            for (key, value) in args {
                if let propSchema = properties[key] {
                    if let typeError = validateType(value: value, expected: propSchema.type, key: key) {
                        errors.append(typeError)
                    }
                }
            }
        }

        return errors
    }

    private static func validateType(value: Any, expected: String, key: String) -> String? {
        switch expected {
        case "string":
            if !(value is String) { return "Field '\(key)' expected string" }
        case "number":
            if !(value is Double || value is Int || value is Float) { return "Field '\(key)' expected number" }
        case "integer":
            if !(value is Int) { return "Field '\(key)' expected integer" }
        case "boolean":
            if !(value is Bool) { return "Field '\(key)' expected boolean" }
        case "array":
            if !(value is [Any]) { return "Field '\(key)' expected array" }
        case "object":
            if !(value is [String: Any]) { return "Field '\(key)' expected object" }
        default:
            break
        }
        return nil
    }
}
