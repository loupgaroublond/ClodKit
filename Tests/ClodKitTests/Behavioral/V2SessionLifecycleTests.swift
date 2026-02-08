//
//  V2SessionLifecycleTests.swift
//  ClodKitTests
//
//  Behavioral tests for V2 Session API lifecycle (bead a91).
//

import XCTest
@testable import ClodKit

// MARK: - SDKSessionOptions Tests

final class SDKSessionOptionsTests: XCTestCase {

    func testModelIsRequired() {
        let options = SDKSessionOptions(model: "claude-sonnet-4-20250514")
        XCTAssertEqual(options.model, "claude-sonnet-4-20250514")
    }

    func testAllOptionalFieldsDefaultToNil() {
        let options = SDKSessionOptions(model: "opus")
        XCTAssertNil(options.pathToClaudeCodeExecutable)
        XCTAssertNil(options.executableArgs)
        XCTAssertNil(options.env)
        XCTAssertNil(options.allowedTools)
        XCTAssertNil(options.disallowedTools)
        XCTAssertNil(options.canUseTool)
        XCTAssertNil(options.permissionMode)
    }

    func testOptionalFieldsCanBeSet() {
        var options = SDKSessionOptions(model: "sonnet")
        options.pathToClaudeCodeExecutable = "/usr/local/bin/claude"
        options.executableArgs = ["--debug"]
        options.env = ["KEY": "value"]
        options.allowedTools = ["Bash", "Read"]
        options.disallowedTools = ["Write"]
        options.permissionMode = .bypassPermissions

        XCTAssertEqual(options.pathToClaudeCodeExecutable, "/usr/local/bin/claude")
        XCTAssertEqual(options.executableArgs, ["--debug"])
        XCTAssertEqual(options.env, ["KEY": "value"])
        XCTAssertEqual(options.allowedTools, ["Bash", "Read"])
        XCTAssertEqual(options.disallowedTools, ["Write"])
        XCTAssertEqual(options.permissionMode, .bypassPermissions)
    }
}

// MARK: - SDKResultMessage Tests

final class SDKResultMessageTests: XCTestCase {

    func testSuccessResult() {
        let result = SDKResultMessage(type: "result", subtype: "success", result: "Hello", sessionId: "sess-1")
        XCTAssertEqual(result.type, "result")
        XCTAssertEqual(result.subtype, "success")
        XCTAssertEqual(result.result, "Hello")
        XCTAssertEqual(result.sessionId, "sess-1")
    }

    func testErrorResult() {
        let result = SDKResultMessage(type: "result", subtype: "error")
        XCTAssertEqual(result.subtype, "error")
        XCTAssertNil(result.result)
        XCTAssertNil(result.sessionId)
    }

    func testCodableRoundTrip() throws {
        let original = SDKResultMessage(type: "result", subtype: "success", result: "test output", sessionId: "abc-123")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SDKResultMessage.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSessionIdEncodesAsSnakeCase() throws {
        let result = SDKResultMessage(type: "result", subtype: "success", sessionId: "sess-1")
        let data = try JSONEncoder().encode(result)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["session_id"])
        XCTAssertNil(json["sessionId"])
    }

    func testEquatable() {
        let a = SDKResultMessage(type: "result", subtype: "success", result: "hi")
        let b = SDKResultMessage(type: "result", subtype: "success", result: "hi")
        let c = SDKResultMessage(type: "result", subtype: "error", result: "hi")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - SDKSession Protocol Tests

final class SDKSessionProtocolTests: XCTestCase {

    func testSDKSessionProtocolExists() {
        // Verify the protocol has the expected members by creating a V2Session
        let options = SDKSessionOptions(model: "sonnet")
        let session: any SDKSession = unstable_v2_createSession(options: options)
        // session conforms to SDKSession protocol
        XCTAssertNotNil(session)
    }

    func testSessionIdThrowsBeforeInit() async {
        let options = SDKSessionOptions(model: "sonnet")
        let session = V2Session(options: options, sessionIdToResume: nil)
        do {
            _ = try await session.sessionId
            XCTFail("Expected SessionError.notInitialized")
        } catch {
            XCTAssertEqual(error as? SessionError, .notInitialized)
        }
    }

    func testResumeSessionSetsSessionId() async throws {
        let options = SDKSessionOptions(model: "sonnet")
        let session = V2Session(options: options, sessionIdToResume: "existing-id")
        let id = try await session.sessionId
        XCTAssertEqual(id, "existing-id")
    }

    func testCloseIsIdempotent() {
        let options = SDKSessionOptions(model: "sonnet")
        let session = V2Session(options: options, sessionIdToResume: nil)
        // Calling close multiple times should not crash
        session.close()
        session.close()
        session.close()
    }

    func testStreamBeforeSendThrows() async {
        let options = SDKSessionOptions(model: "sonnet")
        let session = V2Session(options: options, sessionIdToResume: nil)
        let stream = session.stream()
        do {
            for try await _ in stream {
                XCTFail("Expected error, not a message")
            }
            XCTFail("Expected stream to throw")
        } catch {
            XCTAssertEqual(error as? SessionError, .notInitialized)
        }
    }
}

// MARK: - V2 Session API Function Tests

final class V2SessionAPITests: XCTestCase {

    func testCreateSessionReturnsSDKSession() {
        let options = SDKSessionOptions(model: "sonnet")
        let session = unstable_v2_createSession(options: options)
        XCTAssertNotNil(session)
    }

    func testResumeSessionReturnsSDKSession() {
        let options = SDKSessionOptions(model: "sonnet")
        let session = unstable_v2_resumeSession(sessionId: "my-session", options: options)
        XCTAssertNotNil(session)
    }

    func testResumeSessionPreservesSessionId() async throws {
        let options = SDKSessionOptions(model: "sonnet")
        let session = unstable_v2_resumeSession(sessionId: "my-session", options: options)
        let id = try await session.sessionId
        XCTAssertEqual(id, "my-session")
    }
}
