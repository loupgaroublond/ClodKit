//
//  IntegrationTestHelpers.swift
//  ClaudeCodeSDKTests
//
//  Helper utilities for integration tests that run against the real Claude CLI.
//  These tests require a valid API key and network access.
//

import XCTest
@testable import ClaudeCodeSDK

// MARK: - Integration Test Configuration

/// Configuration for integration tests.
enum IntegrationTestConfig {

    /// Check if Claude CLI is available in PATH.
    static var isClaudeAvailable: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Default timeout for API calls (60 seconds).
    static let apiTimeout: TimeInterval = 60.0

    /// Short timeout for simple queries (30 seconds).
    static let shortTimeout: TimeInterval = 30.0

    /// Extended timeout for complex operations (120 seconds).
    static let extendedTimeout: TimeInterval = 120.0
}

// MARK: - Test Directory Helper

/// Creates an isolated temporary directory for a test and cleans it up after.
/// - Parameter work: The async work to perform with the temp directory.
func withTestDirectory(_ work: (URL) async throws -> Void) async throws {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("sdk-integration-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    defer {
        try? FileManager.default.removeItem(at: tempDir)
    }

    try await work(tempDir)
}

// MARK: - Test Tools

/// Standard test tools for integration testing.
enum TestTools {

    /// Creates an echo tool that returns its input.
    static func echoTool() -> MCPTool {
        MCPTool(
            name: "echo",
            description: "Returns the input message back as output",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "message": .string("The message to echo back")
                ],
                required: ["message"]
            ),
            handler: { args in
                let message = args["message"] as? String ?? "no message"
                return .text("Echo: \(message)")
            }
        )
    }

    /// Creates a failing tool that always throws an error.
    static func failingTool() -> MCPTool {
        MCPTool(
            name: "always_fails",
            description: "A tool that always fails with an error",
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: []
            ),
            handler: { _ in
                throw MCPServerError.invalidArguments("This tool always fails")
            }
        )
    }

    /// Creates an add tool that adds two numbers.
    static func addTool() -> MCPTool {
        MCPTool(
            name: "add",
            description: "Adds two numbers together",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "a": .number("First number"),
                    "b": .number("Second number")
                ],
                required: ["a", "b"]
            ),
            handler: { args in
                let a = (args["a"] as? Double) ?? (args["a"] as? Int).map { Double($0) } ?? 0
                let b = (args["b"] as? Double) ?? (args["b"] as? Int).map { Double($0) } ?? 0
                return .text("Result: \(a + b)")
            }
        )
    }

    /// Creates a slow tool that takes time to respond.
    static func slowTool(delay: TimeInterval = 5.0) -> MCPTool {
        MCPTool(
            name: "slow_operation",
            description: "A tool that takes time to complete",
            inputSchema: JSONSchema(
                type: "object",
                properties: [:],
                required: []
            ),
            handler: { _ in
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return .text("Completed after delay")
            }
        )
    }
}

// MARK: - Thread-Safe Capture

// Note: TestCapture and TestFlag are defined in HookRegistryTests.swift
// They are available to all test files in the same test target.

/// Thread-safe array capture for async tests.
final class TestArrayCapture<T: Sendable>: @unchecked Sendable {
    private var _values: [T] = []
    private let lock = NSLock()

    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _values.count
    }

    func append(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        _values.append(value)
    }

    init() {}
}

// MARK: - Message Extraction Helpers

extension StdoutMessage {
    /// Extract the SDK message if this is a regular message.
    var sdkMessage: SDKMessage? {
        if case .regular(let msg) = self {
            return msg
        }
        return nil
    }

    /// Check if this is a system init message.
    var isSystemInit: Bool {
        sdkMessage?.type == "system"
    }

    /// Check if this is an assistant message.
    var isAssistant: Bool {
        sdkMessage?.type == "assistant"
    }

    /// Check if this is a result message.
    var isResult: Bool {
        sdkMessage?.type == "result"
    }
}

// MARK: - Timeout Support

/// Error thrown when a test operation times out.
struct TestTimeoutError: Error, LocalizedError {
    let seconds: TimeInterval
    let operation: String

    var errorDescription: String? {
        "Test operation '\(operation)' timed out after \(Int(seconds)) seconds"
    }
}

/// Runs an async operation with a timeout.
/// - Parameters:
///   - seconds: Maximum time to wait.
///   - operation: Description of the operation (for error messages).
///   - work: The async work to perform.
/// - Returns: The result of the work.
/// - Throws: `TestTimeoutError` if the timeout is exceeded.
func integrationTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: String = "operation",
    _ work: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await work()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TestTimeoutError(seconds: seconds, operation: operation)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

/// Runs a query and collects all messages with a timeout.
/// - Parameters:
///   - claudeQuery: The query to consume.
///   - timeout: Maximum time to wait (default 60s).
///   - verbose: If true, print each message as it arrives.
/// - Returns: Array of received messages.
func collectMessages(
    from claudeQuery: ClaudeQuery,
    timeout: TimeInterval = 60.0,
    verbose: Bool = false
) async throws -> [StdoutMessage] {
    try await integrationTimeout(seconds: timeout, operation: "collectMessages") {
        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            if verbose {
                printMessage(message, index: messages.count)
            }
            messages.append(message)
        }
        if verbose {
            print("[DEBUG] Stream ended. Total messages: \(messages.count)")
        }
        return messages
    }
}

/// Runs a query and collects messages until a result message is received.
/// This variant is useful when the stream doesn't close properly after completion.
/// - Parameters:
///   - claudeQuery: The query to consume.
///   - timeout: Maximum time to wait (default 60s).
///   - verbose: If true, print each message as it arrives.
/// - Returns: Array of received messages including the result.
func collectMessagesUntilResult(
    from claudeQuery: ClaudeQuery,
    timeout: TimeInterval = 60.0,
    verbose: Bool = false
) async throws -> [StdoutMessage] {
    try await integrationTimeout(seconds: timeout, operation: "collectMessagesUntilResult") {
        var messages: [StdoutMessage] = []
        for try await message in claudeQuery {
            if verbose {
                printMessage(message, index: messages.count)
            }
            messages.append(message)

            // Stop when we receive a result message
            if message.isResult {
                if verbose {
                    print("[DEBUG] Result received. Stopping collection.")
                }
                break
            }
        }
        if verbose {
            print("[DEBUG] Collection complete. Total messages: \(messages.count)")
        }
        return messages
    }
}

/// Prints a message for debugging.
private func printMessage(_ message: StdoutMessage, index: Int) {
    switch message {
    case .regular(let sdkMessage):
        var extra = ""
        if let data = sdkMessage.data {
            // Show subtype for system messages, content preview for others
            if case .object(let obj) = data {
                if let subtype = obj["subtype"], case .string(let s) = subtype {
                    extra = " subtype=\(s)"
                }
                if let content = obj["content"] {
                    let preview = String(describing: content).prefix(100)
                    extra += " content=\(preview)..."
                }
            }
        }
        print("[DEBUG \(index)] REGULAR: type=\(sdkMessage.type)\(extra)")
    case .controlRequest(let req):
        print("[DEBUG \(index)] CONTROL_REQUEST: id=\(req.requestId) request=\(req.request)")
    case .controlResponse(let resp):
        print("[DEBUG \(index)] CONTROL_RESPONSE: \(resp.response)")
    case .controlCancelRequest(let cancel):
        print("[DEBUG \(index)] CANCEL_REQUEST: id=\(cancel.requestId)")
    case .keepAlive:
        print("[DEBUG \(index)] KEEP_ALIVE")
    }
    fflush(stdout)  // Flush output immediately
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Skip test if Claude CLI is not available.
    func skipIfCLIUnavailable() throws {
        try XCTSkipUnless(
            IntegrationTestConfig.isClaudeAvailable,
            "Claude CLI not available - skipping integration test"
        )
    }

    /// Create default query options for integration tests.
    func defaultIntegrationOptions() -> QueryOptions {
        var options = QueryOptions()
        options.maxTurns = 1
        options.permissionMode = .bypassPermissions
        return options
    }

    /// Run an async test with a timeout.
    /// - Parameters:
    ///   - timeout: Maximum time for the test (default 60s).
    ///   - testName: Name of the test for error messages.
    ///   - work: The async test work to perform.
    func runWithTimeout(
        _ timeout: TimeInterval = 60.0,
        testName: String = #function,
        _ work: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await integrationTimeout(seconds: timeout, operation: testName) {
            try await work()
        }
    }
}
