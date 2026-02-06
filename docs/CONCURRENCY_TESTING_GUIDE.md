# Concurrency Testing Guide for Swift

A practical guide to writing automated tests that expose concurrency bugs. Tests should **fail in the broken state** and **pass once fixed**.

---

## Table of Contents

1. [Philosophy](#philosophy)
2. [Testing Infrastructure](#testing-infrastructure)
3. [Race Condition Testing](#race-condition-testing)
4. [AsyncSequence & Stream Testing](#asyncsequence--stream-testing)
5. [Task Lifecycle Testing](#task-lifecycle-testing)
6. [Lock & Synchronization Testing](#lock--synchronization-testing)
7. [Resource Leak Testing](#resource-leak-testing)
8. [Actor Isolation Testing](#actor-isolation-testing)
9. [Tooling](#tooling)
10. [Test Patterns Reference](#test-patterns-reference)

---

## Philosophy

### Goals of Concurrency Testing

1. **Deterministic failure** — Tests should reliably fail when bugs exist, not be flaky
2. **Fast feedback** — Tests should run quickly, not require minutes of stress testing
3. **Clear diagnostics** — When tests fail, the failure message should explain what went wrong
4. **Regression prevention** — Once fixed, the test ensures the bug never returns

### The Challenge

Concurrency bugs are timing-dependent. A test that runs operations "concurrently" might pass 99% of the time because the scheduler happens to order them safely. This creates flaky tests that erode trust.

### The Solution: Controlled Concurrency

Instead of hoping for lucky timing, **control the interleaving**:

1. **Injection points** — Add hooks that let tests control when operations proceed
2. **Barriers and gates** — Use synchronization primitives to force specific orderings
3. **Mocks with delays** — Simulate slow operations to widen race windows
4. **Repetition with variation** — Run tests many times with randomized timing

---

## Testing Infrastructure

### Base Test Utilities

```swift
import XCTest

/// Utility for running concurrent operations with controlled timing
enum ConcurrencyTestUtils {

    /// Run an operation multiple times concurrently and collect results
    static func runConcurrently<T: Sendable>(
        count: Int,
        operation: @escaping @Sendable (Int) async throws -> T
    ) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for i in 0..<count {
                group.addTask {
                    (i, try await operation(i))
                }
            }

            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Run two operations with a gate to control ordering
    static func runWithOrdering<A: Sendable, B: Sendable>(
        first: @escaping @Sendable () async throws -> A,
        second: @escaping @Sendable () async throws -> B,
        firstCompletesBeforeSecondStarts: Bool
    ) async throws -> (A, B) {
        if firstCompletesBeforeSecondStarts {
            let a = try await first()
            let b = try await second()
            return (a, b)
        } else {
            // Run concurrently
            async let a = first()
            async let b = second()
            return try await (a, b)
        }
    }
}

/// A gate that blocks until opened
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }
}

/// A barrier that waits for N parties before proceeding
actor Barrier {
    private let count: Int
    private var arrived = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(count: Int) {
        self.count = count
    }

    func arrive() async {
        arrived += 1
        if arrived >= count {
            // Release everyone
            for waiter in waiters {
                waiter.resume()
            }
            waiters.removeAll()
        } else {
            // Wait for others
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
}
```

### Testable Protocol Pattern

Make components testable by injecting control points:

```swift
/// Protocol for components that need testable timing
protocol TestableComponent {
    /// Hook called before critical operation (tests can inject delays)
    var beforeCriticalOperation: (@Sendable () async -> Void)? { get set }

    /// Hook called after critical operation
    var afterCriticalOperation: (@Sendable () async -> Void)? { get set }
}
```

---

## Race Condition Testing

### Pattern 1: Response-Before-Registration Race

**Bug pattern:** Registration of a handler/continuation happens asynchronously, but the response can arrive before registration completes.

```swift
final class RegistrationRaceTests: XCTestCase {

    /// Test that responses arriving before registration are handled correctly
    func testResponseBeforeRegistration() async throws {
        let handler = TestableControlProtocolHandler()
        let gate = Gate()

        // Inject delay AFTER sending request but BEFORE registering continuation
        handler.beforeRegisterContinuation = {
            await gate.wait()  // Block until we manually open
        }

        // Start the request (will block at registration)
        let requestTask = Task {
            try await handler.sendRequest(.interrupt)
        }

        // Give the request time to send but block at registration
        try await Task.sleep(nanoseconds: 10_000_000)  // 10ms

        // Simulate response arriving BEFORE registration
        handler.simulateResponse(requestId: handler.lastRequestId!, success: true)

        // Now let registration proceed
        await gate.open()

        // The request should either:
        // - FAIL: If bug exists (response was dropped, request times out)
        // - SUCCEED: If fixed (response was queued or registration happened first)

        do {
            let result = try await withTimeout(seconds: 1) {
                try await requestTask.value
            }
            // If we get here quickly, the bug is fixed
            XCTAssertNotNil(result)
        } catch is TimeoutError {
            XCTFail("Request hung - response was dropped due to registration race")
        }
    }
}

/// Helper for timeout
struct TimeoutError: Error {}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

### Pattern 2: Concurrent Modification Race

**Bug pattern:** Multiple threads modify shared state without proper synchronization.

```swift
final class ConcurrentModificationTests: XCTestCase {

    /// Stress test concurrent access to shared state
    func testConcurrentStateAccess() async throws {
        let component = SharedStateComponent()

        // Run many concurrent operations
        let results = try await ConcurrencyTestUtils.runConcurrently(count: 100) { i in
            if i % 2 == 0 {
                await component.write(value: i)
            } else {
                return await component.read()
            }
        }

        // Verify invariants
        // - No crashes (implicit)
        // - Values are consistent (depending on semantics)
    }

    /// Test specific interleaving that triggers the bug
    func testSpecificRaceInterleaving() async throws {
        let component = SharedStateComponent()
        let barrier = Barrier(count: 2)

        // Force two operations to start at exactly the same time
        async let op1: Void = {
            await barrier.arrive()  // Wait for both to be ready
            await component.write(value: 1)
        }()

        async let op2: Void = {
            await barrier.arrive()  // Wait for both to be ready
            await component.write(value: 2)
        }()

        _ = await (op1, op2)

        // Verify final state is valid (either 1 or 2, not corrupted)
        let finalValue = await component.read()
        XCTAssertTrue(finalValue == 1 || finalValue == 2,
            "State corrupted: got \(finalValue)")
    }
}
```

### Pattern 3: TOCTOU (Time-of-Check-Time-of-Use)

**Bug pattern:** State is checked, then used, but can change between check and use.

```swift
final class TOCTOUTests: XCTestCase {

    /// Test that concurrent close() calls don't cause double-close
    func testConcurrentClose() async throws {
        let transport = TestableTransport()

        // Track how many times close actually executes
        var closeCount = 0
        let lock = NSLock()

        transport.onActualClose = {
            lock.withLock { closeCount += 1 }
        }

        // Call close() from many threads simultaneously
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await transport.close()
                }
            }
        }

        // Should only close once
        XCTAssertEqual(closeCount, 1, "close() executed \(closeCount) times, expected 1")
    }

    /// Test that check-then-act is atomic
    func testCheckThenActAtomicity() async throws {
        let resource = ConditionalResource()

        // Try to acquire from multiple tasks simultaneously
        let results = try await ConcurrencyTestUtils.runConcurrently(count: 10) { _ in
            await resource.acquireIfAvailable()
        }

        // Only one should succeed
        let successCount = results.filter { $0 }.count
        XCTAssertEqual(successCount, 1, "Resource acquired \(successCount) times, expected 1")
    }
}
```

---

## AsyncSequence & Stream Testing

### Pattern 4: Single-Consumer Violation

**Bug pattern:** AsyncSequence is iterated by multiple consumers, causing message loss.

```swift
final class SingleConsumerTests: XCTestCase {

    /// Test that multiple iterations cause failure or are prevented
    func testMultipleIterationPrevented() async throws {
        let stream = makeSingleConsumerStream()

        // First iteration should work
        var iterator1 = stream.makeAsyncIterator()
        _ = try await iterator1.next()

        // Second iteration should either:
        // - Throw an error (preferred)
        // - Return the same iterator (acceptable)
        // - NOT silently create a broken second iterator

        var iterator2 = stream.makeAsyncIterator()

        // If we can get different values from both iterators, that's a bug
        // Messages are being split between consumers
    }

    /// Test that messages aren't lost when iterating
    func testNoMessageLoss() async throws {
        let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()

        // Send messages
        for i in 0..<100 {
            continuation.yield(i)
        }
        continuation.finish()

        // Collect all messages
        var received: [Int] = []
        for try await value in stream {
            received.append(value)
        }

        XCTAssertEqual(received, Array(0..<100), "Messages lost or reordered")
    }
}
```

### Pattern 5: Stream Orphaning

**Bug pattern:** A stream's continuation is replaced, orphaning consumers of the old stream.

```swift
final class StreamOrphaningTests: XCTestCase {

    /// Test that calling readMessages() twice doesn't orphan the first stream
    func testReadMessagesCalledTwice() async throws {
        let transport = ProcessTransport(command: "echo test")

        let stream1 = transport.readMessages()
        let stream2 = transport.readMessages()  // Should this throw? Return same? Replace?

        // Start consuming stream1
        let consumer1 = Task {
            var count = 0
            for try await _ in stream1 {
                count += 1
                if count > 10 { break }  // Safety limit
            }
            return count
        }

        // If stream1 is orphaned, this will hang
        let result = try await withTimeout(seconds: 2) {
            try await consumer1.value
        }

        // Should have received messages OR thrown an error
        // Should NOT have hung
    }

    /// Test that stream properly finishes on component deallocation
    func testStreamFinishesOnDealloc() async throws {
        var component: StreamingComponent? = StreamingComponent()
        let stream = component!.startStream()

        // Start consuming
        let consumer = Task {
            var messages: [String] = []
            do {
                for try await msg in stream {
                    messages.append(msg)
                }
            } catch {
                // Should throw SessionError.closed or similar
                throw error
            }
            return messages
        }

        // Deallocate while consuming
        component = nil

        // Consumer should finish (with error, not silently)
        do {
            _ = try await withTimeout(seconds: 1) {
                try await consumer.value
            }
            XCTFail("Stream finished silently - should have thrown error")
        } catch is ComponentClosedError {
            // Expected - component closure was properly signaled
        } catch is TimeoutError {
            XCTFail("Stream hung after component deallocation")
        }
    }
}
```

---

## Task Lifecycle Testing

### Pattern 6: Untracked Task Completion

**Bug pattern:** A Task is spawned but not tracked, so callers can't wait for completion.

```swift
final class TaskLifecycleTests: XCTestCase {

    /// Test that cancel() completes before returning (or provides completion signal)
    func testCancelCompletion() async throws {
        let backend = NativeBackend()

        // Start a long-running query
        let query = try await backend.runSinglePrompt(prompt: "test", options: .init())

        // Cancel and measure how long it takes
        let cancelStart = ContinuousClock.now
        await backend.cancel()  // Should this be async?
        let cancelDuration = ContinuousClock.now - cancelStart

        // If cancel() returns immediately with untracked Task,
        // the actual cancellation is still in progress

        // Try to start a new query immediately
        let newQuery = try await backend.runSinglePrompt(prompt: "test2", options: .init())

        // This should work without racing with the cancellation
        // If it fails intermittently, cancel() doesn't properly wait
    }

    /// Test that spawned tasks don't leak
    func testNoTaskLeaks() async throws {
        weak var weakTask: Task<Void, Never>?

        do {
            let component = TaskSpawningComponent()
            weakTask = component.spawnedTask

            // Trigger operation that spawns task
            component.doSomething()

            // Component goes out of scope
        }

        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000)

        // Task should have completed and been released
        // (This test is imperfect - GC timing varies)
    }
}
```

### Pattern 7: Task Cancellation Propagation

**Bug pattern:** Cancellation doesn't propagate to child tasks or cleanup doesn't run.

```swift
final class CancellationTests: XCTestCase {

    /// Test that cancellation propagates to child operations
    func testCancellationPropagates() async throws {
        let component = CancellableComponent()
        var childWasCancelled = false

        component.onChildCancellation = {
            childWasCancelled = true
        }

        let task = Task {
            try await component.longRunningOperation()
        }

        // Let it start
        try await Task.sleep(nanoseconds: 10_000_000)

        // Cancel
        task.cancel()

        // Wait for cancellation to propagate
        try? await task.value

        XCTAssertTrue(childWasCancelled, "Cancellation didn't propagate to child")
    }

    /// Test that cleanup runs even when cancelled
    func testCleanupRunsOnCancellation() async throws {
        let component = CleanupComponent()

        let task = Task {
            try await component.operationWithCleanup()
        }

        // Let it start
        try await Task.sleep(nanoseconds: 10_000_000)

        // Cancel
        task.cancel()
        try? await task.value

        // Cleanup should have run
        XCTAssertTrue(component.cleanupDidRun, "Cleanup didn't run on cancellation")
    }
}
```

---

## Lock & Synchronization Testing

### Pattern 8: Lock Ordering / Deadlock Detection

**Bug pattern:** Locks acquired in inconsistent order cause deadlocks.

```swift
final class DeadlockTests: XCTestCase {

    /// Test that operations don't deadlock
    func testNoDeadlock() async throws {
        let component = MultiLockComponent()

        // Run operations that acquire multiple locks
        let task = Task {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        if i % 2 == 0 {
                            await component.operationAB()  // Acquires A then B
                        } else {
                            await component.operationBA()  // Acquires B then A (potential deadlock!)
                        }
                    }
                }
                try await group.waitForAll()
            }
        }

        // Should complete within timeout (deadlock = hang)
        do {
            try await withTimeout(seconds: 5) {
                try await task.value
            }
        } catch is TimeoutError {
            XCTFail("Deadlock detected - operations hung")
        }
    }
}
```

### Pattern 9: Lock Held During Await

**Bug pattern:** Lock is held while awaiting, blocking other threads.

```swift
final class LockDuringAwaitTests: XCTestCase {

    /// Test that locks aren't held during async operations
    func testLockNotHeldDuringAwait() async throws {
        let component = LockingComponent()

        // Start slow operation that should release lock during await
        let slowTask = Task {
            await component.slowOperationThatAwaits()
        }

        // Give it time to start and hit the await point
        try await Task.sleep(nanoseconds: 50_000_000)

        // This should NOT block if lock was released during await
        let fastTask = Task {
            await component.fastOperation()
        }

        // Fast operation should complete quickly
        do {
            try await withTimeout(seconds: 0.5) {
                await fastTask.value
            }
        } catch is TimeoutError {
            XCTFail("Fast operation blocked - lock held during await")
        }

        slowTask.cancel()
    }
}
```

---

## Resource Leak Testing

### Pattern 10: Temp File Cleanup

**Bug pattern:** Temporary resources aren't cleaned up.

```swift
final class ResourceLeakTests: XCTestCase {

    /// Test that temp files are cleaned up
    func testTempFileCleanup() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let filesBefore = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }

        // Run multiple queries
        for _ in 0..<10 {
            let query = try await ClaudeCode.query("test", options: .init())
            // Don't actually iterate, just create and discard
        }

        // Force cleanup
        try await Task.sleep(nanoseconds: 100_000_000)

        let filesAfter = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("mcp-config-") }

        XCTAssertEqual(filesBefore.count, filesAfter.count,
            "Leaked \(filesAfter.count - filesBefore.count) temp files")
    }

    /// Test that resources are released on error paths
    func testResourceCleanupOnError() async throws {
        let component = ResourceHoldingComponent()

        do {
            try await component.operationThatFails()
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }

        // Resource should be released even though we threw
        XCTAssertFalse(component.isHoldingResource,
            "Resource not released on error path")
    }
}
```

---

## Actor Isolation Testing

### Pattern 11: Actor Reentrancy

**Bug pattern:** Actor method suspends, another call modifies state, first call sees inconsistent state.

```swift
final class ActorReentrancyTests: XCTestCase {

    /// Test that actor handles reentrant calls correctly
    func testReentrancyDoesntCorruptState() async throws {
        let actor = StatefulActor()

        // Start operation that will suspend
        let task1 = Task {
            await actor.incrementWithSuspension()
        }

        // Give it time to start and suspend
        try await Task.sleep(nanoseconds: 10_000_000)

        // Call again while first is suspended
        let task2 = Task {
            await actor.incrementWithSuspension()
        }

        await task1.value
        await task2.value

        // State should be consistent (2, not 1 or corrupted)
        let finalValue = await actor.value
        XCTAssertEqual(finalValue, 2, "Actor state corrupted by reentrancy")
    }
}

actor StatefulActor {
    var value = 0

    func incrementWithSuspension() async {
        let current = value
        await Task.yield()  // Suspension point - reentrancy can occur
        value = current + 1  // BUG: Uses stale 'current' if reentrant
    }
}
```

---

## Tooling

### Thread Sanitizer (TSan)

Enable in Xcode: Edit Scheme → Test → Diagnostics → Thread Sanitizer

```bash
# Command line
swift test --sanitize=thread
```

TSan detects:
- Data races
- Use of uninitialized mutexes
- Unlock from wrong thread

### XCTest Async Support

```swift
// Async test methods
func testAsyncOperation() async throws {
    let result = try await someAsyncOperation()
    XCTAssertEqual(result, expected)
}

// Expectations for callback-based code
func testCallbackOperation() async throws {
    let expectation = expectation(description: "callback called")

    component.doSomething { result in
        XCTAssertEqual(result, expected)
        expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 5)
}
```

### Custom Test Assertions

```swift
/// Assert that an async operation completes within timeout
func XCTAssertCompletesWithin<T>(
    seconds: TimeInterval,
    _ operation: @escaping () async throws -> T,
    _ message: String = "Operation timed out",
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await withTimeout(seconds: seconds, operation: operation)
    } catch is TimeoutError {
        XCTFail(message, file: file, line: line)
    } catch {
        // Other errors are fine - we're just testing for hangs
    }
}

/// Assert that an operation hangs (useful for testing broken states)
func XCTAssertHangs<T>(
    seconds: TimeInterval = 0.5,
    _ operation: @escaping () async throws -> T,
    _ message: String = "Operation should have hung but completed",
    file: StaticString = #file,
    line: UInt = #line
) async {
    do {
        _ = try await withTimeout(seconds: seconds, operation: operation)
        XCTFail(message, file: file, line: line)
    } catch is TimeoutError {
        // Expected - it hung
    } catch {
        XCTFail("Operation threw instead of hanging: \(error)", file: file, line: line)
    }
}
```

---

## Test Patterns Reference

### Quick Reference Table

| Bug Type | Test Strategy | Key Technique |
|----------|---------------|---------------|
| Registration race | Inject delay before registration | Gate/barrier |
| TOCTOU | Concurrent calls to same operation | Barrier for simultaneous start |
| Stream orphaning | Multiple readMessages() calls | Timeout detection |
| Silent failure | Check for thrown error vs silent finish | Assert error type |
| Untracked task | Check completion timing | Immediate follow-up operation |
| Deadlock | Concurrent lock acquisition | Timeout detection |
| Resource leak | Count resources before/after | File system inspection |
| Actor reentrancy | Concurrent calls with suspension | Assert final state |

### Test Naming Convention

```swift
func test_<Component>_<Scenario>_<ExpectedBehavior>() async throws {
    // Example: test_Transport_ConcurrentClose_OnlyClosesOnce
}
```

### Test Organization

```
Tests/
├── ConcurrencyTests/
│   ├── RaceConditionTests.swift       # Registration, TOCTOU, etc.
│   ├── AsyncSequenceTests.swift       # Stream, iteration, orphaning
│   ├── TaskLifecycleTests.swift       # Cancellation, tracking
│   ├── LockingTests.swift             # Deadlock, lock discipline
│   └── ResourceTests.swift            # Leaks, cleanup
├── Utilities/
│   ├── ConcurrencyTestUtils.swift     # Shared helpers
│   ├── Gate.swift                     # Synchronization primitives
│   └── Barrier.swift
└── Mocks/
    └── TestableTransport.swift        # Mocks with injection points
```

---

## Checklist: Adding Concurrency Tests

When adding a new concurrent component:

- [ ] Identify all shared mutable state
- [ ] Identify all suspension points (await)
- [ ] For each state + suspension combination, write a reentrancy test
- [ ] For each public method, write a concurrent-call test
- [ ] For any check-then-act pattern, write a TOCTOU test
- [ ] For any spawned Task, verify it's tracked or fire-and-forget is acceptable
- [ ] For any AsyncSequence, test single-consumer invariant
- [ ] For any resources (files, connections), test cleanup
- [ ] Run all tests with TSan enabled
- [ ] Run tests in loop (100+ iterations) to catch intermittent races

---

## Example: Complete Test Suite for a Transport

```swift
final class TransportConcurrencyTests: XCTestCase {

    // MARK: - Race Conditions

    func test_readMessages_calledTwice_secondCallFailsOrReturnsSame() async throws { }
    func test_write_duringClose_failsGracefully() async throws { }
    func test_close_calledConcurrently_onlyClosesOnce() async throws { }

    // MARK: - Stream Lifecycle

    func test_stream_finishesOnClose() async throws { }
    func test_stream_finishesOnProcessExit() async throws { }
    func test_stream_deliversAllMessages() async throws { }

    // MARK: - Resource Management

    func test_close_releasesAllResources() async throws { }
    func test_deinit_closesAutomatically() async throws { }

    // MARK: - Error Handling

    func test_writeAfterClose_throwsNotConnected() async throws { }
    func test_processExitNonZero_throwsError() async throws { }
}
```

---

*This guide should be treated as a living document. Update it as new concurrency patterns and testing techniques are discovered.*
