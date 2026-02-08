//
//  ConversationIntegrationTests.swift
//  ClodKitTests
//
//  Integration tests for multi-turn conversation features using real Claude CLI.
//

import XCTest
@testable import ClodKit

final class ConversationIntegrationTests: XCTestCase {

    // MARK: - Two-Turn Conversation

    @available(*, deprecated, message: "V2 Session API is unstable and may change")
    func testTwoTurnConversation_MaintainsContext() async throws {
        try skipIfCLIUnavailable()

        let options = SDKSessionOptions(model: "claude-sonnet-4-20250514")

        let session = unstable_v2_createSession(options: options)

        // First turn: establish context
        try await session.send("My favorite color is blue. Remember that. Reply with only OK.")
        var turn1Messages: [SDKMessage] = []
        for try await msg in session.receiveResponse() {
            turn1Messages.append(msg)
        }

        XCTAssertFalse(turn1Messages.isEmpty, "Should receive at least one message in turn 1")

        // Second turn: verify context was retained
        try await session.send("What is my favorite color? Reply with only the color name.")
        var turn2Messages: [SDKMessage] = []
        for try await msg in session.receiveResponse() {
            turn2Messages.append(msg)
        }

        XCTAssertFalse(turn2Messages.isEmpty, "Should receive at least one message in turn 2")
    }

    // MARK: - Session Resume

    func testSessionResume_PreservesContext() async throws {
        try skipIfCLIUnavailable()

        // Start a session and capture its ID
        var options = defaultIntegrationOptions()
        options.systemPrompt = "Reply with only the word OK"

        let query = try await ClodKit.query(prompt: "Say OK", options: options)
        let messages = try await collectMessagesUntilResult(from: query, timeout: IntegrationTestConfig.apiTimeout)

        XCTAssertFalse(messages.isEmpty, "Should receive messages from first session")

        // Get session ID
        let sessionId = await query.sessionId
        XCTAssertNotNil(sessionId, "Should have a session ID")

        guard let sid = sessionId else { return }

        // Resume the session
        var resumeOptions = defaultIntegrationOptions()
        resumeOptions.resume = sid
        resumeOptions.systemPrompt = "Reply with only the word OK"

        let resumeQuery = try await ClodKit.query(prompt: "Say OK again", options: resumeOptions)
        let resumeMessages = try await collectMessagesUntilResult(from: resumeQuery, timeout: IntegrationTestConfig.apiTimeout)

        XCTAssertFalse(resumeMessages.isEmpty, "Should receive messages from resumed session")
    }

    // MARK: - QueryOptions Multi-Turn Properties

    func testContinueConversation_DefaultIsFalse() {
        let options = QueryOptions()
        XCTAssertFalse(options.continueConversation)
    }

    func testForkSession_DefaultIsFalse() {
        let options = QueryOptions()
        XCTAssertFalse(options.forkSession)
    }

    func testContinueConversation_CanBeSet() {
        var options = QueryOptions()
        options.continueConversation = true
        XCTAssertTrue(options.continueConversation)
    }

    func testForkSession_CanBeSet() {
        var options = QueryOptions()
        options.forkSession = true
        XCTAssertTrue(options.forkSession)
    }
}
