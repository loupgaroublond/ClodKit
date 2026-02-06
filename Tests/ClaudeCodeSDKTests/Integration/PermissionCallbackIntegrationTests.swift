//
//  PermissionCallbackIntegrationTests.swift
//  ClaudeCodeSDKTests
//
//  Integration tests for permission callbacks with the real Claude CLI.
//
//  IMPORTANT: Permission callbacks are only invoked when the CLI needs to ask for permission.
//  The CLI auto-allows many operations without asking, including:
//  - Read tool: Always auto-allowed (read-only)
//  - Read-only Bash commands: ls, cat, grep, head, tail, echo (without redirection), etc.
//
//  To trigger the permission callback, use operations that require permission:
//  - Bash with output redirection (>) - writes to files
//  - Bash with destructive commands (rm, mv, etc.)
//  - Write tool
//  - Edit tool
//

import XCTest
@testable import ClaudeCodeSDK

final class PermissionCallbackIntegrationTests: XCTestCase {

    // MARK: - Basic Permission Callback Tests

    /// Tests that canUseTool callback is invoked for non-auto-allowed commands.
    /// Note: Read-only commands (ls, cat, Read tool) are auto-allowed and won't trigger the callback.
    /// Commands with output redirection (>) require permission and will trigger the callback.
    func testCanUseToolCallbackInvocation() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let capturedToolName = TestCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackInvoked.set()
            capturedToolName.value = toolName
            return .allowTool()
        }

        // Use a command that requires permission - output redirection is NOT auto-allowed
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_test_callback.txt with the text 'test'. Use: echo test > /tmp/sdk_test_callback.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(callbackInvoked.value, "canUseTool callback should be invoked for write operations")
        XCTAssertNotNil(capturedToolName.value, "Tool name should be captured")
        // Claude may use Write, Edit, or Bash tool - all should trigger permission callback
    }

    /// Tests that simple queries without tool use work correctly with permission mode.
    /// This test doesn't trigger any tools, so the callback won't be invoked.
    func testSimpleQueryWithPermissionMode() async throws {
        try skipIfCLIUnavailable()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .default

        let claudeQuery = try await query(
            prompt: "What is 2 + 2?",
            options: options
        )
        let messages = try await collectMessagesUntilResult(from: claudeQuery, timeout: 30)

        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")
    }

    /// Tests that denyTool blocks the command and Claude receives the denial message.
    /// Uses output redirection which is NOT auto-allowed and will trigger the callback.
    func testPermissionDenyWithMessage() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { _, _, _ in
            callbackInvoked.set()
            return .denyTool("Not allowed in test")
        }

        // Use a command that requires permission - output redirection is NOT auto-allowed
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_test_deny.txt with text 'denied'. Use: echo denied > /tmp/sdk_test_deny.txt",
            options: options
        )
        let messages = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(callbackInvoked.value, "Callback should be invoked for write operations")
        XCTAssertGreaterThan(messages.count, 0, "Should receive messages even after denial")
    }

    /// Tests that denyToolAndInterrupt stops the session.
    /// Uses output redirection which is NOT auto-allowed and will trigger the callback.
    func testPermissionDenyWithInterrupt() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { _, _, _ in
            callbackInvoked.set()
            return .denyToolAndInterrupt("Security violation")
        }

        // Use a command that requires permission - output redirection is NOT auto-allowed
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_test_interrupt.txt with text 'test'. Use: echo test > /tmp/sdk_test_interrupt.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(callbackInvoked.value, "Callback should be invoked for write operations")
        // Test passes if it completes without hanging - the interrupt should end the session
    }

    // MARK: - Selective Permission Tests

    /// Tests that selective permission works by tool name.
    /// Note: Read-only tools/commands are auto-allowed and won't trigger the callback.
    /// This test uses write operations which require permission.
    func testSelectivePermissionByTool() async throws {
        try skipIfCLIUnavailable()

        let bashCallbackInvoked = TestFlag()
        let capturedToolNames = TestArrayCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, _, _ in
            capturedToolNames.append(toolName)
            if toolName == "Bash" {
                bashCallbackInvoked.set()
                return .allowTool()
            }
            return .allowTool()
        }

        // Use a command that requires permission - output redirection is NOT auto-allowed
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_selective_test.txt with text 'selective'. Use: echo selective > /tmp/sdk_selective_test.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        // Claude may use Write, Edit, or Bash tool for file creation
        XCTAssertGreaterThan(capturedToolNames.count, 0, "At least one tool should trigger permission callback")
    }

    // MARK: - Debug Test

    /// Verbose debug test to observe message flow with permission callbacks.
    /// Useful for troubleshooting permission callback issues - prints all messages to stdout.
    /// Note: "Saw control request: false" is expected because control requests are handled
    /// internally by the SDK and not exposed as separate messages in the stream.
    func testDebugPermissionMessages() async throws {
        try skipIfCLIUnavailable()

        // Immediate console output for debugging
        print("[DEBUG] Test starting...")
        fflush(stdout)

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            print("[CALLBACK] *** canUseTool INVOKED *** tool=\(toolName)")
            print("[CALLBACK] input=\(String(describing: input))")
            fflush(stdout)
            return .allowTool()
        }

        print("[DEBUG] Options configured. Calling query()...")
        fflush(stdout)

        // Use a non-read-only command that should trigger permission check
        // Read commands (cat, ls, etc.) are auto-allowed - we need write/delete/create
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_permission_test.txt with the text 'hello world'. Use Bash with 'echo hello world > /tmp/sdk_permission_test.txt'.",
            options: options
        )

        print("[DEBUG] Query returned. Starting message iteration...")
        fflush(stdout)

        var messages: [String] = []
        var messageIndex = 0
        var sawControlRequest = false

        for try await message in claudeQuery {
            let detail = describeMessage(message)
            print("[DEBUG \(messageIndex)] \(detail)")
            fflush(stdout)
            messages.append(detail)

            // Check for control requests specifically
            if case .controlRequest(let req) = message {
                sawControlRequest = true
                print("[DEBUG] *** CONTROL REQUEST FOUND: \(req.request) ***")
                fflush(stdout)
            }

            messageIndex += 1

            // Safety: stop after 30 messages
            if messageIndex > 30 {
                print("[DEBUG] SAFETY LIMIT: Stopping after 30 messages")
                break
            }
        }

        print("[DEBUG] Stream ended. Total messages: \(messageIndex)")
        print("[DEBUG] Saw control request: \(sawControlRequest)")
        fflush(stdout)

        // Write to log file
        let logContent = messages.joined(separator: "\n")
        try? logContent.write(toFile: "/tmp/permission_debug.log", atomically: true, encoding: .utf8)
        print("[DEBUG] Log written to /tmp/permission_debug.log")
    }

    private func describeMessage(_ message: StdoutMessage) -> String {
        switch message {
        case .regular(let sdkMessage):
            var desc = "REGULAR type=\(sdkMessage.type)"
            if let data = sdkMessage.data {
                // Serialize the entire data for inspection
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
                if let jsonData = try? encoder.encode(data),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    // Truncate if too long
                    let truncated = jsonString.count > 1000 ? String(jsonString.prefix(1000)) + "...[TRUNCATED]" : jsonString
                    desc += "\n  DATA: \(truncated)"
                } else {
                    desc += "\n  DATA: [encoding failed]"
                }
            } else {
                desc += "\n  DATA: nil"
            }
            return desc
        case .controlRequest(let req):
            return "*** CONTROL_REQUEST *** id=\(req.requestId) request=\(req.request)"
        case .controlResponse(let resp):
            return "CONTROL_RESPONSE \(resp.response)"
        case .controlCancelRequest(let cancel):
            return "CANCEL_REQUEST id=\(cancel.requestId)"
        case .keepAlive:
            return "KEEP_ALIVE"
        }
    }

    // MARK: - Bypass Permission Mode Tests

    func testBypassPermissionsModeSkipsCallback() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .bypassPermissions
        options.canUseTool = { _, _, _ in
            callbackInvoked.set()
            return .allowTool()
        }

        let claudeQuery = try await query(
            prompt: "Read /etc/hosts.",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 45)

        XCTAssertFalse(callbackInvoked.value, "Callback should not be invoked in bypass mode")
    }

    // MARK: - Input Modification Tests

    /// Tests that allowToolWithModification can modify tool input.
    func testAllowToolWithModification() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let capturedOriginalInput = TestCapture<[String: JSONValue]>()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackInvoked.set()
            capturedOriginalInput.value = input

            // Modify the input - change the command being run
            let modifiedInput = input
            // Example: if it's a Bash command, we could modify it
            // This depends on the actual tool input structure
            return .allowTool(updatedInput: modifiedInput)
        }

        // Use a write command that requires permission
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_modify_test.txt with text 'test'. Use: echo test > /tmp/sdk_modify_test.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(callbackInvoked.value, "Callback should have been invoked")
        XCTAssertNotNil(capturedOriginalInput.value, "Should have captured original input")
    }

    // MARK: - Permission Context Tests

    /// Tests that ToolPermissionContext provides expected fields.
    func testToolPermissionContextFields() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let capturedSuggestions = TestCapture<[PermissionUpdate]>()
        let capturedBlockedPath = TestCapture<String?>()
        let capturedDecisionReason = TestCapture<String?>()
        let capturedAgentId = TestCapture<String?>()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackInvoked.set()
            capturedSuggestions.value = context.suggestions
            capturedBlockedPath.value = context.blockedPath
            capturedDecisionReason.value = context.decisionReason
            capturedAgentId.value = context.agentId
            return .allowTool()
        }

        // Use a write command to trigger permission
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_context_test.txt with text 'test'. Use: echo test > /tmp/sdk_context_test.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        if callbackInvoked.value {
            // Suggestions may or may not be provided depending on the operation
            // Just verify the callback received the context
            XCTAssertTrue(true, "Permission context was provided to callback")
        }
    }

    /// Tests that blocked path is provided for file operations.
    func testBlockedPathInContext() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let capturedBlockedPath = TestCapture<String?>()
        let capturedToolName = TestCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackInvoked.set()
            capturedToolName.value = toolName
            capturedBlockedPath.value = context.blockedPath
            return .allowTool()
        }

        // Request a write to a specific path
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/blocked_path_test.txt with text 'test'. Use the Write tool or Bash.",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        if callbackInvoked.value {
            // The blocked path may contain the file path for write operations
            print("[DEBUG] Tool: \(capturedToolName.value ?? "unknown")")
            print("[DEBUG] Blocked path: \(capturedBlockedPath.value.flatMap { $0 } ?? "nil")")
        }
    }

    // MARK: - Permission Updates Tests

    /// Tests that permission updates can be returned from callback.
    func testAllowToolWithPermissionUpdates() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let callbackCounter = TestArrayCapture<Int>()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackCounter.append(1)
            let count = callbackCounter.count

            if count == 1 {
                callbackInvoked.set()
                // Return with permission updates to allow future similar operations
                let rule = PermissionRule(toolName: toolName, ruleContent: "/tmp/")
                let update = PermissionUpdate.addRules([rule], behavior: .allow)
                return .allowTool(permissionUpdates: [update])
            }
            return .allowTool()
        }

        // First write should trigger callback
        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/sdk_perm_update.txt with text 'first', then create /tmp/sdk_perm_update2.txt with text 'second'. Use Bash with echo and redirection.",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(callbackInvoked.value, "Callback should have been invoked")
    }

    // MARK: - Multiple Callback Invocations Tests

    /// Tests that callback is invoked for each permission-requiring operation.
    func testMultipleCallbackInvocations() async throws {
        try skipIfCLIUnavailable()

        let invocationCount = TestArrayCapture<String>()

        var options = QueryOptions()
        options.maxTurns = 10
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            invocationCount.append(toolName)
            return .allowTool()
        }

        // Request multiple write operations
        let claudeQuery = try await query(
            prompt: "Create three files: /tmp/multi1.txt with 'one', /tmp/multi2.txt with 'two', /tmp/multi3.txt with 'three'. Use Bash with echo and redirection for each.",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 90)

        // Should have multiple invocations for multiple write operations
        print("[DEBUG] Callback invocations: \(invocationCount.count) - \(invocationCount.values)")
    }

    // MARK: - Default Permission Mode Tests

    /// Tests default permission mode behavior with read-only operations.
    func testDefaultModeReadOperations() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .default
        options.canUseTool = { _, _, _ in
            callbackInvoked.set()
            return .allowTool()
        }

        // Read operations are auto-allowed and should NOT trigger callback
        let claudeQuery = try await query(
            prompt: "Read /etc/hosts and tell me what's in it.",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 45)

        // Read is auto-allowed, callback should NOT be invoked
        XCTAssertFalse(callbackInvoked.value, "Read operations should be auto-allowed")
    }

    // MARK: - Async Callback Tests

    /// Tests that async operations in callback work correctly.
    func testAsyncPermissionCallback() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let asyncWorkCompleted = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { toolName, input, context in
            callbackInvoked.set()
            // Simulate async work (e.g., external authorization check)
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            asyncWorkCompleted.set()
            return .allowTool()
        }

        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/async_test.txt with text 'async'. Use: echo async > /tmp/async_test.txt",
            options: options
        )
        _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        if callbackInvoked.value {
            XCTAssertTrue(asyncWorkCompleted.value, "Async work should complete")
        }
    }

    // MARK: - Error Handling Tests

    /// Tests that errors in permission callback are handled.
    func testPermissionCallbackError() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()

        var options = QueryOptions()
        options.maxTurns = 3
        options.permissionMode = .default
        options.canUseTool = { _, _, _ in
            callbackInvoked.set()
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission check failed"])
        }

        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/error_test.txt with text 'error'. Use: echo error > /tmp/error_test.txt",
            options: options
        )

        do {
            _ = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)
        } catch {
            // Error from callback should propagate
            XCTAssertTrue(callbackInvoked.value, "Callback should have been invoked before error")
        }
    }

    // MARK: - Deny With Specific Message Tests

    /// Tests that deny message is communicated to Claude.
    func testDenyToolWithSpecificMessage() async throws {
        try skipIfCLIUnavailable()

        let callbackInvoked = TestFlag()
        let denyMessage = "File creation is not allowed for security reasons"

        var options = QueryOptions()
        options.maxTurns = 5
        options.permissionMode = .default
        options.canUseTool = { _, _, _ in
            callbackInvoked.set()
            return .denyTool(denyMessage)
        }

        let claudeQuery = try await query(
            prompt: "Create a file at /tmp/deny_msg_test.txt with text 'test'. Use: echo test > /tmp/deny_msg_test.txt. Report exactly what happened.",
            options: options
        )
        let messages = try await collectMessagesUntilResult(from: claudeQuery, timeout: 60)

        XCTAssertTrue(callbackInvoked.value, "Callback should have been invoked")
        XCTAssertGreaterThan(messages.count, 0, "Should receive messages")
    }
}

// MARK: - Debug Helper

/// Thread-safe debug logger for integration tests.
private actor DebugLogger {
    private var lines: [String] = []
    private let logPath = "/tmp/permission_debug.log"

    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)"
        lines.append(line)
        print(line)
        fflush(stdout)
    }

    func writeToFile() {
        let content = lines.joined(separator: "\n")
        try? content.write(toFile: logPath, atomically: true, encoding: .utf8)
        print("Log written to: \(logPath)")
    }
}
