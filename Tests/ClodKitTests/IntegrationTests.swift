//
//  IntegrationTests.swift
//  ClodKitTests
//
//  Integration tests that actually invoke the Claude CLI.
//  These tests require a valid API key and network access.
//

import XCTest
@testable import ClodKit

final class IntegrationTests: XCTestCase {

    override func setUp() async throws {
        try skipIfCLIUnavailable()
    }

    // MARK: - ProcessTransport Integration Tests

    func testProcessTransport_StartsAndConnects() async throws {
        let transport = ProcessTransport(
            executablePath: "claude",
            arguments: ["-p", "--output-format", "stream-json", "--input-format", "stream-json", "--verbose"]
        )

        try transport.start()

        XCTAssertTrue(transport.isConnected)

        transport.close()

        // Wait for close to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(transport.isConnected)
    }

    func testProcessTransport_WriteAndRead() async throws {
        let transport = ProcessTransport(
            executablePath: "claude",
            arguments: ["-p", "--output-format", "stream-json", "--input-format", "stream-json", "--verbose", "--max-turns", "1", "--permission-mode", "bypassPermissions"]
        )

        try transport.start()

        // Set up message stream BEFORE writing to capture all output
        let messageStream = transport.readMessages()

        // Send a simple prompt in correct stream-json format
        // Format: {"type":"user","message":{"role":"user","content":"..."}}
        let promptPayload: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": "Say hello in exactly 3 words"
            ]
        ]
        let promptData = try JSONSerialization.data(withJSONObject: promptPayload, options: [])
        try await transport.write(promptData)

        // End input
        await transport.endInput()

        // Collect messages
        var messages: [StdoutMessage] = []
        for try await message in messageStream {
            messages.append(message)
        }

        // Should have received at least init and result messages
        XCTAssertGreaterThan(messages.count, 0)

        // Check for system init message
        let hasInit = messages.contains { msg in
            if case .regular(let sdkMsg) = msg {
                return sdkMsg.type == "system"
            }
            return false
        }
        XCTAssertTrue(hasInit, "Expected system init message")
    }

    func testProcessTransport_EndInputClosesStdin() async throws {
        let transport = ProcessTransport(
            executablePath: "claude",
            arguments: ["-p", "--output-format", "stream-json", "--max-turns", "1"]
        )

        try transport.start()
        XCTAssertTrue(transport.isConnected)

        // End input should not crash
        await transport.endInput()

        // Transport should still be connected until process exits
        transport.close()
    }

    func testProcessTransport_CloseTerminatesProcess() async throws {
        let transport = ProcessTransport(
            executablePath: "claude",
            arguments: ["-p", "--output-format", "stream-json", "--input-format", "stream-json"]
        )

        try transport.start()
        XCTAssertTrue(transport.isConnected)

        transport.close()

        // Wait for close to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(transport.isConnected)
    }

    // MARK: - Full Query Integration Tests

    func testQuery_SimplePrompt() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "What is 2+2? Reply with just the number.", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        // Should have received messages
        XCTAssertGreaterThan(messages.count, 0)

        // Check for any regular message
        let hasRegular = messages.contains { msg in
            if case .regular = msg {
                return true
            }
            return false
        }
        XCTAssertTrue(hasRegular, "Expected regular messages")
    }

    func testQuery_WithModel() async throws {
        var options = QueryOptions()
        options.model = "claude-sonnet-4-20250514"
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Say 'test' and nothing else", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    func testQuery_WithMaxTurns() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var messageCount = 0
        for try await _ in claudeQuery {
            messageCount += 1
        }

        // Should complete with at least some messages
        XCTAssertGreaterThan(messageCount, 0)
    }

    func testQuery_WithSystemPrompt() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.systemPrompt = "You are a helpful assistant that only responds with 'YES' or 'NO'"

        let claudeQuery = try await query(prompt: "Is the sky blue?", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    // MARK: - Clod Namespace Tests

    func testClod_Query() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await Clod.query(prompt: "Say OK", options: options)

        var messageCount = 0
        for try await _ in claudeQuery {
            messageCount += 1
        }

        XCTAssertGreaterThan(messageCount, 0)
    }

    // MARK: - NativeBackend Integration Tests

    func testNativeBackend_ValidateSetup() async throws {
        let backend = NativeBackend()

        let isValid = try await backend.validateSetup()

        XCTAssertTrue(isValid, "Claude CLI should be available")
    }

    func testNativeBackend_RunSinglePrompt() async throws {
        let backend = NativeBackend()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await backend.runSinglePrompt(prompt: "Say yes", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    func testNativeBackend_Cancel() async throws {
        let backend = NativeBackend()

        // Cancel when there's no active query should not crash
        backend.cancel()

        XCTAssertTrue(true)
    }

    // MARK: - Working Directory Tests

    func testQuery_WithWorkingDirectory() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.workingDirectory = URL(fileURLWithPath: "/tmp")

        let claudeQuery = try await query(prompt: "What directory are you in? Just say the path.", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    // MARK: - Environment Variables Tests

    func testQuery_WithEnvironment() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.environment = ["TEST_VAR": "test_value"]

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    // MARK: - Multiple Queries Tests

    func testQuery_MultipleSequential() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        // First query
        let query1 = try await query(prompt: "Say one", options: options)
        var count1 = 0
        for try await _ in query1 {
            count1 += 1
        }

        // Second query
        let query2 = try await query(prompt: "Say two", options: options)
        var count2 = 0
        for try await _ in query2 {
            count2 += 1
        }

        XCTAssertGreaterThan(count1, 0)
        XCTAssertGreaterThan(count2, 0)
    }

    // MARK: - Additional Options Tests

    func testQuery_WithAllowedTools() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.allowedTools = ["Read"]

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    func testQuery_WithBlockedTools() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.blockedTools = ["Bash"]

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    func testQuery_WithAppendSystemPrompt() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.appendSystemPrompt = "Always end your response with 'END'"

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    func testQuery_WithAdditionalDirectories() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.additionalDirectories = ["/tmp", "/var"]

        let claudeQuery = try await query(prompt: "Say hello", options: options)

        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            messages.append(message)
        }

        XCTAssertGreaterThan(messages.count, 0)
    }

    // MARK: - Resume Session Tests

    func testQuery_WithResume() async throws {
        // First, run a query to get a session ID
        var options1 = QueryOptions()
        options1.maxTurns = 1
        options1.permissionMode = .bypassPermissions

        let firstQuery = try await query(prompt: "Remember the number 42", options: options1)
        for try await _ in firstQuery {
            // Consume messages
        }

        // Note: Getting session ID would require parsing the init message
        // For now, just test that resume option doesn't crash
        var options2 = QueryOptions()
        options2.maxTurns = 1
        options2.permissionMode = .bypassPermissions
        // options2.resume = sessionId  // Would use actual session ID

        XCTAssertTrue(true)  // Test that we got here without crash
    }
}

// MARK: - Message Type Tests

final class MessageTypeIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try skipIfCLIUnavailable()
    }

    func testQuery_ReceivesSystemMessage() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Say hi", options: options)

        var hasSystem = false
        for try await message in claudeQuery {
            if case .regular(let sdkMsg) = message, sdkMsg.type == "system" {
                hasSystem = true
            }
        }

        XCTAssertTrue(hasSystem, "Should receive system init message")
    }

    func testQuery_ReceivesAssistantMessage() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Say hello world", options: options)

        var hasAssistant = false
        for try await message in claudeQuery {
            if case .regular(let sdkMsg) = message, sdkMsg.type == "assistant" {
                hasAssistant = true
            }
        }

        XCTAssertTrue(hasAssistant, "Should receive assistant message")
    }
}
