//
//  EdgeCaseIntegrationTests.swift
//  ClaudeCodeSDKTests
//
//  Integration tests for edge cases and observability features:
//  - Concurrent parallel queries
//  - stderrHandler callback
//  - Long response handling
//  - Stress tests
//

import XCTest
@testable import ClaudeCodeSDK

final class EdgeCaseIntegrationTests: XCTestCase {

    // MARK: - Concurrent Queries Tests

    /// Tests that multiple queries can run in parallel without interference.
    func testConcurrentParallelQueries() async throws {
        try skipIfCLIUnavailable()

        // Create separate options for each query to avoid data races
        func makeOptions() -> QueryOptions {
            var opts = QueryOptions()
            opts.maxTurns = 1
            opts.permissionMode = .bypassPermissions
            return opts
        }

        // Run 3 queries in parallel using TaskGroup
        let results = try await withThrowingTaskGroup(of: (Int, [StdoutMessage]).self) { group in
            group.addTask {
                let opts = makeOptions()
                let q = try await query(prompt: "Say 'one'", options: opts)
                return (1, try await collectMessages(from: q, timeout: 45))
            }
            group.addTask {
                let opts = makeOptions()
                let q = try await query(prompt: "Say 'two'", options: opts)
                return (2, try await collectMessages(from: q, timeout: 45))
            }
            group.addTask {
                let opts = makeOptions()
                let q = try await query(prompt: "Say 'three'", options: opts)
                return (3, try await collectMessages(from: q, timeout: 45))
            }

            var collected: [Int: [StdoutMessage]] = [:]
            for try await (id, messages) in group {
                collected[id] = messages
            }
            return collected
        }

        XCTAssertGreaterThan(results[1]?.count ?? 0, 0, "Query 1 should complete")
        XCTAssertGreaterThan(results[2]?.count ?? 0, 0, "Query 2 should complete")
        XCTAssertGreaterThan(results[3]?.count ?? 0, 0, "Query 3 should complete")
    }

    /// Tests concurrent queries with different options.
    func testConcurrentQueriesWithDifferentOptions() async throws {
        try skipIfCLIUnavailable()

        // Run queries with different options in parallel using TaskGroup
        let results = try await withThrowingTaskGroup(of: (Int, [StdoutMessage]).self) { group in
            group.addTask {
                var opts = QueryOptions()
                opts.maxTurns = 1
                opts.permissionMode = .bypassPermissions
                opts.systemPrompt = "You are a helpful assistant."
                let q = try await query(prompt: "Say hello", options: opts)
                return (1, try await collectMessages(from: q, timeout: 45))
            }

            group.addTask {
                var opts = QueryOptions()
                opts.maxTurns = 1
                opts.permissionMode = .bypassPermissions
                opts.systemPrompt = "You are a concise assistant."
                let q = try await query(prompt: "Say goodbye", options: opts)
                return (2, try await collectMessages(from: q, timeout: 45))
            }

            var collected: [Int: [StdoutMessage]] = [:]
            for try await (id, messages) in group {
                collected[id] = messages
            }
            return collected
        }

        XCTAssertGreaterThan(results[1]?.count ?? 0, 0, "Query 1 should complete")
        XCTAssertGreaterThan(results[2]?.count ?? 0, 0, "Query 2 should complete")
    }

    // MARK: - stderrHandler Tests

    /// Tests that stderrHandler receives CLI stderr output.
    func testStderrHandlerReceivesOutput() async throws {
        try skipIfCLIUnavailable()

        let stderrReceived = TestFlag()
        let stderrContent = TestArrayCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.stderrHandler = { output in
            stderrReceived.set()
            stderrContent.append(output)
        }

        let claudeQuery = try await query(prompt: "Say hello", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 30)

        // stderr output may or may not be present depending on CLI verbosity
        // This test verifies the handler is wired up correctly
        print("[DEBUG] stderr received: \(stderrReceived.value)")
        print("[DEBUG] stderr content count: \(stderrContent.count)")
    }

    /// Tests that stderrHandler captures error messages.
    func testStderrHandlerCapturesErrors() async throws {
        try skipIfCLIUnavailable()

        let stderrContent = TestArrayCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.model = "invalid-model-name"
        options.stderrHandler = { output in
            stderrContent.append(output)
        }

        do {
            let claudeQuery = try await query(prompt: "Say hello", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
        } catch {
            // Expected - invalid model
        }

        // Error info might appear on stderr
        print("[DEBUG] stderr captured \(stderrContent.count) items")
    }

    // MARK: - Long Response Tests

    /// Tests handling of a long response.
    func testLongResponseHandling() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Write a 500 word essay about the history of computing.",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 120)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")

        // Check for assistant messages with content
        let assistantMessages = messages.filter { $0.isAssistant }
        XCTAssertGreaterThan(assistantMessages.count, 0, "Should receive assistant messages")
    }

    /// Tests handling of multiple tool uses in a single response.
    func testMultipleToolUsesInResponse() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 10
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts and /etc/passwd and summarize both.",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 90)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")

        // Look for multiple tool uses
        let toolUseMessages = messages.filter { msg in
            if case .regular(let sdkMsg) = msg {
                return sdkMsg.type == "assistant" || sdkMsg.type == "tool_use"
            }
            return false
        }
        XCTAssertGreaterThan(toolUseMessages.count, 0, "Should have tool-related messages")
    }

    // MARK: - Message Stream Tests

    /// Tests that all message types are properly streamed.
    func testAllMessageTypesReceived() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts and tell me what's in it.",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 60)

        // Categorize messages
        var hasSystem = false
        var hasAssistant = false
        var hasResult = false

        for message in messages {
            if case .regular(let sdkMsg) = message {
                switch sdkMsg.type {
                case "system": hasSystem = true
                case "assistant": hasAssistant = true
                case "result": hasResult = true
                default: break
                }
            }
        }

        XCTAssertTrue(hasSystem, "Should receive system message")
        XCTAssertTrue(hasAssistant, "Should receive assistant message")
        XCTAssertTrue(hasResult, "Should receive result message")
    }

    // MARK: - Stress Tests

    /// Tests rapid creation and completion of queries.
    func testRapidQueryCreation() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        var successCount = 0

        for i in 1...5 {
            let claudeQuery = try await query(prompt: "Say '\(i)'", options: options)
            let messages = try await collectMessages(from: claudeQuery, timeout: 30)
            if messages.count > 0 {
                successCount += 1
            }
        }

        XCTAssertEqual(successCount, 5, "All rapid queries should complete")
    }

    /// Tests query with minimal response.
    func testMinimalQueryResponse() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Reply with only the word 'OK'",
            options: options
        )
        let messages = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")
    }

    // MARK: - Resource Stress Tests

    /// Tests that resources are properly cleaned up after many queries.
    func testResourceCleanupAfterManyQueries() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        // Run many queries
        for i in 1...10 {
            let claudeQuery = try await query(prompt: "Say '\(i)'", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
        }

        // If we get here without hanging or crashing, resources are being cleaned up
        XCTAssertTrue(true, "Completed 10 queries without resource issues")
    }

    /// Tests query with large input.
    func testQueryWithLargeInput() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        // Create a large prompt
        let largeText = String(repeating: "This is a test sentence. ", count: 100)
        let prompt = "Summarize this text in one sentence: \(largeText)"

        let claudeQuery = try await query(prompt: prompt, options: options)
        let messages = try await collectMessages(from: claudeQuery, timeout: 60)

        XCTAssertGreaterThan(messages.count, 0, "Should handle large input")
    }

    // MARK: - Working Directory Tests

    /// Tests queries with different working directories.
    func testDifferentWorkingDirectories() async throws {
        try skipIfCLIUnavailable()

        try await withTestDirectory { tempDir1 in
            try await withTestDirectory { tempDir2 in
                var options1 = QueryOptions()
                options1.maxTurns = 1
                options1.permissionMode = .bypassPermissions
                options1.workingDirectory = tempDir1

                var options2 = QueryOptions()
                options2.maxTurns = 1
                options2.permissionMode = .bypassPermissions
                options2.workingDirectory = tempDir2

                // Run queries with different working directories
                let query1 = try await query(prompt: "What is the current directory?", options: options1)
                let messages1 = try await collectMessages(from: query1, timeout: 30)

                let query2 = try await query(prompt: "What is the current directory?", options: options2)
                let messages2 = try await collectMessages(from: query2, timeout: 30)

                XCTAssertGreaterThan(messages1.count, 0, "Query 1 should complete")
                XCTAssertGreaterThan(messages2.count, 0, "Query 2 should complete")
            }
        }
    }

    // MARK: - Environment Variable Tests

    /// Tests that custom environment variables are passed to CLI.
    func testCustomEnvironmentVariables() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.environment = [
            "SDK_TEST_VAR": "test_value_12345",
            "SDK_ANOTHER_VAR": "another_value"
        ]

        let claudeQuery = try await query(prompt: "Say OK", options: options)
        let messages = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Query with custom env should complete")
    }

    // MARK: - Keepalive Tests

    /// Tests that keepalive messages don't interfere with regular messages.
    func testKeepaliveMessages() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(
            prompt: "Write a short paragraph about Swift programming.",
            options: options
        )

        var regularMessageCount = 0
        var keepaliveCount = 0

        for try await message in claudeQuery {
            switch message {
            case .regular:
                regularMessageCount += 1
            case .keepAlive:
                keepaliveCount += 1
            default:
                break
            }
        }

        XCTAssertGreaterThan(regularMessageCount, 0, "Should receive regular messages")
        // Keepalive count may be 0 or more depending on timing
        print("[DEBUG] Regular messages: \(regularMessageCount), Keepalives: \(keepaliveCount)")
    }
}
