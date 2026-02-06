//
//  ClaudeQueryTests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for ClaudeQuery.
//

import XCTest
@testable import ClaudeCodeSDK

final class ClaudeQueryTests: XCTestCase {

    // MARK: - Helper Methods

    private func createMockSession() -> (MockTransport, ClaudeSession) {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        return (transport, session)
    }

    private func createQuery(session: ClaudeSession) async -> ClaudeQuery {
        let stream = await session.startMessageLoop()
        return ClaudeQuery(session: session, stream: stream)
    }

    // MARK: - Iteration Tests

    func testMakeAsyncIterator_ReturnsIterator() async {
        let (_, session) = createMockSession()
        let query = await createQuery(session: session)

        let iterator = query.makeAsyncIterator()

        XCTAssertNotNil(iterator)
    }

    func testIteration_YieldsMessages() async throws {
        let (transport, session) = createMockSession()
        let query = await createQuery(session: session)

        // Inject messages after stream starts
        Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            transport.injectMessage(.regular(SDKMessage(type: "assistant", content: .string("Hello"))))
            transport.injectMessage(.regular(SDKMessage(type: "result", content: .string("Done"))))
            transport.finishStream()
        }

        var messages: [StdoutMessage] = []
        for try await message in query {
            messages.append(message)
        }

        XCTAssertEqual(messages.count, 2)
    }

    // MARK: - Session ID Tests

    func testSessionId_ReturnsNilBeforeInit() async {
        let (_, session) = createMockSession()
        let query = await createQuery(session: session)

        let sessionId = await query.sessionId

        XCTAssertNil(sessionId)
    }

    // MARK: - AsyncSequence Conformance Tests

    func testAsyncSequence_WorksWithForAwait() async throws {
        let (transport, session) = createMockSession()
        let query = await createQuery(session: session)

        Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            transport.injectMessage(.regular(SDKMessage(type: "user", content: .string("Test"))))
            transport.finishStream()
        }

        var count = 0
        for try await _ in query {
            count += 1
        }

        XCTAssertEqual(count, 1)
    }

    // MARK: - Control Method Delegation Tests

    // Note: Full control method tests would require more complex mocking
    // These tests verify the methods exist and are callable

    func testControlMethods_Exist() async {
        let (_, session) = createMockSession()
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        // Verify methods exist by getting references (they'll timeout without proper mock)
        _ = query.interrupt
        _ = query.setModel
        _ = query.setPermissionMode
        _ = query.setMaxThinkingTokens
        _ = query.rewindFiles
        _ = query.mcpStatus
        _ = query.reconnectMcpServer
        _ = query.toggleMcpServer
    }
}
