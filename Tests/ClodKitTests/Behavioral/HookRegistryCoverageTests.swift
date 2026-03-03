//
//  HookRegistryCoverageTests.swift
//  ClodKitTests
//
//  Behavioral tests covering HookRegistry and ClaudeSession hook registration
//  and invocation for 11 previously uncovered hook event types.
//

import XCTest
import os
@testable import ClodKit

final class HookRegistryEventCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Helper

    private func makeBaseRawInput(event: String) -> [String: JSONValue] {
        [
            "session_id": .string("test-session"),
            "transcript_path": .string("/tmp/transcript"),
            "cwd": .string("/project"),
            "permission_mode": .string("default"),
            "hook_event_name": .string(event),
        ]
    }

    // MARK: - onStop

    func testOnStop_Registration() async throws {
        let registry = HookRegistry()
        await registry.onStop { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["Stop"])
        XCTAssertEqual(config?["Stop"]?.count, 1)
        XCTAssertEqual(config?["Stop"]?.first?.hookCallbackIds.count, 1)
    }

    func testOnStop_Invocation() async throws {
        let registry = HookRegistry()
        let invoked = TestFlag()
        let captured = TestCapture<Bool>()
        await registry.onStop { input in
            invoked.set()
            captured.value = input.stopHookActive
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        var rawInput = makeBaseRawInput(event: "Stop")
        rawInput["stop_hook_active"] = .bool(true)
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(invoked.value)
        XCTAssertEqual(captured.value, true)
        XCTAssertTrue(output.shouldContinue)
    }

    func testSessionOnStop_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onStop { _ in .continue() }
        // Verifies the hook is registered without crash
    }

    // MARK: - onSetup

    func testOnSetup_Registration() async throws {
        let registry = HookRegistry()
        await registry.onSetup { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["Setup"])
        XCTAssertEqual(config?["Setup"]?.count, 1)
    }

    func testOnSetup_Invocation() async throws {
        let registry = HookRegistry()
        let captured = TestCapture<String>()
        await registry.onSetup { input in
            captured.value = input.trigger
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .setup)!
        var rawInput = makeBaseRawInput(event: "Setup")
        rawInput["trigger"] = .string("init")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(captured.value, "init")
        XCTAssertTrue(output.shouldContinue)
    }

    func testSessionOnSetup_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onSetup { _ in .continue() }
    }

    // MARK: - onTeammateIdle

    func testOnTeammateIdle_Registration() async throws {
        let registry = HookRegistry()
        await registry.onTeammateIdle { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["TeammateIdle"])
        XCTAssertEqual(config?["TeammateIdle"]?.count, 1)
    }

    func testOnTeammateIdle_Invocation() async throws {
        let registry = HookRegistry()
        let capturedName = TestCapture<String>()
        let capturedTeam = TestCapture<String>()
        await registry.onTeammateIdle { input in
            capturedName.value = input.teammateName
            capturedTeam.value = input.teamName
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .teammateIdle)!
        var rawInput = makeBaseRawInput(event: "TeammateIdle")
        rawInput["teammate_name"] = .string("worker-1")
        rawInput["team_name"] = .string("alpha-team")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedName.value, "worker-1")
        XCTAssertEqual(capturedTeam.value, "alpha-team")
        XCTAssertTrue(output.shouldContinue)
    }

    func testSessionOnTeammateIdle_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onTeammateIdle { _ in .continue() }
    }

    // MARK: - onTaskCompleted

    func testOnTaskCompleted_Registration() async throws {
        let registry = HookRegistry()
        await registry.onTaskCompleted { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["TaskCompleted"])
        XCTAssertEqual(config?["TaskCompleted"]?.count, 1)
    }

    func testOnTaskCompleted_Invocation() async throws {
        let registry = HookRegistry()
        let capturedId = TestCapture<String>()
        let capturedSubject = TestCapture<String>()
        let capturedDesc = TestCapture<String>()
        let capturedTeammate = TestCapture<String>()
        await registry.onTaskCompleted { input in
            capturedId.value = input.taskId
            capturedSubject.value = input.taskSubject
            capturedDesc.value = input.taskDescription ?? "nil"
            capturedTeammate.value = input.teammateName ?? "nil"
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .taskCompleted)!
        var rawInput = makeBaseRawInput(event: "TaskCompleted")
        rawInput["task_id"] = .string("task-42")
        rawInput["task_subject"] = .string("Fix the bug")
        rawInput["task_description"] = .string("A detailed description")
        rawInput["teammate_name"] = .string("agent-1")
        rawInput["team_name"] = .string("team-x")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedId.value, "task-42")
        XCTAssertEqual(capturedSubject.value, "Fix the bug")
        XCTAssertEqual(capturedDesc.value, "A detailed description")
        XCTAssertEqual(capturedTeammate.value, "agent-1")
        XCTAssertTrue(output.shouldContinue)
    }

    func testOnTaskCompleted_InvocationOptionalFieldsAbsent() async throws {
        let registry = HookRegistry()
        let capturedDesc = TestCapture<String>()
        await registry.onTaskCompleted { input in
            capturedDesc.value = input.taskDescription ?? "nil"
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .taskCompleted)!
        var rawInput = makeBaseRawInput(event: "TaskCompleted")
        rawInput["task_id"] = .string("task-99")
        rawInput["task_subject"] = .string("Subject only")
        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedDesc.value, "nil")
    }

    func testSessionOnTaskCompleted_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onTaskCompleted { _ in .continue() }
    }

    // MARK: - onSessionStart

    func testOnSessionStart_Registration() async throws {
        let registry = HookRegistry()
        await registry.onSessionStart { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["SessionStart"])
        XCTAssertEqual(config?["SessionStart"]?.count, 1)
    }

    func testOnSessionStart_Invocation() async throws {
        let registry = HookRegistry()
        let captured = TestCapture<String>()
        await registry.onSessionStart { input in
            captured.value = input.source
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .sessionStart)!
        var rawInput = makeBaseRawInput(event: "SessionStart")
        rawInput["source"] = .string("api")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(captured.value, "api")
        XCTAssertTrue(output.shouldContinue)
    }

    func testSessionOnSessionStart_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onSessionStart { _ in .continue() }
    }

    // MARK: - onSessionEnd

    func testOnSessionEnd_Registration() async throws {
        let registry = HookRegistry()
        await registry.onSessionEnd { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["SessionEnd"])
        XCTAssertEqual(config?["SessionEnd"]?.count, 1)
    }

    func testOnSessionEnd_Invocation() async throws {
        let registry = HookRegistry()
        let captured = TestCapture<String>()
        await registry.onSessionEnd { input in
            captured.value = input.reason.rawValue
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .sessionEnd)!
        var rawInput = makeBaseRawInput(event: "SessionEnd")
        rawInput["reason"] = .string("clear")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(captured.value, "clear")
        XCTAssertTrue(output.shouldContinue)
    }

    func testOnSessionEnd_InvocationOtherReason() async throws {
        let registry = HookRegistry()
        let captured = TestCapture<String>()
        await registry.onSessionEnd { input in
            captured.value = input.reason.rawValue
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .sessionEnd)!
        var rawInput = makeBaseRawInput(event: "SessionEnd")
        rawInput["reason"] = .string("other")
        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(captured.value, "other")
    }

    func testSessionOnSessionEnd_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onSessionEnd { _ in .continue() }
    }

    // MARK: - onSubagentStart

    func testOnSubagentStart_Registration() async throws {
        let registry = HookRegistry()
        await registry.onSubagentStart { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["SubagentStart"])
        XCTAssertEqual(config?["SubagentStart"]?.count, 1)
    }

    func testOnSubagentStart_Invocation() async throws {
        let registry = HookRegistry()
        let capturedId = TestCapture<String>()
        let capturedType = TestCapture<String>()
        await registry.onSubagentStart { input in
            capturedId.value = input.agentId
            capturedType.value = input.agentType
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .subagentStart)!
        var rawInput = makeBaseRawInput(event: "SubagentStart")
        rawInput["agent_id"] = .string("agent-abc")
        rawInput["agent_type"] = .string("task")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedId.value, "agent-abc")
        XCTAssertEqual(capturedType.value, "task")
        XCTAssertTrue(output.shouldContinue)
    }

    func testSessionOnSubagentStart_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onSubagentStart { _ in .continue() }
    }

    // MARK: - onSubagentStop

    func testOnSubagentStop_Registration() async throws {
        let registry = HookRegistry()
        await registry.onSubagentStop { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["SubagentStop"])
        XCTAssertEqual(config?["SubagentStop"]?.count, 1)
    }

    func testOnSubagentStop_Invocation() async throws {
        let registry = HookRegistry()
        let capturedId = TestCapture<String>()
        let capturedTranscript = TestCapture<String>()
        let capturedActive = TestCapture<Bool>()
        await registry.onSubagentStop { input in
            capturedId.value = input.agentId
            capturedTranscript.value = input.agentTranscriptPath
            capturedActive.value = input.stopHookActive
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .subagentStop)!
        var rawInput = makeBaseRawInput(event: "SubagentStop")
        rawInput["agent_id"] = .string("agent-xyz")
        rawInput["agent_type"] = .string("research")
        rawInput["agent_transcript_path"] = .string("/transcripts/agent-xyz")
        rawInput["stop_hook_active"] = .bool(true)
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedId.value, "agent-xyz")
        XCTAssertEqual(capturedTranscript.value, "/transcripts/agent-xyz")
        XCTAssertEqual(capturedActive.value, true)
        XCTAssertTrue(output.shouldContinue)
    }

    func testSessionOnSubagentStop_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onSubagentStop { _ in .continue() }
    }

    // MARK: - onPreCompact

    func testOnPreCompact_Registration() async throws {
        let registry = HookRegistry()
        await registry.onPreCompact { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["PreCompact"])
        XCTAssertEqual(config?["PreCompact"]?.count, 1)
    }

    func testOnPreCompact_Invocation() async throws {
        let registry = HookRegistry()
        let capturedTrigger = TestCapture<String>()
        let capturedInstructions = TestCapture<String>()
        await registry.onPreCompact { input in
            capturedTrigger.value = input.trigger
            capturedInstructions.value = input.customInstructions ?? "nil"
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .preCompact)!
        var rawInput = makeBaseRawInput(event: "PreCompact")
        rawInput["trigger"] = .string("auto")
        rawInput["custom_instructions"] = .string("Preserve code blocks")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedTrigger.value, "auto")
        XCTAssertEqual(capturedInstructions.value, "Preserve code blocks")
        XCTAssertTrue(output.shouldContinue)
    }

    func testOnPreCompact_InvocationWithoutCustomInstructions() async throws {
        let registry = HookRegistry()
        let capturedInstructions = TestCapture<String>()
        await registry.onPreCompact { input in
            capturedInstructions.value = input.customInstructions ?? "nil"
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .preCompact)!
        var rawInput = makeBaseRawInput(event: "PreCompact")
        rawInput["trigger"] = .string("manual")
        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedInstructions.value, "nil")
    }

    func testSessionOnPreCompact_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onPreCompact { _ in .continue() }
    }

    // MARK: - onPermissionRequest

    func testOnPermissionRequest_Registration() async throws {
        let registry = HookRegistry()
        await registry.onPermissionRequest { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["PermissionRequest"])
        XCTAssertEqual(config?["PermissionRequest"]?.count, 1)
        XCTAssertNil(config?["PermissionRequest"]?.first?.matcher)
    }

    func testOnPermissionRequest_RegistrationWithPattern() async throws {
        let registry = HookRegistry()
        await registry.onPermissionRequest(matching: "Bash|Write") { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["PermissionRequest"])
        XCTAssertEqual(config?["PermissionRequest"]?.first?.matcher, "Bash|Write")
    }

    func testOnPermissionRequest_Invocation() async throws {
        let registry = HookRegistry()
        let capturedTool = TestCapture<String>()
        let capturedSuggestions = TestCapture<Int>()
        await registry.onPermissionRequest { input in
            capturedTool.value = input.toolName
            capturedSuggestions.value = input.permissionSuggestions.count
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .permissionRequest)!
        var rawInput = makeBaseRawInput(event: "PermissionRequest")
        rawInput["tool_name"] = .string("Bash")
        rawInput["tool_input"] = .object(["command": .string("ls -la")])
        rawInput["permission_suggestions"] = .array([.string("allow"), .string("deny")])
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedTool.value, "Bash")
        XCTAssertEqual(capturedSuggestions.value, 2)
        XCTAssertTrue(output.shouldContinue)
    }

    func testOnPermissionRequest_InvocationWithEmptySuggestions() async throws {
        let registry = HookRegistry()
        let capturedSuggestions = TestCapture<Int>()
        await registry.onPermissionRequest { input in
            capturedSuggestions.value = input.permissionSuggestions.count
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .permissionRequest)!
        var rawInput = makeBaseRawInput(event: "PermissionRequest")
        rawInput["tool_name"] = .string("Read")
        rawInput["tool_input"] = .object([:])
        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedSuggestions.value, 0)
    }

    func testSessionOnPermissionRequest_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onPermissionRequest { _ in .continue() }
    }

    func testSessionOnPermissionRequest_RegistrationWithPattern() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onPermissionRequest(matching: "Bash") { _ in .continue() }
    }

    // MARK: - onNotification

    func testOnNotification_Registration() async throws {
        let registry = HookRegistry()
        await registry.onNotification { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertNotNil(config?["Notification"])
        XCTAssertEqual(config?["Notification"]?.count, 1)
    }

    func testOnNotification_Invocation() async throws {
        let registry = HookRegistry()
        let capturedMsg = TestCapture<String>()
        let capturedType = TestCapture<String>()
        let capturedTitle = TestCapture<String>()
        await registry.onNotification { input in
            capturedMsg.value = input.message
            capturedType.value = input.notificationType
            capturedTitle.value = input.title ?? "nil"
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .notification)!
        var rawInput = makeBaseRawInput(event: "Notification")
        rawInput["message"] = .string("Task started")
        rawInput["notification_type"] = .string("info")
        rawInput["title"] = .string("Agent Update")
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedMsg.value, "Task started")
        XCTAssertEqual(capturedType.value, "info")
        XCTAssertEqual(capturedTitle.value, "Agent Update")
        XCTAssertTrue(output.shouldContinue)
    }

    func testOnNotification_InvocationWithoutTitle() async throws {
        let registry = HookRegistry()
        let capturedTitle = TestCapture<String>()
        await registry.onNotification { input in
            capturedTitle.value = input.title ?? "nil"
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .notification)!
        var rawInput = makeBaseRawInput(event: "Notification")
        rawInput["message"] = .string("msg")
        rawInput["notification_type"] = .string("warning")
        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertEqual(capturedTitle.value, "nil")
    }

    func testSessionOnNotification_Registration() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        await session.onNotification { _ in .continue() }
    }

    // MARK: - Stop Output Variants

    func testOnStop_ReturnsStopOutput() async throws {
        let registry = HookRegistry()
        await registry.onStop { _ in
            .stop(reason: "User requested stop")
        }
        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        var rawInput = makeBaseRawInput(event: "Stop")
        rawInput["stop_hook_active"] = .bool(false)
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertFalse(output.shouldContinue)
        XCTAssertEqual(output.stopReason, "User requested stop")
    }

    // MARK: - Multiple Registrations for Same Event

    func testMultipleRegistrations_SameEvent() async throws {
        let registry = HookRegistry()
        await registry.onNotification { _ in .continue() }
        await registry.onNotification { _ in .continue() }
        let config = await registry.getHookConfig()
        XCTAssertEqual(config?["Notification"]?.count, 2)
        let count = await registry.callbackCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - All 11 Events Register in One Registry

    func testAll11EventsRegisteredTogether() async throws {
        let registry = HookRegistry()
        await registry.onStop { _ in .continue() }
        await registry.onSetup { _ in .continue() }
        await registry.onTeammateIdle { _ in .continue() }
        await registry.onTaskCompleted { _ in .continue() }
        await registry.onSessionStart { _ in .continue() }
        await registry.onSessionEnd { _ in .continue() }
        await registry.onSubagentStart { _ in .continue() }
        await registry.onSubagentStop { _ in .continue() }
        await registry.onPreCompact { _ in .continue() }
        await registry.onPermissionRequest { _ in .continue() }
        await registry.onNotification { _ in .continue() }

        let registered = await registry.registeredEvents
        XCTAssertTrue(registered.contains(.stop))
        XCTAssertTrue(registered.contains(.setup))
        XCTAssertTrue(registered.contains(.teammateIdle))
        XCTAssertTrue(registered.contains(.taskCompleted))
        XCTAssertTrue(registered.contains(.sessionStart))
        XCTAssertTrue(registered.contains(.sessionEnd))
        XCTAssertTrue(registered.contains(.subagentStart))
        XCTAssertTrue(registered.contains(.subagentStop))
        XCTAssertTrue(registered.contains(.preCompact))
        XCTAssertTrue(registered.contains(.permissionRequest))
        XCTAssertTrue(registered.contains(.notification))
        let count = await registry.callbackCount
        XCTAssertEqual(count, 11)
    }

    // MARK: - Logger Coverage

    /// Test that HookRegistry with a logger covers the debug log lines.
    func testRegistrationWithLogger_CoversDebugLines() async throws {
        let logger = Logger(subsystem: "com.clodkit.tests", category: "HookRegistryTests")
        let registry = HookRegistry(logger: logger)

        await registry.onPreToolUse { _ in .continue() }
        await registry.onPostToolUse { _ in .continue() }
        await registry.onPostToolUseFailure { _ in .continue() }
        await registry.onUserPromptSubmit { _ in .continue() }
        await registry.onStop { _ in .continue() }
        await registry.onSetup { _ in .continue() }
        await registry.onTeammateIdle { _ in .continue() }
        await registry.onTaskCompleted { _ in .continue() }
        await registry.onSessionStart { _ in .continue() }
        await registry.onSessionEnd { _ in .continue() }
        await registry.onSubagentStart { _ in .continue() }
        await registry.onSubagentStop { _ in .continue() }
        await registry.onPreCompact { _ in .continue() }
        await registry.onPermissionRequest { _ in .continue() }
        await registry.onNotification { _ in .continue() }

        let count = await registry.callbackCount
        XCTAssertEqual(count, 15)

        // Invoke one to cover the invocation debug log line
        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        var rawInput = makeBaseRawInput(event: "Stop")
        rawInput["stop_hook_active"] = .bool(false)
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - Callback Not Found

    func testInvokeCallback_UnknownIdThrows() async throws {
        let registry = HookRegistry()
        let rawInput = makeBaseRawInput(event: "Stop")
        do {
            _ = try await registry.invokeCallback(callbackId: "nonexistent", rawInput: rawInput)
            XCTFail("Expected HookError.callbackNotFound")
        } catch let error as HookError {
            if case .callbackNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected callbackNotFound, got \(error)")
            }
        }
    }
}
