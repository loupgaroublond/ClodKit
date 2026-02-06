//
//  JSONSchema.swift
//  ClodKit
//
//  JSON Schema types for tool input parameters.
//  EXCEPTION: Schema types are tightly coupled; Box is a private recursive-type helper.
//

import Foundation

// MARK: - JSONSchema

/// JSON Schema for tool input parameters.
public struct JSONSchema: Sendable, Codable, Equatable {
    /// The schema type (usually "object").
    public let type: String

    /// Property definitions.
    public let properties: [String: PropertySchema]?

    /// Required property names.
    public let required: [String]?

    /// Whether additional properties are allowed.
    public let additionalProperties: Bool?

    /// Creates a new JSON Schema.
    /// - Parameters:
    ///   - type: The schema type (default "object").
    ///   - properties: Property definitions.
    ///   - required: Required property names.
    ///   - additionalProperties: Whether additional properties are allowed.
    public init(
        type: String = "object",
        properties: [String: PropertySchema]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }

    /// Returns the schema as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let properties {
            dict["properties"] = Dictionary(uniqueKeysWithValues: properties.map { ($0.key, $0.value.toDictionary()) })
        }
        if let required { dict["required"] = required }
        if let additionalProperties { dict["additionalProperties"] = additionalProperties }
        return dict
    }
}

// MARK: - Box (Private)

/// Box wrapper for recursive types.
/// Since T is constrained to Sendable and value is immutable, Box is safely Sendable.
private final class Box<T: Sendable>: Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

// MARK: - PropertySchema

/// Schema for a property within a JSON Schema.
public struct PropertySchema: Sendable, Equatable {
    /// The property type.
    public let type: String

    /// Description of the property.
    public let description: String?

    /// Allowed enum values (for string enums).
    public let `enum`: [String]?

    /// Schema for array items (boxed for recursion).
    private let _items: Box<PropertySchema>?

    /// Nested properties (for object types, boxed for recursion).
    private let _properties: Box<[String: PropertySchema]>?

    /// Schema for array items.
    public var items: PropertySchema? { _items?.value }

    /// Nested properties (for object types).
    public var properties: [String: PropertySchema]? { _properties?.value }

    /// Creates a new property schema.
    /// - Parameters:
    ///   - type: The property type.
    ///   - description: Description of the property.
    ///   - enum: Allowed enum values.
    ///   - items: Schema for array items.
    ///   - properties: Nested properties.
    public init(
        type: String,
        description: String? = nil,
        enum: [String]? = nil,
        items: PropertySchema? = nil,
        properties: [String: PropertySchema]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self._items = items.map { Box($0) }
        self._properties = properties.map { Box($0) }
    }

    public static func == (lhs: PropertySchema, rhs: PropertySchema) -> Bool {
        lhs.type == rhs.type &&
        lhs.description == rhs.description &&
        lhs.enum == rhs.enum &&
        lhs.items == rhs.items &&
        lhs.properties == rhs.properties
    }

    // MARK: Static Builders

    /// Creates a string property schema.
    /// - Parameter description: Optional description.
    /// - Returns: A string property schema.
    public static func string(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "string", description: description)
    }

    /// Creates a number property schema.
    /// - Parameter description: Optional description.
    /// - Returns: A number property schema.
    public static func number(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "number", description: description)
    }

    /// Creates an integer property schema.
    /// - Parameter description: Optional description.
    /// - Returns: An integer property schema.
    public static func integer(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "integer", description: description)
    }

    /// Creates a boolean property schema.
    /// - Parameter description: Optional description.
    /// - Returns: A boolean property schema.
    public static func boolean(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "boolean", description: description)
    }

    /// Creates an array property schema.
    /// - Parameters:
    ///   - items: Schema for array items.
    ///   - description: Optional description.
    /// - Returns: An array property schema.
    public static func array(of items: PropertySchema, description: String? = nil) -> PropertySchema {
        PropertySchema(type: "array", description: description, items: items)
    }

    /// Creates an object property schema.
    /// - Parameters:
    ///   - properties: Nested property definitions.
    ///   - description: Optional description.
    /// - Returns: An object property schema.
    public static func object(properties: [String: PropertySchema], description: String? = nil) -> PropertySchema {
        PropertySchema(type: "object", description: description, properties: properties)
    }

    /// Creates a string enum property schema.
    /// - Parameters:
    ///   - values: Allowed enum values.
    ///   - description: Optional description.
    /// - Returns: An enum property schema.
    public static func `enum`(_ values: [String], description: String? = nil) -> PropertySchema {
        PropertySchema(type: "string", description: description, enum: values)
    }

    /// Returns the property schema as dictionary for JSON serialization.
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description { dict["description"] = description }
        if let `enum` { dict["enum"] = `enum` }
        if let items { dict["items"] = items.toDictionary() }
        if let properties {
            dict["properties"] = Dictionary(uniqueKeysWithValues: properties.map { ($0.key, $0.value.toDictionary()) })
        }
        return dict
    }
}

// MARK: - PropertySchema Codable

extension PropertySchema: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, description, `enum`, items, properties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        `enum` = try container.decodeIfPresent([String].self, forKey: .enum)
        _items = try container.decodeIfPresent(PropertySchema.self, forKey: .items).map { Box($0) }
        _properties = try container.decodeIfPresent([String: PropertySchema].self, forKey: .properties).map { Box($0) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(`enum`, forKey: .enum)
        try container.encodeIfPresent(items, forKey: .items)
        try container.encodeIfPresent(properties, forKey: .properties)
    }
}
