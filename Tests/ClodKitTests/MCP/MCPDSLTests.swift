//
//  MCPDSLTests.swift
//  ClodKitTests
//
//  Unit tests for MCP Tool Builder DSL types.
//

import XCTest
@testable import ClodKit

// MARK: - ToolArgs Tests

final class ToolArgsTests: XCTestCase {

    func testRequire_ReturnsTypedValue() throws {
        let args = ToolArgs(["name": "test", "count": 42])

        let name: String = try args.require("name")
        XCTAssertEqual(name, "test")

        let count: Int = try args.require("count")
        XCTAssertEqual(count, 42)
    }

    func testRequire_ThrowsMissingRequired() {
        let args = ToolArgs(["name": "test"])

        XCTAssertThrowsError(try args.require("missing") as String) { error in
            guard let argError = error as? ToolArgError else {
                XCTFail("Expected ToolArgError"); return
            }
            XCTAssertEqual(argError, .missingRequired(key: "missing"))
        }
    }

    func testRequire_ThrowsTypeMismatch() {
        let args = ToolArgs(["name": 42])

        XCTAssertThrowsError(try args.require("name") as String) { error in
            guard let argError = error as? ToolArgError else {
                XCTFail("Expected ToolArgError"); return
            }
            if case .typeMismatch(let key, let expected, _) = argError {
                XCTAssertEqual(key, "name")
                XCTAssertEqual(expected, "String")
            } else {
                XCTFail("Expected typeMismatch error")
            }
        }
    }

    func testGet_ReturnsOptionalValue() {
        let args = ToolArgs(["name": "test"])

        let name: String? = args.get("name")
        XCTAssertEqual(name, "test")

        let missing: String? = args.get("missing")
        XCTAssertNil(missing)

        let wrongType: Int? = args.get("name")
        XCTAssertNil(wrongType)
    }

    func testGet_WithDefault() {
        let args = ToolArgs([:])

        let val: String = args.get("key", default: "fallback")
        XCTAssertEqual(val, "fallback")
    }

    func testGet_WithDefault_ReturnsActualValue() {
        let args = ToolArgs(["key": "actual"])

        let val: String = args.get("key", default: "fallback")
        XCTAssertEqual(val, "actual")
    }

    func testRawDictionary_ReturnsUnderlyingDict() {
        let args = ToolArgs(["a": 1, "b": "two"])
        let raw = args.rawDictionary
        XCTAssertEqual(raw["a"] as? Int, 1)
        XCTAssertEqual(raw["b"] as? String, "two")
    }
}

// MARK: - ToolArgError Tests

final class ToolArgErrorTests: XCTestCase {

    func testEquatable() {
        let e1 = ToolArgError.missingRequired(key: "foo")
        let e2 = ToolArgError.missingRequired(key: "foo")
        let e3 = ToolArgError.missingRequired(key: "bar")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }

    func testLocalizedDescription_MissingRequired() {
        let error = ToolArgError.missingRequired(key: "name")
        XCTAssertEqual(error.errorDescription, "Missing required argument: name")
    }

    func testLocalizedDescription_TypeMismatch() {
        let error = ToolArgError.typeMismatch(key: "age", expected: "Int", actual: "String")
        XCTAssertEqual(error.errorDescription, "Argument 'age' expected Int, got String")
    }
}

// MARK: - SchemaValidator Tests

final class SchemaValidatorTests: XCTestCase {

    func testValidate_ValidArguments() {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "name": PropertySchema(type: "string", description: "Name"),
                "age": PropertySchema(type: "integer", description: "Age")
            ],
            required: ["name"]
        )

        let errors = SchemaValidator.validate(["name": "Alice", "age": 30], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_MissingRequired() {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "name": PropertySchema(type: "string", description: "Name")
            ],
            required: ["name"]
        )

        let errors = SchemaValidator.validate([:], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("name"))
    }

    func testValidate_TypeMismatch() {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "age": PropertySchema(type: "integer", description: "Age")
            ]
        )

        let errors = SchemaValidator.validate(["age": "not a number"], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("age"))
    }

    func testValidate_AllTypes() {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "s": PropertySchema(type: "string"),
                "n": PropertySchema(type: "number"),
                "i": PropertySchema(type: "integer"),
                "b": PropertySchema(type: "boolean"),
                "a": PropertySchema(type: "array"),
                "o": PropertySchema(type: "object")
            ]
        )

        let valid = SchemaValidator.validate([
            "s": "hello",
            "n": 3.14,
            "i": 42,
            "b": true,
            "a": [1, 2, 3] as [Any],
            "o": ["key": "val"] as [String: Any]
        ], against: schema)
        XCTAssertTrue(valid.isEmpty)
    }

    func testValidate_NoSchema_AlwaysValid() {
        let schema = JSONSchema(type: "object")
        let errors = SchemaValidator.validate(["anything": "goes"], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidate_IntAsNumber() {
        let schema = JSONSchema(
            type: "object",
            properties: [
                "val": PropertySchema(type: "number")
            ]
        )

        let errors = SchemaValidator.validate(["val": 42], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }
}

// MARK: - ToolParam Tests

final class ToolParamTests: XCTestCase {

    func testStringParam() {
        let p = stringParam("name", "The name")
        XCTAssertEqual(p.name, "name")
        XCTAssertEqual(p.description, "The name")
        XCTAssertEqual(p.type, .string)
        XCTAssertTrue(p.required)
    }

    func testIntParam_Optional() {
        let p = intParam("age", "The age", required: false)
        XCTAssertEqual(p.type, .integer)
        XCTAssertFalse(p.required)
    }

    func testNumberParam() {
        let p = numberParam("score", "The score")
        XCTAssertEqual(p.type, .number)
    }

    func testBoolParam() {
        let p = boolParam("active", "Is active")
        XCTAssertEqual(p.type, .boolean)
    }

    func testGenericParam() {
        let p = param("data", "Some data", type: .object)
        XCTAssertEqual(p.type, .object)
    }

    func testBuildSchema_FromParams() {
        let params = [
            stringParam("name", "The name"),
            intParam("age", "The age", required: false)
        ]

        let schema = buildSchema(from: params)
        XCTAssertEqual(schema.type, "object")
        XCTAssertEqual(schema.required, ["name"])
        XCTAssertNotNil(schema.properties?["name"])
        XCTAssertNotNil(schema.properties?["age"])
        XCTAssertEqual(schema.properties?["name"]?.type, "string")
        XCTAssertEqual(schema.properties?["age"]?.type, "integer")
    }

    func testBuildSchema_NoRequired() {
        let params = [
            stringParam("opt", "Optional", required: false)
        ]

        let schema = buildSchema(from: params)
        XCTAssertNil(schema.required)
    }
}

// MARK: - MCPToolAnnotations Tests

final class MCPToolAnnotationsTests: XCTestCase {

    func testInit_AllNil() {
        let annotations = MCPToolAnnotations()
        XCTAssertNil(annotations.title)
        XCTAssertNil(annotations.readOnlyHint)
        XCTAssertNil(annotations.destructiveHint)
        XCTAssertNil(annotations.idempotentHint)
        XCTAssertNil(annotations.openWorldHint)
    }

    func testInit_WithValues() {
        let annotations = MCPToolAnnotations(
            title: "My Tool",
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )

        XCTAssertEqual(annotations.title, "My Tool")
        XCTAssertEqual(annotations.readOnlyHint, true)
        XCTAssertEqual(annotations.destructiveHint, false)
        XCTAssertEqual(annotations.idempotentHint, true)
        XCTAssertEqual(annotations.openWorldHint, false)
    }

    func testEquatable() {
        let a = MCPToolAnnotations(readOnlyHint: true)
        let b = MCPToolAnnotations(readOnlyHint: true)
        let c = MCPToolAnnotations(readOnlyHint: false)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testToDictionary_OnlyIncludesNonNil() {
        let annotations = MCPToolAnnotations(readOnlyHint: true)
        let dict = annotations.toDictionary()

        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["readOnlyHint"] as? Bool, true)
        XCTAssertNil(dict["title"])
    }

    func testToDictionary_Empty() {
        let annotations = MCPToolAnnotations()
        let dict = annotations.toDictionary()
        XCTAssertTrue(dict.isEmpty)
    }

    func testCodable() throws {
        let original = MCPToolAnnotations(
            title: "Test",
            readOnlyHint: true,
            destructiveHint: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPToolAnnotations.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}

// MARK: - MCPTool Annotations Integration Tests

final class MCPToolAnnotationsIntegrationTests: XCTestCase {

    func testMCPTool_WithAnnotations() {
        let tool = MCPTool(
            name: "read-file",
            description: "Reads a file",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["path": .string("File path")],
                required: ["path"]
            ),
            annotations: MCPToolAnnotations(readOnlyHint: true),
            handler: { _ in .text("content") }
        )

        XCTAssertNotNil(tool.annotations)
        XCTAssertEqual(tool.annotations?.readOnlyHint, true)
    }

    func testMCPTool_WithoutAnnotations() {
        let tool = MCPTool(
            name: "echo",
            description: "Echoes input",
            inputSchema: JSONSchema(type: "object"),
            handler: { _ in .text("echo") }
        )

        XCTAssertNil(tool.annotations)
    }

    func testMCPTool_ToDictionary_IncludesAnnotations() {
        let tool = MCPTool(
            name: "test",
            description: "A test tool",
            inputSchema: JSONSchema(type: "object"),
            annotations: MCPToolAnnotations(readOnlyHint: true, destructiveHint: false),
            handler: { _ in .text("ok") }
        )

        let dict = tool.toDictionary()
        XCTAssertNotNil(dict["annotations"])

        let annotations = dict["annotations"] as? [String: Any]
        XCTAssertEqual(annotations?["readOnlyHint"] as? Bool, true)
        XCTAssertEqual(annotations?["destructiveHint"] as? Bool, false)
    }

    func testMCPTool_ToDictionary_ExcludesNilAnnotations() {
        let tool = MCPTool(
            name: "test",
            description: "A test tool",
            inputSchema: JSONSchema(type: "object"),
            handler: { _ in .text("ok") }
        )

        let dict = tool.toDictionary()
        XCTAssertNil(dict["annotations"])
    }

    func testMCPTool_ToDictionary_ExcludesEmptyAnnotations() {
        let tool = MCPTool(
            name: "test",
            description: "A test tool",
            inputSchema: JSONSchema(type: "object"),
            annotations: MCPToolAnnotations(),
            handler: { _ in .text("ok") }
        )

        let dict = tool.toDictionary()
        XCTAssertNil(dict["annotations"])
    }
}

// MARK: - SDKMCPServer Schema Validation Tests

final class SDKMCPServerValidationTests: XCTestCase {

    func testCallTool_ValidatesArguments() async {
        let tool = MCPTool(
            name: "greet",
            description: "Greets someone",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["name": .string("Name")],
                required: ["name"]
            ),
            handler: { _ in .text("hello") }
        )

        let server = SDKMCPServer(name: "test", tools: [tool])

        do {
            _ = try await server.callTool(name: "greet", arguments: [:])
            XCTFail("Expected invalidArguments error")
        } catch let error as MCPServerError {
            if case .invalidArguments(let reason) = error {
                XCTAssertTrue(reason.contains("name"))
            } else {
                XCTFail("Expected invalidArguments, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCallTool_PassesValidation() async throws {
        let tool = MCPTool(
            name: "greet",
            description: "Greets someone",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["name": .string("Name")],
                required: ["name"]
            ),
            handler: { args in
                let name = args["name"] as? String ?? "World"
                return .text("Hello, \(name)!")
            }
        )

        let server = SDKMCPServer(name: "test", tools: [tool])
        let result = try await server.callTool(name: "greet", arguments: ["name": "Alice"])
        XCTAssertEqual(result.content.first, .text("Hello, Alice!"))
    }
}
