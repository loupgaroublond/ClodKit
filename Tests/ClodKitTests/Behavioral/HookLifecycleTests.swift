//
//  HookLifecycleTests.swift
//  ClodKitTests
//
//  Behavioral tests for hook event lifecycle and routing (Bead 94r).
//

import XCTest
@testable import ClodKit

final class HookLifecycleTests: XCTestCase {

    // MARK: - HookEvent Has Exactly 15 Cases

    func testHookEventHasExactly15Cases() {
        XCTAssertEqual(HookEvent.allCases.count, 15)
    }

    func testAllExpectedEventsExist() {
        let expectedEvents: Set<HookEvent> = [
            .preToolUse, .postToolUse, .postToolUseFailure,
            .userPromptSubmit, .stop, .subagentStart, .subagentStop,
            .preCompact, .permissionRequest, .sessionStart, .sessionEnd,
            .notification, .setup, .teammateIdle, .taskCompleted
        ]
        XCTAssertEqual(Set(HookEvent.allCases), expectedEvents)
    }

    // MARK: - HookEvent Raw Values Match TS SDK HOOK_EVENTS

    func testPreToolUseRawValue() { XCTAssertEqual(HookEvent.preToolUse.rawValue, "PreToolUse") }
    func testPostToolUseRawValue() { XCTAssertEqual(HookEvent.postToolUse.rawValue, "PostToolUse") }
    func testPostToolUseFailureRawValue() { XCTAssertEqual(HookEvent.postToolUseFailure.rawValue, "PostToolUseFailure") }
    func testUserPromptSubmitRawValue() { XCTAssertEqual(HookEvent.userPromptSubmit.rawValue, "UserPromptSubmit") }
    func testStopRawValue() { XCTAssertEqual(HookEvent.stop.rawValue, "Stop") }
    func testSubagentStartRawValue() { XCTAssertEqual(HookEvent.subagentStart.rawValue, "SubagentStart") }
    func testSubagentStopRawValue() { XCTAssertEqual(HookEvent.subagentStop.rawValue, "SubagentStop") }
    func testPreCompactRawValue() { XCTAssertEqual(HookEvent.preCompact.rawValue, "PreCompact") }
    func testPermissionRequestRawValue() { XCTAssertEqual(HookEvent.permissionRequest.rawValue, "PermissionRequest") }
    func testSessionStartRawValue() { XCTAssertEqual(HookEvent.sessionStart.rawValue, "SessionStart") }
    func testSessionEndRawValue() { XCTAssertEqual(HookEvent.sessionEnd.rawValue, "SessionEnd") }
    func testNotificationRawValue() { XCTAssertEqual(HookEvent.notification.rawValue, "Notification") }
    func testSetupRawValue() { XCTAssertEqual(HookEvent.setup.rawValue, "Setup") }
    func testTeammateIdleRawValue() { XCTAssertEqual(HookEvent.teammateIdle.rawValue, "TeammateIdle") }
    func testTaskCompletedRawValue() { XCTAssertEqual(HookEvent.taskCompleted.rawValue, "TaskCompleted") }

    // MARK: - New Events Route Correctly

    func testSetupEventExists() {
        XCTAssertNotNil(HookEvent(rawValue: "Setup"))
    }

    func testTeammateIdleEventExists() {
        XCTAssertNotNil(HookEvent(rawValue: "TeammateIdle"))
    }

    func testTaskCompletedEventExists() {
        XCTAssertNotNil(HookEvent(rawValue: "TaskCompleted"))
    }

    // MARK: - HookInput Has Exactly 15 Cases Matching HookEvent

    func testHookInputEventTypeMatchesForAllCases() {
        let base = BaseHookInput(sessionId: "s1", transcriptPath: "/t", cwd: "/c", permissionMode: "default", hookEventName: .preToolUse)

        let inputs: [HookInput] = [
            .preToolUse(PreToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolUseId: "tu1")),
            .postToolUse(PostToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolResponse: .null, toolUseId: "tu2")),
            .postToolUseFailure(PostToolUseFailureInput(base: base, toolName: "Bash", toolInput: [:], error: "err", isInterrupt: false, toolUseId: "tu3")),
            .userPromptSubmit(UserPromptSubmitInput(base: base, prompt: "hello")),
            .stop(StopInput(base: base, stopHookActive: false)),
            .subagentStart(SubagentStartInput(base: base, agentId: "a1", agentType: "task")),
            .subagentStop(SubagentStopInput(base: base, stopHookActive: false, agentTranscriptPath: "/t", agentId: "a1", agentType: "task")),
            .preCompact(PreCompactInput(base: base, trigger: "auto", customInstructions: nil)),
            .permissionRequest(PermissionRequestInput(base: base, toolName: "Bash", toolInput: [:], permissionSuggestions: [])),
            .sessionStart(SessionStartInput(base: base, source: "api")),
            .sessionEnd(SessionEndInput(base: base, reason: .other)),
            .notification(NotificationInput(base: base, message: "msg", notificationType: "info", title: nil)),
            .setup(SetupInput(base: base, trigger: "init")),
            .teammateIdle(TeammateIdleInput(base: base, teammateName: "worker-1", teamName: "team-a")),
            .taskCompleted(TaskCompletedInput(base: base, taskId: "t1", taskSubject: "subject")),
        ]
        XCTAssertEqual(inputs.count, 15)

        let expectedEvents: [HookEvent] = [
            .preToolUse, .postToolUse, .postToolUseFailure,
            .userPromptSubmit, .stop, .subagentStart, .subagentStop,
            .preCompact, .permissionRequest, .sessionStart, .sessionEnd,
            .notification, .setup, .teammateIdle, .taskCompleted
        ]
        for (input, expected) in zip(inputs, expectedEvents) {
            XCTAssertEqual(input.eventType, expected)
        }
    }

    // MARK: - BaseHookInput Fields Flow Through

    func testBaseHookInputFieldsFlowThrough() {
        let base = BaseHookInput(
            sessionId: "sess-123",
            transcriptPath: "/path/to/transcript",
            cwd: "/home/user/project",
            permissionMode: "acceptEdits",
            hookEventName: .preToolUse
        )
        let input = HookInput.preToolUse(
            PreToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolUseId: "tu1")
        )
        XCTAssertEqual(input.base.sessionId, "sess-123")
        XCTAssertEqual(input.base.transcriptPath, "/path/to/transcript")
        XCTAssertEqual(input.base.cwd, "/home/user/project")
        XCTAssertEqual(input.base.permissionMode, "acceptEdits")
        XCTAssertEqual(input.base.hookEventName, .preToolUse)
    }

    // MARK: - HookRegistry Registration

    func testEveryEventCanBeRegisteredInHookRegistry() async {
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
        await registry.onSetup { _ in .continue() }
        await registry.onTeammateIdle { _ in .continue() }
        await registry.onTaskCompleted { _ in .continue() }

        let registered = await registry.registeredEvents
        XCTAssertEqual(registered.count, 15)
        for event in HookEvent.allCases {
            XCTAssertTrue(registered.contains(event),
                          "Event \(event) should be registered")
        }
    }

    func testRegisteredEventsReflectsOnlyRegisteredHooks() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in .continue() }
        await registry.onStop { _ in .continue() }

        let registered = await registry.registeredEvents
        XCTAssertEqual(registered.count, 2)
        XCTAssertTrue(registered.contains(.preToolUse))
        XCTAssertTrue(registered.contains(.stop))
        XCTAssertFalse(registered.contains(.postToolUse))
    }

    // MARK: - Callback Invocation Delivers Correct Input

    func testPreToolUseCallbackReceivesCorrectInput() async throws {
        let registry = HookRegistry()
        let capture = CaptureBox()

        await registry.onPreToolUse { input in
            await capture.set("toolName", input.toolName)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .preToolUse)!
        let base = BaseHookInput(sessionId: "s1", transcriptPath: "/t", cwd: "/c", permissionMode: "default", hookEventName: .preToolUse)
        let input = HookInput.preToolUse(
            PreToolUseInput(base: base, toolName: "Read", toolInput: [:], toolUseId: "tu1")
        )

        _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let receivedToolName = await capture.get("toolName")
        XCTAssertEqual(receivedToolName, "Read")
    }

    func testPostToolUseCallbackReceivesToolResponse() async throws {
        let registry = HookRegistry()
        let capture = CaptureBox()

        await registry.onPostToolUse { input in
            await capture.set("response", "\(input.toolResponse)")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .postToolUse)!
        let base = BaseHookInput(sessionId: "s1", transcriptPath: "/t", cwd: "/c", permissionMode: "default", hookEventName: .postToolUse)
        let input = HookInput.postToolUse(
            PostToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolResponse: .string("output"), toolUseId: "tu2")
        )

        _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let receivedResponse = await capture.get("response")
        XCTAssertEqual(receivedResponse, "string(\"output\")")
    }

    // MARK: - Pattern Matching for PreToolUse/PostToolUse

    func testPreToolUsePatternMatching() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(matching: "Bash.*") { _ in .continue() }

        let config = await registry.getHookConfig()
        XCTAssertNotNil(config)
        let preToolConfigs = config?["PreToolUse"]
        XCTAssertNotNil(preToolConfigs)
        XCTAssertEqual(preToolConfigs?.first?.matcher, "Bash.*")
    }

    func testPostToolUsePatternMatching() async {
        let registry = HookRegistry()

        await registry.onPostToolUse(matching: "Read|Write") { _ in .continue() }

        let config = await registry.getHookConfig()
        let postToolConfigs = config?["PostToolUse"]
        XCTAssertEqual(postToolConfigs?.first?.matcher, "Read|Write")
    }

    // MARK: - Timeout Configuration

    func testTimeoutConfigPropagates() async {
        let registry = HookRegistry()

        await registry.onPreToolUse(timeout: 120.0) { _ in .continue() }

        let config = await registry.getHookConfig()
        let preToolConfigs = config?["PreToolUse"]
        XCTAssertEqual(preToolConfigs?.first?.timeout, 120.0)
    }

    func testDefaultTimeoutIs60() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in .continue() }

        let config = await registry.getHookConfig()
        let preToolConfigs = config?["PreToolUse"]
        XCTAssertEqual(preToolConfigs?.first?.timeout, 60.0)
    }

    // MARK: - HookJSONOutput Distinguishes Sync from Async

    func testSyncOutputIsDistinguishable() {
        let syncOutput = HookJSONOutput.sync(HookOutput.continue())
        if case .sync(let output) = syncOutput {
            XCTAssertTrue(output.shouldContinue)
        } else {
            XCTFail("Expected sync output")
        }
    }

    func testAsyncOutputIsDistinguishable() {
        let asyncOutput = HookJSONOutput.async(AsyncHookOutput(asyncTimeout: 30.0))
        if case .async(let output) = asyncOutput {
            XCTAssertTrue(output.isAsync)
            XCTAssertEqual(output.asyncTimeout, 30.0)
        } else {
            XCTFail("Expected async output")
        }
    }

    // MARK: - Hook-Specific Output Encoding

    func testPreToolUseOutputEncoding() {
        let output = PreToolUseHookOutput(
            permissionDecision: .allow,
            updatedInput: ["command": .string("ls")],
            additionalContext: "safe command"
        )
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(dict["permissionDecision"] as? String, "allow")
        XCTAssertEqual(dict["additionalContext"] as? String, "safe command")
        XCTAssertNotNil(dict["updatedInput"])
    }

    func testPostToolUseOutputEncoding() {
        let output = PostToolUseHookOutput(
            additionalContext: "post context",
            updatedMCPToolOutput: .string("modified output")
        )
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PostToolUse")
        XCTAssertEqual(dict["additionalContext"] as? String, "post context")
        XCTAssertNotNil(dict["updatedMCPToolOutput"])
    }

    func testPermissionRequestOutputAllowEncoding() {
        let output = PermissionRequestHookOutput(
            decision: .allow(updatedInput: nil, updatedPermissions: nil)
        )
        let specific = HookSpecificOutput.permissionRequest(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PermissionRequest")
        XCTAssertEqual(dict["behavior"] as? String, "allow")
    }

    func testPermissionRequestOutputDenyEncoding() {
        let output = PermissionRequestHookOutput(
            decision: .deny(message: "not allowed", interrupt: true)
        )
        let specific = HookSpecificOutput.permissionRequest(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "not allowed")
        XCTAssertEqual(dict["interrupt"] as? Bool, true)
    }

    // MARK: - Hook Input Parsing from Raw JSON

    func testPreToolUseInputParsing() async throws {
        let registry = HookRegistry()
        let capture = CaptureBox()

        await registry.onPreToolUse { input in
            await capture.set("toolName", input.toolName)
            await capture.set("toolUseId", input.toolUseId)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .preToolUse)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("sess-1"),
            "transcript_path": .string("/tmp/transcript"),
            "cwd": .string("/home"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PreToolUse"),
            "tool_name": .string("Write"),
            "tool_input": .object(["path": .string("/foo/bar")]),
            "tool_use_id": .string("tu-abc123"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let receivedToolName = await capture.get("toolName")
        let receivedToolUseId = await capture.get("toolUseId")
        XCTAssertEqual(receivedToolName, "Write")
        XCTAssertEqual(receivedToolUseId, "tu-abc123")
    }

    // MARK: - Callback Not Found Error

    func testInvokeNonExistentCallbackThrows() async {
        let registry = HookRegistry()
        let base = BaseHookInput(sessionId: "s", transcriptPath: "/t", cwd: "/c", permissionMode: "default", hookEventName: .preToolUse)
        let input = HookInput.preToolUse(PreToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolUseId: "tu1"))

        do {
            _ = try await registry.invokeCallback(callbackId: "nonexistent", input: input)
            XCTFail("Should have thrown")
        } catch let error as HookError {
            if case .callbackNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected callbackNotFound error")
            }
        } catch {
            XCTFail("Expected HookError, got \(error)")
        }
    }

    // MARK: - HookOutput Convenience Initializers

    func testHookOutputContinue() {
        let output = HookOutput.continue()
        XCTAssertTrue(output.shouldContinue)
    }

    func testHookOutputStop() {
        let output = HookOutput.stop(reason: "done")
        XCTAssertFalse(output.shouldContinue)
        XCTAssertEqual(output.stopReason, "done")
    }

    func testHookOutputAllow() {
        let output = HookOutput.allow(additionalContext: "ok")
        XCTAssertTrue(output.shouldContinue)
        if case .preToolUse(let specific) = output.hookSpecificOutput {
            XCTAssertEqual(specific.permissionDecision, .allow)
            XCTAssertEqual(specific.additionalContext, "ok")
        } else {
            XCTFail("Expected preToolUse specific output")
        }
    }

    func testHookOutputDeny() {
        let output = HookOutput.deny(reason: "unsafe")
        if case .preToolUse(let specific) = output.hookSpecificOutput {
            XCTAssertEqual(specific.permissionDecision, .deny)
            XCTAssertEqual(specific.permissionDecisionReason, "unsafe")
        } else {
            XCTFail("Expected preToolUse specific output")
        }
    }

    func testHookOutputAsk() {
        let output = HookOutput.ask(reason: "needs review")
        if case .preToolUse(let specific) = output.hookSpecificOutput {
            XCTAssertEqual(specific.permissionDecision, .ask)
            XCTAssertEqual(specific.permissionDecisionReason, "needs review")
        } else {
            XCTFail("Expected preToolUse specific output")
        }
    }
}

// MARK: - Thread-Safe Capture Helper

private actor CaptureBox {
    var values: [String: String] = [:]
    func set(_ key: String, _ value: String) { values[key] = value }
    func get(_ key: String) -> String? { values[key] }
}
