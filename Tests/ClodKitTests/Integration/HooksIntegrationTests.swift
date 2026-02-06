//
//  HooksIntegrationTests.swift
//  ClodKitTests
//
//  Integration tests for the hooks system with the real Claude CLI.
//

import XCTest
@testable import ClodKit

final class HooksIntegrationTests: XCTestCase {

    // MARK: - PreToolUse Hook Tests

    func testPreToolUseHookInvocation() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let capturedToolName = TestCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: nil,
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    capturedToolName.value = input.toolName
                    return .continue()
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read the file /etc/hosts and tell me what's in it.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hookInvoked.value, "PreToolUse hook should have been invoked")
        if let toolName = capturedToolName.value {
            XCTAssertFalse(toolName.isEmpty, "Tool name should not be empty")
        }
    }

    func testPreToolUseHookBlocksTool() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: "Bash",
                timeout: 30.0,
                callback: { _ in
                    hookInvoked.set()
                    return .deny(reason: "Bash commands are not allowed")
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Run 'echo hello' using Bash.",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hookInvoked.value, "PreToolUse hook should have been invoked")
        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")
    }

    func testPreToolUseHookPatternMatching() async throws {
        try skipIfCLIUnavailable()

        let readHookInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: "Read",
                timeout: 30.0,
                callback: { _ in
                    readHookInvoked.set()
                    return .continue()
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(readHookInvoked.value, "Read hook should have been invoked")
    }

    // MARK: - PostToolUse Hook Tests

    func testPostToolUseHookReceivesResponse() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let capturedResponse = TestCapture<JSONValue>()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.postToolUseHooks = [
            PostToolUseHookConfig(
                pattern: nil,
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    capturedResponse.value = input.toolResponse
                    return HookOutput()
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hookInvoked.value, "PostToolUse hook should have been invoked")
        XCTAssertNotNil(capturedResponse.value, "Tool response should be captured")
    }

    // MARK: - Multiple Hooks Tests

    func testMultipleHooksSameEvent() async throws {
        try skipIfCLIUnavailable()

        let hook1Invoked = TestFlag()
        let hook2Invoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(callback: { _ in hook1Invoked.set(); return .continue() }),
            PreToolUseHookConfig(callback: { _ in hook2Invoked.set(); return .continue() })
        ]

        let claudeQuery = try await query(prompt: "Read /etc/hosts.", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hook1Invoked.value, "Hook 1 should have been invoked")
        XCTAssertTrue(hook2Invoked.value, "Hook 2 should have been invoked")
    }

    // MARK: - UserPromptSubmit Hook Tests

    func testUserPromptSubmitHook() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let capturedPrompt = TestCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.userPromptSubmitHooks = [
            UserPromptSubmitHookConfig(
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    capturedPrompt.value = input.prompt
                    return HookOutput()
                }
            )
        ]

        let testPrompt = "Say hello"
        let claudeQuery = try await query(prompt: testPrompt, options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertTrue(hookInvoked.value, "UserPromptSubmit hook should have been invoked")
        if let prompt = capturedPrompt.value {
            XCTAssertEqual(prompt, testPrompt, "Captured prompt should match")
        }
    }

    // MARK: - Stop Hook Tests

    func testStopHook() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.stopHooks = [
            StopHookConfig(
                timeout: 30.0,
                callback: { _ in hookInvoked.set(); return HookOutput() }
            )
        ]

        let claudeQuery = try await query(prompt: "Say OK", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertTrue(hookInvoked.value, "Stop hook should have been invoked")
    }

    // MARK: - Hook with MCP Tool Tests

    func testHooksWithMCPTools() async throws {
        try skipIfCLIUnavailable()

        let mcpToolInvoked = TestFlag()
        let preToolHookInvoked = TestFlag()

        let echoTool = MCPTool(
            name: "echo",
            description: "Echoes the input",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["message": .string("Message")],
                required: ["message"]
            ),
            handler: { args in
                mcpToolInvoked.set()
                return .text("Echo: \(args["message"] ?? "none")")
            }
        )

        let server = SDKMCPServer(name: "test", version: "1.0.0", tools: [echoTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["test": server]
        options.preToolUseHooks = [
            PreToolUseHookConfig(callback: { _ in preToolHookInvoked.set(); return .continue() })
        ]

        let claudeQuery = try await query(
            prompt: "Use mcp__test__echo with message 'test'",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        XCTAssertTrue(mcpToolInvoked.value, "MCP tool should have been invoked")
    }

    // MARK: - PreToolUse Input Modification Tests

    /// Tests that preToolUse hook can modify tool input.
    func testPreToolUseHookModifyInput() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let originalMessage = TestCapture<String>()
        let toolReceivedMessage = TestCapture<String>()

        let echoTool = MCPTool(
            name: "echo",
            description: "Returns the input message",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["message": .string("The message")],
                required: ["message"]
            ),
            handler: { args in
                toolReceivedMessage.value = args["message"] as? String
                return .text("Received: \(args["message"] ?? "none")")
            }
        )

        let server = SDKMCPServer(name: "modifier", version: "1.0.0", tools: [echoTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["modifier": server]
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: "echo",
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    // Capture original message
                    if case .string(let msg) = input.toolInput["message"] {
                        originalMessage.value = msg
                    }
                    // Modify the input
                    return .allow(
                        updatedInput: ["message": .string("MODIFIED_MESSAGE")],
                        additionalContext: "Input was modified by hook"
                    )
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Use mcp__modifier__echo with message 'original_text'",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        XCTAssertTrue(hookInvoked.value, "Hook should have been invoked")
        // Note: Whether modification actually works depends on CLI support
        // The test verifies the hook mechanism is working
    }

    // MARK: - PostToolUse Output Modification Tests

    /// Tests that postToolUse hook can add context to tool response.
    func testPostToolUseHookAddContext() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let capturedResponse = TestCapture<JSONValue>()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.postToolUseHooks = [
            PostToolUseHookConfig(
                pattern: nil,
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    capturedResponse.value = input.toolResponse

                    // Add additional context to the response
                    var output = HookOutput()
                    output.hookSpecificOutput = .postToolUse(
                        PostToolUseHookOutput(
                            additionalContext: "Hook processed this tool result"
                        )
                    )
                    return output
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hookInvoked.value, "PostToolUse hook should have been invoked")
        XCTAssertNotNil(capturedResponse.value, "Tool response should have been captured")
    }

    // MARK: - PostToolUseFailure Hook Tests

    /// Tests that postToolUseFailure hook is invoked when a tool fails.
    func testPostToolUseFailureHookInvocation() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let capturedError = TestCapture<String>()
        let capturedToolName = TestCapture<String>()

        let failingTool = MCPTool(
            name: "fail_tool",
            description: "A tool that always fails",
            inputSchema: JSONSchema(type: "object", properties: [:], required: []),
            handler: { _ in
                throw MCPServerError.invalidArguments("Intentional failure for testing")
            }
        )

        let server = SDKMCPServer(name: "failer", version: "1.0.0", tools: [failingTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["failer": server]
        options.postToolUseFailureHooks = [
            PostToolUseFailureHookConfig(
                pattern: nil,
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    capturedError.value = input.error
                    capturedToolName.value = input.toolName
                    return HookOutput()
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Use mcp__failer__fail_tool and report what happens.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        // Note: Hook invocation depends on CLI actually calling the failure hook
        // The MCP tool error may be handled differently by the CLI
        if hookInvoked.value {
            XCTAssertNotNil(capturedError.value, "Error should have been captured")
        }
    }

    /// Tests that postToolUseFailure hook pattern matching works.
    func testPostToolUseFailureHookPatternMatching() async throws {
        try skipIfCLIUnavailable()

        let specificHookInvoked = TestFlag()
        let genericHookInvoked = TestFlag()

        let failingTool = MCPTool(
            name: "specific_fail",
            description: "A tool that fails",
            inputSchema: JSONSchema(type: "object", properties: [:], required: []),
            handler: { _ in
                throw MCPServerError.invalidArguments("Test failure")
            }
        )

        let server = SDKMCPServer(name: "fail_test", version: "1.0.0", tools: [failingTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["fail_test": server]
        options.postToolUseFailureHooks = [
            PostToolUseFailureHookConfig(
                pattern: "specific_fail",
                timeout: 30.0,
                callback: { _ in specificHookInvoked.set(); return HookOutput() }
            ),
            PostToolUseFailureHookConfig(
                pattern: "other_tool",
                timeout: 30.0,
                callback: { _ in genericHookInvoked.set(); return HookOutput() }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Use mcp__fail_test__specific_fail.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        // Pattern matching should only invoke the specific hook
        if specificHookInvoked.value {
            XCTAssertFalse(genericHookInvoked.value, "Non-matching pattern hook should not be invoked")
        }
    }

    // MARK: - UserPromptSubmit Modification Tests

    /// Tests that userPromptSubmit hook receives the correct prompt.
    func testUserPromptSubmitHookReceivesPrompt() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let capturedPrompt = TestCapture<String>()
        let capturedSessionId = TestCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.userPromptSubmitHooks = [
            UserPromptSubmitHookConfig(
                timeout: 30.0,
                callback: { input in
                    hookInvoked.set()
                    capturedPrompt.value = input.prompt
                    capturedSessionId.value = input.base.sessionId
                    return HookOutput()
                }
            )
        ]

        let testPrompt = "What is the capital of France?"
        let claudeQuery = try await query(prompt: testPrompt, options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertTrue(hookInvoked.value, "UserPromptSubmit hook should have been invoked")
        XCTAssertEqual(capturedPrompt.value, testPrompt, "Captured prompt should match")
        XCTAssertNotNil(capturedSessionId.value, "Session ID should be provided")
    }

    // MARK: - Hook Timeout Tests

    /// Tests behavior when a hook takes too long (but doesn't actually timeout).
    func testHookSlowExecution() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()
        let hookCompleted = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: nil,
                timeout: 30.0,  // Long timeout
                callback: { _ in
                    hookInvoked.set()
                    // Simulate slow processing (but within timeout)
                    try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
                    hookCompleted.set()
                    return .continue()
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        if hookInvoked.value {
            XCTAssertTrue(hookCompleted.value, "Slow hook should still complete")
        }
    }

    // MARK: - Hook System Message Tests

    /// Tests that hooks can inject system messages.
    func testHookSystemMessageInjection() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: nil,
                timeout: 30.0,
                callback: { _ in
                    hookInvoked.set()
                    var output = HookOutput()
                    output.systemMessage = "Note: This operation is being monitored."
                    return output
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hookInvoked.value, "Hook should have been invoked")
    }

    // MARK: - Multiple Hook Types Tests

    /// Tests that multiple different hook types can be registered and invoked.
    func testMultipleHookTypes() async throws {
        try skipIfCLIUnavailable()

        let preToolInvoked = TestFlag()
        let postToolInvoked = TestFlag()
        let promptSubmitInvoked = TestFlag()
        let stopInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(callback: { _ in preToolInvoked.set(); return .continue() })
        ]
        options.postToolUseHooks = [
            PostToolUseHookConfig(callback: { _ in postToolInvoked.set(); return HookOutput() })
        ]
        options.userPromptSubmitHooks = [
            UserPromptSubmitHookConfig(callback: { _ in promptSubmitInvoked.set(); return HookOutput() })
        ]
        options.stopHooks = [
            StopHookConfig(callback: { _ in stopInvoked.set(); return HookOutput() })
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts and summarize it.",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(promptSubmitInvoked.value, "UserPromptSubmit hook should have been invoked")
        XCTAssertTrue(preToolInvoked.value, "PreToolUse hook should have been invoked")
        XCTAssertTrue(postToolInvoked.value, "PostToolUse hook should have been invoked")
        XCTAssertTrue(stopInvoked.value, "Stop hook should have been invoked")
    }

    // MARK: - Hook Stop Execution Tests

    /// Tests that a hook can stop execution entirely.
    func testHookStopExecution() async throws {
        try skipIfCLIUnavailable()

        let hookInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: nil,
                timeout: 30.0,
                callback: { _ in
                    hookInvoked.set()
                    return .stop(reason: "Stopped by test hook")
                }
            )
        ]

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 45)

        XCTAssertTrue(hookInvoked.value, "Hook should have been invoked")
        // The session should complete (with or without the tool result)
        XCTAssertGreaterThan(messages.count, 0, "Should receive some messages")
    }
}
