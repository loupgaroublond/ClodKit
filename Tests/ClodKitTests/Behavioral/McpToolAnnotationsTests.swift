//
//  McpToolAnnotationsTests.swift
//  ClodKitTests
//
//  Behavioral tests for MCPTool annotations and tool builder (bead wns).
//

import XCTest
@testable import ClodKit

// MARK: - MCPToolAnnotations Tests

final class MCPToolAnnotationsFieldTests: XCTestCase {

    func testAllFieldsOptional() {
        let ann = MCPToolAnnotations()
        XCTAssertNil(ann.title)
        XCTAssertNil(ann.readOnlyHint)
        XCTAssertNil(ann.destructiveHint)
        XCTAssertNil(ann.idempotentHint)
        XCTAssertNil(ann.openWorldHint)
    }

    func testAllFieldsPopulated() {
        let ann = MCPToolAnnotations(
            title: "File Reader",
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
        XCTAssertEqual(ann.title, "File Reader")
        XCTAssertEqual(ann.readOnlyHint, true)
        XCTAssertEqual(ann.destructiveHint, false)
        XCTAssertEqual(ann.idempotentHint, true)
        XCTAssertEqual(ann.openWorldHint, false)
    }

    func testCodableRoundTrip() throws {
        let original = MCPToolAnnotations(
            title: "Test Tool",
            readOnlyHint: true,
            destructiveHint: false,
            idempotentHint: true,
            openWorldHint: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MCPToolAnnotations.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testToDictionaryIncludesOnlySetFields() {
        let ann = MCPToolAnnotations(readOnlyHint: true)
        let dict = ann.toDictionary()
        XCTAssertEqual(dict["readOnlyHint"] as? Bool, true)
        XCTAssertNil(dict["destructiveHint"])
        XCTAssertNil(dict["idempotentHint"])
        XCTAssertNil(dict["openWorldHint"])
        XCTAssertNil(dict["title"])
    }

    func testToDictionaryWithAllFields() {
        let ann = MCPToolAnnotations(
            title: "Tool",
            readOnlyHint: false,
            destructiveHint: true,
            idempotentHint: false,
            openWorldHint: true
        )
        let dict = ann.toDictionary()
        XCTAssertEqual(dict["title"] as? String, "Tool")
        XCTAssertEqual(dict["readOnlyHint"] as? Bool, false)
        XCTAssertEqual(dict["destructiveHint"] as? Bool, true)
        XCTAssertEqual(dict["idempotentHint"] as? Bool, false)
        XCTAssertEqual(dict["openWorldHint"] as? Bool, true)
    }

    func testEmptyAnnotationsToDictionary() {
        let ann = MCPToolAnnotations()
        let dict = ann.toDictionary()
        XCTAssertTrue(dict.isEmpty)
    }
}

// MARK: - MCPTool with Annotations Tests

final class MCPToolWithAnnotationsTests: XCTestCase {

    func testToolWithNilAnnotationsBackwardCompatible() {
        let tool = MCPTool(
            name: "echo",
            description: "Echo input",
            inputSchema: JSONSchema(),
            annotations: nil,
            handler: { _ in .text("ok") }
        )
        XCTAssertNil(tool.annotations)
    }

    func testToolWithAnnotations() {
        let ann = MCPToolAnnotations(readOnlyHint: true, destructiveHint: false, openWorldHint: false)
        let tool = MCPTool(
            name: "read_file",
            description: "Read a file",
            inputSchema: JSONSchema(
                properties: ["path": .string("File path")],
                required: ["path"]
            ),
            annotations: ann,
            handler: { _ in .text("content") }
        )
        XCTAssertNotNil(tool.annotations)
        XCTAssertEqual(tool.annotations?.readOnlyHint, true)
        XCTAssertEqual(tool.annotations?.destructiveHint, false)
    }

    func testToDictionaryIncludesAnnotations() {
        let ann = MCPToolAnnotations(readOnlyHint: true, destructiveHint: false)
        let tool = MCPTool(
            name: "test",
            description: "test tool",
            inputSchema: JSONSchema(),
            annotations: ann,
            handler: { _ in .text("ok") }
        )
        let dict = tool.toDictionary()
        XCTAssertNotNil(dict["annotations"])
        let annDict = dict["annotations"] as! [String: Any]
        XCTAssertEqual(annDict["readOnlyHint"] as? Bool, true)
        XCTAssertEqual(annDict["destructiveHint"] as? Bool, false)
    }

    func testToDictionaryOmitsAnnotationsWhenNil() {
        let tool = MCPTool(
            name: "test",
            description: "test tool",
            inputSchema: JSONSchema(),
            handler: { _ in .text("ok") }
        )
        let dict = tool.toDictionary()
        XCTAssertNil(dict["annotations"])
    }

    func testToDictionaryOmitsAnnotationsWhenEmpty() {
        let tool = MCPTool(
            name: "test",
            description: "test tool",
            inputSchema: JSONSchema(),
            annotations: MCPToolAnnotations(),
            handler: { _ in .text("ok") }
        )
        let dict = tool.toDictionary()
        // Empty annotations dict should be omitted
        XCTAssertNil(dict["annotations"])
    }
}

// MARK: - Tool Builder with Annotations Tests

final class ToolBuilderAnnotationsTests: XCTestCase {

    func testCreateSDKMCPServerWithAnnotatedTools() {
        let server = createSDKMCPServer(name: "annotated-server", version: "1.0.0") {
            MCPTool(
                name: "safe_read",
                description: "Safely read data",
                inputSchema: JSONSchema(
                    properties: ["key": .string("Key to read")],
                    required: ["key"]
                ),
                annotations: MCPToolAnnotations(readOnlyHint: true, destructiveHint: false),
                handler: { args in .text("value") }
            )
            MCPTool(
                name: "dangerous_delete",
                description: "Delete data",
                inputSchema: JSONSchema(
                    properties: ["key": .string("Key to delete")],
                    required: ["key"]
                ),
                annotations: MCPToolAnnotations(readOnlyHint: false, destructiveHint: true),
                handler: { args in .text("deleted") }
            )
        }

        XCTAssertEqual(server.toolCount, 2)

        let safeTool = server.getTool(named: "safe_read")
        XCTAssertNotNil(safeTool)
        XCTAssertEqual(safeTool?.annotations?.readOnlyHint, true)
        XCTAssertEqual(safeTool?.annotations?.destructiveHint, false)

        let dangerousTool = server.getTool(named: "dangerous_delete")
        XCTAssertNotNil(dangerousTool)
        XCTAssertEqual(dangerousTool?.annotations?.destructiveHint, true)
    }

    func testListToolsIncludesAnnotations() {
        let server = createSDKMCPServer(name: "test") {
            MCPTool(
                name: "annotated",
                description: "Has annotations",
                inputSchema: JSONSchema(),
                annotations: MCPToolAnnotations(readOnlyHint: true),
                handler: { _ in .text("ok") }
            )
        }

        let tools = server.listTools()
        XCTAssertEqual(tools.count, 1)
        let toolDict = tools[0]
        XCTAssertNotNil(toolDict["annotations"])
    }

    func testListToolsOmitsAnnotationsWhenNil() {
        let server = createSDKMCPServer(name: "test") {
            MCPTool(
                name: "plain",
                description: "No annotations",
                inputSchema: JSONSchema(),
                handler: { _ in .text("ok") }
            )
        }

        let tools = server.listTools()
        XCTAssertEqual(tools.count, 1)
        let toolDict = tools[0]
        XCTAssertNil(toolDict["annotations"])
    }
}

// MARK: - ToolParam and ParamBuilder Tests

final class ToolParamBehavioralTests: XCTestCase {

    func testToolParamCreation() {
        let p = ToolParam(name: "query", description: "Search query", type: .string, required: true)
        XCTAssertEqual(p.name, "query")
        XCTAssertEqual(p.description, "Search query")
        XCTAssertEqual(p.type, .string)
        XCTAssertTrue(p.required)
    }

    func testParamTypeRawValues() {
        XCTAssertEqual(ParamType.string.rawValue, "string")
        XCTAssertEqual(ParamType.number.rawValue, "number")
        XCTAssertEqual(ParamType.integer.rawValue, "integer")
        XCTAssertEqual(ParamType.boolean.rawValue, "boolean")
        XCTAssertEqual(ParamType.array.rawValue, "array")
        XCTAssertEqual(ParamType.object.rawValue, "object")
    }

    func testBuildSchemaFromParams() {
        let params = [
            ToolParam(name: "name", description: "Name", type: .string, required: true),
            ToolParam(name: "age", description: "Age", type: .integer, required: false),
        ]
        let schema = buildSchema(from: params)
        XCTAssertEqual(schema.type, "object")
        XCTAssertNotNil(schema.properties?["name"])
        XCTAssertNotNil(schema.properties?["age"])
        XCTAssertEqual(schema.properties?["name"]?.type, "string")
        XCTAssertEqual(schema.properties?["age"]?.type, "integer")
        XCTAssertEqual(schema.required, ["name"])
    }

    func testBuildSchemaNoRequiredParams() {
        let params = [
            ToolParam(name: "opt", description: "Optional", type: .string, required: false),
        ]
        let schema = buildSchema(from: params)
        XCTAssertNil(schema.required)
    }

    func testConvenienceParamFunctions() {
        let s = stringParam("name", "A name")
        XCTAssertEqual(s.type, .string)
        XCTAssertTrue(s.required)

        let n = numberParam("score", "Score", required: false)
        XCTAssertEqual(n.type, .number)
        XCTAssertFalse(n.required)

        let i = intParam("count", "Count")
        XCTAssertEqual(i.type, .integer)

        let b = boolParam("flag", "Flag")
        XCTAssertEqual(b.type, .boolean)
    }
}
