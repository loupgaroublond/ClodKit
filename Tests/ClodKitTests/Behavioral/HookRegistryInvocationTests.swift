//
//  HookRegistryInvocationTests.swift
//  ClodKitTests
//
//  Tests that exercise the HookRegistry's invokeCallback paths for ALL 20 hook
//  event types, with a Logger to cover logger?.debug lines in registration
//  and invocation methods.
//

import XCTest
import os
@testable import ClodKit

final class HookRegistryInvocationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private let logger = Logger(subsystem: "com.clodkit.tests", category: "HookRegistryInvocationTests")

    /// Standard base fields included in all rawInput dictionaries.
    private var baseRawInput: [String: JSONValue] {
        [
            "session_id": .string("test-session"),
            "transcript_path": .string("/tmp/transcript.json"),
            "cwd": .string("/tmp"),
            "permission_mode": .string("default"),
        ]
    }

    // MARK: - PreToolUse

    func testInvoke_PreToolUse() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onPreToolUse { input in
            XCTAssertEqual(input.toolName, "Bash")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .preToolUse)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("PreToolUse")
        raw["tool_name"] = .string("Bash")
        raw["tool_input"] = .object(["command": .string("ls")])
        raw["tool_use_id"] = .string("tu_1")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - PostToolUse

    func testInvoke_PostToolUse() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onPostToolUse { input in
            XCTAssertEqual(input.toolName, "Read")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .postToolUse)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("PostToolUse")
        raw["tool_name"] = .string("Read")
        raw["tool_input"] = .object([:])
        raw["tool_response"] = .string("file content")
        raw["tool_use_id"] = .string("tu_2")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - PostToolUseFailure

    func testInvoke_PostToolUseFailure() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onPostToolUseFailure { input in
            XCTAssertEqual(input.error, "file not found")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .postToolUseFailure)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("PostToolUseFailure")
        raw["tool_name"] = .string("Read")
        raw["tool_input"] = .object([:])
        raw["error"] = .string("file not found")
        raw["is_interrupt"] = .bool(false)
        raw["tool_use_id"] = .string("tu_3")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - UserPromptSubmit

    func testInvoke_UserPromptSubmit() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onUserPromptSubmit { input in
            XCTAssertEqual(input.prompt, "hello")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .userPromptSubmit)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("UserPromptSubmit")
        raw["prompt"] = .string("hello")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - Stop

    func testInvoke_Stop() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onStop { input in
            XCTAssertTrue(input.stopHookActive)
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .stop)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("Stop")
        raw["stop_hook_active"] = .bool(true)
        raw["last_assistant_message"] = .string("Done")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - SubagentStart

    func testInvoke_SubagentStart() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onSubagentStart { input in
            XCTAssertEqual(input.agentId, "agent_1")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .subagentStart)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("SubagentStart")
        raw["agent_id"] = .string("agent_1")
        raw["agent_type"] = .string("researcher")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - SubagentStop

    func testInvoke_SubagentStop() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onSubagentStop { input in
            XCTAssertEqual(input.agentId, "agent_2")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .subagentStop)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("SubagentStop")
        raw["stop_hook_active"] = .bool(false)
        raw["agent_transcript_path"] = .string("/tmp/agent.json")
        raw["agent_id"] = .string("agent_2")
        raw["agent_type"] = .string("coder")
        raw["last_assistant_message"] = .string("bye")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - PreCompact

    func testInvoke_PreCompact() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onPreCompact { input in
            XCTAssertEqual(input.trigger, "context_limit")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .preCompact)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("PreCompact")
        raw["trigger"] = .string("context_limit")
        raw["custom_instructions"] = .string("Summarize")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - PermissionRequest

    func testInvoke_PermissionRequest() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onPermissionRequest { input in
            XCTAssertEqual(input.toolName, "Write")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .permissionRequest)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("PermissionRequest")
        raw["tool_name"] = .string("Write")
        raw["tool_input"] = .object([:])
        raw["permission_suggestions"] = .array([.string("allow_once")])
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - SessionStart

    func testInvoke_SessionStart() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onSessionStart { input in
            XCTAssertEqual(input.source, "cli")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .sessionStart)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("SessionStart")
        raw["source"] = .string("cli")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - SessionEnd

    func testInvoke_SessionEnd() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onSessionEnd { input in
            XCTAssertEqual(input.reason, .other)
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .sessionEnd)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("SessionEnd")
        raw["reason"] = .string("other")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - Notification

    func testInvoke_Notification() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onNotification { input in
            XCTAssertEqual(input.message, "Task done")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .notification)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("Notification")
        raw["message"] = .string("Task done")
        raw["notification_type"] = .string("info")
        raw["title"] = .string("Notice")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - Setup

    func testInvoke_Setup() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onSetup { input in
            XCTAssertEqual(input.trigger, "session_start")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .setup)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("Setup")
        raw["trigger"] = .string("session_start")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - TeammateIdle

    func testInvoke_TeammateIdle() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onTeammateIdle { input in
            XCTAssertEqual(input.teammateName, "researcher")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .teammateIdle)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("TeammateIdle")
        raw["teammate_name"] = .string("researcher")
        raw["team_name"] = .string("alpha")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - TaskCompleted

    func testInvoke_TaskCompleted() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onTaskCompleted { input in
            XCTAssertEqual(input.taskId, "task_42")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .taskCompleted)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("TaskCompleted")
        raw["task_id"] = .string("task_42")
        raw["task_subject"] = .string("Fix bug")
        raw["task_description"] = .string("A critical bug")
        raw["teammate_name"] = .string("coder")
        raw["team_name"] = .string("beta")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - Elicitation

    func testInvoke_Elicitation() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onElicitation { input in
            XCTAssertEqual(input.mcpServerName, "auth-srv")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .elicitation)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("Elicitation")
        raw["mcp_server_name"] = .string("auth-srv")
        raw["message"] = .string("Enter token")
        raw["mode"] = .string("form")
        raw["url"] = .string("https://example.com")
        raw["elicitation_id"] = .string("e_1")
        raw["requested_schema"] = .object(["type": .string("object")])
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - ElicitationResult

    func testInvoke_ElicitationResult() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onElicitationResult { input in
            XCTAssertEqual(input.action, "submit")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .elicitationResult)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("ElicitationResult")
        raw["mcp_server_name"] = .string("auth-srv")
        raw["elicitation_id"] = .string("e_1")
        raw["mode"] = .string("form")
        raw["action"] = .string("submit")
        raw["content"] = .object(["token": .string("abc123")])
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - ConfigChange

    func testInvoke_ConfigChange() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onConfigChange { input in
            XCTAssertEqual(input.source, "settings")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .configChange)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("ConfigChange")
        raw["source"] = .string("settings")
        raw["file_path"] = .string("/home/.claude/settings.json")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - WorktreeCreate

    func testInvoke_WorktreeCreate() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onWorktreeCreate { input in
            XCTAssertEqual(input.name, "feature-branch")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .worktreeCreate)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("WorktreeCreate")
        raw["name"] = .string("feature-branch")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - WorktreeRemove

    func testInvoke_WorktreeRemove() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onWorktreeRemove { input in
            XCTAssertEqual(input.worktreePath, "/tmp/worktree")
            return .continue()
        }
        let id = await registry.getCallbackId(forEvent: .worktreeRemove)!
        var raw = baseRawInput
        raw["hook_event_name"] = .string("WorktreeRemove")
        raw["worktree_path"] = .string("/tmp/worktree")
        let output = try await registry.invokeCallback(callbackId: id, rawInput: raw)
        XCTAssertTrue(output.shouldContinue)
    }

    // MARK: - CallbackBox.invoke with Wrong Input Type

    func testInvoke_WrongInputType_ThrowsInvalidInput() async throws {
        let registry = HookRegistry(logger: logger)
        await registry.onPreToolUse { _ in .continue() }
        let id = await registry.getCallbackId(forEvent: .preToolUse)!

        // Invoke with a StopInput (wrong type for PreToolUse)
        let base = BaseHookInput(sessionId: "", transcriptPath: "", cwd: "", permissionMode: "", hookEventName: .stop)
        let wrongInput = HookInput.stop(StopInput(base: base, stopHookActive: false))

        do {
            _ = try await registry.invokeCallback(callbackId: id, input: wrongInput)
            XCTFail("Expected HookError.invalidInput")
        } catch let error as HookError {
            if case .invalidInput(let msg) = error {
                XCTAssertTrue(msg.contains("Cannot extract input"))
            } else {
                XCTFail("Expected invalidInput, got \(error)")
            }
        }
    }
}
