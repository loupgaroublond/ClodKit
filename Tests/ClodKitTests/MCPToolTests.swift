//
//  MCPToolTests.swift
//  ClodKitTests
//
//  Unit tests for MCP tool types.
//

import XCTest
@testable import ClodKit

// MARK: - JSONSchema Tests

final class JSONSchemaTests: XCTestCase {

    func testToDictionary_BasicObject() {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "name": .string("The name"),
                "age": .integer("The age")
            ],
            required: ["name"]
        )

        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "object")
        XCTAssertEqual(dict["required"] as? [String], ["name"])

        let properties = dict["properties"] as? [String: [String: Any]]
        XCTAssertNotNil(properties)
        XCTAssertEqual(properties?["name"]?["type"] as? String, "string")
        XCTAssertEqual(properties?["name"]?["description"] as? String, "The name")
        XCTAssertEqual(properties?["age"]?["type"] as? String, "integer")
    }

    func testToDictionary_WithAdditionalProperties() {
        let schema = JSONSchema(
            type: "object",
            additionalProperties: false
        )

        let dict = schema.toDictionary()

        XCTAssertEqual(dict["additionalProperties"] as? Bool, false)
    }

    func testToDictionary_MinimalSchema() {
        let schema = JSONSchema()

        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "object")
        XCTAssertNil(dict["properties"])
        XCTAssertNil(dict["required"])
    }

    func testCodableRoundTrip() throws {
        let schema = JSONSchema(
            type: "object",
            properties: ["input": .string("Input text")],
            required: ["input"]
        )

        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)

        XCTAssertEqual(decoded.type, "object")
        XCTAssertEqual(decoded.required, ["input"])
        XCTAssertEqual(decoded.properties?["input"]?.type, "string")
    }
}

// MARK: - PropertySchema Tests

final class PropertySchemaTests: XCTestCase {

    func testStringBuilder() {
        let prop = PropertySchema.string("A string value")

        XCTAssertEqual(prop.type, "string")
        XCTAssertEqual(prop.description, "A string value")
        XCTAssertNil(prop.items)
        XCTAssertNil(prop.properties)
    }

    func testNumberBuilder() {
        let prop = PropertySchema.number("A number")

        XCTAssertEqual(prop.type, "number")
    }

    func testIntegerBuilder() {
        let prop = PropertySchema.integer()

        XCTAssertEqual(prop.type, "integer")
        XCTAssertNil(prop.description)
    }

    func testBooleanBuilder() {
        let prop = PropertySchema.boolean("Is enabled")

        XCTAssertEqual(prop.type, "boolean")
        XCTAssertEqual(prop.description, "Is enabled")
    }

    func testArrayBuilder() {
        let prop = PropertySchema.array(of: .string(), description: "List of strings")

        XCTAssertEqual(prop.type, "array")
        XCTAssertEqual(prop.description, "List of strings")
        XCTAssertEqual(prop.items?.type, "string")
    }

    func testObjectBuilder() {
        let prop = PropertySchema.object(
            properties: [
                "x": .number(),
                "y": .number()
            ],
            description: "A point"
        )

        XCTAssertEqual(prop.type, "object")
        XCTAssertEqual(prop.properties?["x"]?.type, "number")
        XCTAssertEqual(prop.properties?["y"]?.type, "number")
    }

    func testEnumBuilder() {
        let prop = PropertySchema.enum(["red", "green", "blue"], description: "Color")

        XCTAssertEqual(prop.type, "string")
        XCTAssertEqual(prop.enum, ["red", "green", "blue"])
        XCTAssertEqual(prop.description, "Color")
    }

    func testToDictionary_IncludesAllFields() {
        let prop = PropertySchema.array(of: .string("Item"), description: "Items")

        let dict = prop.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "array")
        XCTAssertEqual(dict["description"] as? String, "Items")

        let items = dict["items"] as? [String: Any]
        XCTAssertEqual(items?["type"] as? String, "string")
        XCTAssertEqual(items?["description"] as? String, "Item")
    }

    func testToDictionary_NestedObject() {
        let prop = PropertySchema.object(properties: [
            "inner": .object(properties: [
                "value": .number()
            ])
        ])

        let dict = prop.toDictionary()
        let properties = dict["properties"] as? [String: [String: Any]]
        let inner = properties?["inner"]
        let innerProps = inner?["properties"] as? [String: [String: Any]]

        XCTAssertEqual(innerProps?["value"]?["type"] as? String, "number")
    }

    func testCodableRoundTrip() throws {
        let prop = PropertySchema.array(of: .integer("Index"), description: "Indices")

        let data = try JSONEncoder().encode(prop)
        let decoded = try JSONDecoder().decode(PropertySchema.self, from: data)

        XCTAssertEqual(decoded.type, "array")
        XCTAssertEqual(decoded.description, "Indices")
        XCTAssertEqual(decoded.items?.type, "integer")
    }
}

// MARK: - MCPContent Tests

final class MCPContentTests: XCTestCase {

    func testTextToDictionary() {
        let content = MCPContent.text("Hello, world!")

        let dict = content.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "text")
        XCTAssertEqual(dict["text"] as? String, "Hello, world!")
    }

    func testImageToDictionary() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])  // PNG header bytes
        let content = MCPContent.image(data: imageData, mimeType: "image/png")

        let dict = content.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "image")
        XCTAssertEqual(dict["mimeType"] as? String, "image/png")
        XCTAssertEqual(dict["data"] as? String, imageData.base64EncodedString())
    }

    func testResourceToDictionary_AllFields() {
        let content = MCPContent.resource(
            uri: "file:///tmp/test.txt",
            mimeType: "text/plain",
            text: "File content"
        )

        let dict = content.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "resource")
        XCTAssertEqual(dict["uri"] as? String, "file:///tmp/test.txt")
        XCTAssertEqual(dict["mimeType"] as? String, "text/plain")
        XCTAssertEqual(dict["text"] as? String, "File content")
    }

    func testResourceToDictionary_OptionalFieldsNil() {
        let content = MCPContent.resource(uri: "https://example.com", mimeType: nil, text: nil)

        let dict = content.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "resource")
        XCTAssertEqual(dict["uri"] as? String, "https://example.com")
        XCTAssertNil(dict["mimeType"])
        XCTAssertNil(dict["text"])
    }

    func testEquatable() {
        let text1 = MCPContent.text("Hello")
        let text2 = MCPContent.text("Hello")
        let text3 = MCPContent.text("World")

        XCTAssertEqual(text1, text2)
        XCTAssertNotEqual(text1, text3)
    }
}

// MARK: - MCPToolResult Tests

final class MCPToolResultTests: XCTestCase {

    func testTextConvenience() {
        let result = MCPToolResult.text("Success!")

        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content[0], .text("Success!"))
        XCTAssertFalse(result.isError)
    }

    func testErrorConvenience() {
        let result = MCPToolResult.error("Something went wrong")

        XCTAssertEqual(result.content.count, 1)
        XCTAssertEqual(result.content[0], .text("Something went wrong"))
        XCTAssertTrue(result.isError)
    }

    func testToDictionary_Success() {
        let result = MCPToolResult(content: [
            .text("Line 1"),
            .text("Line 2")
        ])

        let dict = result.toDictionary()

        let content = dict["content"] as? [[String: Any]]
        XCTAssertEqual(content?.count, 2)
        XCTAssertEqual(content?[0]["text"] as? String, "Line 1")
        XCTAssertEqual(content?[1]["text"] as? String, "Line 2")
        XCTAssertNil(dict["isError"])
    }

    func testToDictionary_Error() {
        let result = MCPToolResult.error("Failed!")

        let dict = result.toDictionary()

        XCTAssertEqual(dict["isError"] as? Bool, true)
    }

    func testEquatable() {
        let r1 = MCPToolResult.text("A")
        let r2 = MCPToolResult.text("A")
        let r3 = MCPToolResult.error("A")

        XCTAssertEqual(r1, r2)
        XCTAssertNotEqual(r1, r3)
    }
}

// MARK: - MCPTool Tests

final class MCPToolTests: XCTestCase {

    func testToDictionary() {
        let tool = MCPTool(
            name: "echo",
            description: "Echoes the input",
            inputSchema: JSONSchema(
                properties: ["message": .string("Message to echo")],
                required: ["message"]
            ),
            handler: { _ in .text("test") }
        )

        let dict = tool.toDictionary()

        XCTAssertEqual(dict["name"] as? String, "echo")
        XCTAssertEqual(dict["description"] as? String, "Echoes the input")

        let schema = dict["inputSchema"] as? [String: Any]
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?["type"] as? String, "object")
        XCTAssertEqual(schema?["required"] as? [String], ["message"])
    }

    func testHandlerExecution() async throws {
        let tool = MCPTool(
            name: "add",
            description: "Adds two numbers",
            inputSchema: JSONSchema(
                properties: [
                    "a": .number(),
                    "b": .number()
                ],
                required: ["a", "b"]
            ),
            handler: { args in
                let a = args["a"] as? Double ?? 0
                let b = args["b"] as? Double ?? 0
                return .text("\(a + b)")
            }
        )

        let result = try await tool.handler(["a": 5.0, "b": 3.0])

        XCTAssertEqual(result.content.first, .text("8.0"))
    }

    func testHandlerThrowsError() async {
        struct TestError: Error {}

        let tool = MCPTool(
            name: "failing",
            description: "Always fails",
            inputSchema: JSONSchema(),
            handler: { _ in throw TestError() }
        )

        do {
            _ = try await tool.handler([:])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}
