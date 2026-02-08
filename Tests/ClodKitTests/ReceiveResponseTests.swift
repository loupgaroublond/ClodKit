//
//  ReceiveResponseTests.swift
//  ClodKitTests
//
//  Unit tests for receiveResponse() convenience on SDKSession.
//

import XCTest
@testable import ClodKit

@available(*, deprecated, message: "V2 Session API is unstable and may change")
final class ReceiveResponseTests: XCTestCase {

    // MARK: - V2 Session Type Tests

    func testSDKSessionOptions_Creation() {
        let options = SDKSessionOptions(model: "claude-sonnet-4-20250514")

        XCTAssertEqual(options.model, "claude-sonnet-4-20250514")
        XCTAssertNil(options.pathToClaudeCodeExecutable)
        XCTAssertNil(options.executableArgs)
        XCTAssertNil(options.env)
        XCTAssertNil(options.allowedTools)
        XCTAssertNil(options.disallowedTools)
        XCTAssertNil(options.canUseTool)
        XCTAssertNil(options.permissionMode)
    }

    func testSDKSessionOptions_WithAllProperties() {
        var options = SDKSessionOptions(model: "claude-sonnet-4-20250514")
        options.pathToClaudeCodeExecutable = "/usr/bin/claude"
        options.executableArgs = ["--verbose"]
        options.env = ["KEY": "value"]
        options.allowedTools = ["Read"]
        options.disallowedTools = ["Bash"]
        options.permissionMode = .bypassPermissions

        XCTAssertEqual(options.model, "claude-sonnet-4-20250514")
        XCTAssertEqual(options.pathToClaudeCodeExecutable, "/usr/bin/claude")
        XCTAssertEqual(options.executableArgs, ["--verbose"])
        XCTAssertEqual(options.env?["KEY"], "value")
        XCTAssertEqual(options.allowedTools, ["Read"])
        XCTAssertEqual(options.disallowedTools, ["Bash"])
        XCTAssertEqual(options.permissionMode, .bypassPermissions)
    }

    func testSDKResultMessage_Creation() {
        let result = SDKResultMessage(type: "result", subtype: "success", result: "Done", sessionId: "sess-123")

        XCTAssertEqual(result.type, "result")
        XCTAssertEqual(result.subtype, "success")
        XCTAssertEqual(result.result, "Done")
        XCTAssertEqual(result.sessionId, "sess-123")
    }

    func testSDKResultMessage_Encoding() throws {
        let result = SDKResultMessage(type: "result", subtype: "success", result: "OK", sessionId: "sess-1")
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(SDKResultMessage.self, from: data)

        XCTAssertEqual(result, decoded)
    }

    // MARK: - receiveResponse() Tests

    func testReceiveResponse_YieldsMessagesUntilResult() async throws {
        // Create a mock session that returns messages followed by a result
        let mockSession = MockSDKSession()
        mockSession.messagesToYield = [
            SDKMessage(type: "assistant", content: .string("Hello there")),
            SDKMessage(type: "assistant", content: .string("More content")),
            SDKMessage(type: "result", rawJSON: ["type": .string("result"), "result": .string("Final")])
        ]

        var collected: [SDKMessage] = []
        for try await msg in mockSession.receiveResponse() {
            collected.append(msg)
        }

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0].type, "assistant")
        XCTAssertEqual(collected[1].type, "assistant")
        XCTAssertEqual(collected[2].type, "result")
    }

    func testReceiveResponse_MultipleTurns() async throws {
        let mockSession = MockSDKSession()

        // First turn
        mockSession.messagesToYield = [
            SDKMessage(type: "assistant", content: .string("Turn 1 response")),
            SDKMessage(type: "result", rawJSON: ["type": .string("result"), "result": .string("Turn 1 done")])
        ]

        var turn1: [SDKMessage] = []
        for try await msg in mockSession.receiveResponse() {
            turn1.append(msg)
        }

        XCTAssertEqual(turn1.count, 2)
        XCTAssertEqual(turn1[0].type, "assistant")
        XCTAssertEqual(turn1[1].type, "result")

        // Second turn
        mockSession.messagesToYield = [
            SDKMessage(type: "assistant", content: .string("Turn 2 response")),
            SDKMessage(type: "result", rawJSON: ["type": .string("result"), "result": .string("Turn 2 done")])
        ]

        var turn2: [SDKMessage] = []
        for try await msg in mockSession.receiveResponse() {
            turn2.append(msg)
        }

        XCTAssertEqual(turn2.count, 2)
        XCTAssertEqual(turn2[0].type, "assistant")
        XCTAssertEqual(turn2[1].type, "result")
    }

    func testReceiveResponse_EmptyTurn() async throws {
        // Result comes immediately with no preceding messages
        let mockSession = MockSDKSession()
        mockSession.messagesToYield = [
            SDKMessage(type: "result", rawJSON: ["type": .string("result"), "result": .string("Empty")])
        ]

        var collected: [SDKMessage] = []
        for try await msg in mockSession.receiveResponse() {
            collected.append(msg)
        }

        XCTAssertEqual(collected.count, 1)
        XCTAssertEqual(collected[0].type, "result")
    }

    func testReceiveResponse_StreamFinishesCleanly() async throws {
        let mockSession = MockSDKSession()
        mockSession.messagesToYield = [
            SDKMessage(type: "assistant", content: .string("Response")),
            SDKMessage(type: "result", rawJSON: ["type": .string("result"), "result": .string("Done")])
        ]

        // Stream should finish without hanging - use timeout to verify
        let expectation = XCTestExpectation(description: "Stream should finish")

        Task {
            for try await _ in mockSession.receiveResponse() {
                // consume
            }
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock SDKSession

/// A mock SDKSession for testing receiveResponse() without spawning a real process.
@available(*, deprecated, message: "V2 Session API is unstable and may change")
private final class MockSDKSession: SDKSession, @unchecked Sendable {
    var messagesToYield: [SDKMessage] = []
    private var _sessionId: String = "mock-session-id"

    var sessionId: String {
        get async throws { _sessionId }
    }

    func send(_ message: String) async throws {
        // No-op for mock
    }

    func stream() -> AsyncThrowingStream<SDKMessage, Error> {
        let messages = self.messagesToYield
        return AsyncThrowingStream { continuation in
            for msg in messages {
                continuation.yield(msg)
            }
            continuation.finish()
        }
    }

    func close() {
        // No-op for mock
    }
}
