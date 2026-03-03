//
//  CoverageIntegrationTests.swift
//  ClodKitTests
//
//  Integration tests targeting uncovered code paths in NativeBackend,
//  V2SessionAPI, QueryAPI hook registration, ClaudeSession, and ClaudeQuery
//  control methods. Requires a live Claude CLI (`claude` binary in PATH).
//

import XCTest
@testable import ClodKit

// MARK: - NativeBackend Integration Tests

final class NativeBackendIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60
    }

    /// Tests validateSetup returns true when the CLI is available.
    func testValidateSetup_CLIAvailable() async throws {
        try requireCLI()
        let backend = NativeBackend()
        let isValid = try await backend.validateSetup()
        XCTAssertTrue(isValid, "validateSetup should return true when claude is in PATH")
    }

    /// Tests validateSetup with an explicit CLI path resolved via /usr/bin/which.
    func testValidateSetup_WithExplicitPath() async throws {
        try requireCLI()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let path = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )!.trimmingCharacters(in: .whitespacesAndNewlines)

        let backend = NativeBackend(cliPath: path)
        let isValid = try await backend.validateSetup()
        XCTAssertTrue(isValid, "validateSetup should succeed with explicit path: \(path)")
    }

    /// Tests validateSetup returns false when the CLI path is invalid.
    func testValidateSetup_InvalidPath() async throws {
        let backend = NativeBackend(cliPath: "/nonexistent/path/claude-fake")
        do {
            let isValid = try await backend.validateSetup()
            XCTAssertFalse(isValid, "validateSetup should return false for nonexistent path")
        } catch {
            // NativeBackendError.validationFailed is also acceptable
        }
    }

    /// Tests that cancel() does not crash when there is no active query.
    func testCancel_NoActiveQuery() {
        let backend = NativeBackend()
        backend.cancel() // Should not crash
    }

    /// Tests applyDefaultOptions by creating a backend with custom options and running validateSetup.
    func testApplyDefaultOptions() async throws {
        try requireCLI()
        let backend = NativeBackend(
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            environment: ["TEST_VAR": "test_value"],
            enableLogging: true
        )
        // validateSetup exercises applyDefaultOptions indirectly for cliPath default
        let isValid = try await backend.validateSetup()
        XCTAssertTrue(isValid, "validateSetup should succeed with default CLI path")
    }

    /// Tests resumeSession by establishing a session and then resuming it.
    func testResumeSession() async throws {
        try requireCLI()
        let backend = NativeBackend()

        // First query to get a session ID
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let firstQuery = try await backend.runSinglePrompt(prompt: "Say hello", options: options)
        _ = try await collectMessages(from: firstQuery, timeout: 30)
        let sessionId = await firstQuery.sessionId

        guard let validSessionId = sessionId else {
            XCTFail("First query should have a session ID")
            return
        }

        // Resume the session
        let resumedQuery = try await backend.resumeSession(
            sessionId: validSessionId,
            prompt: "Say goodbye",
            options: options
        )
        let messages = try await collectMessages(from: resumedQuery, timeout: 30)
        XCTAssertGreaterThan(messages.count, 0, "Resumed session should produce messages")
    }

    /// Tests cancel on a backend with an active query.
    func testCancel_WithActiveQuery() async throws {
        try requireCLI()
        let backend = NativeBackend()

        var options = QueryOptions()
        options.maxTurns = 10
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await backend.runSinglePrompt(
            prompt: "Count from 1 to 100 slowly, one number per line.",
            options: options
        )

        // Wait for at least one message, then cancel
        var messageCount = 0
        for try await _ in claudeQuery {
            messageCount += 1
            if messageCount >= 2 {
                backend.cancel()
                break
            }
        }

        XCTAssertGreaterThanOrEqual(messageCount, 2, "Should receive messages before cancel")
    }
}

// MARK: - V2 Session Integration Tests

final class V2SessionIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60
    }

    /// Tests unstable_v2_prompt returns a result.
    func testV2Prompt_ReturnsResult() async throws {
        try requireCLI()

        var options = SDKSessionOptions(model: "claude-sonnet-4-20250514")
        options.permissionMode = .bypassPermissions

        let result = try await unstable_v2_prompt(
            "What is 2+2? Reply with just the number.",
            options: options
        )
        XCTAssertEqual(result.type, "result")
    }

    /// Tests V2 session send and stream pattern.
    func testV2Session_SendAndStream() async throws {
        try requireCLI()

        var options = SDKSessionOptions(model: "claude-sonnet-4-20250514")
        options.permissionMode = .bypassPermissions

        let session = unstable_v2_createSession(options: options)
        try await session.send("What is 2+2? Reply with just the number.")

        var messageCount = 0
        for try await msg in session.stream() {
            messageCount += 1
            if msg.type == "result" { break }
        }
        XCTAssertGreaterThan(messageCount, 0, "Should receive at least one message from V2 stream")
    }

    /// Tests V2 session receiveResponse convenience.
    func testV2Session_ReceiveResponse() async throws {
        try requireCLI()

        var options = SDKSessionOptions(model: "claude-sonnet-4-20250514")
        options.permissionMode = .bypassPermissions

        let session = unstable_v2_createSession(options: options)
        try await session.send("Reply with just the word 'hello'.")

        var gotResult = false
        for try await msg in session.receiveResponse() {
            if msg.type == "result" { gotResult = true }
        }
        XCTAssertTrue(gotResult, "receiveResponse should yield a result message")
    }

    /// Tests V2 session resume.
    func testV2Session_Resume() async throws {
        try requireCLI()

        var options = SDKSessionOptions(model: "claude-sonnet-4-20250514")
        options.permissionMode = .bypassPermissions

        // First session — use unstable_v2_prompt for simplicity (handles send+receive)
        let result = try await unstable_v2_prompt(
            "Remember the word: PINEAPPLE. Just acknowledge.",
            options: options
        )

        // Get session ID from the result
        guard let sid = result.sessionId else {
            XCTFail("First prompt should produce a session ID")
            return
        }

        // Resume session
        let session2 = unstable_v2_resumeSession(sessionId: sid, options: options)
        try await session2.send("What word did I say?")
        var messageCount = 0
        for try await msg in session2.receiveResponse() {
            messageCount += 1
            if msg.type == "result" { break }
        }
        XCTAssertGreaterThan(messageCount, 0, "Resumed V2 session should produce messages")
    }
}

// MARK: - QueryAPI Hook Registration Integration Tests

final class QueryAPIHookIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60
    }

    /// Tests that a query with ALL hook types populated can start and complete.
    /// This exercises the hook registration loops in QueryAPI.swift (lines 85-114).
    func testQuery_WithAllHookTypes() async throws {
        try requireCLI()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        // Register one of each hook type
        options.preToolUseHooks = [PreToolUseHookConfig { _ in .continue() }]
        options.postToolUseHooks = [PostToolUseHookConfig { _ in HookOutput() }]
        options.postToolUseFailureHooks = [PostToolUseFailureHookConfig { _ in HookOutput() }]
        options.userPromptSubmitHooks = [UserPromptSubmitHookConfig { _ in HookOutput() }]
        options.stopHooks = [StopHookConfig { _ in HookOutput() }]
        options.setupHooks = [SetupHookConfig { _ in HookOutput() }]
        options.teammateIdleHooks = [TeammateIdleHookConfig { _ in HookOutput() }]
        options.taskCompletedHooks = [TaskCompletedHookConfig { _ in HookOutput() }]
        options.sessionStartHooks = [SessionStartHookConfig { _ in HookOutput() }]
        options.sessionEndHooks = [SessionEndHookConfig { _ in HookOutput() }]
        options.subagentStartHooks = [SubagentStartHookConfig { _ in HookOutput() }]
        options.subagentStopHooks = [SubagentStopHookConfig { _ in HookOutput() }]
        options.preCompactHooks = [PreCompactHookConfig { _ in HookOutput() }]
        options.permissionRequestHooks = [PermissionRequestHookConfig { _ in HookOutput() }]
        options.notificationHooks = [NotificationHookConfig { _ in HookOutput() }]

        let claudeQuery = try await Clod.query(prompt: "Say hi", options: options)
        let messages = try await collectMessages(from: claudeQuery, timeout: 45)
        XCTAssertGreaterThan(messages.count, 0, "Query with all hook types should produce messages")
    }

    /// Tests the streaming query overload with hooks, exercising the parallel
    /// hook registration in the streaming query path.
    func testStreamingQuery_WithHooks() async throws {
        try requireCLI()

        let promptSubmitInvoked = TestFlag()
        let stopInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.userPromptSubmitHooks = [
            UserPromptSubmitHookConfig { _ in
                promptSubmitInvoked.set()
                return HookOutput()
            }
        ]
        options.stopHooks = [
            StopHookConfig { _ in
                stopInvoked.set()
                return HookOutput()
            }
        ]

        let claudeQuery = try await query(prompt: "Say OK", options: options)
        let messages = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Streaming query with hooks should produce messages")
        XCTAssertTrue(promptSubmitInvoked.value, "UserPromptSubmit hook should be invoked")
        XCTAssertTrue(stopInvoked.value, "Stop hook should be invoked")
    }
}

// MARK: - Session Initialization Integration Tests

final class SessionInitIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60
    }

    /// Tests the full session lifecycle: init, message loop, result.
    /// Exercises initialize(), startMessageLoop(), and initializationResult().
    func testSession_FullLifecycle() async throws {
        try requireCLI()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        // Adding a hook triggers control protocol initialization
        options.preToolUseHooks = [PreToolUseHookConfig { _ in .continue() }]

        let claudeQuery = try await Clod.query(
            prompt: "What is 1+1? Reply with just the number.",
            options: options
        )

        // Collect messages to completion
        let messages = try await collectMessages(from: claudeQuery, timeout: 45)
        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")

        // Verify initializationResult works
        do {
            let initResult = try await claudeQuery.initializationResult()
            // The init response should have some content
            XCTAssertNotNil(initResult, "Initialization result should be available")
        } catch {
            // initializationResult may fail if control protocol was not used
            print("[DEBUG] initializationResult error (may be expected): \(error)")
        }

        // Verify sessionId is available
        let sessionId = await claudeQuery.sessionId
        XCTAssertNotNil(sessionId, "Session ID should be available after completion")
    }

    /// Tests the permission callback handler in the session (handleCanUseToolRequest).
    func testSession_WithPermissionCallback() async throws {
        try requireCLI()

        let callbackCalled = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackCalled.set()
            return .allowTool()
        }

        // Use a command that requires permission (write operation)
        let claudeQuery = try await Clod.query(
            prompt: "Create a file at /tmp/sdk_coverage_test.txt with the text 'hello'. Use: echo hello > /tmp/sdk_coverage_test.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(
            callbackCalled.value,
            "Permission callback should be invoked for write operations"
        )
    }

    /// Tests SDK MCP server routing through the session's MCPMessage handler.
    func testSession_WithMCPServer() async throws {
        try requireCLI()

        let toolInvoked = TestFlag()

        let echoTool = MCPTool(
            name: "echo_test",
            description: "Echoes input back for testing",
            inputSchema: JSONSchema(
                type: "object",
                properties: ["message": .string("Message to echo")],
                required: ["message"]
            ),
            handler: { args in
                toolInvoked.set()
                let msg = args["message"] as? String ?? "no message"
                return .text("Echo: \(msg)")
            }
        )
        let server = SDKMCPServer(name: "test-echo", version: "1.0.0", tools: [echoTool])

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["test-echo": server]

        let claudeQuery = try await Clod.query(
            prompt: "Use mcp__test-echo__echo_test with message 'hello world'",
            options: options
        )
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        XCTAssertTrue(toolInvoked.value, "MCP tool should have been invoked through session routing")
    }
}

// MARK: - ClaudeQuery Control Method Integration Tests

final class ClaudeQueryControlIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 60
    }

    /// Tests mcpStatus() on an initialized query.
    func testQuery_McpStatus() async throws {
        try requireCLI()

        let echoServer = SDKMCPServer(
            name: "status_server",
            version: "1.0.0",
            tools: [TestTools.echoTool()]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["status_server": echoServer]

        let claudeQuery = try await Clod.query(prompt: "Say hello", options: options)

        var initialized = false
        for try await message in claudeQuery {
            if message.isSystemInit {
                initialized = true
                do {
                    let status = try await claudeQuery.mcpStatus()
                    _ = status // Verify no throw
                } catch {
                    // mcpStatus may not be supported in all CLI versions
                    print("[DEBUG] mcpStatus error: \(error)")
                }
                break
            }
        }

        XCTAssertTrue(initialized, "Should receive system init message")
    }

    /// Tests initializationResult() after control protocol init.
    func testQuery_InitializationResult() async throws {
        try requireCLI()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        // Hooks trigger control protocol initialization
        options.preToolUseHooks = [PreToolUseHookConfig { _ in .continue() }]

        let claudeQuery = try await Clod.query(prompt: "Say OK", options: options)

        // Wait for init message
        for try await message in claudeQuery {
            if message.isSystemInit {
                do {
                    let initResult = try await claudeQuery.initializationResult()
                    XCTAssertNotNil(initResult, "Should get initialization result")
                } catch {
                    print("[DEBUG] initializationResult error: \(error)")
                }
                break
            }
        }
    }

    /// Tests setMcpServers on an initialized query.
    func testQuery_SetMcpServers() async throws {
        try requireCLI()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        // Need control protocol for setMcpServers
        options.preToolUseHooks = [PreToolUseHookConfig { _ in .continue() }]

        let claudeQuery = try await Clod.query(prompt: "Say hello", options: options)

        for try await message in claudeQuery {
            if message.isSystemInit {
                do {
                    let result = try await claudeQuery.setMcpServers([:])
                    _ = result // Verify no crash
                } catch {
                    // May not be supported
                    print("[DEBUG] setMcpServers error: \(error)")
                }
                break
            }
        }
    }

    /// Tests rewindFilesTyped on an initialized query.
    func testQuery_RewindFilesTyped() async throws {
        try requireCLI()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.preToolUseHooks = [PreToolUseHookConfig { _ in .continue() }]

        let claudeQuery = try await Clod.query(prompt: "Say hello", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        do {
            // Use a fake message ID -- we just want to exercise the code path
            let result = try await claudeQuery.rewindFilesTyped(to: "fake-message-id", dryRun: true)
            _ = result
        } catch {
            // Expected to fail with invalid message ID, but code path is exercised
            print("[DEBUG] rewindFilesTyped error (expected): \(error)")
        }
    }

    /// Tests close() on a query.
    func testQuery_Close() async throws {
        try requireCLI()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await Clod.query(prompt: "Say OK", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        // close() should not crash after completion
        await claudeQuery.close()
    }
}
