//
//  LowCoverageTests.swift
//  ClodKitTests
//
//  Tests targeting low-coverage code paths across multiple source files:
//  HookConfigs, HookOutputTypes, HookRegistry, ParamBuilder, SDKSessionInfo, SchemaValidator.
//

import XCTest
@testable import ClodKit

// MARK: - Hook Config Init Tests

final class HookConfigInitTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - PreToolUseHookConfig

    func testPreToolUseHookConfigDefaultParams() {
        let config = PreToolUseHookConfig { _ in .continue() }
        XCTAssertNil(config.pattern)
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testPreToolUseHookConfigAllParams() {
        let config = PreToolUseHookConfig(pattern: "Bash.*", timeout: 30.0) { _ in .stop() }
        XCTAssertEqual(config.pattern, "Bash.*")
        XCTAssertEqual(config.timeout, 30.0)
    }

    func testPreToolUseHookConfigPatternOnly() {
        let config = PreToolUseHookConfig(pattern: "Write") { _ in .continue() }
        XCTAssertEqual(config.pattern, "Write")
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testPreToolUseHookConfigTimeoutOnly() {
        let config = PreToolUseHookConfig(timeout: 120.0) { _ in .continue() }
        XCTAssertNil(config.pattern)
        XCTAssertEqual(config.timeout, 120.0)
    }

    // MARK: - PostToolUseHookConfig

    func testPostToolUseHookConfigDefaultParams() {
        let config = PostToolUseHookConfig { _ in .continue() }
        XCTAssertNil(config.pattern)
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testPostToolUseHookConfigAllParams() {
        let config = PostToolUseHookConfig(pattern: "Read.*", timeout: 15.0) { _ in .continue() }
        XCTAssertEqual(config.pattern, "Read.*")
        XCTAssertEqual(config.timeout, 15.0)
    }

    // MARK: - PostToolUseFailureHookConfig

    func testPostToolUseFailureHookConfigDefaultParams() {
        let config = PostToolUseFailureHookConfig { _ in .continue() }
        XCTAssertNil(config.pattern)
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testPostToolUseFailureHookConfigAllParams() {
        let config = PostToolUseFailureHookConfig(pattern: "Bash", timeout: 5.0) { _ in .stop() }
        XCTAssertEqual(config.pattern, "Bash")
        XCTAssertEqual(config.timeout, 5.0)
    }

    // MARK: - UserPromptSubmitHookConfig

    func testUserPromptSubmitHookConfigDefaultParams() {
        let config = UserPromptSubmitHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testUserPromptSubmitHookConfigCustomTimeout() {
        let config = UserPromptSubmitHookConfig(timeout: 90.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 90.0)
    }

    // MARK: - StopHookConfig

    func testStopHookConfigDefaultParams() {
        let config = StopHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testStopHookConfigCustomTimeout() {
        let config = StopHookConfig(timeout: 10.0) { _ in .stop(reason: "done") }
        XCTAssertEqual(config.timeout, 10.0)
    }

    // MARK: - SetupHookConfig

    func testSetupHookConfigDefaultParams() {
        let config = SetupHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testSetupHookConfigCustomTimeout() {
        let config = SetupHookConfig(timeout: 45.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 45.0)
    }

    // MARK: - TeammateIdleHookConfig

    func testTeammateIdleHookConfigDefaultParams() {
        let config = TeammateIdleHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testTeammateIdleHookConfigCustomTimeout() {
        let config = TeammateIdleHookConfig(timeout: 20.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 20.0)
    }

    // MARK: - TaskCompletedHookConfig

    func testTaskCompletedHookConfigDefaultParams() {
        let config = TaskCompletedHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testTaskCompletedHookConfigCustomTimeout() {
        let config = TaskCompletedHookConfig(timeout: 25.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 25.0)
    }

    // MARK: - SessionStartHookConfig

    func testSessionStartHookConfigDefaultParams() {
        let config = SessionStartHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testSessionStartHookConfigCustomTimeout() {
        let config = SessionStartHookConfig(timeout: 15.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 15.0)
    }

    // MARK: - SessionEndHookConfig

    func testSessionEndHookConfigDefaultParams() {
        let config = SessionEndHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testSessionEndHookConfigCustomTimeout() {
        let config = SessionEndHookConfig(timeout: 35.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 35.0)
    }

    // MARK: - SubagentStartHookConfig

    func testSubagentStartHookConfigDefaultParams() {
        let config = SubagentStartHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testSubagentStartHookConfigCustomTimeout() {
        let config = SubagentStartHookConfig(timeout: 50.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 50.0)
    }

    // MARK: - SubagentStopHookConfig

    func testSubagentStopHookConfigDefaultParams() {
        let config = SubagentStopHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testSubagentStopHookConfigCustomTimeout() {
        let config = SubagentStopHookConfig(timeout: 55.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 55.0)
    }

    // MARK: - PreCompactHookConfig

    func testPreCompactHookConfigDefaultParams() {
        let config = PreCompactHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testPreCompactHookConfigCustomTimeout() {
        let config = PreCompactHookConfig(timeout: 70.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 70.0)
    }

    // MARK: - PermissionRequestHookConfig

    func testPermissionRequestHookConfigDefaultParams() {
        let config = PermissionRequestHookConfig { _ in .continue() }
        XCTAssertNil(config.pattern)
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testPermissionRequestHookConfigAllParams() {
        let config = PermissionRequestHookConfig(pattern: "Bash", timeout: 10.0) { _ in .continue() }
        XCTAssertEqual(config.pattern, "Bash")
        XCTAssertEqual(config.timeout, 10.0)
    }

    // MARK: - NotificationHookConfig

    func testNotificationHookConfigDefaultParams() {
        let config = NotificationHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testNotificationHookConfigCustomTimeout() {
        let config = NotificationHookConfig(timeout: 40.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 40.0)
    }

    // MARK: - ElicitationHookConfig

    func testElicitationHookConfigDefaultParams() {
        let config = ElicitationHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testElicitationHookConfigCustomTimeout() {
        let config = ElicitationHookConfig(timeout: 80.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 80.0)
    }

    // MARK: - ElicitationResultHookConfig

    func testElicitationResultHookConfigDefaultParams() {
        let config = ElicitationResultHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testElicitationResultHookConfigCustomTimeout() {
        let config = ElicitationResultHookConfig(timeout: 100.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 100.0)
    }

    // MARK: - ConfigChangeHookConfig

    func testConfigChangeHookConfigDefaultParams() {
        let config = ConfigChangeHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testConfigChangeHookConfigCustomTimeout() {
        let config = ConfigChangeHookConfig(timeout: 33.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 33.0)
    }

    // MARK: - WorktreeCreateHookConfig

    func testWorktreeCreateHookConfigDefaultParams() {
        let config = WorktreeCreateHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testWorktreeCreateHookConfigCustomTimeout() {
        let config = WorktreeCreateHookConfig(timeout: 22.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 22.0)
    }

    // MARK: - WorktreeRemoveHookConfig

    func testWorktreeRemoveHookConfigDefaultParams() {
        let config = WorktreeRemoveHookConfig { _ in .continue() }
        XCTAssertEqual(config.timeout, 60.0)
    }

    func testWorktreeRemoveHookConfigCustomTimeout() {
        let config = WorktreeRemoveHookConfig(timeout: 11.0) { _ in .continue() }
        XCTAssertEqual(config.timeout, 11.0)
    }
}

// MARK: - Hook Output Types Coverage Tests

final class HookOutputTypesCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - SetupHookOutput

    func testSetupHookOutputInit() {
        let output = SetupHookOutput()
        XCTAssertNil(output.additionalContext)
    }

    func testSetupHookOutputWithContext() {
        let output = SetupHookOutput(additionalContext: "Setup complete")
        XCTAssertEqual(output.additionalContext, "Setup complete")
    }

    // MARK: - SessionStartHookOutput

    func testSessionStartHookOutputInit() {
        let output = SessionStartHookOutput()
        XCTAssertNil(output.additionalContext)
    }

    func testSessionStartHookOutputWithContext() {
        let output = SessionStartHookOutput(additionalContext: "Session initialized")
        XCTAssertEqual(output.additionalContext, "Session initialized")
    }

    // MARK: - SubagentStartHookOutput

    func testSubagentStartHookOutputInit() {
        let output = SubagentStartHookOutput()
        XCTAssertNil(output.additionalContext)
    }

    func testSubagentStartHookOutputWithContext() {
        let output = SubagentStartHookOutput(additionalContext: "Subagent ready")
        XCTAssertEqual(output.additionalContext, "Subagent ready")
    }

    // MARK: - PostToolUseFailureHookOutput

    func testPostToolUseFailureHookOutputInit() {
        let output = PostToolUseFailureHookOutput()
        XCTAssertNil(output.additionalContext)
    }

    func testPostToolUseFailureHookOutputWithContext() {
        let output = PostToolUseFailureHookOutput(additionalContext: "Retry suggested")
        XCTAssertEqual(output.additionalContext, "Retry suggested")
    }

    // MARK: - NotificationHookOutput

    func testNotificationHookOutputInit() {
        let output = NotificationHookOutput()
        XCTAssertNil(output.additionalContext)
    }

    func testNotificationHookOutputWithContext() {
        let output = NotificationHookOutput(additionalContext: "Notification handled")
        XCTAssertEqual(output.additionalContext, "Notification handled")
    }

    // MARK: - UserPromptSubmitHookOutput

    func testUserPromptSubmitHookOutputInit() {
        let output = UserPromptSubmitHookOutput()
        XCTAssertNil(output.additionalContext)
    }

    func testUserPromptSubmitHookOutputWithContext() {
        let output = UserPromptSubmitHookOutput(additionalContext: "Prompt validated")
        XCTAssertEqual(output.additionalContext, "Prompt validated")
    }

    // MARK: - PermissionRequestDecision

    func testPermissionRequestDecisionAllowDefaults() {
        let decision = PermissionRequestDecision.allow()
        if case .allow(let updatedInput, let updatedPermissions) = decision {
            XCTAssertNil(updatedInput)
            XCTAssertNil(updatedPermissions)
        } else {
            XCTFail("Expected .allow")
        }
    }

    func testPermissionRequestDecisionAllowWithInput() {
        let decision = PermissionRequestDecision.allow(updatedInput: ["key": .string("val")])
        if case .allow(let updatedInput, _) = decision {
            XCTAssertNotNil(updatedInput)
            XCTAssertEqual(updatedInput?["key"], .string("val"))
        } else {
            XCTFail("Expected .allow")
        }
    }

    func testPermissionRequestDecisionDenyDefaults() {
        let decision = PermissionRequestDecision.deny()
        if case .deny(let message, let interrupt) = decision {
            XCTAssertNil(message)
            XCTAssertNil(interrupt)
        } else {
            XCTFail("Expected .deny")
        }
    }

    func testPermissionRequestDecisionDenyWithMessage() {
        let decision = PermissionRequestDecision.deny(message: "Not allowed", interrupt: true)
        if case .deny(let message, let interrupt) = decision {
            XCTAssertEqual(message, "Not allowed")
            XCTAssertEqual(interrupt, true)
        } else {
            XCTFail("Expected .deny")
        }
    }

    // MARK: - PermissionRequestHookOutput

    func testPermissionRequestHookOutputAllow() {
        let output = PermissionRequestHookOutput(decision: .allow())
        if case .allow = output.decision {
            // pass
        } else {
            XCTFail("Expected .allow decision")
        }
    }

    func testPermissionRequestHookOutputDeny() {
        let output = PermissionRequestHookOutput(decision: .deny(message: "Denied"))
        if case .deny(let msg, _) = output.decision {
            XCTAssertEqual(msg, "Denied")
        } else {
            XCTFail("Expected .deny decision")
        }
    }

    // MARK: - HookSpecificOutput toDictionary for uncovered cases

    func testHookSpecificOutputSetupWithContext() {
        let output = HookSpecificOutput.setup(SetupHookOutput(additionalContext: "Ready"))
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Setup")
        XCTAssertEqual(dict["additionalContext"] as? String, "Ready")
    }

    func testHookSpecificOutputSetupWithoutContext() {
        let output = HookSpecificOutput.setup(SetupHookOutput())
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Setup")
        XCTAssertNil(dict["additionalContext"])
    }

    func testHookSpecificOutputSessionStartWithContext() {
        let output = HookSpecificOutput.sessionStart(SessionStartHookOutput(additionalContext: "Started"))
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "SessionStart")
        XCTAssertEqual(dict["additionalContext"] as? String, "Started")
    }

    func testHookSpecificOutputSessionStartWithoutContext() {
        let output = HookSpecificOutput.sessionStart(SessionStartHookOutput())
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "SessionStart")
        XCTAssertNil(dict["additionalContext"])
    }

    func testHookSpecificOutputSubagentStartWithContext() {
        let output = HookSpecificOutput.subagentStart(SubagentStartHookOutput(additionalContext: "Agent up"))
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "SubagentStart")
        XCTAssertEqual(dict["additionalContext"] as? String, "Agent up")
    }

    func testHookSpecificOutputPostToolUseFailureWithContext() {
        let output = HookSpecificOutput.postToolUseFailure(PostToolUseFailureHookOutput(additionalContext: "Error logged"))
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PostToolUseFailure")
        XCTAssertEqual(dict["additionalContext"] as? String, "Error logged")
    }

    func testHookSpecificOutputNotificationWithContext() {
        let output = HookSpecificOutput.notification(NotificationHookOutput(additionalContext: "Notified"))
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Notification")
        XCTAssertEqual(dict["additionalContext"] as? String, "Notified")
    }

    func testHookSpecificOutputUserPromptSubmitWithContext() {
        let output = HookSpecificOutput.userPromptSubmit(UserPromptSubmitHookOutput(additionalContext: "Validated"))
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "UserPromptSubmit")
        XCTAssertEqual(dict["additionalContext"] as? String, "Validated")
    }

    func testHookSpecificOutputPermissionRequestAllow() {
        let permOutput = PermissionRequestHookOutput(decision: .allow(
            updatedInput: ["cmd": .string("ls")],
            updatedPermissions: nil
        ))
        let output = HookSpecificOutput.permissionRequest(permOutput)
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PermissionRequest")
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedInput"])
        XCTAssertNil(dict["updatedPermissions"])
    }

    func testHookSpecificOutputPermissionRequestDeny() {
        let permOutput = PermissionRequestHookOutput(decision: .deny(message: "Blocked", interrupt: true))
        let output = HookSpecificOutput.permissionRequest(permOutput)
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PermissionRequest")
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Blocked")
        XCTAssertEqual(dict["interrupt"] as? Bool, true)
    }

    func testHookSpecificOutputPermissionRequestDenyNoMessage() {
        let permOutput = PermissionRequestHookOutput(decision: .deny())
        let output = HookSpecificOutput.permissionRequest(permOutput)
        let dict = output.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertNil(dict["message"])
        XCTAssertNil(dict["interrupt"])
    }

    // MARK: - AsyncHookOutput

    func testAsyncHookOutputDefaults() {
        let output = AsyncHookOutput()
        XCTAssertTrue(output.isAsync)
        XCTAssertNil(output.asyncTimeout)
    }

    func testAsyncHookOutputWithTimeout() {
        let output = AsyncHookOutput(asyncTimeout: 30.0)
        XCTAssertTrue(output.isAsync)
        XCTAssertEqual(output.asyncTimeout, 30.0)
    }

    // MARK: - HookJSONOutput

    func testHookJSONOutputSyncVariant() {
        let hookOutput = HookOutput.continue()
        let jsonOutput = HookJSONOutput.sync(hookOutput)
        if case .sync(let inner) = jsonOutput {
            XCTAssertTrue(inner.shouldContinue)
        } else {
            XCTFail("Expected .sync variant")
        }
    }

    func testHookJSONOutputAsyncVariant() {
        let asyncOutput = AsyncHookOutput(asyncTimeout: 10.0)
        let jsonOutput = HookJSONOutput.async(asyncOutput)
        if case .async(let inner) = jsonOutput {
            XCTAssertTrue(inner.isAsync)
            XCTAssertEqual(inner.asyncTimeout, 10.0)
        } else {
            XCTFail("Expected .async variant")
        }
    }

    // MARK: - ElicitationHookOutput toDictionary

    func testElicitationHookOutputToDictionaryAllFields() {
        let output = ElicitationHookOutput(action: "accept", content: ["name": .string("Bob")])
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Elicitation")
        XCTAssertEqual(dict["action"] as? String, "accept")
        XCTAssertNotNil(dict["content"])
    }

    func testElicitationHookOutputToDictionaryNoFields() {
        let output = ElicitationHookOutput()
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "Elicitation")
        XCTAssertNil(dict["action"])
        XCTAssertNil(dict["content"])
    }

    // MARK: - ElicitationResultHookOutput toDictionary

    func testElicitationResultHookOutputToDictionaryAllFields() {
        let output = ElicitationResultHookOutput(action: "accept", content: ["answer": .int(42)])
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "ElicitationResult")
        XCTAssertEqual(dict["action"] as? String, "accept")
        XCTAssertNotNil(dict["content"])
    }

    func testElicitationResultHookOutputToDictionaryNoFields() {
        let output = ElicitationResultHookOutput()
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "ElicitationResult")
        XCTAssertNil(dict["action"])
        XCTAssertNil(dict["content"])
    }
}

// MARK: - Hook Registry Coverage Tests

final class HookRegistryExtendedCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Registration and Invocation for Events Not Covered Elsewhere

    func testOnTeammateIdleRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onTeammateIdle { input in
            await capture.set("teammateName", input.teammateName)
            await capture.set("teamName", input.teamName)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .teammateIdle)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("TeammateIdle"),
            "teammate_name": .string("worker-1"),
            "team_name": .string("alpha-team"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let tName = await capture.get("teammateName")
        let tTeam = await capture.get("teamName")
        XCTAssertEqual(tName, "worker-1")
        XCTAssertEqual(tTeam, "alpha-team")
    }

    func testOnTaskCompletedRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onTaskCompleted { input in
            await capture.set("taskId", input.taskId)
            await capture.set("taskSubject", input.taskSubject)
            await capture.set("taskDescription", input.taskDescription ?? "nil")
            await capture.set("teammateName", input.teammateName ?? "nil")
            await capture.set("teamName", input.teamName ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .taskCompleted)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("TaskCompleted"),
            "task_id": .string("task-42"),
            "task_subject": .string("Fix login bug"),
            "task_description": .string("The login form breaks on mobile"),
            "teammate_name": .string("dev-1"),
            "team_name": .string("backend-team"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let taskId = await capture.get("taskId")
        let taskSubject = await capture.get("taskSubject")
        let taskDescription = await capture.get("taskDescription")
        let teammateName = await capture.get("teammateName")
        let teamName = await capture.get("teamName")
        XCTAssertEqual(taskId, "task-42")
        XCTAssertEqual(taskSubject, "Fix login bug")
        XCTAssertEqual(taskDescription, "The login form breaks on mobile")
        XCTAssertEqual(teammateName, "dev-1")
        XCTAssertEqual(teamName, "backend-team")
    }

    func testOnSetupRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onSetup { input in
            await capture.set("trigger", input.trigger)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .setup)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Setup"),
            "trigger": .string("init"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let trigger = await capture.get("trigger")
        XCTAssertEqual(trigger, "init")
    }

    func testOnNotificationRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onNotification { input in
            await capture.set("message", input.message)
            await capture.set("notificationType", input.notificationType)
            await capture.set("title", input.title ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .notification)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Notification"),
            "message": .string("Task complete"),
            "notification_type": .string("info"),
            "title": .string("Status Update"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let msg = await capture.get("message")
        let nType = await capture.get("notificationType")
        let title = await capture.get("title")
        XCTAssertEqual(msg, "Task complete")
        XCTAssertEqual(nType, "info")
        XCTAssertEqual(title, "Status Update")
    }

    func testOnSessionStartRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onSessionStart { input in
            await capture.set("source", input.source)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .sessionStart)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("SessionStart"),
            "source": .string("cli"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let source = await capture.get("source")
        XCTAssertEqual(source, "cli")
    }

    func testOnSessionEndRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onSessionEnd { input in
            await capture.set("reason", input.reason.rawValue)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .sessionEnd)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("SessionEnd"),
            "reason": .string("clear"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let reason = await capture.get("reason")
        XCTAssertEqual(reason, "clear")
    }

    func testOnSubagentStartRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onSubagentStart { input in
            await capture.set("agentId", input.agentId)
            await capture.set("agentType", input.agentType)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .subagentStart)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("SubagentStart"),
            "agent_id": .string("agent-99"),
            "agent_type": .string("task"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let agentId = await capture.get("agentId")
        let agentType = await capture.get("agentType")
        XCTAssertEqual(agentId, "agent-99")
        XCTAssertEqual(agentType, "task")
    }

    func testOnSubagentStopRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onSubagentStop { input in
            await capture.set("agentId", input.agentId)
            await capture.set("agentType", input.agentType)
            await capture.set("agentTranscriptPath", input.agentTranscriptPath)
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
            "agent_transcript_path": .string("/tmp/agent_transcript.jsonl"),
            "agent_id": .string("agent-99"),
            "agent_type": .string("task"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let agentId = await capture.get("agentId")
        let transcriptPath = await capture.get("agentTranscriptPath")
        XCTAssertEqual(agentId, "agent-99")
        XCTAssertEqual(transcriptPath, "/tmp/agent_transcript.jsonl")
    }

    func testOnPreCompactRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onPreCompact { input in
            await capture.set("trigger", input.trigger)
            await capture.set("customInstructions", input.customInstructions ?? "nil")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .preCompact)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PreCompact"),
            "trigger": .string("auto"),
            "custom_instructions": .string("Keep code context"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let trigger = await capture.get("trigger")
        let customInstructions = await capture.get("customInstructions")
        XCTAssertEqual(trigger, "auto")
        XCTAssertEqual(customInstructions, "Keep code context")
    }

    func testOnPermissionRequestRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onPermissionRequest { input in
            await capture.set("toolName", input.toolName)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .permissionRequest)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PermissionRequest"),
            "tool_name": .string("Bash"),
            "tool_input": .object(["command": .string("rm -rf /")]),
            "permission_suggestions": .array([.string("allow"), .string("deny")]),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let toolName = await capture.get("toolName")
        XCTAssertEqual(toolName, "Bash")
    }

    func testOnUserPromptSubmitRegistrationAndInvocation() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onUserPromptSubmit { input in
            await capture.set("prompt", input.prompt)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .userPromptSubmit)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("UserPromptSubmit"),
            "prompt": .string("Help me fix this bug"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let prompt = await capture.get("prompt")
        XCTAssertEqual(prompt, "Help me fix this bug")
    }

    // MARK: - Error Cases

    func testInvokeCallbackNotFoundThrows() async {
        let registry = HookRegistry()
        do {
            _ = try await registry.invokeCallback(callbackId: "nonexistent", rawInput: [:])
            XCTFail("Expected HookError.callbackNotFound")
        } catch let error as HookError {
            if case .callbackNotFound(let id) = error {
                XCTAssertEqual(id, "nonexistent")
            } else {
                XCTFail("Expected .callbackNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvokeCallbackWithInputNotFoundThrows() async {
        let registry = HookRegistry()
        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .stop
        )
        let input = HookInput.stop(StopInput(base: base, stopHookActive: false))
        do {
            _ = try await registry.invokeCallback(callbackId: "missing", input: input)
            XCTFail("Expected HookError.callbackNotFound")
        } catch let error as HookError {
            if case .callbackNotFound(let id) = error {
                XCTAssertEqual(id, "missing")
            } else {
                XCTFail("Expected .callbackNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvokeCallbackWithWrongInputTypeThrows() async throws {
        let registry = HookRegistry()

        await registry.onStop { _ in .continue() }

        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .preToolUse
        )
        // Pass a preToolUse input to a stop callback
        let input = HookInput.preToolUse(PreToolUseInput(
            base: base, toolName: "Bash", toolInput: [:], toolUseId: "t1"
        ))
        do {
            _ = try await registry.invokeCallback(callbackId: callbackId, input: input)
            XCTFail("Expected HookError.invalidInput")
        } catch let error as HookError {
            if case .invalidInput = error {
                // pass
            } else {
                XCTFail("Expected .invalidInput, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - getHookConfig returns nil when empty

    func testGetHookConfigReturnsNilWhenEmpty() async {
        let registry = HookRegistry()
        let config = await registry.getHookConfig()
        XCTAssertNil(config)
    }

    // MARK: - hasHooks / callbackCount / registeredEvents

    func testHasHooksReturnsFalseWhenEmpty() async {
        let registry = HookRegistry()
        let hasHooks = await registry.hasHooks
        XCTAssertFalse(hasHooks)
    }

    func testCallbackCountIsZeroWhenEmpty() async {
        let registry = HookRegistry()
        let count = await registry.callbackCount
        XCTAssertEqual(count, 0)
    }

    func testRegisteredEventsIsEmptyWhenEmpty() async {
        let registry = HookRegistry()
        let events = await registry.registeredEvents
        XCTAssertTrue(events.isEmpty)
    }

    func testGetCallbackIdReturnsNilForUnregisteredEvent() async {
        let registry = HookRegistry()
        let id = await registry.getCallbackId(forEvent: .stop)
        XCTAssertNil(id)
    }

    func testGetCallbackIdReturnsNilForOutOfBoundsIndex() async {
        let registry = HookRegistry()
        await registry.onStop { _ in .continue() }
        let id = await registry.getCallbackId(forEvent: .stop, atIndex: 5)
        XCTAssertNil(id)
    }

    // MARK: - Parsing with hookEventName (camelCase key)

    func testBaseInputParsesHookEventNameCamelCase() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onStop { input in
            await capture.set("hookEventName", input.base.hookEventName.rawValue)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .stop)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hookEventName": .string("Stop"),
            "stop_hook_active": .bool(false),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let hookEventName = await capture.get("hookEventName")
        XCTAssertEqual(hookEventName, "Stop")
    }

    // MARK: - Elicitation with requestedSchema

    func testElicitationInputParsedWithRequestedSchema() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onElicitation { input in
            await capture.set("hasSchema", input.requestedSchema != nil ? "yes" : "no")
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .elicitation)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Elicitation"),
            "mcp_server_name": .string("srv"),
            "message": .string("Enter data"),
            "requested_schema": .object(["type": .string("object")]),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let hasSchema = await capture.get("hasSchema")
        XCTAssertEqual(hasSchema, "yes")
    }

    // MARK: - ElicitationResult with content

    func testElicitationResultInputParsedWithContent() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onElicitationResult { input in
            await capture.set("hasContent", input.content != nil ? "yes" : "no")
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
            "mcp_server_name": .string("srv"),
            "action": .string("accept"),
            "content": .object(["name": .string("Alice")]),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let hasContent = await capture.get("hasContent")
        let action = await capture.get("action")
        XCTAssertEqual(hasContent, "yes")
        XCTAssertEqual(action, "accept")
    }

    // MARK: - PermissionRequest with no suggestions

    func testPermissionRequestInputParsedWithoutSuggestions() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onPermissionRequest { input in
            await capture.set("suggestionsCount", String(input.permissionSuggestions.count))
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .permissionRequest)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("PermissionRequest"),
            "tool_name": .string("Write"),
            "tool_input": .object([:]),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let suggestionsCount = await capture.get("suggestionsCount")
        XCTAssertEqual(suggestionsCount, "0")
    }

    // MARK: - SessionEnd with unknown reason falls back

    func testSessionEndInputParsedWithUnknownReasonFallsBackToOther() async throws {
        let registry = HookRegistry()
        let capture = LCCaptureBox()

        await registry.onSessionEnd { input in
            await capture.set("reason", input.reason.rawValue)
            return .continue()
        }

        let callbackId = await registry.getCallbackId(forEvent: .sessionEnd)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s1"),
            "transcript_path": .string("/t"),
            "cwd": .string("/c"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("SessionEnd"),
            "reason": .string("unknown_reason_xyz"),
        ]

        _ = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        let reason = await capture.get("reason")
        XCTAssertEqual(reason, "other")
    }
}

// MARK: - ParamBuilder Coverage Tests

final class ParamBuilderCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - buildBlock

    func testBuildBlockSingleParam() {
        let params = ParamBuilder.buildBlock(stringParam("name", "The name"))
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].name, "name")
    }

    func testBuildBlockMultipleParams() {
        let params = ParamBuilder.buildBlock(
            stringParam("a", "First"),
            numberParam("b", "Second"),
            boolParam("c", "Third")
        )
        XCTAssertEqual(params.count, 3)
    }

    // MARK: - buildOptional

    func testBuildOptionalWithValue() {
        let component: [ToolParam]? = [numberParam("age", "The age")]
        let result = ParamBuilder.buildOptional(component)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "age")
    }

    func testBuildOptionalWithoutValue() {
        let component: [ToolParam]? = nil
        let result = ParamBuilder.buildOptional(component)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - buildEither

    func testBuildEitherFirst() {
        let first = [stringParam("value", "A string value")]
        let result = ParamBuilder.buildEither(first: first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .string)
    }

    func testBuildEitherSecond() {
        let second = [numberParam("value", "A number value")]
        let result = ParamBuilder.buildEither(second: second)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].type, .number)
    }

    // MARK: - buildArray

    func testBuildArray() {
        let components: [[ToolParam]] = [
            [stringParam("a", "Param a")],
            [stringParam("b", "Param b")],
            [stringParam("c", "Param c")],
        ]
        let result = ParamBuilder.buildArray(components)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].name, "a")
        XCTAssertEqual(result[1].name, "b")
        XCTAssertEqual(result[2].name, "c")
    }

    // MARK: - Convenience Functions

    func testParamFunction() {
        let p = param("test", "A test param", type: .integer, required: false)
        XCTAssertEqual(p.name, "test")
        XCTAssertEqual(p.description, "A test param")
        XCTAssertEqual(p.type, .integer)
        XCTAssertFalse(p.required)
    }

    func testParamFunctionDefaults() {
        let p = param("test", "A test param")
        XCTAssertEqual(p.type, .string)
        XCTAssertTrue(p.required)
    }

    func testStringParamFunction() {
        let p = stringParam("name", "Name param")
        XCTAssertEqual(p.type, .string)
        XCTAssertTrue(p.required)
    }

    func testStringParamFunctionNotRequired() {
        let p = stringParam("name", "Name param", required: false)
        XCTAssertFalse(p.required)
    }

    func testNumberParamFunction() {
        let p = numberParam("score", "Score param")
        XCTAssertEqual(p.type, .number)
        XCTAssertTrue(p.required)
    }

    func testNumberParamFunctionNotRequired() {
        let p = numberParam("score", "Score param", required: false)
        XCTAssertFalse(p.required)
    }

    func testIntParamFunction() {
        let p = intParam("count", "Count param")
        XCTAssertEqual(p.type, .integer)
        XCTAssertTrue(p.required)
    }

    func testIntParamFunctionNotRequired() {
        let p = intParam("count", "Count param", required: false)
        XCTAssertFalse(p.required)
    }

    func testBoolParamFunction() {
        let p = boolParam("active", "Active flag")
        XCTAssertEqual(p.type, .boolean)
        XCTAssertTrue(p.required)
    }

    func testBoolParamFunctionNotRequired() {
        let p = boolParam("active", "Active flag", required: false)
        XCTAssertFalse(p.required)
    }

    // MARK: - buildSchema

    func testBuildSchemaFromParams() {
        let params = [
            stringParam("name", "Name"),
            intParam("age", "Age"),
            boolParam("active", "Active", required: false),
        ]
        let schema = buildSchema(from: params)
        XCTAssertEqual(schema.type, "object")
        XCTAssertEqual(schema.properties?.count, 3)
        XCTAssertEqual(schema.properties?["name"]?.type, "string")
        XCTAssertEqual(schema.properties?["age"]?.type, "integer")
        XCTAssertEqual(schema.properties?["active"]?.type, "boolean")
        XCTAssertEqual(schema.required, ["name", "age"])
    }

    func testBuildSchemaNoRequired() {
        let params = [
            stringParam("opt1", "Optional 1", required: false),
            numberParam("opt2", "Optional 2", required: false),
        ]
        let schema = buildSchema(from: params)
        XCTAssertNil(schema.required)
    }

    func testBuildSchemaEmpty() {
        let schema = buildSchema(from: [])
        XCTAssertEqual(schema.type, "object")
        XCTAssertTrue(schema.properties?.isEmpty ?? true)
        XCTAssertNil(schema.required)
    }
}

// MARK: - SDKSessionInfo Coverage Tests

final class SDKSessionInfoCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - SDKSessionInfo init and encode

    func testSDKSessionInfoInitAllFields() {
        let info = SDKSessionInfo(
            sessionId: "sess-1",
            summary: "Test session",
            lastModified: 1700000000.0,
            fileSize: 8192,
            customTitle: "My Session",
            firstPrompt: "Hello world",
            gitBranch: "main",
            cwd: "/project"
        )
        XCTAssertEqual(info.sessionId, "sess-1")
        XCTAssertEqual(info.summary, "Test session")
        XCTAssertEqual(info.lastModified, 1700000000.0)
        XCTAssertEqual(info.fileSize, 8192)
        XCTAssertEqual(info.customTitle, "My Session")
        XCTAssertEqual(info.firstPrompt, "Hello world")
        XCTAssertEqual(info.gitBranch, "main")
        XCTAssertEqual(info.cwd, "/project")
    }

    func testSDKSessionInfoInitMinimalFields() {
        let info = SDKSessionInfo(
            sessionId: "sess-2",
            summary: "Quick",
            lastModified: 1700000001.0,
            fileSize: 256
        )
        XCTAssertNil(info.customTitle)
        XCTAssertNil(info.firstPrompt)
        XCTAssertNil(info.gitBranch)
        XCTAssertNil(info.cwd)
    }

    func testSDKSessionInfoEncodeDecodeAllFields() throws {
        let info = SDKSessionInfo(
            sessionId: "sess-enc",
            summary: "Encode test",
            lastModified: 1700000002.0,
            fileSize: 1024,
            customTitle: "Encoded",
            firstPrompt: "Encode me",
            gitBranch: "feature",
            cwd: "/tmp"
        )
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(SDKSessionInfo.self, from: data)
        XCTAssertEqual(decoded, info)
    }

    func testSDKSessionInfoEncodeDecodeMinimalFields() throws {
        let info = SDKSessionInfo(
            sessionId: "sess-min-enc",
            summary: "Minimal",
            lastModified: 1700000003.0,
            fileSize: 128
        )
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(SDKSessionInfo.self, from: data)
        XCTAssertEqual(decoded, info)
        XCTAssertNil(decoded.customTitle)
    }

    func testSDKSessionInfoEquatable() {
        let a = SDKSessionInfo(sessionId: "a", summary: "s", lastModified: 1.0, fileSize: 1)
        let b = SDKSessionInfo(sessionId: "a", summary: "s", lastModified: 1.0, fileSize: 1)
        let c = SDKSessionInfo(sessionId: "c", summary: "s", lastModified: 1.0, fileSize: 1)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - SessionMessage

    func testSessionMessageInitAndEncode() throws {
        let msg = SessionMessage(
            type: "assistant",
            uuid: "uuid-1",
            sessionId: "sess-1",
            message: .object(["role": .string("assistant"), "content": .string("Hello")]),
            parentToolUseId: .string("tu-1")
        )
        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(SessionMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        XCTAssertEqual(decoded.type, "assistant")
        XCTAssertNotNil(decoded.parentToolUseId)
    }

    func testSessionMessageNilParentToolUseId() throws {
        let msg = SessionMessage(
            type: "user",
            uuid: "uuid-2",
            sessionId: "sess-2",
            message: .string("test")
        )
        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(SessionMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
        XCTAssertNil(decoded.parentToolUseId)
    }

    // MARK: - GetSessionMessagesOptions

    func testGetSessionMessagesOptionsAllFields() throws {
        let opts = GetSessionMessagesOptions(dir: "/project", limit: 50, offset: 10)
        let data = try encoder.encode(opts)
        let decoded = try decoder.decode(GetSessionMessagesOptions.self, from: data)
        XCTAssertEqual(decoded, opts)
        XCTAssertEqual(decoded.dir, "/project")
        XCTAssertEqual(decoded.limit, 50)
        XCTAssertEqual(decoded.offset, 10)
    }

    func testGetSessionMessagesOptionsMinimal() throws {
        let opts = GetSessionMessagesOptions()
        let data = try encoder.encode(opts)
        let decoded = try decoder.decode(GetSessionMessagesOptions.self, from: data)
        XCTAssertEqual(decoded, opts)
        XCTAssertNil(decoded.dir)
        XCTAssertNil(decoded.limit)
        XCTAssertNil(decoded.offset)
    }

    // MARK: - ListSessionsOptions

    func testListSessionsOptionsAllFields() throws {
        let opts = ListSessionsOptions(dir: "/home", limit: 25)
        let data = try encoder.encode(opts)
        let decoded = try decoder.decode(ListSessionsOptions.self, from: data)
        XCTAssertEqual(decoded, opts)
        XCTAssertEqual(decoded.dir, "/home")
        XCTAssertEqual(decoded.limit, 25)
    }

    func testListSessionsOptionsMinimal() throws {
        let opts = ListSessionsOptions()
        let data = try encoder.encode(opts)
        let decoded = try decoder.decode(ListSessionsOptions.self, from: data)
        XCTAssertEqual(decoded, opts)
        XCTAssertNil(decoded.dir)
        XCTAssertNil(decoded.limit)
    }
}

// MARK: - SchemaValidator Coverage Tests

final class SchemaValidatorCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private func makeSchema(
        properties: [String: PropertySchema],
        required: [String]? = nil
    ) -> JSONSchema {
        JSONSchema(type: "object", properties: properties, required: required)
    }

    // MARK: - Required Field Validation

    func testValidateRequiredFieldPresent() {
        let schema = makeSchema(
            properties: ["name": PropertySchema(type: "string", description: "Name")],
            required: ["name"]
        )
        let errors = SchemaValidator.validate(["name": "Alice"], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateRequiredFieldMissing() {
        let schema = makeSchema(
            properties: ["name": PropertySchema(type: "string", description: "Name")],
            required: ["name"]
        )
        let errors = SchemaValidator.validate([:], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("Missing required field: name"))
    }

    func testValidateMultipleRequiredFieldsMissing() {
        let schema = makeSchema(
            properties: [
                "name": PropertySchema(type: "string", description: "Name"),
                "age": PropertySchema(type: "integer", description: "Age"),
            ],
            required: ["name", "age"]
        )
        let errors = SchemaValidator.validate([:], against: schema)
        XCTAssertEqual(errors.count, 2)
    }

    // MARK: - Type Validation

    func testValidateStringTypeCorrect() {
        let schema = makeSchema(
            properties: ["name": PropertySchema(type: "string", description: "Name")]
        )
        let errors = SchemaValidator.validate(["name": "Alice"], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateStringTypeIncorrect() {
        let schema = makeSchema(
            properties: ["name": PropertySchema(type: "string", description: "Name")]
        )
        let errors = SchemaValidator.validate(["name": 42], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("expected string"))
    }

    func testValidateNumberTypeWithDouble() {
        let schema = makeSchema(
            properties: ["score": PropertySchema(type: "number", description: "Score")]
        )
        let errors = SchemaValidator.validate(["score": 3.14], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateNumberTypeWithInt() {
        let schema = makeSchema(
            properties: ["score": PropertySchema(type: "number", description: "Score")]
        )
        let errors = SchemaValidator.validate(["score": 42], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateNumberTypeWithFloat() {
        let schema = makeSchema(
            properties: ["score": PropertySchema(type: "number", description: "Score")]
        )
        let errors = SchemaValidator.validate(["score": Float(1.5)], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateNumberTypeIncorrect() {
        let schema = makeSchema(
            properties: ["score": PropertySchema(type: "number", description: "Score")]
        )
        let errors = SchemaValidator.validate(["score": "not a number"], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("expected number"))
    }

    func testValidateIntegerTypeCorrect() {
        let schema = makeSchema(
            properties: ["count": PropertySchema(type: "integer", description: "Count")]
        )
        let errors = SchemaValidator.validate(["count": 10], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateIntegerTypeIncorrect() {
        let schema = makeSchema(
            properties: ["count": PropertySchema(type: "integer", description: "Count")]
        )
        let errors = SchemaValidator.validate(["count": 3.14], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("expected integer"))
    }

    func testValidateBooleanTypeCorrect() {
        let schema = makeSchema(
            properties: ["active": PropertySchema(type: "boolean", description: "Active")]
        )
        let errors = SchemaValidator.validate(["active": true], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateBooleanTypeIncorrect() {
        let schema = makeSchema(
            properties: ["active": PropertySchema(type: "boolean", description: "Active")]
        )
        let errors = SchemaValidator.validate(["active": "yes"], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("expected boolean"))
    }

    func testValidateArrayTypeCorrect() {
        let schema = makeSchema(
            properties: ["items": PropertySchema(type: "array", description: "Items")]
        )
        let errors = SchemaValidator.validate(["items": [1, 2, 3]], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateArrayTypeIncorrect() {
        let schema = makeSchema(
            properties: ["items": PropertySchema(type: "array", description: "Items")]
        )
        let errors = SchemaValidator.validate(["items": "not an array"], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("expected array"))
    }

    func testValidateObjectTypeCorrect() {
        let schema = makeSchema(
            properties: ["config": PropertySchema(type: "object", description: "Config")]
        )
        let errors = SchemaValidator.validate(["config": ["key": "value"]], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidateObjectTypeIncorrect() {
        let schema = makeSchema(
            properties: ["config": PropertySchema(type: "object", description: "Config")]
        )
        let errors = SchemaValidator.validate(["config": [1, 2, 3]], against: schema)
        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("expected object"))
    }

    // MARK: - Unknown Type Passes

    func testValidateUnknownTypePassesValidation() {
        let schema = makeSchema(
            properties: ["custom": PropertySchema(type: "custom_type", description: "Custom")]
        )
        let errors = SchemaValidator.validate(["custom": "anything"], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Extra Fields Ignored

    func testValidateExtraFieldsNotInSchema() {
        let schema = makeSchema(
            properties: ["name": PropertySchema(type: "string", description: "Name")]
        )
        let errors = SchemaValidator.validate(["name": "Alice", "extra": 42], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - No Properties Schema

    func testValidateSchemaWithNoProperties() {
        let schema = JSONSchema(type: "object", properties: nil, required: nil)
        let errors = SchemaValidator.validate(["anything": "goes"], against: schema)
        XCTAssertTrue(errors.isEmpty)
    }

    // MARK: - Combined Required and Type Errors

    func testValidateCombinedErrors() {
        let schema = makeSchema(
            properties: [
                "name": PropertySchema(type: "string", description: "Name"),
                "age": PropertySchema(type: "integer", description: "Age"),
            ],
            required: ["name", "age"]
        )
        // Missing "name", wrong type for "age"
        let errors = SchemaValidator.validate(["age": "not an int"], against: schema)
        XCTAssertEqual(errors.count, 2)
    }
}

// MARK: - Thread-Safe Capture Helper

private actor LCCaptureBox {
    private var values: [String: String] = [:]
    func set(_ key: String, _ value: String) { values[key] = value }
    func get(_ key: String) -> String? { values[key] }
}
