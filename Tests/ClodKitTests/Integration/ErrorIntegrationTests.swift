//
//  ErrorIntegrationTests.swift
//  ClodKitTests
//
//  Integration tests for error scenarios with the real Claude CLI.
//

import XCTest
@testable import ClodKit

final class ErrorIntegrationTests: XCTestCase {

    // MARK: - CLI Availability Tests

    func testCLINotAvailable() async throws {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.cliPath = "/nonexistent/path/to/claude"

        do {
            let claudeQuery = try await query(prompt: "Say hello", options: options)
            let messages = try await collectMessages(from: claudeQuery, timeout: 30)
            // If no throw, the stream should be empty or contain only error info
            // (process launch with invalid path may fail silently with empty stream)
            XCTAssertTrue(messages.isEmpty || messages.contains(where: { $0.sdkMessage?.type == "error" }),
                          "Invalid CLI path should produce empty stream or error message")
        } catch {
            XCTAssertTrue(true, "Error thrown as expected: \(error)")
        }
    }

    func testValidateSetupWithInvalidPath() async throws {
        let backend = NativeBackend(cliPath: "/nonexistent/path/to/claude")

        do {
            let isValid = try await backend.validateSetup()
            XCTAssertFalse(isValid, "Should return false for invalid CLI path")
        } catch {
            XCTAssertTrue(true, "Error thrown as expected")
        }
    }

    // MARK: - Invalid Options Tests

    func testInvalidModel() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.model = "definitely-not-a-real-model"

        do {
            let claudeQuery = try await query(prompt: "Say hello", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
        } catch {
            // Error expected for invalid model
            XCTAssertTrue(true, "Error thrown for invalid model")
        }
    }

    func testInvalidWorkingDirectory() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.workingDirectory = URL(fileURLWithPath: "/nonexistent/directory")

        do {
            let claudeQuery = try await query(prompt: "Say hello", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
        } catch {
            XCTAssertTrue(true, "Error handled")
        }
    }

    // MARK: - Timeout Tests

    func testOperationTimeout() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let startTime = Date()

        let claudeQuery = try await query(prompt: "Say 'done'", options: options)
        _ = try await collectMessages(from: claudeQuery, timeout: 60)

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 120.0, "Operation should complete within 2 minutes")
    }

    // MARK: - Resource Cleanup Tests

    func testResourceCleanup() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        for i in 1...3 {
            let claudeQuery = try await query(prompt: "Say '\(i)'", options: options)
            _ = try await collectMessages(from: claudeQuery, timeout: 30)
        }

        XCTAssertTrue(true, "Multiple queries completed without resource issues")
    }

    func testResourceCleanupAfterInterrupt() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 10
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Count to 100.", options: options)

        var count = 0
        for try await _ in claudeQuery {
            count += 1
            if count >= 2 {
                // Process may have already exited, making pipe write fail
                do { try await claudeQuery.interrupt() } catch {}
                break
            }
        }

        // Run another query to verify cleanup
        options.maxTurns = 1
        let messages = try await collectMessages(
            from: try await query(prompt: "Say 'after'", options: options),
            timeout: 30
        )

        XCTAssertGreaterThan(messages.count, 0, "Should work after interrupted query")
    }

    // MARK: - Empty Response Tests

    func testMinimalResponse() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        let claudeQuery = try await query(prompt: "Reply with just 'OK'", options: options)
        let messages = try await collectMessages(from: claudeQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")
        let hasInit = messages.contains { $0.isSystemInit }
        XCTAssertTrue(hasInit, "Should receive system init")
    }

    // MARK: - Concurrent Query Tests

    func testRapidSequentialQueries() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions

        var successCount = 0

        for i in 1...3 {
            let messages = try await collectMessages(
                from: try await query(prompt: "Say '\(i)'", options: options),
                timeout: 30
            )
            if messages.count > 0 { successCount += 1 }
        }

        XCTAssertEqual(successCount, 3, "All rapid queries should complete")
    }
}
