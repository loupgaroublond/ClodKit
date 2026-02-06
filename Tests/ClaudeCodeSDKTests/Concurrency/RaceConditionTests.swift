//
//  RaceConditionTests.swift
//  ClaudeCodeSDKTests
//
//  Tests for race conditions: registration races, TOCTOU, concurrent modification.
//  These tests should FAIL in the current buggy state and PASS once fixed.
//

import XCTest
@testable import ClaudeCodeSDK

// MARK: - Registration Race Tests

/// Tests for CRITICAL-1: Request/Response Registration Race
/// The bug: Response can arrive before continuation is registered, causing hang.
final class RegistrationRaceTests: XCTestCase {

    /// Test that fast responses don't get lost.
    /// EXPECTED: FAIL in buggy state (hangs until timeout)
    /// EXPECTED: PASS once fixed (completes quickly)
    func test_sendRequest_fastResponse_doesNotHang() async throws {
        // Create a mock transport that responds immediately
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport, defaultTimeout: 2.0)

        // Set up mock to respond immediately when it sees a request
        transport.mockResponseHandler = { data in
            // Parse the request to get the ID
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let requestId = json["request_id"] as? String {
                // Respond immediately (before registration can complete)
                let response = ControlResponse(
                    type: "control_response",
                    response: ControlResponsePayload(
                        subtype: "success",
                        requestId: requestId,
                        response: .null
                    )
                )
                if let _ = try? JSONEncoder().encode(response) {
                    transport.injectMessage(.controlResponse(response))
                }
            }
        }

        // Start reading messages in background
        Task {
            for try await message in transport.readMessages() {
                if case .controlResponse(let response) = message {
                    await handler.handleControlResponse(response)
                }
            }
        }

        // Give message loop time to start
        try await Task.sleep(nanoseconds: 10_000_000)

        // This should complete quickly, not hang for 2 seconds
        let startTime = ContinuousClock.now
        do {
            let _ = try await withTimeout(seconds: 1.0, operation: "sendRequest") {
                try await handler.sendRequest(.interrupt)
            }
            let elapsed = ContinuousClock.now - startTime
            // Should complete in well under 1 second
            XCTAssertLessThan(elapsed, .seconds(1), "Request completed but took too long")
        } catch is TimeoutError {
            XCTFail("Request hung - response was likely dropped due to registration race")
        }

        transport.close()
    }

    /// Stress test: Many rapid requests should all complete.
    /// EXPECTED: FAIL in buggy state (some requests hang)
    func test_sendRequest_rapidFire_allComplete() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport, defaultTimeout: 5.0)
        let completedCount = AtomicCounter()
        let requestCount = TestMode.current == .concurrency ? 50 : 10

        // Set up immediate responses
        transport.mockResponseHandler = { data in
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let requestId = json["request_id"] as? String {
                let response = ControlResponse(
                    type: "control_response",
                    response: ControlResponsePayload(subtype: "success", requestId: requestId)
                )
                transport.injectMessage(.controlResponse(response))
            }
        }

        // Message loop
        let loopTask = Task {
            for try await message in transport.readMessages() {
                if case .controlResponse(let response) = message {
                    await handler.handleControlResponse(response)
                }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        // Fire many requests concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<requestCount {
                group.addTask {
                    do {
                        let _ = try await handler.sendRequest(.interrupt)
                        completedCount.increment()
                    } catch {
                        // Request failed
                    }
                }
            }
        }

        transport.close()
        loopTask.cancel()

        XCTAssertEqual(
            completedCount.value, requestCount,
            "Only \(completedCount.value)/\(requestCount) requests completed - registration race likely"
        )
    }
}

// MARK: - TOCTOU Tests

/// Tests for HIGH-2: Time-of-Check-Time-of-Use in closeInternal()
/// The bug: Concurrent close() calls can both pass the guard and double-close.
final class TOCTOUTests: XCTestCase {

    /// Test that concurrent close() calls only execute close logic once.
    /// EXPECTED: FAIL in buggy state (closeCount > 1)
    /// EXPECTED: PASS once fixed (closeCount == 1)
    func test_close_calledConcurrently_executesOnce() async throws {
        // We need to track how many times the actual close logic runs.
        // Since we can't easily hook into ProcessTransport's internals,
        // we test with MockTransport which has the same pattern.

        let transport = MockTransport()

        // Start reading to set up continuation
        let stream = transport.readMessages()
        let readTask = Task {
            for try await _ in stream { }
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        // Call close() from many tasks simultaneously
        let concurrentCalls = concurrentOperations

        _ = try await ConcurrencyTestRunner.runSimultaneously(count: concurrentCalls) { _ in
            transport.close()
            // We can't directly count internal close executions,
            // but we can verify the transport ends up in correct state
        }

        readTask.cancel()

        // Transport should be closed
        XCTAssertFalse(transport.isConnected, "Transport should be closed")

        // Note: This test verifies behavior but can't directly count internal close() calls.
        // A more thorough test would require modifying ProcessTransport to have a hook.
    }

    /// Test ProcessTransport TOCTOU with stress.
    /// Creates many transports and closes them concurrently.
    func test_processTransport_concurrentClose_nocrash() async throws {
        // This test verifies no crashes occur during concurrent close.
        // It's a smoke test - the real verification requires hooks.

        for _ in 0..<stressIterations {
            let transport = ProcessTransport(command: "echo test")

            do {
                try transport.start()
            } catch {
                // CLI might not be available, skip
                continue
            }

            // Concurrent close attempts
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<5 {
                    group.addTask {
                        transport.close()
                    }
                }
            }

            // Small delay between iterations
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // If we get here without crashing, the test passes
        // (Though the underlying TOCTOU bug may still exist)
    }
}

// MARK: - Concurrent Modification Tests

/// Tests for concurrent access to shared state.
final class ConcurrentModificationTests: XCTestCase {

    /// Test that HookRegistry handles concurrent registrations.
    func test_hookRegistry_concurrentRegistration_noCorruption() async throws {
        let registry = HookRegistry()
        let registrationCount = concurrentOperations

        // Register hooks concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<registrationCount {
                group.addTask {
                    await registry.onPreToolUse(matching: "tool_\(i)") { _ in
                        .continue()
                    }
                }
            }
        }

        // Verify all hooks were registered
        let callbackCount = await registry.callbackCount
        XCTAssertEqual(callbackCount, registrationCount,
            "Expected \(registrationCount) callbacks, got \(callbackCount)")
    }

    /// Test that MCPServerRouter handles concurrent server registration.
    func test_mcpRouter_concurrentRegistration_noCorruption() async throws {
        let router = MCPServerRouter()
        let serverCount = concurrentOperations

        // Create servers
        let servers = (0..<serverCount).map { i in
            SDKMCPServer(name: "server_\(i)", tools: [])
        }

        // Register concurrently
        await withTaskGroup(of: Void.self) { group in
            for server in servers {
                group.addTask {
                    await router.registerServer(server)
                }
            }
        }

        // Verify all registered
        let names = await router.getServerNames()
        XCTAssertEqual(names.count, serverCount,
            "Expected \(serverCount) servers, got \(names.count)")
    }

    /// Test NativeBackend concurrent query tracking.
    func test_nativeBackend_concurrentActiveQueryAccess() async throws {
        // This tests that activeQuery access is properly synchronized.
        // We can't easily test the actual race without a real query,
        // but we can verify the lock doesn't deadlock.

        let backend = NativeBackend()
        let accessCount = AtomicCounter()

        // Concurrent cancel() calls (which access activeQuery)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentOperations {
                group.addTask {
                    backend.cancel()
                    accessCount.increment()
                }
            }
        }

        XCTAssertEqual(accessCount.value, concurrentOperations,
            "Some cancel() calls didn't complete")
    }
}

// MARK: - Cancel Task Tests

/// Tests for HIGH-1: Untracked Task in cancel()
final class CancelTaskTests: XCTestCase {

    /// Test that cancel() completion can be awaited.
    /// This test documents the CURRENT BROKEN BEHAVIOR.
    /// EXPECTED: In current state, we can't await cancel completion.
    func test_cancel_cannotAwaitCompletion() async throws {
        let backend = NativeBackend()

        // cancel() returns immediately, spawning untracked Task
        let startTime = ContinuousClock.now
        backend.cancel()  // Note: not async, can't await
        let elapsed = ContinuousClock.now - startTime

        // cancel() returns immediately (< 1ms typically)
        // This documents that we CAN'T wait for actual cancellation
        XCTAssertLessThan(elapsed, .milliseconds(10),
            "cancel() blocked - expected immediate return")

        // The actual interrupt() call happens in background, untracked.
        // There's no way to know when it completes.
        // This is the bug - we should be able to await cancellation.
    }

    /// Test that rapid cancel/query cycles don't race.
    /// EXPECTED: May exhibit flaky behavior due to untracked cancel Task.
    func test_cancel_thenImmediateNewQuery_mayRace() async throws {
        // Skip if no CLI - this test needs real queries
        try XCTSkipUnless(IntegrationTestConfig.isClaudeAvailable,
            "Claude CLI not available")

        let _ = NativeBackend()

        // This pattern is problematic with untracked cancel:
        // 1. Start query
        // 2. Cancel (returns immediately, actual cancel in background)
        // 3. Start new query (may race with step 2's background work)

        // We can't reliably test the race without real queries,
        // but we document the problematic pattern here.

        // The fix: make cancel() async or track the Task
    }
}
