//
//  ExitPlanModeTests.swift
//  ClodKitTests
//
//  Behavioral tests for ExitPlanMode and ExitReason types (bead cm4).
//

import XCTest
@testable import ClodKit

// MARK: - ExitPlanModeInput Tests

final class ExitPlanModeInputTests: XCTestCase {

    func testEmptyIsValid() throws {
        let input = ExitPlanModeInput()
        let data = try JSONEncoder().encode(input)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // All fields are optional, so empty should encode with only nil-omitted keys
        XCTAssertNil(json["allowed_prompts"])
        XCTAssertNil(json["push_to_remote"])
        XCTAssertNil(json["remote_session_id"])
        XCTAssertNil(json["remote_session_url"])
        XCTAssertNil(json["remote_session_title"])
    }

    func testAllFieldsOptional() {
        let input = ExitPlanModeInput()
        XCTAssertNil(input.allowedPrompts)
        XCTAssertNil(input.pushToRemote)
        XCTAssertNil(input.remoteSessionId)
        XCTAssertNil(input.remoteSessionUrl)
        XCTAssertNil(input.remoteSessionTitle)
        XCTAssertNil(input.additionalProperties)
    }

    func testAllowedPromptsArray() throws {
        let input = ExitPlanModeInput(
            allowedPrompts: [
                AllowedPrompt(tool: "Bash", prompt: "Run tests"),
                AllowedPrompt(tool: "Bash", prompt: "Build project"),
            ]
        )
        XCTAssertEqual(input.allowedPrompts?.count, 2)
        XCTAssertEqual(input.allowedPrompts?[0].tool, "Bash")
        XCTAssertEqual(input.allowedPrompts?[0].prompt, "Run tests")
        XCTAssertEqual(input.allowedPrompts?[1].prompt, "Build project")
    }

    func testRemoteSessionFields() {
        let input = ExitPlanModeInput(
            pushToRemote: true,
            remoteSessionId: "remote-123",
            remoteSessionUrl: "https://claude.ai/session/remote-123",
            remoteSessionTitle: "Bug fix session"
        )
        XCTAssertEqual(input.pushToRemote, true)
        XCTAssertEqual(input.remoteSessionId, "remote-123")
        XCTAssertEqual(input.remoteSessionUrl, "https://claude.ai/session/remote-123")
        XCTAssertEqual(input.remoteSessionTitle, "Bug fix session")
    }

    func testAdditionalPropertiesForOpenSchema() {
        let input = ExitPlanModeInput(
            additionalProperties: [
                "customKey": .string("customValue"),
                "numericKey": .int(42),
            ]
        )
        XCTAssertEqual(input.additionalProperties?["customKey"]?.stringValue, "customValue")
        XCTAssertEqual(input.additionalProperties?["numericKey"]?.intValue, 42)
    }

    func testCodableRoundTrip() throws {
        let original = ExitPlanModeInput(
            allowedPrompts: [AllowedPrompt(tool: "Bash", prompt: "swift test")],
            pushToRemote: false,
            remoteSessionId: "sess-abc",
            remoteSessionUrl: "https://example.com/sess",
            remoteSessionTitle: "Test Session",
            additionalProperties: ["extra": .string("data")]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ExitPlanModeInput.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testJsonKeysUseSnakeCase() throws {
        let input = ExitPlanModeInput(
            allowedPrompts: [AllowedPrompt(tool: "Bash", prompt: "test")],
            pushToRemote: true,
            remoteSessionId: "id",
            remoteSessionUrl: "url",
            remoteSessionTitle: "title"
        )
        let data = try JSONEncoder().encode(input)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["allowed_prompts"])
        XCTAssertNotNil(json["push_to_remote"])
        XCTAssertNotNil(json["remote_session_id"])
        XCTAssertNotNil(json["remote_session_url"])
        XCTAssertNotNil(json["remote_session_title"])
    }
}

// MARK: - AllowedPrompt Tests

final class AllowedPromptTests: XCTestCase {

    func testFields() {
        let prompt = AllowedPrompt(tool: "Bash", prompt: "npm test")
        XCTAssertEqual(prompt.tool, "Bash")
        XCTAssertEqual(prompt.prompt, "npm test")
    }

    func testCodableRoundTrip() throws {
        let original = AllowedPrompt(tool: "Bash", prompt: "swift build")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AllowedPrompt.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ExitReason Tests

final class ExitReasonTests: XCTestCase {

    func testAllFiveCases() {
        let allCases = ExitReason.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.clear))
        XCTAssertTrue(allCases.contains(.logout))
        XCTAssertTrue(allCases.contains(.promptInputExit))
        XCTAssertTrue(allCases.contains(.other))
        XCTAssertTrue(allCases.contains(.bypassPermissionsDisabled))
    }

    func testRawValuesMatchSnakeCase() {
        XCTAssertEqual(ExitReason.clear.rawValue, "clear")
        XCTAssertEqual(ExitReason.logout.rawValue, "logout")
        XCTAssertEqual(ExitReason.promptInputExit.rawValue, "prompt_input_exit")
        XCTAssertEqual(ExitReason.other.rawValue, "other")
        XCTAssertEqual(ExitReason.bypassPermissionsDisabled.rawValue, "bypass_permissions_disabled")
    }

    func testJsonEncodingMatchesSnakeCase() throws {
        let cases: [(ExitReason, String)] = [
            (.clear, "\"clear\""),
            (.logout, "\"logout\""),
            (.promptInputExit, "\"prompt_input_exit\""),
            (.other, "\"other\""),
            (.bypassPermissionsDisabled, "\"bypass_permissions_disabled\""),
        ]
        for (reason, expected) in cases {
            let data = try JSONEncoder().encode(reason)
            let str = String(data: data, encoding: .utf8)!
            XCTAssertEqual(str, expected)
        }
    }

    func testCodableRoundTrip() throws {
        for reason in ExitReason.allCases {
            let data = try JSONEncoder().encode(reason)
            let decoded = try JSONDecoder().decode(ExitReason.self, from: data)
            XCTAssertEqual(decoded, reason)
        }
    }

    func testUsedBySessionEndInput() {
        let base = BaseHookInput(
            sessionId: "sess-1",
            transcriptPath: "/tmp/transcript.jsonl",
            cwd: "/home/user",
            permissionMode: "default",
            hookEventName: .sessionEnd
        )
        let input = SessionEndInput(base: base, reason: .promptInputExit)
        XCTAssertEqual(input.reason, .promptInputExit)
    }

    func testCaseIterableReturnsAllFive() {
        XCTAssertEqual(ExitReason.allCases.count, 5)
    }
}
