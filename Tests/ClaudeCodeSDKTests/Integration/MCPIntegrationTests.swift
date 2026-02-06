//
//  MCPIntegrationTests.swift
//  ClaudeCodeSDKTests
//
//  Integration tests for SDK MCP server functionality with the real Claude CLI.
//  Tests verify that in-process MCP tools are properly registered, discovered,
//  and invoked by the CLI.
//

import XCTest
@testable import ClaudeCodeSDK

final class MCPIntegrationTests: XCTestCase {

    // MARK: - SDK MCP Tool Registration

    /// Verifies SDK MCP server tools are registered with the CLI.
    /// The tools should appear in the session initialization.
    func testSDKMCPToolRegistration() async throws {
        try skipIfCLIUnavailable()

        let echoServer = SDKMCPServer(
            name: "test_server",
            version: "1.0.0",
            tools: [TestTools.echoTool()]
        )

        var options = defaultIntegrationOptions()
        options.sdkMcpServers = ["test_server": echoServer]

        let claudeQuery = try await query(prompt: "What tools do you have available? Just list tool names.", options: options)
        let receivedMessages = try await collectMessages(from: claudeQuery, timeout: 30)

        // Should have received at least init message
        XCTAssertGreaterThan(receivedMessages.count, 0, "Should receive messages")

        // Check for system init message which contains tool info
        let hasInit = receivedMessages.contains { $0.isSystemInit }
        XCTAssertTrue(hasInit, "Should receive system init message")
    }

    /// Verifies SDK MCP tools can be invoked by Claude.
    /// Registers an echo tool and asks Claude to use it.
    func testSDKMCPToolInvocation() async throws {
        try skipIfCLIUnavailable()

        let toolInvoked = TestFlag()
        let capturedMessage = TestCapture<String>()

        let echoTool = MCPTool(
            name: "echo",
            description: "Returns the input message back as output. Use this tool to echo messages.",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "message": .string("The message to echo back")
                ],
                required: ["message"]
            ),
            handler: { args in
                toolInvoked.set()
                capturedMessage.value = args["message"] as? String
                let message = args["message"] as? String ?? "no message"
                return .text("Echo: \(message)")
            }
        )

        let echoServer = SDKMCPServer(
            name: "test_server",
            version: "1.0.0",
            tools: [echoTool]
        )

        var options = QueryOptions()
        options.maxTurns = 3  // Allow multiple turns for tool use
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["test_server": echoServer]

        let claudeQuery = try await query(
            prompt: "Use the mcp__test_server__echo tool to echo the message 'Hello from test'. Just use the tool and report what it returned.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        // Verify tool was invoked
        XCTAssertTrue(toolInvoked.value, "Echo tool should have been invoked")

        // Verify arguments were passed
        if let message = capturedMessage.value {
            XCTAssertEqual(message, "Hello from test", "Message argument should match")
        }
    }

    /// Verifies errors in SDK tools are handled correctly.
    /// Registers a tool that throws and verifies error is communicated.
    func testSDKMCPToolError() async throws {
        try skipIfCLIUnavailable()

        let toolInvoked = TestFlag()

        let failingTool = MCPTool(
            name: "always_fails",
            description: "A tool that always fails with an error. Use this to test error handling.",
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: []
            ),
            handler: { _ in
                toolInvoked.set()
                throw MCPServerError.invalidArguments("This tool always fails intentionally")
            }
        )

        let server = SDKMCPServer(
            name: "test_server",
            version: "1.0.0",
            tools: [failingTool]
        )

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["test_server": server]

        let claudeQuery = try await query(
            prompt: "Use the mcp__test_server__always_fails tool and report what happens.",
            options: options
        )
        let receivedMessages = try await collectMessages(from: claudeQuery, timeout: 45)

        // Tool should have been invoked (it will fail)
        XCTAssertTrue(toolInvoked.value, "Failing tool should have been invoked")

        // Session should complete (error is handled gracefully)
        XCTAssertGreaterThan(receivedMessages.count, 0, "Should receive messages even after tool error")
    }

    /// Verifies multiple SDK MCP servers can coexist.
    /// Registers two servers with different tools and verifies both work.
    func testMultipleMCPServers() async throws {
        try skipIfCLIUnavailable()

        let echoInvoked = TestFlag()
        let addInvoked = TestFlag()

        let echoTool = MCPTool(
            name: "echo",
            description: "Echoes the input message",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["message": .string("Message to echo")],
                required: ["message"]
            ),
            handler: { args in
                echoInvoked.set()
                return .text("Echo: \(args["message"] ?? "none")")
            }
        )

        let addTool = MCPTool(
            name: "add",
            description: "Adds two numbers",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "a": .number("First number"),
                    "b": .number("Second number")
                ],
                required: ["a", "b"]
            ),
            handler: { args in
                addInvoked.set()
                let a = (args["a"] as? Double) ?? 0
                let b = (args["b"] as? Double) ?? 0
                return .text("Sum: \(a + b)")
            }
        )

        let echoServer = SDKMCPServer(name: "echo_server", version: "1.0.0", tools: [echoTool])
        let mathServer = SDKMCPServer(name: "math_server", version: "1.0.0", tools: [addTool])

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = [
            "echo_server": echoServer,
            "math_server": mathServer
        ]

        let claudeQuery = try await query(
            prompt: "First use mcp__echo_server__echo with message 'test', then use mcp__math_server__add to add 2 and 3. Report both results.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        // Both tools should have been invoked
        XCTAssertTrue(echoInvoked.value, "Echo tool should have been invoked")
        XCTAssertTrue(addInvoked.value, "Add tool should have been invoked")
    }

    /// Verifies MCP tool with complex input schema works correctly.
    func testMCPToolWithComplexSchema() async throws {
        try skipIfCLIUnavailable()

        let toolInvoked = TestFlag()
        let capturedName = TestCapture<String>()

        let complexTool = MCPTool(
            name: "process_data",
            description: "Processes structured data with multiple fields",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "name": .string("Name of the item"),
                    "count": .integer("Number of items"),
                    "enabled": .boolean("Whether enabled"),
                    "tags": .array(of: .string(), description: "List of tags")
                ],
                required: ["name", "count"]
            ),
            handler: { args in
                toolInvoked.set()
                capturedName.value = args["name"] as? String
                let name = args["name"] as? String ?? "unknown"
                let count = args["count"] as? Int ?? 0
                return .text("Processed \(count) items named '\(name)'")
            }
        )

        let server = SDKMCPServer(name: "data_server", version: "1.0.0", tools: [complexTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["data_server": server]

        let claudeQuery = try await query(
            prompt: "Use mcp__data_server__process_data with name='widget' and count=5. Report the result.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(toolInvoked.value, "Complex tool should have been invoked")

        if let name = capturedName.value {
            XCTAssertEqual(name, "widget")
        }
    }

    /// Verifies MCP tool result with multiple content items.
    func testMCPToolMultipleContentResult() async throws {
        try skipIfCLIUnavailable()

        let toolInvoked = TestFlag()

        let multiContentTool = MCPTool(
            name: "multi_result",
            description: "Returns multiple content items",
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: []
            ),
            handler: { _ in
                toolInvoked.set()
                return MCPToolResult(content: [
                    .text("First result"),
                    .text("Second result"),
                    .text("Third result")
                ])
            }
        )

        let server = SDKMCPServer(name: "multi_server", version: "1.0.0", tools: [multiContentTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["multi_server": server]

        let claudeQuery = try await query(
            prompt: "Use mcp__multi_server__multi_result and report all the results you receive.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(toolInvoked.value, "Multi-content tool should have been invoked")
    }
}
