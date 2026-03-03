//
//  RemainingCoverageTests.swift
//  ClodKit
//
//  Tests for uncovered code paths across multiple source files.
//

@testable import ClodKit
import XCTest
import os

// MARK: - 1. HookRegistry Logger Coverage

final class HookRegistryLoggerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testRegistration_WithLogger_CoversDebugLines() async {
        let logger = Logger(subsystem: "com.clodkit.tests", category: "HookRegistryLoggerTests")
        let registry = HookRegistry(logger: logger)

        // Register all 15 hook types to cover all registration debug lines
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
    }

    func testInvocation_WithLogger_CoversDebugLines() async throws {
        let logger = Logger(subsystem: "com.clodkit.tests", category: "HookRegistryLoggerTests")
        let registry = HookRegistry(logger: logger)

        await registry.onStop { _ in .continue() }
        let callbackId = await registry.getCallbackId(forEvent: .stop)!

        let rawInput: [String: JSONValue] = [
            "session_id": .string("test"),
            "transcript_path": .string("/tmp"),
            "cwd": .string("/"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Stop"),
            "stop_hook_active": .bool(false)
        ]
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(output.shouldContinue)
    }

    func testInvocation_WithLogger_UnknownCallback() async {
        let logger = Logger(subsystem: "com.clodkit.tests", category: "HookRegistryLoggerTests")
        let registry = HookRegistry(logger: logger)

        let rawInput: [String: JSONValue] = [
            "session_id": .string("test"),
            "transcript_path": .string("/tmp"),
            "cwd": .string("/"),
            "permission_mode": .string("default"),
            "hook_event_name": .string("Stop"),
        ]
        do {
            _ = try await registry.invokeCallback(callbackId: "nonexistent", rawInput: rawInput)
            XCTFail("Expected error")
        } catch {
            // Expected - covers the logger?.error line in invokeCallback
        }
    }
}

// MARK: - 2. HookRegistry invokeCallback(input:) Overload

final class HookRegistryInvokeOverloadTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testInvokeCallback_WithParsedInput() async throws {
        let registry = HookRegistry()
        await registry.onPreToolUse { input in
            XCTAssertEqual(input.toolName, "Bash")
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .preToolUse)!

        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .preToolUse
        )
        let input = HookInput.preToolUse(PreToolUseInput(
            base: base, toolName: "Bash", toolInput: [:], toolUseId: "tu1"
        ))
        let output = try await registry.invokeCallback(callbackId: callbackId, input: input)
        XCTAssertTrue(output.shouldContinue)
    }

    func testInvokeCallback_WithParsedInput_UnknownId() async {
        let registry = HookRegistry()
        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .preToolUse
        )
        let input = HookInput.preToolUse(PreToolUseInput(
            base: base, toolName: "Bash", toolInput: [:], toolUseId: "tu1"
        ))
        do {
            _ = try await registry.invokeCallback(callbackId: "missing", input: input)
            XCTFail("Expected error")
        } catch let error as HookError {
            if case .callbackNotFound(let id) = error {
                XCTAssertEqual(id, "missing")
            } else {
                XCTFail("Wrong error variant: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvokeCallback_WithParsedInput_Logger() async throws {
        let logger = Logger(subsystem: "com.clodkit.tests", category: "test")
        let registry = HookRegistry(logger: logger)
        await registry.onPreToolUse { _ in .continue() }
        let callbackId = await registry.getCallbackId(forEvent: .preToolUse)!

        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .preToolUse
        )
        let input = HookInput.preToolUse(PreToolUseInput(
            base: base, toolName: "Read", toolInput: [:], toolUseId: "tu2"
        ))
        let output = try await registry.invokeCallback(callbackId: callbackId, input: input)
        XCTAssertTrue(output.shouldContinue)
    }
}

// MARK: - 3. HookRegistry Parse Methods (Original 4 Event Types)

final class HookRegistryOriginalEventParseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testInvokePreToolUseCallback() async throws {
        let registry = HookRegistry()
        await registry.onPreToolUse { input in
            XCTAssertEqual(input.toolName, "Read")
            XCTAssertEqual(input.toolUseId, "tu1")
            XCTAssertEqual(input.toolInput["path"]?.stringValue, "/tmp")
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .preToolUse)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s"), "transcript_path": .string("/t"),
            "cwd": .string("/c"), "permission_mode": .string("default"),
            "hook_event_name": .string("PreToolUse"),
            "tool_name": .string("Read"),
            "tool_input": .object(["path": .string("/tmp")]),
            "tool_use_id": .string("tu1")
        ]
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(output.shouldContinue)
    }

    func testInvokePostToolUseCallback() async throws {
        let registry = HookRegistry()
        await registry.onPostToolUse { input in
            XCTAssertEqual(input.toolName, "Bash")
            XCTAssertEqual(input.toolResponse.stringValue, "ok")
            XCTAssertEqual(input.toolUseId, "tu2")
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .postToolUse)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s"), "transcript_path": .string("/t"),
            "cwd": .string("/c"), "permission_mode": .string("default"),
            "hook_event_name": .string("PostToolUse"),
            "tool_name": .string("Bash"),
            "tool_input": .object(["command": .string("ls")]),
            "tool_response": .string("ok"),
            "tool_use_id": .string("tu2")
        ]
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(output.shouldContinue)
    }

    func testInvokePostToolUseFailureCallback() async throws {
        let registry = HookRegistry()
        await registry.onPostToolUseFailure { input in
            XCTAssertEqual(input.toolName, "Write")
            XCTAssertEqual(input.error, "permission denied")
            XCTAssertTrue(input.isInterrupt)
            XCTAssertEqual(input.toolUseId, "tu3")
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .postToolUseFailure)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s"), "transcript_path": .string("/t"),
            "cwd": .string("/c"), "permission_mode": .string("default"),
            "hook_event_name": .string("PostToolUseFailure"),
            "tool_name": .string("Write"),
            "tool_input": .object([:]),
            "error": .string("permission denied"),
            "is_interrupt": .bool(true),
            "tool_use_id": .string("tu3")
        ]
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(output.shouldContinue)
    }

    func testInvokeUserPromptSubmitCallback() async throws {
        let registry = HookRegistry()
        await registry.onUserPromptSubmit { input in
            XCTAssertEqual(input.prompt, "hello world")
            return .continue()
        }
        let callbackId = await registry.getCallbackId(forEvent: .userPromptSubmit)!
        let rawInput: [String: JSONValue] = [
            "session_id": .string("s"), "transcript_path": .string("/t"),
            "cwd": .string("/c"), "permission_mode": .string("default"),
            "hook_event_name": .string("UserPromptSubmit"),
            "prompt": .string("hello world")
        ]
        let output = try await registry.invokeCallback(callbackId: callbackId, rawInput: rawInput)
        XCTAssertTrue(output.shouldContinue)
    }
}

// MARK: - 4. HookInput.base Coverage

final class HookInputBaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testHookInput_Base_AllVariants() {
        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .preToolUse
        )

        let inputs: [HookInput] = [
            .preToolUse(PreToolUseInput(base: base, toolName: "T", toolInput: [:], toolUseId: "id")),
            .postToolUse(PostToolUseInput(base: base, toolName: "T", toolInput: [:], toolResponse: .null, toolUseId: "id")),
            .postToolUseFailure(PostToolUseFailureInput(base: base, toolName: "T", toolInput: [:], error: "e", isInterrupt: false, toolUseId: "id")),
            .userPromptSubmit(UserPromptSubmitInput(base: base, prompt: "p")),
            .stop(StopInput(base: base, stopHookActive: false)),
            .subagentStart(SubagentStartInput(base: base, agentId: "a", agentType: "t")),
            .subagentStop(SubagentStopInput(base: base, stopHookActive: false, agentTranscriptPath: "/p", agentId: "a", agentType: "t")),
            .preCompact(PreCompactInput(base: base, trigger: "auto", customInstructions: nil)),
            .permissionRequest(PermissionRequestInput(base: base, toolName: "T", toolInput: [:], permissionSuggestions: [])),
            .sessionStart(SessionStartInput(base: base, source: "api")),
            .sessionEnd(SessionEndInput(base: base, reason: .clear)),
            .notification(NotificationInput(base: base, message: "m", notificationType: "info", title: nil)),
            .setup(SetupInput(base: base, trigger: "init")),
            .teammateIdle(TeammateIdleInput(base: base, teammateName: "w", teamName: "t")),
            .taskCompleted(TaskCompletedInput(base: base, taskId: "1", taskSubject: "s")),
        ]

        for input in inputs {
            XCTAssertEqual(input.base.sessionId, "s")
            XCTAssertEqual(input.base.transcriptPath, "/t")
            XCTAssertEqual(input.base.cwd, "/c")
        }
    }

    func testHookInput_EventType_AllVariants() {
        let base = BaseHookInput(
            sessionId: "s", transcriptPath: "/t", cwd: "/c",
            permissionMode: "default", hookEventName: .preToolUse
        )

        let expectations: [(HookInput, HookEvent)] = [
            (.preToolUse(PreToolUseInput(base: base, toolName: "T", toolInput: [:], toolUseId: "id")), .preToolUse),
            (.postToolUse(PostToolUseInput(base: base, toolName: "T", toolInput: [:], toolResponse: .null, toolUseId: "id")), .postToolUse),
            (.postToolUseFailure(PostToolUseFailureInput(base: base, toolName: "T", toolInput: [:], error: "e", isInterrupt: false, toolUseId: "id")), .postToolUseFailure),
            (.userPromptSubmit(UserPromptSubmitInput(base: base, prompt: "p")), .userPromptSubmit),
            (.stop(StopInput(base: base, stopHookActive: false)), .stop),
            (.subagentStart(SubagentStartInput(base: base, agentId: "a", agentType: "t")), .subagentStart),
            (.subagentStop(SubagentStopInput(base: base, stopHookActive: false, agentTranscriptPath: "/p", agentId: "a", agentType: "t")), .subagentStop),
            (.preCompact(PreCompactInput(base: base, trigger: "auto", customInstructions: nil)), .preCompact),
            (.permissionRequest(PermissionRequestInput(base: base, toolName: "T", toolInput: [:], permissionSuggestions: [])), .permissionRequest),
            (.sessionStart(SessionStartInput(base: base, source: "api")), .sessionStart),
            (.sessionEnd(SessionEndInput(base: base, reason: .clear)), .sessionEnd),
            (.notification(NotificationInput(base: base, message: "m", notificationType: "info", title: nil)), .notification),
            (.setup(SetupInput(base: base, trigger: "init")), .setup),
            (.teammateIdle(TeammateIdleInput(base: base, teammateName: "w", teamName: "t")), .teammateIdle),
            (.taskCompleted(TaskCompletedInput(base: base, taskId: "1", taskSubject: "s")), .taskCompleted),
        ]

        for (input, expected) in expectations {
            XCTAssertEqual(input.eventType, expected)
        }
    }
}

// MARK: - 5. HookOutputTypes Coverage

final class HookOutputTypesToDictionaryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testHookOutput_ToDictionary_AllFields() {
        let output = HookOutput(
            shouldContinue: false,
            suppressOutput: true,
            stopReason: "done",
            systemMessage: "sys msg",
            reason: "feedback",
            hookSpecificOutput: .preToolUse(PreToolUseHookOutput(
                permissionDecision: .allow,
                permissionDecisionReason: "safe",
                updatedInput: ["key": .string("val")],
                additionalContext: "ctx"
            ))
        )
        let dict = output.toDictionary()
        XCTAssertEqual(dict["continue"] as? Bool, false)
        XCTAssertEqual(dict["suppressOutput"] as? Bool, true)
        XCTAssertEqual(dict["stopReason"] as? String, "done")
        XCTAssertEqual(dict["systemMessage"] as? String, "sys msg")
        XCTAssertEqual(dict["reason"] as? String, "feedback")
        XCTAssertNotNil(dict["hookSpecificOutput"])
    }

    func testHookSpecificOutput_ToDictionary_AllVariants() {
        // Setup
        let setupOutput = HookSpecificOutput.setup(SetupHookOutput(additionalContext: "ctx"))
        let setupDict = setupOutput.toDictionary()
        XCTAssertEqual(setupDict["hookEventName"] as? String, "Setup")
        XCTAssertEqual(setupDict["additionalContext"] as? String, "ctx")

        // SessionStart
        let sessionStartOutput = HookSpecificOutput.sessionStart(SessionStartHookOutput(additionalContext: "start"))
        let sessionStartDict = sessionStartOutput.toDictionary()
        XCTAssertEqual(sessionStartDict["hookEventName"] as? String, "SessionStart")

        // SubagentStart
        let subagentStartOutput = HookSpecificOutput.subagentStart(SubagentStartHookOutput(additionalContext: "sub"))
        let subagentStartDict = subagentStartOutput.toDictionary()
        XCTAssertEqual(subagentStartDict["hookEventName"] as? String, "SubagentStart")

        // PostToolUseFailure
        let failureOutput = HookSpecificOutput.postToolUseFailure(PostToolUseFailureHookOutput(additionalContext: "fail"))
        let failureDict = failureOutput.toDictionary()
        XCTAssertEqual(failureDict["hookEventName"] as? String, "PostToolUseFailure")

        // Notification
        let notifOutput = HookSpecificOutput.notification(NotificationHookOutput(additionalContext: "notif"))
        let notifDict = notifOutput.toDictionary()
        XCTAssertEqual(notifDict["hookEventName"] as? String, "Notification")

        // UserPromptSubmit
        let promptOutput = HookSpecificOutput.userPromptSubmit(UserPromptSubmitHookOutput(additionalContext: "prompt"))
        let promptDict = promptOutput.toDictionary()
        XCTAssertEqual(promptDict["hookEventName"] as? String, "UserPromptSubmit")

        // PostToolUse
        let postToolOutput = HookSpecificOutput.postToolUse(PostToolUseHookOutput(
            additionalContext: "post", updatedMCPToolOutput: .string("updated")
        ))
        let postToolDict = postToolOutput.toDictionary()
        XCTAssertEqual(postToolDict["hookEventName"] as? String, "PostToolUse")

        // PermissionRequest - allow with updatedInput and updatedPermissions
        let allowOutput = HookSpecificOutput.permissionRequest(PermissionRequestHookOutput(
            decision: .allow(updatedInput: ["k": .string("v")], updatedPermissions: nil)
        ))
        let allowDict = allowOutput.toDictionary()
        XCTAssertEqual(allowDict["behavior"] as? String, "allow")
        XCTAssertNotNil(allowDict["updatedInput"])

        // PermissionRequest - deny with message and interrupt
        let denyOutput = HookSpecificOutput.permissionRequest(PermissionRequestHookOutput(
            decision: .deny(message: "no", interrupt: true)
        ))
        let denyDict = denyOutput.toDictionary()
        XCTAssertEqual(denyDict["behavior"] as? String, "deny")
        XCTAssertEqual(denyDict["message"] as? String, "no")
        XCTAssertEqual(denyDict["interrupt"] as? Bool, true)
    }

    func testHookOutput_ConvenienceInitializers() {
        let allow = HookOutput.allow(updatedInput: ["x": .int(1)], additionalContext: "ctx")
        XCTAssertTrue(allow.shouldContinue)
        XCTAssertNotNil(allow.hookSpecificOutput)

        let deny = HookOutput.deny(reason: "blocked")
        XCTAssertTrue(deny.shouldContinue)
        XCTAssertNotNil(deny.hookSpecificOutput)

        let ask = HookOutput.ask(reason: "check")
        XCTAssertTrue(ask.shouldContinue)
        XCTAssertNotNil(ask.hookSpecificOutput)

        let stop = HookOutput.stop(reason: "done")
        XCTAssertFalse(stop.shouldContinue)
        XCTAssertEqual(stop.stopReason, "done")
    }

    func testAsyncHookOutput() {
        let asyncOutput = AsyncHookOutput(asyncTimeout: 30.0)
        XCTAssertTrue(asyncOutput.isAsync)
        XCTAssertEqual(asyncOutput.asyncTimeout, 30.0)

        let defaultAsync = AsyncHookOutput()
        XCTAssertTrue(defaultAsync.isAsync)
        XCTAssertNil(defaultAsync.asyncTimeout)
    }

    func testHookJSONOutput_Variants() {
        let sync = HookJSONOutput.sync(HookOutput.continue())
        if case .sync(let output) = sync {
            XCTAssertTrue(output.shouldContinue)
        } else {
            XCTFail("Expected sync variant")
        }

        let asyncOut = HookJSONOutput.async(AsyncHookOutput(asyncTimeout: 5.0))
        if case .async(let output) = asyncOut {
            XCTAssertTrue(output.isAsync)
        } else {
            XCTFail("Expected async variant")
        }
    }
}

// MARK: - 6. JSONValue Uncovered Lines

final class JSONValueAdditionalTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // Line 40: Decoding error for unsupported type
    func testJSONValue_DecodingError_UnknownType() {
        // JSONValue.init(from:) line 40-44: the else branch when no type matches
        // This is hard to trigger with JSONDecoder since all JSON types map to something,
        // but we can test the encode/decode round trip for all types
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let values: [JSONValue] = [
            .null, .bool(true), .int(42), .double(3.14),
            .string("hello"), .array([.int(1), .string("two")]),
            .object(["key": .bool(false)])
        ]
        for value in values {
            let data = try! encoder.encode(value)
            let decoded = try! decoder.decode(JSONValue.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    // Line 71: toAny() for .null returns NSNull
    func testJSONValue_ToAny_Null() {
        let value = JSONValue.null
        let any = value.toAny()
        XCTAssertTrue(any is NSNull)
    }

    // Line 77: toAny() for .double
    func testJSONValue_ToAny_Double() {
        let value = JSONValue.double(3.14)
        let any = value.toAny()
        XCTAssertEqual(any as? Double, 3.14)
    }

    // Line 91: from(NSNull) returns .null
    func testJSONValue_From_NSNull() {
        let value = JSONValue.from(NSNull())
        XCTAssertEqual(value, .null)
    }

    // Line 105: from(unknown type) returns .string(describing:)
    func testJSONValue_From_UnknownType() {
        let date = Date(timeIntervalSince1970: 0)
        let value = JSONValue.from(date)
        if case .string(let str) = value {
            XCTAssertFalse(str.isEmpty)
        } else {
            XCTFail("Expected .string for unknown type")
        }
    }

    // Accessor coverage: intValue, doubleValue (implicit), boolValue, arrayValue, objectValue
    func testJSONValue_Accessors() {
        XCTAssertEqual(JSONValue.int(42).intValue, 42)
        XCTAssertNil(JSONValue.string("x").intValue)

        XCTAssertEqual(JSONValue.bool(true).boolValue, true)
        XCTAssertNil(JSONValue.int(1).boolValue)

        XCTAssertEqual(JSONValue.array([.int(1)]).arrayValue, [.int(1)])
        XCTAssertNil(JSONValue.string("x").arrayValue)

        XCTAssertEqual(JSONValue.object(["k": .string("v")]).objectValue, ["k": .string("v")])
        XCTAssertNil(JSONValue.int(1).objectValue)

        XCTAssertEqual(JSONValue.string("hello").stringValue, "hello")
        XCTAssertNil(JSONValue.null.stringValue)
    }

    // toAny() for remaining types
    func testJSONValue_ToAny_AllTypes() {
        XCTAssertEqual(JSONValue.bool(true).toAny() as? Bool, true)
        XCTAssertEqual(JSONValue.int(5).toAny() as? Int, 5)
        XCTAssertEqual(JSONValue.string("s").toAny() as? String, "s")

        let arrayAny = JSONValue.array([.int(1), .string("two")]).toAny() as? [Any]
        XCTAssertNotNil(arrayAny)
        XCTAssertEqual(arrayAny?.count, 2)

        let objectAny = JSONValue.object(["a": .int(1)]).toAny() as? [String: Any]
        XCTAssertNotNil(objectAny)
        XCTAssertEqual(objectAny?["a"] as? Int, 1)
    }

    // from() for remaining types
    func testJSONValue_From_AllTypes() {
        XCTAssertEqual(JSONValue.from(true), .bool(true))
        XCTAssertEqual(JSONValue.from(42 as Int), .int(42))
        XCTAssertEqual(JSONValue.from(3.14 as Double), .double(3.14))
        XCTAssertEqual(JSONValue.from("hello"), .string("hello"))

        let arrayValue = JSONValue.from([1, 2] as [Any])
        if case .array(let arr) = arrayValue {
            XCTAssertEqual(arr.count, 2)
        } else {
            XCTFail("Expected .array")
        }

        let dictValue = JSONValue.from(["k": "v"] as [String: Any])
        if case .object(let obj) = dictValue {
            XCTAssertEqual(obj["k"], .string("v"))
        } else {
            XCTFail("Expected .object")
        }
    }
}

// MARK: - 8. SDKMessage Line 37 Coverage

final class SDKMessageContentTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // SDKMessage.content for "assistant" type that successfully extracts text (line 36)
    func testSDKMessage_Content_AssistantWithText() {
        let msg = SDKMessage(type: "assistant", rawJSON: [
            "message": .object([
                "content": .array([
                    .object([
                        "text": .string("Hello world"),
                        "type": .string("text")
                    ])
                ])
            ])
        ])
        XCTAssertEqual(msg.content, .string("Hello world"))
    }

    // SDKMessage.content for "assistant" type that fails extraction (line 37-38)
    func testSDKMessage_Content_AssistantWithoutText() {
        let msg = SDKMessage(type: "assistant", rawJSON: [
            "message": .object([
                "content": .array([
                    .object(["type": .string("image")])
                ])
            ])
        ])
        XCTAssertNil(msg.content)
    }

    // SDKMessage.content for "assistant" with missing message field
    func testSDKMessage_Content_AssistantMissingMessage() {
        let msg = SDKMessage(type: "assistant", rawJSON: [:])
        XCTAssertNil(msg.content)
    }

    // SDKMessage.content for "assistant" with empty content array
    func testSDKMessage_Content_AssistantEmptyContentArray() {
        let msg = SDKMessage(type: "assistant", rawJSON: [
            "message": .object([
                "content": .array([])
            ])
        ])
        XCTAssertNil(msg.content)
    }

    // SDKMessage.content for "result" type
    func testSDKMessage_Content_Result() {
        let msg = SDKMessage(type: "result", rawJSON: [
            "result": .string("done")
        ])
        XCTAssertEqual(msg.content, .string("done"))
    }

    // SDKMessage.content for default type (line 40)
    func testSDKMessage_Content_DefaultType() {
        let msg = SDKMessage(type: "system", rawJSON: [
            "content": .string("system message")
        ])
        XCTAssertEqual(msg.content, .string("system message"))
    }

    // SDKMessage other accessors
    func testSDKMessage_Accessors() {
        let msg = SDKMessage(type: "result", rawJSON: [
            "session_id": .string("sess-123"),
            "stop_reason": .string("end_turn"),
            "isSynthetic": .bool(true),
            "tool_use_result": .object(["output": .string("result")])
        ])
        XCTAssertEqual(msg.sessionId, "sess-123")
        XCTAssertEqual(msg.stopReason, "end_turn")
        XCTAssertEqual(msg.isSynthetic, true)
        XCTAssertNotNil(msg.toolUseResult)
        XCTAssertNotNil(msg.data)
    }

    // SDKMessage.error accessor
    func testSDKMessage_Error() {
        let msg = SDKMessage(type: "assistant", rawJSON: [
            "error": .string("rate_limit")
        ])
        XCTAssertEqual(msg.error, .rateLimit)

        // Non-assistant type returns nil
        let nonAssistant = SDKMessage(type: "result", rawJSON: [
            "error": .string("rate_limit")
        ])
        XCTAssertNil(nonAssistant.error)

        // Unknown error type
        let unknownError = SDKMessage(type: "assistant", rawJSON: [
            "error": .string("some_new_error")
        ])
        XCTAssertEqual(unknownError.error, .unknown)

        // No error field
        let noError = SDKMessage(type: "assistant", rawJSON: [:])
        XCTAssertNil(noError.error)
    }

    // SDKMessage legacy convenience init
    func testSDKMessage_LegacyInit() {
        let msg = SDKMessage(type: "user", content: .string("hello"), data: .object(["extra": .int(1)]))
        XCTAssertEqual(msg.rawJSON["content"], .string("hello"))
        XCTAssertEqual(msg.rawJSON["extra"], .int(1))

        let noData = SDKMessage(type: "user", content: nil, data: nil)
        XCTAssertTrue(noData.rawJSON.isEmpty)
    }

    // SDKMessage Codable
    func testSDKMessage_Codable() throws {
        let json = """
        {"type": "result", "result": "done", "session_id": "abc"}
        """.data(using: .utf8)!
        let msg = try JSONDecoder().decode(SDKMessage.self, from: json)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.content, .string("done"))

        // Round-trip encode
        let encoded = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SDKMessage.self, from: encoded)
        XCTAssertEqual(decoded.type, "result")
    }

    // SDKMessage decode failure (missing type)
    func testSDKMessage_DecodeMissingType() {
        let json = """
        {"result": "done"}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SDKMessage.self, from: json))
    }
}

// MARK: - 9. JSONLineParser Lines 38, 50, 97-98 Coverage

final class JSONLineParserEdgeCaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // Line 38: Empty line followed by empty remaining
    func testParseLine_EmptyLineOnly() {
        let parser = JSONLineParser()
        let buffer = "\n".data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNil(result)
    }

    // Line 38-41: Empty line followed by valid data
    func testParseLine_EmptyLineThenValidJSON() {
        let parser = JSONLineParser()
        // Empty line (just newline) followed by valid JSON line
        let buffer = "\n{\"type\":\"result\",\"result\":\"ok\"}\n".data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNotNil(result)
        if let (message, _) = result {
            if case .regular(let msg) = message {
                XCTAssertEqual(msg.type, "result")
            } else {
                XCTFail("Expected regular message")
            }
        }
    }

    // Line 50: Malformed JSON followed by empty remaining
    func testParseLine_MalformedJSONOnly() {
        let parser = JSONLineParser()
        let buffer = "not json\n".data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNil(result)
    }

    // Line 50-53: Malformed JSON followed by valid JSON
    func testParseLine_MalformedThenValidJSON() {
        let parser = JSONLineParser()
        let json = "bad json\n{\"type\":\"result\",\"result\":\"ok\"}\n"
        let buffer = json.data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNotNil(result)
    }

    // Line 97-98: tool_progress, auth_status, tool_use_summary message types
    func testParseLine_ToolProgressMessage() {
        let parser = JSONLineParser()
        let json = "{\"type\":\"tool_progress\",\"content\":\"working\"}\n"
        let buffer = json.data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNotNil(result)
        if let (message, _) = result {
            if case .regular(let msg) = message {
                XCTAssertEqual(msg.type, "tool_progress")
            } else {
                XCTFail("Expected regular message")
            }
        }
    }

    func testParseLine_AuthStatusMessage() {
        let parser = JSONLineParser()
        let json = "{\"type\":\"auth_status\",\"status\":\"ok\"}\n"
        let buffer = json.data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNotNil(result)
        if let (message, _) = result {
            if case .regular(let msg) = message {
                XCTAssertEqual(msg.type, "auth_status")
            } else {
                XCTFail("Expected regular message")
            }
        }
    }

    func testParseLine_ToolUseSummaryMessage() {
        let parser = JSONLineParser()
        let json = "{\"type\":\"tool_use_summary\",\"summary\":\"done\"}\n"
        let buffer = json.data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNotNil(result)
        if let (message, _) = result {
            if case .regular(let msg) = message {
                XCTAssertEqual(msg.type, "tool_use_summary")
            } else {
                XCTFail("Expected regular message")
            }
        }
    }

    // Line 94-95: keep_alive message
    func testParseLine_KeepAliveMessage() {
        let parser = JSONLineParser()
        let json = "{\"type\":\"keep_alive\"}\n"
        let buffer = json.data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNotNil(result)
        if let (message, _) = result {
            if case .keepAlive = message {
                // expected
            } else {
                XCTFail("Expected keepAlive message")
            }
        }
    }

    // parseAllLines coverage
    func testParseAllLines_MultipleMessages() {
        let parser = JSONLineParser()
        let json = "{\"type\":\"result\",\"result\":\"a\"}\n{\"type\":\"result\",\"result\":\"b\"}\n"
        let buffer = json.data(using: .utf8)!
        let (messages, remaining) = parser.parseAllLines(from: buffer)
        XCTAssertEqual(messages.count, 2)
        XCTAssertTrue(remaining.isEmpty)
    }

    // No complete line
    func testParseLine_IncompleteBuffer() {
        let parser = JSONLineParser()
        let buffer = "{\"type\":\"res".data(using: .utf8)!
        let result = parser.parseLine(from: buffer)
        XCTAssertNil(result)
    }
}

// MARK: - 11. JSONSchema Lines 181, 203 Coverage

final class JSONSchemaAdditionalTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // Line 181: PropertySchema.toDictionary() with enum field
    func testPropertySchema_ToDictionary_WithEnum() {
        let schema = PropertySchema.enum(["a", "b", "c"], description: "choices")
        let dict = schema.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "string")
        XCTAssertEqual(dict["description"] as? String, "choices")
        XCTAssertEqual(dict["enum"] as? [String], ["a", "b", "c"])
    }

    // Line 181: toDictionary() with items (array schema)
    func testPropertySchema_ToDictionary_WithItems() {
        let schema = PropertySchema.array(of: .string("item desc"), description: "list")
        let dict = schema.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "array")
        let items = dict["items"] as? [String: Any]
        XCTAssertNotNil(items)
        XCTAssertEqual(items?["type"] as? String, "string")
    }

    // toDictionary() with nested properties (object schema)
    func testPropertySchema_ToDictionary_WithProperties() {
        let schema = PropertySchema.object(properties: [
            "name": .string("the name"),
            "age": .integer("the age")
        ], description: "person")
        let dict = schema.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "object")
        let props = dict["properties"] as? [String: Any]
        XCTAssertNotNil(props)
        XCTAssertEqual(props?.count, 2)
    }

    // Line 203: PropertySchema Codable decode with items and properties
    func testPropertySchema_Codable_WithItems() throws {
        let json = """
        {"type":"array","items":{"type":"string","description":"item"},"description":"list"}
        """.data(using: .utf8)!
        let schema = try JSONDecoder().decode(PropertySchema.self, from: json)
        XCTAssertEqual(schema.type, "array")
        XCTAssertEqual(schema.items?.type, "string")
        XCTAssertEqual(schema.description, "list")

        // Round-trip
        let encoded = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(PropertySchema.self, from: encoded)
        XCTAssertEqual(decoded, schema)
    }

    func testPropertySchema_Codable_WithProperties() throws {
        let json = """
        {"type":"object","properties":{"name":{"type":"string"},"count":{"type":"integer"}}}
        """.data(using: .utf8)!
        let schema = try JSONDecoder().decode(PropertySchema.self, from: json)
        XCTAssertEqual(schema.type, "object")
        XCTAssertNotNil(schema.properties)
        XCTAssertEqual(schema.properties?.count, 2)
    }

    func testPropertySchema_Codable_WithEnum() throws {
        let json = """
        {"type":"string","enum":["red","green","blue"]}
        """.data(using: .utf8)!
        let schema = try JSONDecoder().decode(PropertySchema.self, from: json)
        XCTAssertEqual(schema.type, "string")
        XCTAssertEqual(schema.enum, ["red", "green", "blue"])
    }

    // JSONSchema.toDictionary
    func testJSONSchema_ToDictionary_AllFields() {
        let schema = JSONSchema(
            type: "object",
            properties: ["name": .string("the name")],
            required: ["name"],
            additionalProperties: false
        )
        let dict = schema.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "object")
        XCTAssertNotNil(dict["properties"])
        XCTAssertEqual(dict["required"] as? [String], ["name"])
        XCTAssertEqual(dict["additionalProperties"] as? Bool, false)
    }
}

// MARK: - 12. MCPServerRouter Lines 153, 163 Coverage

final class MCPServerRouterAdditionalTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testRoute_ServerNotFound() async {
        let router = MCPServerRouter()
        let request = MCPMessageRequest(
            serverName: "nonexistent",
            message: JSONRPCMessage(jsonrpc: "2.0", id: .int(1), method: "tools/list")
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.methodNotFound)
    }

    func testRoute_MissingMethod() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(jsonrpc: "2.0", id: .int(1))
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.invalidRequest)
    }

    func testRoute_UnknownMethod() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(jsonrpc: "2.0", id: .int(1), method: "unknown/method")
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.methodNotFound)
    }

    func testRoute_Initialize() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(jsonrpc: "2.0", id: .int(1), method: "initialize")
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)
    }

    func testRoute_NotificationsInitialized() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(jsonrpc: "2.0", id: .int(1), method: "notifications/initialized")
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.result)
        let isInit = await router.isInitialized(name: "test")
        XCTAssertTrue(isInit)
    }

    func testRoute_ToolsList() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(jsonrpc: "2.0", id: .int(1), method: "tools/list")
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.result)
    }

    // Line 153: tools/call that throws MCPServerError
    func testRoute_ToolsCall_ToolNotFound() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(
                jsonrpc: "2.0",
                id: .int(1),
                method: "tools/call",
                params: .object([
                    "name": .string("nonexistent_tool"),
                    "arguments": .object([:])
                ])
            )
        )
        let response = await router.route(request)
        // Should get an error since tool doesn't exist
        XCTAssertNotNil(response.error)
    }

    // Line 163: tools/call missing tool name in params
    func testRoute_ToolsCall_MissingName() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(
                jsonrpc: "2.0",
                id: .int(1),
                method: "tools/call",
                params: .object([:])
            )
        )
        let response = await router.route(request)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.invalidParams)
    }

    // tools/call with no arguments (covers the empty arguments path)
    func testRoute_ToolsCall_NoArguments() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "test", tools: [])
        await router.registerServer(server)

        let request = MCPMessageRequest(
            serverName: "test",
            message: JSONRPCMessage(
                jsonrpc: "2.0",
                id: .int(1),
                method: "tools/call",
                params: .object([
                    "name": .string("nonexistent")
                ])
            )
        )
        let response = await router.route(request)
        // Will error because tool doesn't exist, but exercises the no-arguments path
        XCTAssertNotNil(response.error)
    }

    // Server management
    func testRouter_ServerManagement() async {
        let router = MCPServerRouter()
        let server = SDKMCPServer(name: "myserver", tools: [])
        await router.registerServer(server)

        let names = await router.getServerNames()
        XCTAssertEqual(names, ["myserver"])

        let hasMyServer = await router.hasServer(name: "myserver")
        XCTAssertTrue(hasMyServer)

        let hasOther = await router.hasServer(name: "other")
        XCTAssertFalse(hasOther)

        let isInit = await router.isInitialized(name: "myserver")
        XCTAssertFalse(isInit)

        await router.unregisterServer(name: "myserver")

        let hasAfterRemove = await router.hasServer(name: "myserver")
        XCTAssertFalse(hasAfterRemove)

        let namesAfterRemove = await router.getServerNames()
        XCTAssertTrue(namesAfterRemove.isEmpty)
    }
}
