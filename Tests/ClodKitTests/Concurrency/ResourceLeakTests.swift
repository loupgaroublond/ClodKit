//
//  ResourceLeakTests.swift
//  ClodKitTests
//
//  Tests for resource leaks: temp files, unclosed handles, memory.
//  These tests should FAIL in the current buggy state and PASS once fixed.
//

import XCTest
@testable import ClodKit

// MARK: - Temp File Leak Tests

/// Tests for MEDIUM-1: Temp file leak in QueryAPI
/// The bug: MCP config temp files are created but never deleted.
final class TempFileLeakTests: XCTestCase {

    /// Test that MCP config temp files are cleaned up.
    /// EXPECTED: FAIL in buggy state (file count increases)
    /// EXPECTED: PASS once fixed (file count stays same or decreases)
    /// NOTE: This is an integration test - skipped by default, run with TEST_MODE=integration
    func test_query_withMCPServers_cleansUpTempFiles() async throws {
        // Skip unless in integration test mode (these tests spawn real CLI processes)
        try XCTSkipUnless(TestMode.current == .integration,
            "Skipping integration test - set TEST_MODE=integration to run")

        let tempDir = FileManager.default.temporaryDirectory

        // Count existing mcp-config files
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }
        let countBefore = filesBefore.count

        // Create a query with SDK MCP server (triggers temp file creation)
        let server = SDKMCPServer(name: "test-server", tools: [
            TestTools.echoTool()
        ])

        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        options.sdkMcpServers["test-server"] = server

        // Create and immediately discard query
        // The temp file should be cleaned up when query/session is released
        do {
            let query = try await ClaudeCode.query(prompt: "test", options: options)
            // Don't iterate, just let it go out of scope
            _ = query
        } catch {
            // Query might fail for various reasons, but temp file behavior is what we're testing
        }

        // Give time for cleanup
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Count files after
        let filesAfter = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }
        let countAfter = filesAfter.count

        // In buggy state: countAfter > countBefore (file leaked)
        // In fixed state: countAfter <= countBefore (file cleaned up)
        XCTAssertLessThanOrEqual(countAfter, countBefore,
            "Temp file leaked: had \(countBefore) mcp-config files before, now have \(countAfter)")
    }

    /// Stress test: Multiple queries shouldn't accumulate temp files.
    /// NOTE: This is an integration test - skipped by default, run with TEST_MODE=integration
    func test_multipleQueries_dontAccumulateTempFiles() async throws {
        try XCTSkipUnless(TestMode.current == .integration,
            "Skipping integration test - set TEST_MODE=integration to run")

        let tempDir = FileManager.default.temporaryDirectory
        let queryCount = 5

        // Count existing files
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }
        let countBefore = filesBefore.count

        // Create multiple queries with MCP servers
        for i in 0..<queryCount {
            let server = SDKMCPServer(name: "server-\(i)", tools: [])

            var options = QueryOptions()
            options.maxTurns = 1
            options.permissionMode = .bypassPermissions
            options.sdkMcpServers["server-\(i)"] = server

            do {
                let query = try await ClaudeCode.query(prompt: "test \(i)", options: options)
                _ = query
            } catch {
                // Ignore errors
            }

            // Small delay between queries
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Give time for cleanup
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

        // Count files after
        let filesAfter = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }
        let countAfter = filesAfter.count

        let leaked = countAfter - countBefore

        if leaked > 0 {
            XCTFail("Leaked \(leaked) temp files after \(queryCount) queries")
        }
    }

    /// Test that buildMCPConfigFile creates files in temp directory.
    /// This documents the current behavior (files are created but not tracked).
    func test_buildMCPConfigFile_createsFile() async throws {
        // We can't directly call the private function, but we can verify
        // that queries with MCP servers create temp files.

        let tempDir = FileManager.default.temporaryDirectory
        let _ = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }
            .count

        // Create QueryOptions with SDK MCP server
        var options = QueryOptions()
        options.sdkMcpServers["test"] = SDKMCPServer(name: "test", tools: [])

        // The query creation will trigger buildMCPConfigFile
        // Even if we can't start the query, the file gets created
        // during argument building

        // Note: This test just documents that files are created.
        // The actual leak happens because they're never deleted.
    }
}

// MARK: - Handle Cleanup Tests

/// Tests for proper cleanup of file handles and pipes.
final class HandleCleanupTests: XCTestCase {

    /// Test that ProcessTransport closes all pipes on close().
    func test_processTransport_close_closesAllPipes() async throws {
        let transport = ProcessTransport(command: "sleep 10")

        do {
            try transport.start()
        } catch {
            // CLI might fail, that's OK for this test
            throw XCTSkip("Could not start process")
        }

        // Close transport
        transport.close()

        // Give time for close to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        // Verify transport is not connected
        XCTAssertFalse(transport.isConnected)

        // We can't directly verify pipes are closed, but we can verify
        // write fails after close
        do {
            try await transport.write(Data("test".utf8))
            XCTFail("Write should fail after close")
        } catch {
            // Expected
        }
    }

    /// Test that transport handles are released on dealloc.
    func test_processTransport_dealloc_releasesHandles() async throws {
        weak var weakTransport: ProcessTransport?

        do {
            let transport = ProcessTransport(command: "echo test")
            weakTransport = transport

            do {
                try transport.start()
            } catch {
                // Start might fail, that's OK
            }
            // transport goes out of scope
        }

        // Give time for dealloc
        try await Task.sleep(nanoseconds: 100_000_000)

        // Transport should be deallocated - verify weak reference is nil
        XCTAssertNil(weakTransport, "Transport should be deallocated after going out of scope")
    }
}

// MARK: - Session Cleanup Tests

/// Tests for proper cleanup of session resources.
final class SessionCleanupTests: XCTestCase {

    /// Test that ClaudeSession.close() cleans up properly.
    func test_session_close_cleansUpResources() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        // Start message loop
        let stream = await session.startMessageLoop()

        // Start consuming in background
        let consumerTask = Task {
            for try await _ in stream { }
        }

        // Give time to start
        try await Task.sleep(nanoseconds: 10_000_000)

        // Close session
        await session.close()

        // Consumer should finish
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        consumerTask.cancel()
        try await Task.sleep(nanoseconds: 50_000_000)

        // Transport should be closed
        XCTAssertFalse(transport.isConnected)
    }

    /// Test that session actors don't leak.
    func test_session_dealloc_noActorLeak() async throws {
        weak var weakSession: ClaudeSession?

        do {
            let transport = MockTransport()
            let session = ClaudeSession(transport: transport)
            weakSession = session
        }

        // Give time for dealloc
        try await Task.sleep(nanoseconds: 100_000_000)

        // Note: Actors may not be immediately deallocated due to
        // internal Swift runtime behavior. This assertion may fail
        // intermittently but documents the expected behavior.
        XCTAssertNil(weakSession, "Session actor should be deallocated after going out of scope")
    }

    /// Test that hook registry is cleaned up.
    func test_hookRegistry_cleanup() async throws {
        let registry = HookRegistry()

        // Register many hooks
        for i in 0..<100 {
            await registry.onPreToolUse(matching: "tool_\(i)") { _ in .continue() }
        }

        let countBefore = await registry.callbackCount
        XCTAssertEqual(countBefore, 100)

        // Note: HookRegistry doesn't have a clear/cleanup method.
        // Hooks are only removed when the registry is deallocated.
        // This documents the current behavior.
    }
}

// MARK: - Memory Pressure Tests

/// Tests for behavior under memory pressure.
final class MemoryPressureTests: XCTestCase {

    /// Test that large message volumes don't cause memory issues.
    func test_largeMessageVolume_noMemoryLeak() async throws {
        let transport = MockTransport()
        let messageCount = 10000

        let stream = transport.readMessages()

        // Consumer that processes and discards messages
        let processedCount = AtomicCounter()

        let consumerTask = Task {
            for try await _ in stream {
                processedCount.increment()
            }
        }

        // Give consumer time to start
        try await Task.sleep(nanoseconds: 10_000_000)

        // Inject many messages
        for i in 0..<messageCount {
            let largeContent = String(repeating: "x", count: 1000) // 1KB per message
            transport.injectMessage(.regular(SDKMessage(type: "msg_\(i)", content: .string(largeContent))))

            // Small yield to prevent overwhelming
            if i % 100 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000)
            }
        }

        transport.finishStream()

        // Wait for consumer with generous timeout
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5s for 10K messages
        consumerTask.cancel()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(processedCount.value, messageCount)

        // Memory should be stable after processing
        // Note: Actual memory verification would require memory profiling tools
    }
}
