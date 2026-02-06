//
//  MockTransportTests.swift
//  ClodKitTests
//
//  Unit tests for MockTransport.
//

import XCTest
@testable import ClodKit

final class MockTransportTests: XCTestCase {

    // MARK: - Write Tests

    func testWrite_CapturesData() async throws {
        let transport = MockTransport()
        let testData = Data("Hello, World!".utf8)

        try await transport.write(testData)

        let writtenData = transport.getWrittenData()
        XCTAssertEqual(writtenData.count, 1)
        XCTAssertEqual(writtenData[0], testData)
    }

    func testWrite_CapturesMultipleWrites() async throws {
        let transport = MockTransport()
        let data1 = Data("First".utf8)
        let data2 = Data("Second".utf8)
        let data3 = Data("Third".utf8)

        try await transport.write(data1)
        try await transport.write(data2)
        try await transport.write(data3)

        let writtenData = transport.getWrittenData()
        XCTAssertEqual(writtenData.count, 3)
        XCTAssertEqual(writtenData[0], data1)
        XCTAssertEqual(writtenData[1], data2)
        XCTAssertEqual(writtenData[2], data3)
    }

    func testWrite_ThrowsWhenInputEnded() async throws {
        let transport = MockTransport()

        await transport.endInput()

        do {
            try await transport.write(Data("test".utf8))
            XCTFail("Expected write to throw")
        } catch let error as TransportError {
            XCTAssertEqual(error, .closed)
        }
    }

    // MARK: - Clear Written Data Tests

    func testClearWrittenData_Clears() async throws {
        let transport = MockTransport()
        try await transport.write(Data("test".utf8))

        transport.clearWrittenData()

        let writtenData = transport.getWrittenData()
        XCTAssertTrue(writtenData.isEmpty)
    }

    // MARK: - Inject Message Tests

    func testInjectMessage_YieldsFromStream() async throws {
        let transport = MockTransport()
        let message = StdoutMessage.regular(SDKMessage(type: "user", content: .string("Hello")))

        // Start reading in background
        let stream = transport.readMessages()

        // Give the stream time to set up
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Inject message
        transport.injectMessage(message)

        // Finish stream to prevent hanging
        transport.finishStream()

        // Collect messages
        var messages: [StdoutMessage] = []
        for try await msg in stream {
            messages.append(msg)
        }

        XCTAssertEqual(messages.count, 1)
        if case .regular(let sdkMessage) = messages[0] {
            XCTAssertEqual(sdkMessage.type, "user")
        } else {
            XCTFail("Expected regular message")
        }
    }

    func testInjectMessage_QueuedBeforeStreamStart() async throws {
        let transport = MockTransport()
        let message1 = StdoutMessage.regular(SDKMessage(type: "user"))
        let message2 = StdoutMessage.keepAlive

        // Inject before starting stream
        transport.injectMessage(message1)
        transport.injectMessage(message2)

        // Now start reading
        let stream = transport.readMessages()

        // Finish stream after a short delay
        Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            transport.finishStream()
        }

        // Collect messages
        var messages: [StdoutMessage] = []
        for try await msg in stream {
            messages.append(msg)
        }

        XCTAssertEqual(messages.count, 2)
    }

    // MARK: - Inject Error Tests

    func testInjectError_ThrowsFromStream() async throws {
        let transport = MockTransport()

        // Start reading in background
        let stream = transport.readMessages()

        // Give the stream time to set up
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Inject error
        transport.injectError(TransportError.processTerminated(1))

        // Collect and expect error
        do {
            for try await _ in stream {
                // Consume any messages
            }
            XCTFail("Expected stream to throw error")
        } catch let error as TransportError {
            XCTAssertEqual(error, .processTerminated(1))
        }
    }

    func testInjectError_QueuedBeforeStreamStart() async throws {
        let transport = MockTransport()

        // Inject error before starting stream
        transport.injectError(TransportError.writeFailed("test error"))

        // Now start reading
        let stream = transport.readMessages()

        // Expect error
        do {
            for try await _ in stream {
                // Consume any messages
            }
            XCTFail("Expected stream to throw error")
        } catch let error as TransportError {
            XCTAssertEqual(error, .writeFailed("test error"))
        }
    }

    // MARK: - Connection State Tests

    func testIsConnected_InitiallyTrue() {
        let transport = MockTransport()
        XCTAssertTrue(transport.isConnected)
    }

    func testClose_SetsConnectedFalse() {
        let transport = MockTransport()

        transport.close()

        XCTAssertFalse(transport.isConnected)
    }

    // MARK: - End Input Tests

    func testEndInput_SetsInputEnded() async {
        let transport = MockTransport()

        await transport.endInput()

        XCTAssertTrue(transport.isInputEnded())
    }

    func testEndInput_InitiallyFalse() {
        let transport = MockTransport()

        XCTAssertFalse(transport.isInputEnded())
    }

    // MARK: - Multiple Message Types Tests

    func testInjectMessage_AllMessageTypes() async throws {
        let transport = MockTransport()

        // Inject all message types before stream
        transport.injectMessage(.regular(SDKMessage(type: "assistant")))
        transport.injectMessage(.controlRequest(ControlRequest(type: "control_request", requestId: "1", request: .null)))
        transport.injectMessage(.controlResponse(ControlResponse(type: "control_response", response: ControlResponsePayload(subtype: "success", requestId: "1"))))
        transport.injectMessage(.controlCancelRequest(ControlCancelRequest(type: "control_cancel_request", requestId: "1")))
        transport.injectMessage(.keepAlive)

        let stream = transport.readMessages()

        // Finish stream after a short delay
        Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            transport.finishStream()
        }

        var messages: [StdoutMessage] = []
        for try await msg in stream {
            messages.append(msg)
        }

        XCTAssertEqual(messages.count, 5)
    }
}
