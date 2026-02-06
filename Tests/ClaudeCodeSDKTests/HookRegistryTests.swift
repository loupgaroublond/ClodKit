//
//  HookRegistryTests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for HookRegistry.
//

import XCTest
@testable import ClaudeCodeSDK

// MARK: - Test Helper for Capturing Values in Sendable Closures

/// Thread-safe container for capturing values in async tests.
final class TestCapture<T: Sendable>: @unchecked Sendable {
    private var _value: T?
    private let lock = NSLock()

    var value: T? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }

    init() {}
}

/// Thread-safe boolean flag for tests.
final class TestFlag: @unchecked Sendable {
    private var _value: Bool = false
    private let lock = NSLock()

    var value: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _value = newValue
        }
    }

    func set() {
        value = true
    }
}

final class HookRegistryTests: XCTestCase {

    // MARK: - Registration Tests

    func testRegistration_AddsCallback() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in
            return .continue()
        }

        let hasHooks = await registry.hasHooks
        let count = await registry.callbackCount

        XCTAssertTrue(hasHooks)
        XCTAssertEqual(count, 1)
    }

    func testRegistration_MultipleHooks() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in .continue() }
        await registry.onPostToolUse { _ in .continue() }
        await registry.onStop { _ in .continue() }

        let count = await registry.callbackCount
        let events = await registry.registeredEvents

        XCTAssertEqual(count, 3)
        XCTAssertTrue(events.contains(.preToolUse))
        XCTAssertTrue(events.contains(.postToolUse))
        XCTAssertTrue(events.contains(.stop))
    }

    func testRegistration_AllHookTypes() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in .continue() }
        await registry.onPostToolUse { _ in .continue() }
        await registry.onPostToolUseFailure { _ in .continue() }
        await registry.onUserPromptSubmit { _ in .continue() }
        await registry.onStop { _ in .continue() }
        await registry.onSubagentStart { _ in .continue() }
        await registry.onSubagentStop { _ in .continue() }
        await registry.onPreCompact { _ in .continue() }
        await registry.onPermissionRequest { _ in .continue() }
        await registry.onSessionStart { _ in .continue() }
        await registry.onSessionEnd { _ in .continue() }
        await registry.onNotification { _ in .continue() }

        let count = await registry.callbackCount
        XCTAssertEqual(count, 12)
    }

    // MARK: - GetHookConfig Tests

    func testGetHookConfig_EmptyRegistry() async {
        let registry = HookRegistry()
        let config = await registry.getHookConfig()
        XCTAssertNil(config)
    }

    func testGetHookConfig_Format() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(matching: "Bash", timeout: 30.0) { _ in
            return .continue()
        }

        guard let config = await registry.getHookConfig() else {
            XCTFail("Expected config to be non-nil")
            return
        }

        XCTAssertNotNil(config["PreToolUse"])

        guard let preToolUseConfigs = config["PreToolUse"] else {
            XCTFail("Expected PreToolUse config")
            return
        }

        XCTAssertEqual(preToolUseConfigs.count, 1)

        let firstConfig = preToolUseConfigs[0]
        XCTAssertEqual(firstConfig.matcher, "Bash")
        XCTAssertEqual(firstConfig.timeout, 30.0)
        XCTAssertEqual(firstConfig.hookCallbackIds.count, 1)
        XCTAssertTrue(firstConfig.hookCallbackIds[0].hasPrefix("hook_"))
    }

    func testGetHookConfig_MultipleMatchers() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(matching: "Bash") { _ in .continue() }
        await registry.onPreToolUse(matching: "Read") { _ in .continue() }

        guard let config = await registry.getHookConfig(),
              let preToolUseConfigs = config["PreToolUse"] else {
            XCTFail("Expected config")
            return
        }

        XCTAssertEqual(preToolUseConfigs.count, 2)
    }

    // MARK: - Invocation Tests

    func testInvokeCallback_RoutesCorrectly() async throws {
        let registry = HookRegistry()
        let invoked = TestFlag()
        let capturedToolName = TestCapture<String>()
        let capturedSessionId = TestCapture<String>()

        await registry.onPreToolUse { input in
            invoked.set()
            capturedToolName.value = input.toolName
            capturedSessionId.value = input.base.sessionId
            return .allow()
        }

        // Get the callback ID
        guard let callbackId = await registry.getCallbackId(forEvent: .preToolUse) else {
            XCTFail("Could not get callback ID")
            return
        }

        let rawInput: [String: JSONValue] = [
            "session_id": .string("session-123"),
            "transcript_path": .string("/tmp/transcript.jsonl"),
            "cwd": .string("/home/user"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PreToolUse"),
            "tool_name": .string("TestTool"),
            "tool_input": .object(["arg": .string("value")]),
            "tool_use_id": .string("toolu_1")
        ]

        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)

        XCTAssertTrue(invoked.value)
        XCTAssertEqual(capturedToolName.value, "TestTool")
        XCTAssertEqual(capturedSessionId.value, "session-123")
        XCTAssertTrue(output.shouldContinue)
    }

    func testCallbackNotFound_ThrowsError() async {
        let registry = HookRegistry()

        do {
            _ = try await registry.invokeCallback(
                callbackId: "nonexistent",
                rawInput: [:]
            )
            XCTFail("Expected error to be thrown")
        } catch let error as HookError {
            if case .callbackNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected callbackNotFound error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvokeCallback_WithHookInput() async throws {
        let registry = HookRegistry()
        let capturedStopHookActive = TestCapture<Bool>()

        await registry.onStop { input in
            capturedStopHookActive.value = input.stopHookActive
            return .stop(reason: "Test stop")
        }

        guard let callbackId = await registry.getCallbackId(forEvent: .stop) else {
            XCTFail("Could not get callback ID")
            return
        }

        let base = BaseHookInput(
            sessionId: "test-session",
            transcriptPath: "/tmp/test.jsonl",
            cwd: "/test",
            permissionMode: "default",
            hookEventName: .stop
        )
        let input = HookInput.stop(StopInput(base: base, stopHookActive: true))

        let output = try await registry.invokeCallback(callbackId: callbackId, input: input)

        XCTAssertTrue(capturedStopHookActive.value ?? false)
        XCTAssertFalse(output.shouldContinue)
        XCTAssertEqual(output.stopReason, "Test stop")
    }

    func testInvokeCallback_PostToolUse() async throws {
        let registry = HookRegistry()
        let invoked = TestFlag()
        let capturedToolName = TestCapture<String>()
        let capturedResponse = TestCapture<String>()

        await registry.onPostToolUse { input in
            invoked.set()
            capturedToolName.value = input.toolName
            if case .string(let response) = input.toolResponse {
                capturedResponse.value = response
            }
            return .continue()
        }

        guard let callbackId = await registry.getCallbackId(forEvent: .postToolUse) else {
            XCTFail("Could not get callback ID")
            return
        }

        let rawInput: [String: JSONValue] = [
            "session_id": .string("sess"),
            "transcript_path": .string("/tmp/t.jsonl"),
            "cwd": .string("/"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PostToolUse"),
            "tool_name": .string("Read"),
            "tool_input": .object(["path": .string("/etc/hosts")]),
            "tool_response": .string("file contents"),
            "tool_use_id": .string("toolu_2")
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)

        XCTAssertTrue(invoked.value)
        XCTAssertEqual(capturedToolName.value, "Read")
        XCTAssertEqual(capturedResponse.value, "file contents")
    }

    func testInvokeCallback_PostToolUseFailure() async throws {
        let registry = HookRegistry()
        let invoked = TestFlag()
        let capturedError = TestCapture<String>()
        let capturedIsInterrupt = TestCapture<Bool>()

        await registry.onPostToolUseFailure { input in
            invoked.set()
            capturedError.value = input.error
            capturedIsInterrupt.value = input.isInterrupt
            return .continue()
        }

        guard let callbackId = await registry.getCallbackId(forEvent: .postToolUseFailure) else {
            XCTFail("Could not get callback ID")
            return
        }

        let rawInput: [String: JSONValue] = [
            "session_id": .string("sess"),
            "transcript_path": .string("/tmp/t.jsonl"),
            "cwd": .string("/"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PostToolUseFailure"),
            "tool_name": .string("Bash"),
            "tool_input": .object([:]),
            "error": .string("Permission denied"),
            "is_interrupt": .bool(true),
            "tool_use_id": .string("toolu_3")
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)

        XCTAssertTrue(invoked.value)
        XCTAssertEqual(capturedError.value, "Permission denied")
        XCTAssertTrue(capturedIsInterrupt.value ?? false)
    }

    func testInvokeCallback_UserPromptSubmit() async throws {
        let registry = HookRegistry()
        let capturedPrompt = TestCapture<String>()

        await registry.onUserPromptSubmit { input in
            capturedPrompt.value = input.prompt
            return .continue()
        }

        guard let callbackId = await registry.getCallbackId(forEvent: .userPromptSubmit) else {
            XCTFail("Could not get callback ID")
            return
        }

        let rawInput: [String: JSONValue] = [
            "session_id": .string("sess"),
            "transcript_path": .string("/tmp/t.jsonl"),
            "cwd": .string("/"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("UserPromptSubmit"),
            "prompt": .string("Hello, Claude!")
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedPrompt.value, "Hello, Claude!")
    }

    // MARK: - Pattern Matching Tests

    func testRegistration_WithPattern() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(matching: "Bash|Write") { _ in
            return .deny(reason: "Blocked")
        }

        guard let config = await registry.getHookConfig(),
              let configs = config["PreToolUse"],
              let firstConfig = configs.first else {
            XCTFail("Expected config")
            return
        }

        XCTAssertEqual(firstConfig.matcher, "Bash|Write")
    }

    func testRegistration_WithTimeout() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(timeout: 120.0) { _ in
            return .continue()
        }

        guard let config = await registry.getHookConfig(),
              let configs = config["PreToolUse"],
              let firstConfig = configs.first else {
            XCTFail("Expected config")
            return
        }

        XCTAssertEqual(firstConfig.timeout, 120.0)
    }

    // MARK: - Callback ID Generation Tests

    func testCallbackIdGeneration_Unique() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in .continue() }
        await registry.onPreToolUse { _ in .continue() }
        await registry.onPostToolUse { _ in .continue() }

        guard let config = await registry.getHookConfig() else {
            XCTFail("Expected config")
            return
        }

        var allIds: Set<String> = []

        for (_, configs) in config {
            for configItem in configs {
                for id in configItem.hookCallbackIds {
                    XCTAssertFalse(allIds.contains(id), "Duplicate callback ID: \(id)")
                    allIds.insert(id)
                }
            }
        }

        XCTAssertEqual(allIds.count, 3)
    }

    // MARK: - toDictionary Tests

    func testHookMatcherConfig_toDictionary() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(matching: "Bash", timeout: 30.0) { _ in
            return .continue()
        }

        guard let config = await registry.getHookConfig(),
              let configs = config["PreToolUse"],
              let firstConfig = configs.first else {
            XCTFail("Expected config")
            return
        }

        let dict = firstConfig.toDictionary()

        XCTAssertEqual(dict["matcher"] as? String, "Bash")
        XCTAssertEqual(dict["timeout"] as? TimeInterval, 30.0)
        XCTAssertEqual((dict["hookCallbackIds"] as? [String])?.count, 1)
    }
}

// MARK: - HookError Tests

final class HookErrorTests: XCTestCase {

    func testCallbackNotFound_Message() {
        let error = HookError.callbackNotFound("hook_123")
        if case .callbackNotFound(let id) = error {
            XCTAssertEqual(id, "hook_123")
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testUnsupportedHookEvent() {
        let error = HookError.unsupportedHookEvent(.notification)
        if case .unsupportedHookEvent(let event) = error {
            XCTAssertEqual(event, .notification)
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testInvalidInput() {
        let error = HookError.invalidInput("Missing tool_name")
        if case .invalidInput(let msg) = error {
            XCTAssertEqual(msg, "Missing tool_name")
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testEquatable() {
        let error1 = HookError.callbackNotFound("hook_1")
        let error2 = HookError.callbackNotFound("hook_1")
        let error3 = HookError.callbackNotFound("hook_2")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}
