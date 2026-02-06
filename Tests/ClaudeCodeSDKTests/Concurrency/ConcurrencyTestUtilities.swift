//
//  ConcurrencyTestUtilities.swift
//  ClaudeCodeSDKTests
//
//  Utilities for testing concurrency issues: races, deadlocks, resource leaks.
//  These utilities help write deterministic tests for timing-dependent bugs.
//

import XCTest
@testable import ClaudeCodeSDK

// MARK: - Test Mode Configuration

/// Configuration for different test modes.
/// Use environment variables to select mode:
///   TEST_MODE=coverage     - Standard tests with coverage
///   TEST_MODE=concurrency  - Stress tests for race conditions
///   TEST_MODE=integration  - Full integration tests with real CLI
enum TestMode {
    case coverage
    case concurrency
    case integration

    static var current: TestMode {
        switch ProcessInfo.processInfo.environment["TEST_MODE"]?.lowercased() {
        case "concurrency", "stress", "perf":
            return .concurrency
        case "integration", "full":
            return .integration
        default:
            return .coverage
        }
    }

    /// Number of iterations for stress tests
    var stressIterations: Int {
        switch self {
        case .coverage: return 10
        case .concurrency: return 100
        case .integration: return 5
        }
    }

    /// Number of concurrent operations for race tests
    var concurrentOperations: Int {
        switch self {
        case .coverage: return 5
        case .concurrency: return 50
        case .integration: return 3
        }
    }

    /// Timeout multiplier for slow environments
    var timeoutMultiplier: Double {
        switch self {
        case .coverage: return 1.0
        case .concurrency: return 2.0
        case .integration: return 3.0
        }
    }
}

// MARK: - Timeout Error

/// Error thrown when an operation times out.
struct TimeoutError: Error, Equatable {
    let seconds: TimeInterval
    let operation: String

    init(seconds: TimeInterval, operation: String = "Operation") {
        self.seconds = seconds
        self.operation = operation
    }
}

extension TimeoutError: LocalizedError {
    var errorDescription: String? {
        "\(operation) timed out after \(seconds) seconds"
    }
}

// MARK: - Timeout Helper

/// Run an async operation with a timeout.
/// - Parameters:
///   - seconds: Maximum time to wait
///   - operation: Description for error messages
///   - work: The async work to perform
/// - Returns: The result of the work
/// - Throws: TimeoutError if the operation doesn't complete in time
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: String = "Operation",
    work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await work()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError(seconds: seconds, operation: operation)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - Gate (Single-Use Barrier)

/// A gate that blocks waiters until opened.
/// Use to control ordering in tests: make one operation wait for another.
actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Wait until the gate is opened. Returns immediately if already open.
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Open the gate, releasing all waiters.
    func open() {
        isOpen = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }

    /// Check if the gate is open without waiting.
    var opened: Bool {
        isOpen
    }
}

// MARK: - Barrier (Multi-Party Synchronization)

/// A barrier that waits for N parties before all proceed.
/// Use to start multiple operations at exactly the same time.
actor Barrier {
    private let count: Int
    private var arrived = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(count: Int) {
        precondition(count > 0, "Barrier count must be positive")
        self.count = count
    }

    /// Arrive at the barrier and wait for others.
    /// Once `count` parties have arrived, all are released.
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

    /// Number of parties that have arrived.
    var arrivedCount: Int {
        arrived
    }
}

// MARK: - Concurrent Runner

/// Utilities for running concurrent operations in tests.
enum ConcurrencyTestRunner {

    /// Run an operation multiple times concurrently and collect results.
    /// - Parameters:
    ///   - count: Number of concurrent operations
    ///   - operation: The operation to run (receives index 0..<count)
    /// - Returns: Results in index order
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

    /// Run an operation multiple times concurrently, all starting at the same time.
    /// Uses a barrier to synchronize the start.
    static func runSimultaneously<T: Sendable>(
        count: Int,
        operation: @escaping @Sendable (Int) async throws -> T
    ) async throws -> [T] {
        let barrier = Barrier(count: count)

        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for i in 0..<count {
                group.addTask {
                    await barrier.arrive()  // Wait for all to be ready
                    return (i, try await operation(i))
                }
            }

            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Run operation repeatedly and check if any iteration fails.
    /// Useful for stress testing race conditions.
    static func stressTest(
        iterations: Int,
        operation: @escaping @Sendable (Int) async throws -> Void
    ) async throws {
        for i in 0..<iterations {
            try await operation(i)
        }
    }
}

// MARK: - Thread-Safe Counters

/// Thread-safe counter for tracking concurrent operations.
final class AtomicCounter: @unchecked Sendable {
    private var _value: Int
    private let lock = NSLock()

    init(_ initial: Int = 0) {
        _value = initial
    }

    var value: Int {
        lock.withLock { _value }
    }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            _value += 1
            return _value
        }
    }

    @discardableResult
    func decrement() -> Int {
        lock.withLock {
            _value -= 1
            return _value
        }
    }

    func reset() {
        lock.withLock { _value = 0 }
    }
}

/// Thread-safe flag for tracking events.
final class AtomicFlag: @unchecked Sendable {
    private var _value: Bool
    private let lock = NSLock()

    init(_ initial: Bool = false) {
        _value = initial
    }

    var value: Bool {
        lock.withLock { _value }
    }

    func set() {
        lock.withLock { _value = true }
    }

    func clear() {
        lock.withLock { _value = false }
    }

    /// Set the flag and return the previous value.
    @discardableResult
    func testAndSet() -> Bool {
        lock.withLock {
            let old = _value
            _value = true
            return old
        }
    }
}

/// Thread-safe value capture.
final class AtomicValue<T: Sendable>: @unchecked Sendable {
    private var _value: T?
    private let lock = NSLock()

    init(_ initial: T? = nil) {
        _value = initial
    }

    var value: T? {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}

/// Thread-safe array for collecting values.
final class AtomicArray<T: Sendable>: @unchecked Sendable {
    private var _values: [T] = []
    private let lock = NSLock()

    var values: [T] {
        lock.withLock { _values }
    }

    var count: Int {
        lock.withLock { _values.count }
    }

    func append(_ value: T) {
        lock.withLock { _values.append(value) }
    }

    func clear() {
        lock.withLock { _values.removeAll() }
    }
}

// MARK: - XCTest Extensions for Concurrency

extension XCTestCase {

    /// Assert that an operation completes within timeout.
    func assertCompletesWithin<T: Sendable>(
        seconds: TimeInterval,
        _ operation: @escaping @Sendable () async throws -> T,
        _ message: String = "Operation timed out",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await withTimeout(seconds: seconds, operation: message, work: operation)
        } catch is TimeoutError {
            XCTFail(message, file: file, line: line)
        } catch {
            // Other errors are fine - we're just testing for hangs
        }
    }

    /// Assert that an operation hangs (doesn't complete within timeout).
    /// Useful for verifying that broken code actually hangs.
    func assertHangs<T: Sendable>(
        seconds: TimeInterval = 0.5,
        _ operation: @escaping @Sendable () async throws -> T,
        _ message: String = "Operation should have hung but completed",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await withTimeout(seconds: seconds, work: operation)
            XCTFail(message, file: file, line: line)
        } catch is TimeoutError {
            // Expected - it hung
        } catch {
            XCTFail("Operation threw instead of hanging: \(error)", file: file, line: line)
        }
    }

    /// Skip test if not in concurrency test mode.
    func skipUnlessConcurrencyMode() throws {
        try XCTSkipUnless(
            TestMode.current == .concurrency,
            "Skipping stress test - set TEST_MODE=concurrency to run"
        )
    }

    /// Get stress test iteration count based on test mode.
    var stressIterations: Int {
        TestMode.current.stressIterations
    }

    /// Get concurrent operation count based on test mode.
    var concurrentOperations: Int {
        TestMode.current.concurrentOperations
    }
}

// MARK: - Testable Protocol Pattern

/// Protocol for components that expose hooks for test control.
/// Implement this to allow tests to inject delays and observe internal state.
protocol TestableForConcurrency {
    /// Hook called before critical operations (tests can inject delays).
    var testHook_beforeCriticalSection: (@Sendable () async -> Void)? { get set }

    /// Hook called after critical operations.
    var testHook_afterCriticalSection: (@Sendable () async -> Void)? { get set }
}

// MARK: - Temp File Tracking

/// Track temporary files for leak detection.
final class TempFileTracker: @unchecked Sendable {
    private var trackedPatterns: [String] = []
    private let lock = NSLock()

    /// Start tracking files matching a pattern in the temp directory.
    func track(pattern: String) {
        lock.withLock { trackedPatterns.append(pattern) }
    }

    /// Count files matching tracked patterns.
    func countTrackedFiles() -> Int {
        let tempDir = FileManager.default.temporaryDirectory
        let patterns = lock.withLock { trackedPatterns }

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) else {
            return 0
        }

        return contents.filter { file in
            patterns.contains { pattern in
                file.hasPrefix(pattern) || file.contains(pattern)
            }
        }.count
    }

    /// Get list of tracked files.
    func listTrackedFiles() -> [String] {
        let tempDir = FileManager.default.temporaryDirectory
        let patterns = lock.withLock { trackedPatterns }

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: tempDir.path) else {
            return []
        }

        return contents.filter { file in
            patterns.contains { pattern in
                file.hasPrefix(pattern) || file.contains(pattern)
            }
        }
    }
}
