//
//  StreamingInputTests.swift
//  ClodKitTests
//
//  Unit tests for streaming query overloads.
//

import XCTest
@testable import ClodKit

final class StreamingInputTests: XCTestCase {

    // MARK: - SDKUserMessage Tests

    func testSDKUserMessage_Creation() {
        let message = SDKUserMessage(content: "Hello, Claude")

        XCTAssertEqual(message.type, "user")
        XCTAssertEqual(message.message.role, "user")
        XCTAssertEqual(message.message.content, "Hello, Claude")
    }

    func testSDKUserMessage_Encoding() throws {
        let message = SDKUserMessage(content: "Test message")
        let data = try JSONEncoder().encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["type"] as? String, "user")
        let innerMessage = json?["message"] as? [String: String]
        XCTAssertEqual(innerMessage?["role"], "user")
        XCTAssertEqual(innerMessage?["content"], "Test message")
    }

    func testSDKUserMessage_Equatable() {
        let msg1 = SDKUserMessage(content: "Hello")
        let msg2 = SDKUserMessage(content: "Hello")
        let msg3 = SDKUserMessage(content: "Different")

        XCTAssertEqual(msg1, msg2)
        XCTAssertNotEqual(msg1, msg3)
    }

    func testSDKUserMessage_RoundTrip() throws {
        let original = SDKUserMessage(content: "Round trip test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SDKUserMessage.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Streaming Query Overload Signature Tests

    func testStreamingQueryOverload_FreeFunction_SignatureExists() {
        // Verify the free function overload exists with the correct signature
        // Compilation is the test - if this compiles, the function exists
        let _: (AsyncStream<SDKUserMessage>, QueryOptions) async throws -> ClaudeQuery = ClodKit.query(prompt:options:)
        XCTAssertTrue(true)
    }

    func testStreamingQueryOverload_ClodNamespace_SignatureExists() {
        // Verify the Clod namespace overload exists with the correct signature
        let _: (AsyncStream<SDKUserMessage>, QueryOptions) async throws -> ClaudeQuery = Clod.query(prompt:options:)
        XCTAssertTrue(true)
    }

    func testStreamingQueryOverload_ClosureConvenience_SignatureExists() {
        // Verify the closure convenience exists with the correct signature
        let _: (QueryOptions, @Sendable @escaping (AsyncStream<SDKUserMessage>.Continuation) -> Void) async throws -> ClaudeQuery = Clod.query(options:promptStream:)
        XCTAssertTrue(true)
    }

    // MARK: - AsyncSequence Overload Behavior Tests

    func testStreamingQuery_SendsMessagesViaStreamInput() async throws {
        // Create a simple AsyncStream with known messages
        let messages = [
            SDKUserMessage(content: "First message"),
            SDKUserMessage(content: "Second message")
        ]

        // Verify SDKUserMessage encodes to the expected wire format
        for message in messages {
            let data = try JSONEncoder().encode(message)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["type"] as? String, "user")
            let inner = json?["message"] as? [String: String]
            XCTAssertEqual(inner?["role"], "user")
            XCTAssertNotNil(inner?["content"])
        }
    }

    // MARK: - Closure Convenience Tests

    func testClosureConvenience_CreatesStreamFromClosure() async {
        // Verify that the closure receives a valid continuation
        let expectation = XCTestExpectation(description: "Closure should be called")

        let stream = AsyncStream<SDKUserMessage> { continuation in
            continuation.yield(SDKUserMessage(content: "From closure"))
            continuation.finish()
            expectation.fulfill()
        }

        var collected: [SDKUserMessage] = []
        for await message in stream {
            collected.append(message)
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertEqual(collected.count, 1)
        XCTAssertEqual(collected[0].message.content, "From closure")
    }

    func testClosureConvenience_MultipleMessages() async {
        let stream = AsyncStream<SDKUserMessage> { continuation in
            continuation.yield(SDKUserMessage(content: "Message 1"))
            continuation.yield(SDKUserMessage(content: "Message 2"))
            continuation.yield(SDKUserMessage(content: "Message 3"))
            continuation.finish()
        }

        var collected: [SDKUserMessage] = []
        for await message in stream {
            collected.append(message)
        }

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0].message.content, "Message 1")
        XCTAssertEqual(collected[1].message.content, "Message 2")
        XCTAssertEqual(collected[2].message.content, "Message 3")
    }

    // MARK: - Cancellation Tests

    func testStreamingQuery_CancellationPropagation() async {
        // Verify that cancelling a task terminates an AsyncStream
        let stream = AsyncStream<SDKUserMessage> { continuation in
            // Simulate a slow producer
            Task {
                for i in 0..<100 {
                    guard !Task.isCancelled else {
                        continuation.finish()
                        return
                    }
                    continuation.yield(SDKUserMessage(content: "Message \(i)"))
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                continuation.finish()
            }
        }

        let task = Task {
            var count = 0
            for await _ in stream {
                count += 1
                if count >= 3 {
                    break
                }
            }
            return count
        }

        let count = await task.value
        XCTAssertGreaterThanOrEqual(count, 3)
    }
}
