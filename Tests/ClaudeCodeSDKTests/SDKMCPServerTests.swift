//
//  SDKMCPServerTests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for SDKMCPServer.
//

import XCTest
@testable import ClaudeCodeSDK

final class SDKMCPServerTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_StoresToolsByName() {
        let tool1 = MCPTool(
            name: "tool1",
            description: "First tool",
            inputSchema: JSONSchema(),
            handler: { _ in .text("1") }
        )
        let tool2 = MCPTool(
            name: "tool2",
            description: "Second tool",
            inputSchema: JSONSchema(),
            handler: { _ in .text("2") }
        )

        let server = SDKMCPServer(name: "test", tools: [tool1, tool2])

        XCTAssertEqual(server.toolCount, 2)
        XCTAssertTrue(server.toolNames.contains("tool1"))
        XCTAssertTrue(server.toolNames.contains("tool2"))
    }

    func testInit_DefaultVersion() {
        let server = SDKMCPServer(name: "test", tools: [])

        XCTAssertEqual(server.version, "1.0.0")
    }

    func testInit_CustomVersion() {
        let server = SDKMCPServer(name: "test", version: "2.0.0", tools: [])

        XCTAssertEqual(server.version, "2.0.0")
    }

    // MARK: - listTools Tests

    func testListTools_ReturnsCorrectFormat() {
        let tool = MCPTool(
            name: "echo",
            description: "Echoes input",
            inputSchema: JSONSchema(
                properties: ["message": .string("The message")],
                required: ["message"]
            ),
            handler: { _ in .text("test") }
        )

        let server = SDKMCPServer(name: "test", tools: [tool])
        let listing = server.listTools()

        XCTAssertEqual(listing.count, 1)

        let toolDef = listing[0]
        XCTAssertEqual(toolDef["name"] as? String, "echo")
        XCTAssertEqual(toolDef["description"] as? String, "Echoes input")

        let schema = toolDef["inputSchema"] as? [String: Any]
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?["type"] as? String, "object")
    }

    func testListTools_EmptyServer() {
        let server = SDKMCPServer(name: "empty", tools: [])
        let listing = server.listTools()

        XCTAssertEqual(listing.count, 0)
    }

    // MARK: - callTool Tests

    func testCallTool_ExecutesHandler() async throws {
        let tool = MCPTool(
            name: "greet",
            description: "Greets someone",
            inputSchema: JSONSchema(
                properties: ["name": .string()],
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
        XCTAssertFalse(result.isError)
    }

    func testCallTool_ToolNotFound_ThrowsError() async {
        let server = SDKMCPServer(name: "test", tools: [])

        do {
            _ = try await server.callTool(name: "nonexistent", arguments: [:])
            XCTFail("Expected toolNotFound error")
        } catch let error as MCPServerError {
            if case .toolNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent")
            } else {
                XCTFail("Expected toolNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCallTool_HandlerThrows_PropagatesError() async {
        struct TestError: Error {}

        let tool = MCPTool(
            name: "failing",
            description: "Always fails",
            inputSchema: JSONSchema(),
            handler: { _ in throw TestError() }
        )

        let server = SDKMCPServer(name: "test", tools: [tool])

        do {
            _ = try await server.callTool(name: "failing", arguments: [:])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - capabilities Tests

    func testCapabilities_ReturnsCorrectFormat() {
        let server = SDKMCPServer(name: "test", tools: [])

        let caps = server.capabilities

        let tools = caps["tools"] as? [String: Any]
        XCTAssertNotNil(tools)
        XCTAssertEqual(tools?["listChanged"] as? Bool, false)
    }

    // MARK: - serverInfo Tests

    func testServerInfo_ReturnsCorrectFormat() {
        let server = SDKMCPServer(name: "my-server", version: "1.2.3", tools: [])

        let info = server.serverInfo

        XCTAssertEqual(info["name"] as? String, "my-server")
        XCTAssertEqual(info["version"] as? String, "1.2.3")
    }

    // MARK: - getTool Tests

    func testGetTool_ReturnsToolIfExists() {
        let tool = MCPTool(
            name: "finder",
            description: "Finds things",
            inputSchema: JSONSchema(),
            handler: { _ in .text("found") }
        )

        let server = SDKMCPServer(name: "test", tools: [tool])
        let found = server.getTool(named: "finder")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "finder")
    }

    func testGetTool_ReturnsNilIfNotExists() {
        let server = SDKMCPServer(name: "test", tools: [])
        let found = server.getTool(named: "nonexistent")

        XCTAssertNil(found)
    }

    // MARK: - MCPServerError Tests

    func testMCPServerError_Equatable() {
        let e1 = MCPServerError.toolNotFound("foo")
        let e2 = MCPServerError.toolNotFound("foo")
        let e3 = MCPServerError.toolNotFound("bar")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }

    func testMCPServerError_LocalizedDescription() {
        let error = MCPServerError.toolNotFound("myTool")

        XCTAssertTrue(error.localizedDescription.contains("myTool"))
    }

    // MARK: - MCPToolBuilder Tests

    func testCreateSDKMCPServer_WithBuilder() {
        let server = createSDKMCPServer(name: "builder-test", version: "2.0.0") {
            MCPTool(
                name: "tool1",
                description: "First",
                inputSchema: JSONSchema(),
                handler: { _ in .text("1") }
            )
            MCPTool(
                name: "tool2",
                description: "Second",
                inputSchema: JSONSchema(),
                handler: { _ in .text("2") }
            )
        }

        XCTAssertEqual(server.name, "builder-test")
        XCTAssertEqual(server.version, "2.0.0")
        XCTAssertEqual(server.toolCount, 2)
    }
}
