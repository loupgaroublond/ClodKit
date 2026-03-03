//
//  HookExpansionTests.swift
//  ClodKitTests
//
//  Behavioral tests for the hook system expansion from 15 to 20 events.
//  Covers: new HookEvent cases, new input/output types, lastAssistantMessage fields.
//

import XCTest
@testable import ClodKit

final class HookExpansionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - HookEvent Has Exactly 20 Cases

    func testHookEventHasExactly20Cases() {
        XCTAssertEqual(HookEvent.allCases.count, 20)
    }

    func testAllNewEventsExistInAllCases() {
        let newEvents: Set<HookEvent> = [
            .elicitation, .elicitationResult, .configChange,
            .worktreeCreate, .worktreeRemove
        ]
        let allCasesSet = Set(HookEvent.allCases)
        for event in newEvents {
            XCTAssertTrue(allCasesSet.contains(event),
                          "HookEvent.allCases missing: \(event)")
        }
    }

    func testAllEventsPresentInAllCases() {
        let expected: Set<HookEvent> = [
            .preToolUse, .postToolUse, .postToolUseFailure,
            .userPromptSubmit, .stop, .subagentStart, .subagentStop,
            .preCompact, .permissionRequest, .sessionStart, .sessionEnd,
            .notification, .setup, .teammateIdle, .taskCompleted,
            .elicitation, .elicitationResult, .configChange,
            .worktreeCreate, .worktreeRemove
        ]
        XCTAssertEqual(Set(HookEvent.allCases), expected)
    }

    // MARK: - New HookEvent Raw Values (Round-Trip JSON)

    func testElicitationRawValue() {
        XCTAssertEqual(HookEvent.elicitation.rawValue, "Elicitation")
    }

    func testElicitationResultRawValue() {
        XCTAssertEqual(HookEvent.elicitationResult.rawValue, "ElicitationResult")
    }

    func testConfigChangeRawValue() {
        XCTAssertEqual(HookEvent.configChange.rawValue, "ConfigChange")
    }

    func testWorktreeCreateRawValue() {
        XCTAssertEqual(HookEvent.worktreeCreate.rawValue, "WorktreeCreate")
    }

    func testWorktreeRemoveRawValue() {
        XCTAssertEqual(HookEvent.worktreeRemove.rawValue, "WorktreeRemove")
    }

    func testElicitationRoundTripJSON() throws {
        let encoded = try JSONEncoder().encode(HookEvent.elicitation)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: encoded)
        XCTAssertEqual(decoded, .elicitation)
    }

    func testElicitationResultRoundTripJSON() throws {
        let encoded = try JSONEncoder().encode(HookEvent.elicitationResult)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: encoded)
        XCTAssertEqual(decoded, .elicitationResult)
    }

    func testConfigChangeRoundTripJSON() throws {
        let encoded = try JSONEncoder().encode(HookEvent.configChange)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: encoded)
        XCTAssertEqual(decoded, .configChange)
    }

    func testWorktreeCreateRoundTripJSON() throws {
        let encoded = try JSONEncoder().encode(HookEvent.worktreeCreate)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: encoded)
        XCTAssertEqual(decoded, .worktreeCreate)
    }

    func testWorktreeRemoveRoundTripJSON() throws {
        let encoded = try JSONEncoder().encode(HookEvent.worktreeRemove)
        let decoded = try JSONDecoder().decode(HookEvent.self, from: encoded)
        XCTAssertEqual(decoded, .worktreeRemove)
    }

    func testNewEventsInitFromRawValue() {
        XCTAssertEqual(HookEvent(rawValue: "Elicitation"), .elicitation)
        XCTAssertEqual(HookEvent(rawValue: "ElicitationResult"), .elicitationResult)
        XCTAssertEqual(HookEvent(rawValue: "ConfigChange"), .configChange)
        XCTAssertEqual(HookEvent(rawValue: "WorktreeCreate"), .worktreeCreate)
        XCTAssertEqual(HookEvent(rawValue: "WorktreeRemove"), .worktreeRemove)
    }

    // MARK: - HookInput Has 20 Cases Matching HookEvent

    func testHookInputHas20Cases() {
        let base = makeBase(.preToolUse)
        let inputs: [HookInput] = [
            .preToolUse(PreToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolUseId: "t1")),
            .postToolUse(PostToolUseInput(base: base, toolName: "Bash", toolInput: [:], toolResponse: .null, toolUseId: "t2")),
            .postToolUseFailure(PostToolUseFailureInput(base: base, toolName: "Bash", toolInput: [:], error: "err", isInterrupt: false, toolUseId: "t3")),
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
            .teammateIdle(TeammateIdleInput(base: base, teammateName: "worker", teamName: "team")),
            .taskCompleted(TaskCompletedInput(base: base, taskId: "t1", taskSubject: "subject")),
            .elicitation(ElicitationInput(base: base, mcpServerName: "mcp", message: "Please fill in the form")),
            .elicitationResult(ElicitationResultInput(base: base, mcpServerName: "mcp", action: "accept")),
            .configChange(ConfigChangeInput(base: base, source: "user_settings")),
            .worktreeCreate(WorktreeCreateInput(base: base, name: "feature-branch")),
            .worktreeRemove(WorktreeRemoveInput(base: base, worktreePath: "/path/to/worktree")),
        ]
        XCTAssertEqual(inputs.count, 20)
    }

    func testHookInputEventTypeMatchesForNewCases() {
        let base = makeBase(.elicitation)
        let cases: [(HookInput, HookEvent)] = [
            (.elicitation(ElicitationInput(base: base, mcpServerName: "mcp", message: "msg")), .elicitation),
            (.elicitationResult(ElicitationResultInput(base: base, mcpServerName: "mcp", action: "accept")), .elicitationResult),
            (.configChange(ConfigChangeInput(base: base, source: "project_settings")), .configChange),
            (.worktreeCreate(WorktreeCreateInput(base: base, name: "my-worktree")), .worktreeCreate),
            (.worktreeRemove(WorktreeRemoveInput(base: base, worktreePath: "/wt/path")), .worktreeRemove),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(input.eventType, expected,
                           "Expected eventType \(expected) for \(input)")
        }
    }

    func testHookInputBaseFieldsFlowThroughNewTypes() {
        let base = BaseHookInput(
            sessionId: "sess-abc",
            transcriptPath: "/tmp/transcript",
            cwd: "/home/user",
            permissionMode: "default",
            hookEventName: .elicitation
        )
        let input = HookInput.elicitation(
            ElicitationInput(base: base, mcpServerName: "my-server", message: "Enter value")
        )
        XCTAssertEqual(input.base.sessionId, "sess-abc")
        XCTAssertEqual(input.base.cwd, "/home/user")
        XCTAssertEqual(input.base.hookEventName, .elicitation)
    }

    // MARK: - ElicitationInput Fields

    func testElicitationInputAllFields() {
        let base = makeBase(.elicitation)
        let input = ElicitationInput(
            base: base,
            mcpServerName: "my-mcp",
            message: "Please provide your name",
            mode: "form",
            url: nil,
            elicitationId: "elic-123",
            requestedSchema: ["name": .string("string")]
        )
        XCTAssertEqual(input.mcpServerName, "my-mcp")
        XCTAssertEqual(input.message, "Please provide your name")
        XCTAssertEqual(input.mode, "form")
        XCTAssertNil(input.url)
        XCTAssertEqual(input.elicitationId, "elic-123")
        XCTAssertNotNil(input.requestedSchema)
    }

    func testElicitationInputOptionalFieldsDefaultToNil() {
        let base = makeBase(.elicitation)
        let input = ElicitationInput(base: base, mcpServerName: "srv", message: "msg")
        XCTAssertNil(input.mode)
        XCTAssertNil(input.url)
        XCTAssertNil(input.elicitationId)
        XCTAssertNil(input.requestedSchema)
    }

    func testElicitationInputUrlMode() {
        let base = makeBase(.elicitation)
        let input = ElicitationInput(
            base: base,
            mcpServerName: "srv",
            message: "Visit this URL",
            mode: "url",
            url: "https://example.com/auth"
        )
        XCTAssertEqual(input.mode, "url")
        XCTAssertEqual(input.url, "https://example.com/auth")
    }

    // MARK: - ElicitationResultInput Fields

    func testElicitationResultInputAllFields() {
        let base = makeBase(.elicitationResult)
        let input = ElicitationResultInput(
            base: base,
            mcpServerName: "my-mcp",
            elicitationId: "elic-456",
            mode: "form",
            action: "accept",
            content: ["name": .string("Alice")]
        )
        XCTAssertEqual(input.mcpServerName, "my-mcp")
        XCTAssertEqual(input.elicitationId, "elic-456")
        XCTAssertEqual(input.mode, "form")
        XCTAssertEqual(input.action, "accept")
        XCTAssertNotNil(input.content)
    }

    func testElicitationResultInputDeclineAction() {
        let base = makeBase(.elicitationResult)
        let input = ElicitationResultInput(
            base: base,
            mcpServerName: "srv",
            action: "decline"
        )
        XCTAssertEqual(input.action, "decline")
        XCTAssertNil(input.content)
        XCTAssertNil(input.elicitationId)
    }

    func testElicitationResultInputCancelAction() {
        let base = makeBase(.elicitationResult)
        let input = ElicitationResultInput(
            base: base,
            mcpServerName: "srv",
            action: "cancel"
        )
        XCTAssertEqual(input.action, "cancel")
    }

    // MARK: - ConfigChangeInput Fields

    func testConfigChangeInputAllFields() {
        let base = makeBase(.configChange)
        let input = ConfigChangeInput(
            base: base,
            source: "project_settings",
            filePath: "/path/to/config.json"
        )
        XCTAssertEqual(input.source, "project_settings")
        XCTAssertEqual(input.filePath, "/path/to/config.json")
    }

    func testConfigChangeInputAllSources() {
        let base = makeBase(.configChange)
        let sources = ["user_settings", "project_settings", "local_settings",
                       "policy_settings", "skills"]
        for source in sources {
            let input = ConfigChangeInput(base: base, source: source)
            XCTAssertEqual(input.source, source)
        }
    }

    func testConfigChangeInputFilePathOptional() {
        let base = makeBase(.configChange)
        let input = ConfigChangeInput(base: base, source: "user_settings")
        XCTAssertNil(input.filePath)
    }

    // MARK: - WorktreeCreateInput Fields

    func testWorktreeCreateInputFields() {
        let base = makeBase(.worktreeCreate)
        let input = WorktreeCreateInput(base: base, name: "my-feature")
        XCTAssertEqual(input.name, "my-feature")
    }

    // MARK: - WorktreeRemoveInput Fields

    func testWorktreeRemoveInputFields() {
        let base = makeBase(.worktreeRemove)
        let input = WorktreeRemoveInput(base: base, worktreePath: "/worktrees/my-feature")
        XCTAssertEqual(input.worktreePath, "/worktrees/my-feature")
    }

    // MARK: - lastAssistantMessage on StopInput

    func testStopInputLastAssistantMessagePresent() {
        let base = makeBase(.stop)
        let input = StopInput(base: base, stopHookActive: false, lastAssistantMessage: "I'm done!")
        XCTAssertEqual(input.lastAssistantMessage, "I'm done!")
    }

    func testStopInputLastAssistantMessageAbsent() {
        let base = makeBase(.stop)
        let input = StopInput(base: base, stopHookActive: false)
        XCTAssertNil(input.lastAssistantMessage)
    }

    func testStopInputLastAssistantMessageDefaultsToNil() {
        let base = makeBase(.stop)
        let input = StopInput(base: base, stopHookActive: true)
        XCTAssertNil(input.lastAssistantMessage)
        XCTAssertTrue(input.stopHookActive)
    }

    // MARK: - lastAssistantMessage on SubagentStopInput

    func testSubagentStopInputLastAssistantMessagePresent() {
        let base = makeBase(.subagentStop)
        let input = SubagentStopInput(
            base: base,
            stopHookActive: false,
            agentTranscriptPath: "/t",
            agentId: "a1",
            agentType: "task",
            lastAssistantMessage: "Subagent finished."
        )
        XCTAssertEqual(input.lastAssistantMessage, "Subagent finished.")
    }

    func testSubagentStopInputLastAssistantMessageAbsent() {
        let base = makeBase(.subagentStop)
        let input = SubagentStopInput(
            base: base,
            stopHookActive: false,
            agentTranscriptPath: "/t",
            agentId: "a1",
            agentType: "task"
        )
        XCTAssertNil(input.lastAssistantMessage)
    }

    // MARK: - Input Parsing from Raw JSON (HookRegistry)

    func testElicitationInputParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onElicitation { input in
            await capture.set("mcpServerName", input.mcpServerName)
            await capture.set("message", input.message)
            await capture.set("mode", input.mode ?? "")
            await capture.set("elicitationId", input.elicitationId ?? "")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .elicitation)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Elicitation"),
            "mcp_server_name": .string("my-server"),
            "message": .string("Please enter your name"),
            "mode": .string("form"),
            "elicitation_id": .string("elic-789"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let name = await capture.get("mcpServerName")
        let msg = await capture.get("message")
        let mode = await capture.get("mode")
        let elicId = await capture.get("elicitationId")
        XCTAssertEqual(name, "my-server")
        XCTAssertEqual(msg, "Please enter your name")
        XCTAssertEqual(mode, "form")
        XCTAssertEqual(elicId, "elic-789")
    }

    func testElicitationResultInputParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onElicitationResult { input in
            await capture.set("mcpServerName", input.mcpServerName)
            await capture.set("action", input.action)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .elicitationResult)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("ElicitationResult"),
            "mcp_server_name": .string("result-server"),
            "action": .string("accept"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let name = await capture.get("mcpServerName")
        let action = await capture.get("action")
        XCTAssertEqual(name, "result-server")
        XCTAssertEqual(action, "accept")
    }

    func testConfigChangeInputParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onConfigChange { input in
            await capture.set("source", input.source)
            await capture.set("filePath", input.filePath ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .configChange)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("ConfigChange"),
            "source": .string("local_settings"),
            "file_path": .string("/home/user/.claude/settings.json"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let source = await capture.get("source")
        let filePath = await capture.get("filePath")
        XCTAssertEqual(source, "local_settings")
        XCTAssertEqual(filePath, "/home/user/.claude/settings.json")
    }

    func testWorktreeCreateInputParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onWorktreeCreate { input in
            await capture.set("name", input.name)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .worktreeCreate)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("WorktreeCreate"),
            "name": .string("my-feature-branch"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let name = await capture.get("name")
        XCTAssertEqual(name, "my-feature-branch")
    }

    func testWorktreeRemoveInputParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onWorktreeRemove { input in
            await capture.set("worktreePath", input.worktreePath)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .worktreeRemove)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("WorktreeRemove"),
            "worktree_path": .string("/worktrees/my-feature-branch"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let path = await capture.get("worktreePath")
        XCTAssertEqual(path, "/worktrees/my-feature-branch")
    }

    func testStopInputLastAssistantMessageParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onStop { input in
            await capture.set("lastAssistantMessage", input.lastAssistantMessage ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Stop"),
            "stop_hook_active": .bool(false),
            "last_assistant_message": .string("Task complete."),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let msg = await capture.get("lastAssistantMessage")
        XCTAssertEqual(msg, "Task complete.")
    }

    func testSubagentStopLastAssistantMessageParsedFromRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onSubagentStop { input in
            await capture.set("lastAssistantMessage", input.lastAssistantMessage ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .subagentStop)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("SubagentStop"),
            "stop_hook_active": .bool(false),
            "agent_transcript_path": .string("/agent/t"),
            "agent_id": .string("agent-1"),
            "agent_type": .string("task"),
            "last_assistant_message": .string("Subagent done."),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let msg = await capture.get("lastAssistantMessage")
        XCTAssertEqual(msg, "Subagent done.")
    }

    func testStopInputLastAssistantMessageAbsentInRawJSON() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onStop { input in
            await capture.set("lastAssistantMessage", input.lastAssistantMessage ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Stop"),
            "stop_hook_active": .bool(false),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let msg = await capture.get("lastAssistantMessage")
        XCTAssertEqual(msg, "nil")
    }

    // MARK: - HookSpecificOutput Has 11 Cases

    func testHookSpecificOutputElicitationEncoding() {
        let output = ElicitationHookOutput(action: "accept", content: ["name": .string("Alice")])
        let specific = HookSpecificOutput.elicitation(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Elicitation")
        XCTAssertEqual(dict["action"] as? String, "accept")
        XCTAssertNotNil(dict["content"])
    }

    func testHookSpecificOutputElicitationEncodingNoContent() {
        let output = ElicitationHookOutput(action: "decline")
        let specific = HookSpecificOutput.elicitation(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Elicitation")
        XCTAssertEqual(dict["action"] as? String, "decline")
        XCTAssertNil(dict["content"])
    }

    func testHookSpecificOutputElicitationEncodingNoAction() {
        let output = ElicitationHookOutput()
        let specific = HookSpecificOutput.elicitation(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Elicitation")
        XCTAssertNil(dict["action"])
        XCTAssertNil(dict["content"])
    }

    func testHookSpecificOutputElicitationResultEncoding() {
        let output = ElicitationResultHookOutput(action: "cancel")
        let specific = HookSpecificOutput.elicitationResult(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "ElicitationResult")
        XCTAssertEqual(dict["action"] as? String, "cancel")
    }

    func testHookSpecificOutputElicitationResultWithContent() {
        let output = ElicitationResultHookOutput(
            action: "accept",
            content: ["answer": .string("42")]
        )
        let specific = HookSpecificOutput.elicitationResult(output)
        let dict = specific.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "ElicitationResult")
        XCTAssertEqual(dict["action"] as? String, "accept")
        XCTAssertNotNil(dict["content"])
    }

    func testElicitationHookOutputInitDefaults() {
        let output = ElicitationHookOutput()
        XCTAssertNil(output.action)
        XCTAssertNil(output.content)
    }

    func testElicitationResultHookOutputInitDefaults() {
        let output = ElicitationResultHookOutput()
        XCTAssertNil(output.action)
        XCTAssertNil(output.content)
    }

    // MARK: - HookRegistry Accepts All 20 Events

    func testHookRegistryAcceptsAll20Events() async {
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
        await registry.onElicitation { _ in .continue() }
        await registry.onElicitationResult { _ in .continue() }
        await registry.onConfigChange { _ in .continue() }
        await registry.onWorktreeCreate { _ in .continue() }
        await registry.onWorktreeRemove { _ in .continue() }

        let registered = await registry.registeredEvents
        XCTAssertEqual(registered.count, 20)
        for event in HookEvent.allCases {
            XCTAssertTrue(registered.contains(event),
                          "Event \(event.rawValue) missing from registry")
        }
    }

    func testHookRegistryCallbackCountForNewEvents() async {
        let registry = HookRegistry()

        await registry.onElicitation { _ in .continue() }
        await registry.onElicitationResult { _ in .continue() }
        await registry.onConfigChange { _ in .continue() }
        await registry.onWorktreeCreate { _ in .continue() }
        await registry.onWorktreeRemove { _ in .continue() }

        let count = await registry.callbackCount
        XCTAssertEqual(count, 5)
    }

    // MARK: - Callback Invocation for New Events

    func testElicitationCallbackInvocation() async throws {
        let registry = HookRegistry()
        let flag = TestBoolFlag()

        await registry.onElicitation { _ in
            await flag.set(true)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .elicitation)!
        let base = makeBase(.elicitation)
        let input = HookInput.elicitation(
            ElicitationInput(base: base, mcpServerName: "srv", message: "Hello")
        )

        let result = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let wasCalled = await flag.value
        XCTAssertTrue(wasCalled)
        XCTAssertTrue(result.shouldContinue)
    }

    func testConfigChangeCallbackInvocation() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onConfigChange { input in
            await capture.set("source", input.source)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .configChange)!
        let base = makeBase(.configChange)
        let input = HookInput.configChange(
            ConfigChangeInput(base: base, source: "policy_settings", filePath: nil)
        )

        _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let source = await capture.get("source")
        XCTAssertEqual(source, "policy_settings")
    }

    func testWorktreeCreateCallbackInvocation() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onWorktreeCreate { input in
            await capture.set("name", input.name)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .worktreeCreate)!
        let base = makeBase(.worktreeCreate)
        let input = HookInput.worktreeCreate(
            WorktreeCreateInput(base: base, name: "test-worktree")
        )

        _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let name = await capture.get("name")
        XCTAssertEqual(name, "test-worktree")
    }

    func testWorktreeRemoveCallbackInvocation() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onWorktreeRemove { input in
            await capture.set("path", input.worktreePath)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .worktreeRemove)!
        let base = makeBase(.worktreeRemove)
        let input = HookInput.worktreeRemove(
            WorktreeRemoveInput(base: base, worktreePath: "/wt/test-worktree")
        )

        _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let path = await capture.get("path")
        XCTAssertEqual(path, "/wt/test-worktree")
    }

    func testElicitationResultCallbackInvocation() async throws {
        let registry = HookRegistry()
        let capture = ExpandCaptureBox()

        await registry.onElicitationResult { input in
            await capture.set("action", input.action)
            await capture.set("server", input.mcpServerName)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .elicitationResult)!
        let base = makeBase(.elicitationResult)
        let input = HookInput.elicitationResult(
            ElicitationResultInput(base: base, mcpServerName: "my-mcp", action: "decline")
        )

        _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
        let action = await capture.get("action")
        let server = await capture.get("server")
        XCTAssertEqual(action, "decline")
        XCTAssertEqual(server, "my-mcp")
    }

    // MARK: - HookConfig Includes New Events

    func testHookConfigContainsNewEvents() async {
        let registry = HookRegistry()

        await registry.onElicitation { _ in .continue() }
        await registry.onConfigChange { _ in .continue() }
        await registry.onWorktreeCreate { _ in .continue() }

        let config = await registry.getHookConfig()
        XCTAssertNotNil(config)
        XCTAssertNotNil(config?["Elicitation"])
        XCTAssertNotNil(config?["ConfigChange"])
        XCTAssertNotNil(config?["WorktreeCreate"])
        XCTAssertNil(config?["WorktreeRemove"])
    }

    // MARK: - Private Helpers

    private func makeBase(_ event: HookEvent) -> BaseHookInput {
        BaseHookInput(
            sessionId: "test-session",
            transcriptPath: "/tmp/transcript",
            cwd: "/project",
            permissionMode: "default",
            hookEventName: event
        )
    }
}

// MARK: - Thread-Safe Capture Helpers

private actor ExpandCaptureBox {
    private var values: [String: String] = [:]
    func set(_ key: String, _ value: String) { values[key] = value }
    func get(_ key: String) -> String? { values[key] }
}

private actor TestBoolFlag {
    private(set) var value: Bool = false
    func set(_ v: Bool) { value = v }
}
