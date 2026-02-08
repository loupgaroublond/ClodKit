//
//  StreamingIntegrationTests.swift
//  ClodKitTests
//
//  Integration tests for streaming query overloads using real Claude CLI.
//

import XCTest
@testable import ClodKit

final class StreamingIntegrationTests: XCTestCase {

    // MARK: - Single Message Streaming

    func testStreamingSingleMessage_ProducesResult() async throws {
        try skipIfCLIUnavailable()

        var options = defaultIntegrationOptions()
        options.systemPrompt = "Reply with only the word OK"

        let stream = AsyncStream<SDKUserMessage> { continuation in
            continuation.yield(SDKUserMessage(content: "Say OK"))
            continuation.finish()
        }

        let query = try await ClodKit.query(prompt: stream, options: options)
        let messages = try await collectMessagesUntilResult(from: query, timeout: IntegrationTestConfig.apiTimeout)

        XCTAssertFalse(messages.isEmpty, "Should receive at least one message")
        XCTAssertTrue(messages.last?.isResult ?? false, "Last message should be a result")
    }

    // MARK: - Multi-Message Streaming

    func testStreamingMultipleMessages_ProcessesBoth() async throws {
        try skipIfCLIUnavailable()

        var options = defaultIntegrationOptions()
        options.systemPrompt = "Reply with only the word OK"

        let query = try await Clod.query(options: options) { continuation in
            continuation.yield(SDKUserMessage(content: "Say OK"))
            continuation.finish()
        }

        let messages = try await collectMessagesUntilResult(from: query, timeout: IntegrationTestConfig.apiTimeout)

        XCTAssertFalse(messages.isEmpty, "Should receive at least one message")
        XCTAssertTrue(messages.last?.isResult ?? false, "Last message should be a result")
    }
}
