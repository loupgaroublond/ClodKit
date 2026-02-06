//
//  HookTypesTests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for hook type definitions.
//

import XCTest
@testable import ClaudeCodeSDK

// MARK: - JSONValue Tests

final class JSONValueTests: XCTestCase {

    func testNullCodable() throws {
        let value = JSONValue.null
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, .null)
    }

    func testBoolCodable() throws {
        let trueValue = JSONValue.bool(true)
        let falseValue = JSONValue.bool(false)

        let trueData = try JSONEncoder().encode(trueValue)
        let falseData = try JSONEncoder().encode(falseValue)

        let decodedTrue = try JSONDecoder().decode(JSONValue.self, from: trueData)
        let decodedFalse = try JSONDecoder().decode(JSONValue.self, from: falseData)

        XCTAssertEqual(decodedTrue, .bool(true))
        XCTAssertEqual(decodedFalse, .bool(false))
    }

    func testIntCodable() throws {
        let value = JSONValue.int(42)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, .int(42))
    }

    func testDoubleCodable() throws {
        let value = JSONValue.double(3.14159)
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, .double(3.14159))
    }

    func testStringCodable() throws {
        let value = JSONValue.string("hello world")
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, .string("hello world"))
    }

    func testArrayCodable() throws {
        let value = JSONValue.array([.int(1), .string("two"), .bool(true)])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testObjectCodable() throws {
        let value = JSONValue.object([
            "name": .string("test"),
            "count": .int(5),
            "active": .bool(true)
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, value)
    }

    func testToAny() {
        let value = JSONValue.object([
            "name": .string("test"),
            "numbers": .array([.int(1), .int(2)])
        ])
        let any = value.toAny()
        guard let dict = any as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }
        XCTAssertEqual(dict["name"] as? String, "test")
        XCTAssertEqual((dict["numbers"] as? [Any])?.count, 2)
    }

    func testFromAny() {
        let dict: [String: Any] = [
            "name": "test",
            "count": 42,
            "active": true
        ]
        let value = JSONValue.from(dict)
        if case .object(let obj) = value {
            XCTAssertEqual(obj["name"], .string("test"))
            XCTAssertEqual(obj["count"], .int(42))
            XCTAssertEqual(obj["active"], .bool(true))
        } else {
            XCTFail("Expected object")
        }
    }
}

// MARK: - HookEvent Tests

final class HookEventTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(HookEvent.preToolUse.rawValue, "PreToolUse")
        XCTAssertEqual(HookEvent.postToolUse.rawValue, "PostToolUse")
        XCTAssertEqual(HookEvent.postToolUseFailure.rawValue, "PostToolUseFailure")
        XCTAssertEqual(HookEvent.userPromptSubmit.rawValue, "UserPromptSubmit")
        XCTAssertEqual(HookEvent.stop.rawValue, "Stop")
        XCTAssertEqual(HookEvent.subagentStart.rawValue, "SubagentStart")
        XCTAssertEqual(HookEvent.subagentStop.rawValue, "SubagentStop")
        XCTAssertEqual(HookEvent.preCompact.rawValue, "PreCompact")
        XCTAssertEqual(HookEvent.permissionRequest.rawValue, "PermissionRequest")
        XCTAssertEqual(HookEvent.sessionStart.rawValue, "SessionStart")
        XCTAssertEqual(HookEvent.sessionEnd.rawValue, "SessionEnd")
        XCTAssertEqual(HookEvent.notification.rawValue, "Notification")
    }

    func testEventCount() {
        XCTAssertEqual(HookEvent.allCases.count, 12)
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for event in HookEvent.allCases {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(HookEvent.self, from: data)
            XCTAssertEqual(decoded, event, "Failed for event: \(event)")
        }
    }

    func testDecodeFromString() throws {
        let json = "\"PreToolUse\""
        let data = json.data(using: .utf8)!
        let event = try JSONDecoder().decode(HookEvent.self, from: data)
        XCTAssertEqual(event, .preToolUse)
    }
}

// MARK: - HookMatcherConfig Tests

final class HookMatcherConfigTests: XCTestCase {

    func testToDictionaryAllFields() {
        let config = HookMatcherConfig(
            matcher: "Bash",
            hookCallbackIds: ["hook_0", "hook_1"],
            timeout: 60.0
        )

        let dict = config.toDictionary()

        XCTAssertEqual(dict["matcher"] as? String, "Bash")
        XCTAssertEqual(dict["hookCallbackIds"] as? [String], ["hook_0", "hook_1"])
        XCTAssertEqual(dict["timeout"] as? TimeInterval, 60.0)
    }

    func testToDictionaryMinimalFields() {
        let config = HookMatcherConfig(hookCallbackIds: ["hook_0"])

        let dict = config.toDictionary()

        XCTAssertNil(dict["matcher"])
        XCTAssertEqual(dict["hookCallbackIds"] as? [String], ["hook_0"])
        XCTAssertNil(dict["timeout"])
    }

    func testCodableRoundTrip() throws {
        let config = HookMatcherConfig(
            matcher: ".*",
            hookCallbackIds: ["hook_0"],
            timeout: 30.0
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(HookMatcherConfig.self, from: data)

        XCTAssertEqual(decoded, config)
    }
}

// MARK: - PermissionDecision Tests

final class PermissionDecisionTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PermissionDecision.allow.rawValue, "allow")
        XCTAssertEqual(PermissionDecision.deny.rawValue, "deny")
        XCTAssertEqual(PermissionDecision.ask.rawValue, "ask")
    }

    func testCodableRoundTrip() throws {
        for decision in [PermissionDecision.allow, .deny, .ask] {
            let data = try JSONEncoder().encode(decision)
            let decoded = try JSONDecoder().decode(PermissionDecision.self, from: data)
            XCTAssertEqual(decoded, decision)
        }
    }
}

// MARK: - PreToolUseHookOutput Tests

final class PreToolUseHookOutputTests: XCTestCase {

    func testHookEventName() {
        let output = PreToolUseHookOutput()
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PreToolUse")
    }

    func testToDictionaryAllFields() {
        let output = PreToolUseHookOutput(
            permissionDecision: .allow,
            permissionDecisionReason: "Approved by policy",
            updatedInput: ["command": .string("echo hello")],
            additionalContext: "This is safe"
        )

        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(dict["permissionDecision"] as? String, "allow")
        XCTAssertEqual(dict["permissionDecisionReason"] as? String, "Approved by policy")
        XCTAssertEqual(dict["additionalContext"] as? String, "This is safe")

        if let updatedInput = dict["updatedInput"] as? [String: Any] {
            XCTAssertEqual(updatedInput["command"] as? String, "echo hello")
        } else {
            XCTFail("Expected updatedInput dictionary")
        }
    }

    func testToDictionaryMinimalFields() {
        let output = PreToolUseHookOutput()
        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PreToolUse")
        XCTAssertNil(dict["permissionDecision"])
        XCTAssertNil(dict["permissionDecisionReason"])
        XCTAssertNil(dict["updatedInput"])
        XCTAssertNil(dict["additionalContext"])
    }
}

// MARK: - PostToolUseHookOutput Tests

final class PostToolUseHookOutputTests: XCTestCase {

    func testHookEventName() {
        let output = PostToolUseHookOutput()
        let dict = output.toDictionary()
        XCTAssertEqual(dict["hookEventName"] as? String, "PostToolUse")
    }

    func testToDictionaryAllFields() {
        let output = PostToolUseHookOutput(
            additionalContext: "Tool executed successfully",
            updatedMCPToolOutput: .string("Modified output")
        )

        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PostToolUse")
        XCTAssertEqual(dict["additionalContext"] as? String, "Tool executed successfully")
        XCTAssertEqual(dict["updatedMCPToolOutput"] as? String, "Modified output")
    }
}

// MARK: - HookSpecificOutput Tests

final class HookSpecificOutputTests: XCTestCase {

    func testPreToolUseVariant() {
        let preToolOutput = PreToolUseHookOutput(permissionDecision: .deny)
        let output = HookSpecificOutput.preToolUse(preToolOutput)
        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(dict["permissionDecision"] as? String, "deny")
    }

    func testPostToolUseVariant() {
        let postToolOutput = PostToolUseHookOutput(additionalContext: "done")
        let output = HookSpecificOutput.postToolUse(postToolOutput)
        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PostToolUse")
        XCTAssertEqual(dict["additionalContext"] as? String, "done")
    }
}

// MARK: - HookOutput Tests

final class HookOutputTests: XCTestCase {

    func testDefaultValues() {
        let output = HookOutput()
        XCTAssertTrue(output.shouldContinue)
        XCTAssertFalse(output.suppressOutput)
        XCTAssertNil(output.stopReason)
        XCTAssertNil(output.systemMessage)
        XCTAssertNil(output.reason)
        XCTAssertNil(output.hookSpecificOutput)
    }

    func testToDictionaryDefaults() {
        let output = HookOutput()
        let dict = output.toDictionary()

        XCTAssertEqual(dict["continue"] as? Bool, true)
        XCTAssertNil(dict["suppressOutput"]) // Only included when true
        XCTAssertNil(dict["stopReason"])
        XCTAssertNil(dict["hookSpecificOutput"])
    }

    func testToDictionaryAllFields() {
        let preToolOutput = PreToolUseHookOutput(permissionDecision: .allow)
        let output = HookOutput(
            shouldContinue: false,
            suppressOutput: true,
            stopReason: "Policy violation",
            systemMessage: "Warning: operation blocked",
            reason: "Security policy",
            hookSpecificOutput: .preToolUse(preToolOutput)
        )

        let dict = output.toDictionary()

        XCTAssertEqual(dict["continue"] as? Bool, false)
        XCTAssertEqual(dict["suppressOutput"] as? Bool, true)
        XCTAssertEqual(dict["stopReason"] as? String, "Policy violation")
        XCTAssertEqual(dict["systemMessage"] as? String, "Warning: operation blocked")
        XCTAssertEqual(dict["reason"] as? String, "Security policy")

        if let hookOutput = dict["hookSpecificOutput"] as? [String: Any] {
            XCTAssertEqual(hookOutput["hookEventName"] as? String, "PreToolUse")
            XCTAssertEqual(hookOutput["permissionDecision"] as? String, "allow")
        } else {
            XCTFail("Expected hookSpecificOutput dictionary")
        }
    }

    func testContinueInitializer() {
        let output = HookOutput.continue()
        XCTAssertTrue(output.shouldContinue)
    }

    func testStopInitializer() {
        let output = HookOutput.stop(reason: "User requested stop")
        XCTAssertFalse(output.shouldContinue)
        XCTAssertEqual(output.stopReason, "User requested stop")
    }

    func testAllowInitializer() {
        let output = HookOutput.allow(
            updatedInput: ["key": .string("value")],
            additionalContext: "Approved"
        )

        if case .preToolUse(let preOutput) = output.hookSpecificOutput {
            XCTAssertEqual(preOutput.permissionDecision, .allow)
            XCTAssertEqual(preOutput.updatedInput?["key"], .string("value"))
            XCTAssertEqual(preOutput.additionalContext, "Approved")
        } else {
            XCTFail("Expected preToolUse hookSpecificOutput")
        }
    }

    func testDenyInitializer() {
        let output = HookOutput.deny(reason: "Not allowed")

        if case .preToolUse(let preOutput) = output.hookSpecificOutput {
            XCTAssertEqual(preOutput.permissionDecision, .deny)
            XCTAssertEqual(preOutput.permissionDecisionReason, "Not allowed")
        } else {
            XCTFail("Expected preToolUse hookSpecificOutput")
        }
    }

    func testAskInitializer() {
        let output = HookOutput.ask(reason: "User confirmation needed")

        if case .preToolUse(let preOutput) = output.hookSpecificOutput {
            XCTAssertEqual(preOutput.permissionDecision, .ask)
            XCTAssertEqual(preOutput.permissionDecisionReason, "User confirmation needed")
        } else {
            XCTFail("Expected preToolUse hookSpecificOutput")
        }
    }
}

// MARK: - HookInput Tests

final class HookInputTests: XCTestCase {

    var sampleBase: BaseHookInput {
        BaseHookInput(
            sessionId: "test-session",
            transcriptPath: "/tmp/transcript.jsonl",
            cwd: "/home/user",
            permissionMode: "default",
            hookEventName: .preToolUse
        )
    }

    func testEventType() {
        let preToolUse = HookInput.preToolUse(PreToolUseInput(
            base: sampleBase,
            toolName: "Bash",
            toolInput: [:],
            toolUseId: "toolu_1"
        ))
        XCTAssertEqual(preToolUse.eventType, .preToolUse)

        let stop = HookInput.stop(StopInput(base: sampleBase, stopHookActive: true))
        XCTAssertEqual(stop.eventType, .stop)
    }

    func testBase() {
        let input = HookInput.userPromptSubmit(UserPromptSubmitInput(
            base: sampleBase,
            prompt: "Hello"
        ))
        XCTAssertEqual(input.base.sessionId, "test-session")
        XCTAssertEqual(input.base.hookEventName, .preToolUse)
    }
}

// MARK: - BaseHookInput Tests

final class BaseHookInputTests: XCTestCase {

    func testFieldAssignment() {
        let input = BaseHookInput(
            sessionId: "session-123",
            transcriptPath: "/path/to/transcript.jsonl",
            cwd: "/working/dir",
            permissionMode: "acceptEdits",
            hookEventName: .postToolUse
        )

        XCTAssertEqual(input.sessionId, "session-123")
        XCTAssertEqual(input.transcriptPath, "/path/to/transcript.jsonl")
        XCTAssertEqual(input.cwd, "/working/dir")
        XCTAssertEqual(input.permissionMode, "acceptEdits")
        XCTAssertEqual(input.hookEventName, .postToolUse)
    }

    func testEquatable() {
        let input1 = BaseHookInput(
            sessionId: "a",
            transcriptPath: "b",
            cwd: "c",
            permissionMode: "d",
            hookEventName: .stop
        )
        let input2 = BaseHookInput(
            sessionId: "a",
            transcriptPath: "b",
            cwd: "c",
            permissionMode: "d",
            hookEventName: .stop
        )
        let input3 = BaseHookInput(
            sessionId: "different",
            transcriptPath: "b",
            cwd: "c",
            permissionMode: "d",
            hookEventName: .stop
        )

        XCTAssertEqual(input1, input2)
        XCTAssertNotEqual(input1, input3)
    }
}
