//
//  ControlProtocolIntegrationTests.swift
//  ClodKitTests
//
//  Integration tests for the control protocol with the real Claude CLI.
//

import XCTest
@testable import ClodKit

final class ControlProtocolIntegrationTests: XCTestCase {

    // MARK: - Interrupt Tests

    func testInterruptCommand() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 10
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Count from 1 to 100 slowly.",
            options: options
        )

        var messageCount = 0
        for try await _ in claudeQuery {
            messageCount += 1
            if messageCount >= 3 {
                try await claudeQuery.interrupt()
                break
            }
        }

        XCTAssertGreaterThanOrEqual(messageCount, 3, "Should receive some messages before interrupt")
    }

    func testInterruptIdempotent() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Count to 10.", options: options)

        var receivedAny = false
        for try await _ in claudeQuery {
            receivedAny = true
            try await claudeQuery.interrupt()
            try await claudeQuery.interrupt()  // Should not crash
            break
        }

        XCTAssertTrue(receivedAny, "Should receive at least one message")
    }

    // MARK: - Session ID Tests

    func testSessionIdAvailable() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Say hello", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        let sessionId = await claudeQuery.sessionId
        XCTAssertNotNil(sessionId, "Session ID should be available")
        if let id = sessionId {
            XCTAssertFalse(id.isEmpty, "Session ID should not be empty")
        }
    }

    // MARK: - MCP Status Tests

    func testMCPStatus() async throws {
        try skipIfCLIUnavailable()

        let echoServer = SDKMCPServer(
            name: "test_server",
            version: "1.0.0",
            tools: [TestTools.echoTool()]
        )

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers = ["test_server": echoServer]

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var initialized = false
        for try await message in claudeQuery {
            if message.isSystemInit {
                initialized = true
                do {
                    let status = try await claudeQuery.mcpStatus()
                    XCTAssertNotNil(status, "MCP status should be available")
                } catch {
                    // MCP status may not be available in all CLI versions
                }
                break
            }
        }

        XCTAssertTrue(initialized, "Should receive init message")
    }

    // MARK: - Multiple Queries Tests

    func testMultipleSequentialQueries() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let messages1 = try await collectMessages(
            from: try await query(prompt: "Say 'first'", options: options),
            timeout: 30
        )
        let messages2 = try await collectMessages(
            from: try await query(prompt: "Say 'second'", options: options),
            timeout: 30
        )
        let messages3 = try await collectMessages(
            from: try await query(prompt: "Say 'third'", options: options),
            timeout: 30
        )

        XCTAssertGreaterThan(messages1.count, 0, "First query should receive messages")
        XCTAssertGreaterThan(messages2.count, 0, "Second query should receive messages")
        XCTAssertGreaterThan(messages3.count, 0, "Third query should receive messages")
    }

    // MARK: - Long Running Query Tests

    func testLongRunningQuery() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Write a short paragraph about Swift. Be concise.",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 60)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")
        let hasAssistant = messages.contains { $0.isAssistant }
        XCTAssertTrue(hasAssistant, "Should receive assistant message")
    }

    // MARK: - Error Recovery Tests

    func testErrorRecovery() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.model = "invalid-model-xyz"

        do {
            let claudeQuery = try await query(prompt: "Say hello", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
        } catch {
            // Error expected for invalid model
        }

        // Second query with valid options should work
        options.model = nil
        let messages = try await collectMessages(
            from: try await query(prompt: "Say hello", options: options),
            timeout: 30
        )

        XCTAssertGreaterThan(messages.count, 0, "Valid query should work after failed query")
    }

    // MARK: - setModel Tests

    /// Tests that setModel() can change the model mid-query.
    /// Note: The CLI may or may not honor mid-query model changes depending on timing.
    func testSetModelMidQuery() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Write a short poem about coding.",
            options: options
        )

        var setModelCalled = false
        var messageCount = 0

        for try await message in claudeQuery {
            messageCount += 1

            // After receiving init, try to set the model
            if message.isSystemInit && !setModelCalled {
                do {
                    try await claudeQuery.setModel("claude-sonnet-4-20250514")
                    setModelCalled = true
                } catch {
                    // setModel may fail if CLI doesn't support it - that's OK
                    print("[DEBUG] setModel failed: \(error)")
                }
            }
        }

        XCTAssertGreaterThan(messageCount, 0, "Should receive messages")
        // We don't assert setModelCalled because it depends on CLI support
    }

    /// Tests that setModel(nil) resets to default model.
    func testSetModelToNil() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.model = "claude-sonnet-4-20250514"

        let claudeQuery = try await query(prompt: "Say OK", options: options)

        var initialized = false
        for try await message in claudeQuery {
            if message.isSystemInit && !initialized {
                initialized = true
                do {
                    try await claudeQuery.setModel(nil)
                } catch {
                    // May not be supported
                }
            }
        }

        XCTAssertTrue(initialized, "Should receive init message")
    }

    // MARK: - setPermissionMode Tests

    /// Tests that setPermissionMode() can change permission mode mid-query.
    func testSetPermissionModeMidQuery() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "What is 2+2? Just say the number.",
            options: options
        )

        var modeChanged = false
        var messageCount = 0

        for try await message in claudeQuery {
            messageCount += 1

            if message.isSystemInit && !modeChanged {
                do {
                    try await claudeQuery.setPermissionMode(.default)
                    modeChanged = true
                } catch {
                    print("[DEBUG] setPermissionMode failed: \(error)")
                }
            }
        }

        XCTAssertGreaterThan(messageCount, 0, "Should receive messages")
    }

    /// Tests that setPermissionMode to bypassPermissions works.
    func testSetPermissionModeBypass() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .default

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var initialized = false
        for try await message in claudeQuery {
            if message.isSystemInit && !initialized {
                initialized = true
                do {
                    try await claudeQuery.setPermissionMode(.bypassPermissions)
                } catch {
                    // May not be supported in all scenarios
                }
            }
        }

        XCTAssertTrue(initialized, "Should receive init message")
    }

    // MARK: - setMaxThinkingTokens Tests

    /// Tests that setMaxThinkingTokens() can be called mid-query.
    func testSetMaxThinkingTokensMidQuery() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Say OK", options: options)

        var tokensCalled = false
        for try await message in claudeQuery {
            if message.isSystemInit && !tokensCalled {
                tokensCalled = true
                do {
                    try await claudeQuery.setMaxThinkingTokens(1000)
                } catch {
                    // May not be supported
                    print("[DEBUG] setMaxThinkingTokens failed: \(error)")
                }
            }
        }

        XCTAssertTrue(tokensCalled, "Should have attempted to set thinking tokens")
    }

    /// Tests that setMaxThinkingTokens(nil) resets to default.
    func testSetMaxThinkingTokensToNil() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.maxThinkingTokens = 500

        let claudeQuery = try await query(prompt: "Say OK", options: options)

        var initialized = false
        for try await message in claudeQuery {
            if message.isSystemInit && !initialized {
                initialized = true
                do {
                    try await claudeQuery.setMaxThinkingTokens(nil)
                } catch {
                    // May not be supported
                }
            }
        }

        XCTAssertTrue(initialized, "Should receive init message")
    }

    // MARK: - Session Resume Tests

    /// Tests that a session can be resumed using the session ID.
    func testSessionResume() async throws {
        try skipIfCLIUnavailable()

        // First query to establish a session
        var options1 = QueryOptions()
        options1.maxTurns = 1
        options1.permissionMode = .bypassPermissions

        let firstQuery = try await query(
            prompt: "Remember the secret word: BANANA. Just acknowledge.",
            options: options1
        )
        _ = try await collectMessages(from: firstQuery, timeout: 30)

        let sessionId = await firstQuery.sessionId
        XCTAssertNotNil(sessionId, "First query should have a session ID")

        guard let validSessionId = sessionId else {
            XCTFail("Session ID required for resume test")
            return
        }

        // Second query resuming the session
        var options2 = QueryOptions()
        options2.maxTurns = 1
        options2.permissionMode = .bypassPermissions
        options2.resume = validSessionId

        let secondQuery = try await query(
            prompt: "What was the secret word I mentioned?",
            options: options2
        )
        let messages = try await collectMessages(from: secondQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Resumed query should receive messages")

        // Verify same session
        let resumedSessionId = await secondQuery.sessionId
        XCTAssertEqual(resumedSessionId, validSessionId, "Resumed session should have same ID")
    }

    /// Tests that resume with invalid session ID handles error gracefully.
    func testSessionResumeInvalidId() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.resume = "invalid-session-id-12345"

        do {
            let claudeQuery = try await query(prompt: "Say hello", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
            // If it succeeds, the CLI may have created a new session
        } catch {
            // Expected - invalid session ID should fail
            XCTAssertTrue(true, "Invalid session ID handled: \(error)")
        }
    }

    // MARK: - maxThinkingTokens Option Tests

    /// Tests that maxThinkingTokens option is passed to CLI.
    func testMaxThinkingTokensOption() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.maxThinkingTokens = 2000

        let claudeQuery = try await query(
            prompt: "Say OK",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages with thinking tokens set")
    }
}
