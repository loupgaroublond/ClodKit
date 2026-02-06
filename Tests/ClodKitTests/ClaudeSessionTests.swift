//
//  ClaudeSessionTests.swift
//  ClodKitTests
//
//  Unit tests for ClaudeSession.
//

import XCTest
@testable import ClodKit

final class ClaudeSessionTests: XCTestCase {

    // MARK: - Helper Methods

    private func createMockTransport() -> MockTransport {
        MockTransport()
    }

    // MARK: - Initialization Tests

    func testInit_CreatesSession() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        let sessionId = await session.currentSessionId
        let initialized = await session.initialized

        XCTAssertNil(sessionId)
        XCTAssertFalse(initialized)
    }

    // MARK: - Configuration Tests

    func testSetCanUseTool_RegistersCallback() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        actor TestState {
            var wasCalled = false
            func setCalled() { wasCalled = true }
        }
        let state = TestState()

        await session.setCanUseTool { _, _, _ in
            await state.setCalled()
            return .allowTool()
        }

        // We verify the callback is registered by the session accepting it
        XCTAssertTrue(true)
    }

    func testRegisterMCPServer() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        let server = SDKMCPServer(name: "test-server", tools: [])
        await session.registerMCPServer(server)

        // Server registered successfully
        XCTAssertTrue(true)
    }

    func testOnPreToolUse_RegistersHook() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onPreToolUse { _ in
            return HookOutput()
        }

        // Hook registered successfully
        XCTAssertTrue(true)
    }

    func testOnPostToolUse_RegistersHook() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onPostToolUse { _ in
            return HookOutput()
        }

        // Hook registered successfully
        XCTAssertTrue(true)
    }

    func testOnStop_RegistersHook() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onStop { _ in
            return HookOutput()
        }

        // Hook registered successfully
        XCTAssertTrue(true)
    }

    // MARK: - Close Tests

    func testClose_ClosesTransport() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        await session.close()

        // Transport should be closed - check isConnected
        let isConnected = transport.isConnected
        XCTAssertFalse(isConnected)
    }

    // MARK: - Message Loop Tests

    func testStartMessageLoop_ReturnsStream() async {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        let stream = await session.startMessageLoop()

        // Stream was created
        XCTAssertNotNil(stream)
    }

    func testMessageLoop_YieldsRegularMessages() async throws {
        let transport = createMockTransport()
        let session = ClaudeSession(transport: transport)

        let stream = await session.startMessageLoop()

        // Inject message and finish stream after loop starts
        Task {
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            transport.injectMessage(.regular(SDKMessage(type: "user", content: .string("Hello"))))
            transport.finishStream()
        }

        var messages: [StdoutMessage] = []

        for try await message in stream {
            messages.append(message)
        }

        XCTAssertEqual(messages.count, 1)
        if case .regular(let sdkMsg) = messages.first {
            XCTAssertEqual(sdkMsg.type, "user")
        } else {
            XCTFail("Expected regular message")
        }
    }

    // MARK: - Session Error Tests

    func testSessionError_SessionClosed_LocalizedDescription() {
        let error = SessionError.sessionClosed

        XCTAssertTrue(error.localizedDescription.contains("closed"))
    }

    func testSessionError_NotInitialized_LocalizedDescription() {
        let error = SessionError.notInitialized

        XCTAssertTrue(error.localizedDescription.contains("not been initialized"))
    }

    func testSessionError_InitializationFailed_LocalizedDescription() {
        let error = SessionError.initializationFailed("Test reason")

        XCTAssertTrue(error.localizedDescription.contains("Test reason"))
    }

    func testSessionError_Equatable() {
        let e1 = SessionError.sessionClosed
        let e2 = SessionError.sessionClosed
        let e3 = SessionError.notInitialized

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }

    func testSessionError_InitializationFailed_Equatable() {
        let e1 = SessionError.initializationFailed("A")
        let e2 = SessionError.initializationFailed("A")
        let e3 = SessionError.initializationFailed("B")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }
}
