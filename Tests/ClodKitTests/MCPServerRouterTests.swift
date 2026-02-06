//
//  MCPServerRouterTests.swift
//  ClodKitTests
//
//  Unit tests for MCPServerRouter.
//

import XCTest
@testable import ClodKit

final class MCPServerRouterTests: XCTestCase {

    // MARK: - Helper Methods

    private func createTestServer() -> SDKMCPServer {
        SDKMCPServer(name: "test-server", version: "1.0.0", tools: [
            MCPTool(
                name: "echo",
                description: "Echoes input",
                inputSchema: JSONSchema(
                    properties: ["message": .string()],
                    required: ["message"]
                ),
                handler: { args in
                    let msg = args["message"] as? String ?? ""
                    return .text("Echo: \(msg)")
                }
            ),
            MCPTool(
                name: "failing",
                description: "Always fails",
                inputSchema: JSONSchema(),
                handler: { _ in throw MCPServerError.invalidArguments("Test error") }
            )
        ])
    }

    // MARK: - Server Management Tests

    func testRegisterServer() async {
        let router = MCPServerRouter()
        let server = createTestServer()

        await router.registerServer(server)

        let names = await router.getServerNames()
        XCTAssertTrue(names.contains("test-server"))
    }

    func testUnregisterServer() async {
        let router = MCPServerRouter()
        let server = createTestServer()

        await router.registerServer(server)
        await router.unregisterServer(name: "test-server")

        let hasServer = await router.hasServer(name: "test-server")
        XCTAssertFalse(hasServer)
    }

    func testHasServer() async {
        let router = MCPServerRouter()
        let server = createTestServer()

        let before = await router.hasServer(name: "test-server")
        XCTAssertFalse(before)

        await router.registerServer(server)

        let after = await router.hasServer(name: "test-server")
        XCTAssertTrue(after)
    }

    // MARK: - Initialize Tests

    func testRoute_Initialize() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(id: 1, method: "initialize")
        )

        let response = await router.route(request)

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertEqual(response.id, .int(1))
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)

        // Check result contains expected fields
        if case .object(let result) = response.result {
            XCTAssertNotNil(result["protocolVersion"])
            XCTAssertNotNil(result["capabilities"])
            XCTAssertNotNil(result["serverInfo"])
        } else {
            XCTFail("Expected object result")
        }
    }

    // MARK: - Notifications/Initialized Tests

    func testRoute_NotificationsInitialized() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.notification(method: "notifications/initialized")
        )

        let _ = await router.route(request)

        let isInit = await router.isInitialized(name: "test-server")
        XCTAssertTrue(isInit)
    }

    // MARK: - Tools/List Tests

    func testRoute_ToolsList() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(id: 2, method: "tools/list")
        )

        let response = await router.route(request)

        XCTAssertNil(response.error)

        if case .object(let result) = response.result,
           case .array(let tools) = result["tools"] {
            XCTAssertEqual(tools.count, 2)
        } else {
            XCTFail("Expected tools array in result")
        }
    }

    // MARK: - Tools/Call Tests

    func testRoute_ToolsCall_Success() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(
                id: 3,
                method: "tools/call",
                params: .object([
                    "name": .string("echo"),
                    "arguments": .object(["message": .string("hello")])
                ])
            )
        )

        let response = await router.route(request)

        XCTAssertNil(response.error)

        if case .object(let result) = response.result,
           case .array(let content) = result["content"],
           case .object(let firstContent) = content.first,
           case .string(let text) = firstContent["text"] {
            XCTAssertEqual(text, "Echo: hello")
        } else {
            XCTFail("Expected text content in result")
        }
    }

    func testRoute_ToolsCall_ToolNotFound() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(
                id: 4,
                method: "tools/call",
                params: .object([
                    "name": .string("nonexistent")
                ])
            )
        )

        let response = await router.route(request)

        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error?.message.contains("not found") == true)
    }

    func testRoute_ToolsCall_HandlerError() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(
                id: 5,
                method: "tools/call",
                params: .object([
                    "name": .string("failing")
                ])
            )
        )

        let response = await router.route(request)

        XCTAssertNotNil(response.error)
    }

    func testRoute_ToolsCall_MissingName() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(
                id: 6,
                method: "tools/call",
                params: .object([:])
            )
        )

        let response = await router.route(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.invalidParams)
    }

    // MARK: - Server Not Found Tests

    func testRoute_ServerNotFound() async {
        let router = MCPServerRouter()

        let request = MCPMessageRequest(
            serverName: "unknown-server",
            message: JSONRPCMessage.request(id: 7, method: "initialize")
        )

        let response = await router.route(request)

        XCTAssertNotNil(response.error)
        XCTAssertTrue(response.error?.message.contains("not found") == true)
    }

    // MARK: - Unknown Method Tests

    func testRoute_UnknownMethod() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage.request(id: 8, method: "unknown/method")
        )

        let response = await router.route(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.methodNotFound)
    }

    // MARK: - Missing Method Tests

    func testRoute_MissingMethod() async {
        let router = MCPServerRouter()
        await router.registerServer(createTestServer())

        let request = MCPMessageRequest(
            serverName: "test-server",
            message: JSONRPCMessage(id: .int(9))  // No method
        )

        let response = await router.route(request)

        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.invalidRequest)
    }
}

// MARK: - JSONValue Extension Tests

final class JSONValueExtensionTests: XCTestCase {

    func testFrom_Dictionary() {
        let dict: [String: Any] = [
            "string": "hello",
            "int": 42,
            "double": 3.14,
            "bool": true,
            "array": [1, 2, 3],
            "nested": ["key": "value"]
        ]

        let value = JSONValue.from(dict)

        if case .object(let obj) = value {
            XCTAssertEqual(obj["string"], .string("hello"))
            XCTAssertEqual(obj["int"], .int(42))
            XCTAssertEqual(obj["bool"], .bool(true))
        } else {
            XCTFail("Expected object")
        }
    }

    func testToAny_RoundTrip() {
        let original: [String: JSONValue] = [
            "name": .string("test"),
            "count": .int(5)
        ]
        let jsonValue = JSONValue.object(original)

        let anyValue = jsonValue.toAny()

        if let dict = anyValue as? [String: Any] {
            XCTAssertEqual(dict["name"] as? String, "test")
            XCTAssertEqual(dict["count"] as? Int, 5)
        } else {
            XCTFail("Expected dictionary")
        }
    }
}
