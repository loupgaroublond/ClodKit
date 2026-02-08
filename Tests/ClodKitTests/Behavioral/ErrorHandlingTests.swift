//
//  ErrorHandlingTests.swift
//  ClodKitTests
//
//  Behavioral tests for error handling across message types (bead 9y2).
//

import XCTest
@testable import ClodKit

// MARK: - SDKAssistantMessageError Tests

final class SDKAssistantMessageErrorTests: XCTestCase {

    func testAllSixValuesDecodeCorrectly() throws {
        let cases: [(String, SDKAssistantMessageError)] = [
            ("\"authentication_failed\"", .authenticationFailed),
            ("\"billing_error\"", .billingError),
            ("\"rate_limit\"", .rateLimit),
            ("\"invalid_request\"", .invalidRequest),
            ("\"server_error\"", .serverError),
            ("\"unknown\"", .unknown),
        ]
        for (json, expected) in cases {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(SDKAssistantMessageError.self, from: data)
            XCTAssertEqual(decoded, expected, "Failed for JSON: \(json)")
        }
    }

    func testRawValues() {
        XCTAssertEqual(SDKAssistantMessageError.authenticationFailed.rawValue, "authentication_failed")
        XCTAssertEqual(SDKAssistantMessageError.billingError.rawValue, "billing_error")
        XCTAssertEqual(SDKAssistantMessageError.rateLimit.rawValue, "rate_limit")
        XCTAssertEqual(SDKAssistantMessageError.invalidRequest.rawValue, "invalid_request")
        XCTAssertEqual(SDKAssistantMessageError.serverError.rawValue, "server_error")
        XCTAssertEqual(SDKAssistantMessageError.unknown.rawValue, "unknown")
    }

    func testCodableRoundTrip() throws {
        let allCases: [SDKAssistantMessageError] = [
            .authenticationFailed, .billingError, .rateLimit,
            .invalidRequest, .serverError, .unknown,
        ]
        for error in allCases {
            let data = try JSONEncoder().encode(error)
            let decoded = try JSONDecoder().decode(SDKAssistantMessageError.self, from: data)
            XCTAssertEqual(decoded, error)
        }
    }
}

// MARK: - SDKMessage Error Accessor Tests

final class SDKMessageErrorAccessorTests: XCTestCase {

    func testAssistantMessageWithError() {
        let msg = SDKMessage(type: "assistant", rawJSON: [
            "error": .string("rate_limit"),
        ])
        XCTAssertEqual(msg.error, .rateLimit)
    }

    func testAssistantMessageWithoutError() {
        let msg = SDKMessage(type: "assistant", rawJSON: [:])
        XCTAssertNil(msg.error)
    }

    func testErrorOnNonAssistantMessageIsNil() {
        let msg = SDKMessage(type: "result", rawJSON: [
            "error": .string("rate_limit"),
        ])
        XCTAssertNil(msg.error)
    }

    func testUnknownErrorStringFallsBackToUnknown() {
        let msg = SDKMessage(type: "assistant", rawJSON: [
            "error": .string("something_totally_new"),
        ])
        XCTAssertEqual(msg.error, .unknown)
    }

    func testStopReasonOnResult() {
        let msg = SDKMessage(type: "result", rawJSON: [
            "stop_reason": .string("end_turn"),
        ])
        XCTAssertEqual(msg.stopReason, "end_turn")
    }

    func testStopReasonAbsent() {
        let msg = SDKMessage(type: "result", rawJSON: [:])
        XCTAssertNil(msg.stopReason)
    }
}

// MARK: - SDKMessage Codable Tests

final class SDKMessageCodableErrorTests: XCTestCase {

    func testDecodeMissingTypeThrows() {
        let json = """
        {"content": "hello"}
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(SDKMessage.self, from: data))
    }

    func testDecodeUnknownTypeDoesNotCrash() throws {
        let json = """
        {"type": "some_future_type", "payload": "data"}
        """
        let data = json.data(using: .utf8)!
        let msg = try JSONDecoder().decode(SDKMessage.self, from: data)
        XCTAssertEqual(msg.type, "some_future_type")
    }

    func testResultMessageDecodes() throws {
        let json = """
        {"type": "result", "result": "output text", "stop_reason": "end_turn", "session_id": "sess-42"}
        """
        let data = json.data(using: .utf8)!
        let msg = try JSONDecoder().decode(SDKMessage.self, from: data)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.content?.stringValue, "output text")
        XCTAssertEqual(msg.stopReason, "end_turn")
        XCTAssertEqual(msg.sessionId, "sess-42")
    }
}

// MARK: - ControlProtocolError Tests

final class ControlProtocolErrorBehavioralTests: XCTestCase {

    func testTimeoutError() {
        let error = ControlProtocolError.timeout(requestId: "req-1")
        if case .timeout(let id) = error {
            XCTAssertEqual(id, "req-1")
        } else {
            XCTFail("Expected timeout")
        }
    }

    func testCancelledError() {
        let error = ControlProtocolError.cancelled(requestId: "req-2")
        if case .cancelled(let id) = error {
            XCTAssertEqual(id, "req-2")
        } else {
            XCTFail("Expected cancelled")
        }
    }

    func testResponseError() {
        let error = ControlProtocolError.responseError(requestId: "req-3", message: "bad request")
        if case .responseError(let id, let msg) = error {
            XCTAssertEqual(id, "req-3")
            XCTAssertEqual(msg, "bad request")
        } else {
            XCTFail("Expected responseError")
        }
    }

    func testUnknownSubtypeError() {
        let error = ControlProtocolError.unknownSubtype("mystery")
        if case .unknownSubtype(let s) = error {
            XCTAssertEqual(s, "mystery")
        } else {
            XCTFail("Expected unknownSubtype")
        }
    }

    func testInvalidMessageError() {
        let error = ControlProtocolError.invalidMessage("bad json")
        if case .invalidMessage(let s) = error {
            XCTAssertEqual(s, "bad json")
        } else {
            XCTFail("Expected invalidMessage")
        }
    }

    func testEquality() {
        XCTAssertEqual(
            ControlProtocolError.timeout(requestId: "a"),
            ControlProtocolError.timeout(requestId: "a")
        )
        XCTAssertNotEqual(
            ControlProtocolError.timeout(requestId: "a"),
            ControlProtocolError.timeout(requestId: "b")
        )
        XCTAssertNotEqual(
            ControlProtocolError.timeout(requestId: "a"),
            ControlProtocolError.cancelled(requestId: "a")
        )
    }
}

// MARK: - SDKAuthStatusMessage Tests

final class SDKAuthStatusMessageTests: XCTestCase {

    func testDecodeFromJSON() throws {
        let json = """
        {
            "type": "auth_status",
            "is_authenticating": true,
            "output": ["Authenticating...", "Please wait"],
            "error": null,
            "uuid": "uuid-1",
            "session_id": "sess-1"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try JSONDecoder().decode(SDKAuthStatusMessage.self, from: data)
        XCTAssertEqual(msg.type, "auth_status")
        XCTAssertTrue(msg.isAuthenticating)
        XCTAssertEqual(msg.output, ["Authenticating...", "Please wait"])
        XCTAssertNil(msg.error)
        XCTAssertEqual(msg.uuid, "uuid-1")
        XCTAssertEqual(msg.sessionId, "sess-1")
    }

    func testDecodeWithError() throws {
        let json = """
        {
            "type": "auth_status",
            "is_authenticating": false,
            "output": [],
            "error": "Authentication failed",
            "uuid": "uuid-2",
            "session_id": "sess-2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try JSONDecoder().decode(SDKAuthStatusMessage.self, from: data)
        XCTAssertFalse(msg.isAuthenticating)
        XCTAssertEqual(msg.error, "Authentication failed")
    }

    func testCodableRoundTrip() throws {
        let original = SDKAuthStatusMessage(
            type: "auth_status",
            isAuthenticating: true,
            output: ["step1", "step2"],
            error: nil,
            uuid: "test-uuid",
            sessionId: "test-session"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SDKAuthStatusMessage.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
