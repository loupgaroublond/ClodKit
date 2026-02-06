//
//  JSONLineParserTests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for JSONLineParser.
//

import XCTest
@testable import ClaudeCodeSDK

final class JSONLineParserTests: XCTestCase {
    var parser: JSONLineParser!

    override func setUp() {
        super.setUp()
        parser = JSONLineParser()
    }

    // MARK: - Regular Message Tests

    func testParseUserMessage() throws {
        let json = "{\"type\":\"user\",\"content\":\"Hello\"}\n"
        let data = Data(json.utf8)

        guard let (message, remaining) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "user")
        } else {
            XCTFail("Expected regular message")
        }

        XCTAssertTrue(remaining.isEmpty)
    }

    func testParseAssistantMessage() throws {
        let json = "{\"type\":\"assistant\",\"content\":\"Hi there\"}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "assistant")
        } else {
            XCTFail("Expected regular message")
        }
    }

    func testParseResultMessage() throws {
        let json = "{\"type\":\"result\",\"data\":{\"success\":true}}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "result")
        } else {
            XCTFail("Expected regular message")
        }
    }

    func testParseSystemMessage() throws {
        let json = "{\"type\":\"system\",\"content\":\"System info\"}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "system")
        } else {
            XCTFail("Expected regular message")
        }
    }

    // MARK: - Control Message Tests

    func testParseControlRequest() throws {
        let json = "{\"type\":\"control_request\",\"request_id\":\"req_1\",\"request\":{\"subtype\":\"can_use_tool\",\"tool_name\":\"Bash\"}}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .controlRequest(let request) = message {
            XCTAssertEqual(request.type, "control_request")
            XCTAssertEqual(request.requestId, "req_1")
        } else {
            XCTFail("Expected controlRequest message")
        }
    }

    func testParseControlResponse() throws {
        let json = "{\"type\":\"control_response\",\"response\":{\"subtype\":\"success\",\"request_id\":\"req_1\",\"response\":{\"session_id\":\"sess_123\"}}}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .controlResponse(let response) = message {
            XCTAssertEqual(response.type, "control_response")
            XCTAssertEqual(response.response.subtype, "success")
            XCTAssertEqual(response.response.requestId, "req_1")
        } else {
            XCTFail("Expected controlResponse message")
        }
    }

    func testParseKeepAlive() throws {
        let json = "{\"type\":\"keep_alive\"}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .keepAlive = message {
            // Success
        } else {
            XCTFail("Expected keepAlive message")
        }
    }

    // MARK: - Buffer Handling Tests

    func testIncompleteBuffer_ReturnsNil() {
        // No newline - incomplete
        let data = Data("{\"type\":\"user\",\"content\":\"Hello\"".utf8)

        let result = parser.parseLine(from: data)
        XCTAssertNil(result, "Incomplete buffer should return nil")
    }

    func testMalformedJSON_SkipsLine() {
        // First line is malformed, second is valid
        let json = "{invalid json here}\n{\"type\":\"user\",\"content\":\"Hello\"}\n"
        let data = Data(json.utf8)

        guard let (message, remaining) = parser.parseLine(from: data) else {
            XCTFail("Expected to skip malformed and parse valid message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "user")
        } else {
            XCTFail("Expected regular message after skipping malformed")
        }

        XCTAssertTrue(remaining.isEmpty)
    }

    func testEmptyLine_SkipsToNext() {
        let json = "\n\n{\"type\":\"user\",\"content\":\"Hello\"}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to skip empty lines and parse valid message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "user")
        } else {
            XCTFail("Expected regular message after skipping empty lines")
        }
    }

    func testMultipleMessages_ParsesAll() {
        let json = "{\"type\":\"user\",\"content\":\"Hello\"}\n{\"type\":\"assistant\",\"content\":\"Hi\"}\n{\"type\":\"result\",\"data\":{}}\n"
        let data = Data(json.utf8)

        let (messages, remaining) = parser.parseAllLines(from: data)

        XCTAssertEqual(messages.count, 3)
        XCTAssertTrue(remaining.isEmpty)

        if case .regular(let msg1) = messages[0] {
            XCTAssertEqual(msg1.type, "user")
        } else {
            XCTFail("Expected user message")
        }

        if case .regular(let msg2) = messages[1] {
            XCTAssertEqual(msg2.type, "assistant")
        } else {
            XCTFail("Expected assistant message")
        }

        if case .regular(let msg3) = messages[2] {
            XCTAssertEqual(msg3.type, "result")
        } else {
            XCTFail("Expected result message")
        }
    }

    func testRemainingBuffer_IsReturned() {
        // First line complete, second incomplete
        let json = "{\"type\":\"user\",\"content\":\"Hello\"}\n{\"type\":\"assis"
        let data = Data(json.utf8)

        guard let (_, remaining) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse first message")
            return
        }

        // Remaining should have the incomplete second message
        XCTAssertEqual(String(data: remaining, encoding: .utf8), "{\"type\":\"assis")
    }

    func testMissingType_SkipsLine() {
        // First line missing type, second is valid
        let json = "{\"content\":\"no type field\"}\n{\"type\":\"user\",\"content\":\"Hello\"}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to skip invalid and parse valid message")
            return
        }

        if case .regular(let sdkMessage) = message {
            XCTAssertEqual(sdkMessage.type, "user")
        } else {
            XCTFail("Expected regular message")
        }
    }

    func testControlCancelRequest() throws {
        let json = "{\"type\":\"control_cancel_request\",\"request_id\":\"req_5\"}\n"
        let data = Data(json.utf8)

        guard let (message, _) = parser.parseLine(from: data) else {
            XCTFail("Expected to parse message")
            return
        }

        if case .controlCancelRequest(let cancelRequest) = message {
            XCTAssertEqual(cancelRequest.type, "control_cancel_request")
            XCTAssertEqual(cancelRequest.requestId, "req_5")
        } else {
            XCTFail("Expected controlCancelRequest message")
        }
    }
}

// MARK: - JSONLineParserError Tests

final class JSONLineParserErrorTests: XCTestCase {

    func testMissingType() {
        let error = JSONLineParserError.missingType
        XCTAssertEqual(error, .missingType)
    }

    func testUnknownType() {
        let error1 = JSONLineParserError.unknownType("foo")
        let error2 = JSONLineParserError.unknownType("foo")
        let error3 = JSONLineParserError.unknownType("bar")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testMalformedJSON() {
        let error = JSONLineParserError.malformedJSON("unexpected token")
        if case .malformedJSON(let msg) = error {
            XCTAssertEqual(msg, "unexpected token")
        } else {
            XCTFail("Wrong error case")
        }
    }
}
