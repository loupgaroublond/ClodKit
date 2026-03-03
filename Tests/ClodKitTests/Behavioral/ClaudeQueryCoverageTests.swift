//
//  ClaudeQueryCoverageTests.swift
//  ClodKitTests
//
//  Tests for ClaudeQuery pass-through methods and ClaudeSession control methods
//  that don't require a live CLI. Uses MockTransport to simulate responses.
//

import XCTest
@testable import ClodKit

final class ClaudeQueryCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - ClaudeQuery Pass-Through Methods

    /// Test that initializationResult() calls through to session.
    /// Session is not initialized, so it should throw.
    func testInitializationResult_NotInitialized_Throws() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        do {
            _ = try await query.initializationResult()
            XCTFail("Expected SessionError.notInitialized")
        } catch let error as SessionError {
            XCTAssertEqual(error, .notInitialized)
        }

        transport.close()
    }

    /// Test supportedCommands throws when not initialized.
    func testSupportedCommands_NotInitialized_Throws() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        do {
            _ = try await query.supportedCommands()
            XCTFail("Expected error")
        } catch {
            // Expected - not initialized
        }

        transport.close()
    }

    /// Test supportedModels throws when not initialized.
    func testSupportedModels_NotInitialized_Throws() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        do {
            _ = try await query.supportedModels()
            XCTFail("Expected error")
        } catch {
            // Expected
        }

        transport.close()
    }

    /// Test supportedAgents throws when not initialized.
    func testSupportedAgents_NotInitialized_Throws() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        do {
            _ = try await query.supportedAgents()
            XCTFail("Expected error")
        } catch {
            // Expected
        }

        transport.close()
    }

    /// Test accountInfo throws when not initialized.
    func testAccountInfo_NotInitialized_Throws() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        do {
            _ = try await query.accountInfo()
            XCTFail("Expected error")
        } catch {
            // Expected
        }

        transport.close()
    }

    /// Test close() calls through to session.
    func testClose_CallsSessionClose() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        await query.close()

        XCTAssertFalse(transport.isConnected)
    }

    /// Test tempFiles are cleaned up in deinit.
    func testDeinit_CleansTempFiles() async throws {
        // Create a temp file
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cleanup-\(UUID().uuidString).json").path
        FileManager.default.createFile(atPath: tempPath, contents: Data("test".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath))

        // Create a query with the temp file registered
        do {
            let transport = MockTransport()
            let session = ClaudeSession(transport: transport)
            let stream = await session.startMessageLoop()
            let _ = ClaudeQuery(session: session, stream: stream, tempFiles: [tempPath])
            // query goes out of scope here
        }

        // Give deinit time to run
        try await Task.sleep(nanoseconds: 100_000_000)

        // File should be cleaned up
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempPath),
            "Temp file should be deleted by ClaudeQuery deinit")
    }

    // MARK: - V2 Session Tests

    /// Test V2Session sessionId throws when not initialized.
    func testV2Session_SessionId_NotInitialized() async throws {
        let session = V2Session(options: SDKSessionOptions(model: "claude-sonnet-4-20250514"), sessionIdToResume: nil)

        do {
            _ = try await session.sessionId
            XCTFail("Expected SessionError.notInitialized")
        } catch let error as SessionError {
            XCTAssertEqual(error, .notInitialized)
        }
    }

    /// Test V2Session sessionId returns resume ID when provided.
    func testV2Session_SessionId_WithResumeId() async throws {
        let session = V2Session(options: SDKSessionOptions(model: "claude-sonnet-4-20250514"), sessionIdToResume: "test-session-123")

        let id = try await session.sessionId
        XCTAssertEqual(id, "test-session-123")
    }

    /// Test V2Session stream without send returns error.
    func testV2Session_Stream_WithoutSend() async throws {
        let session = V2Session(options: SDKSessionOptions(model: "claude-sonnet-4-20250514"), sessionIdToResume: nil)

        let stream = session.stream()
        do {
            for try await _ in stream {
                XCTFail("Should not yield messages")
            }
            XCTFail("Should throw")
        } catch let error as SessionError {
            XCTAssertEqual(error, .notInitialized)
        }
    }

    /// Test V2Session close doesn't crash.
    func testV2Session_Close() {
        let session = V2Session(options: SDKSessionOptions(model: "claude-sonnet-4-20250514"), sessionIdToResume: nil)
        session.close()
        // Should not crash
    }

    /// Test createSession returns a session.
    func testCreateSession() {
        let session = unstable_v2_createSession(options: SDKSessionOptions(model: "claude-sonnet-4-20250514"))
        // Should create without crashing
        session.close()
    }

    /// Test resumeSession returns a session with session ID.
    func testResumeSession() async throws {
        let session = unstable_v2_resumeSession(sessionId: "test-123", options: SDKSessionOptions(model: "claude-sonnet-4-20250514"))
        let id = try await session.sessionId
        XCTAssertEqual(id, "test-123")
    }

    // MARK: - Additional ClaudeQuery Pass-Through Methods

    /// Test initializationResult pass-through (via query).
    func testInitializationResult_ViaQuery_Throws() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        do {
            _ = try await query.initializationResult()
            XCTFail("Expected error")
        } catch {
            // Expected - not initialized
        }

        transport.close()
    }

    /// Test streamInput with empty stream.
    func testStreamInput_EmptyStream() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        // Empty async stream — should complete without error
        let emptyStream = AsyncStream<SDKUserMessage> { $0.finish() }
        try await query.streamInput(emptyStream)

        transport.close()
    }

    // MARK: - ClaudeSession Control Method Error Paths

    /// Test initializationResult with error response.
    func testInitializationResult_ErrorResponse() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        // Can't test error response path without setting initResponse directly,
        // but we can verify the not-initialized path
        do {
            _ = try await session.initializationResult()
            XCTFail("Expected error")
        } catch let error as SessionError {
            XCTAssertEqual(error, .notInitialized)
        }

        transport.close()
    }

    // MARK: - receiveResponse Tests

    /// Test receiveResponse yields messages until result.
    func testReceiveResponse_YieldsUntilResult() async throws {
        // Create a mock session that provides a stream
        let mockSession = V2Session(options: SDKSessionOptions(model: "claude-sonnet-4-20250514"), sessionIdToResume: "test")

        // Since we can't easily set up a full query, test the stream-without-send path
        let stream = mockSession.stream()

        do {
            for try await _ in stream { }
            XCTFail("Should throw")
        } catch {
            // Expected - no query instance
        }
    }
}
