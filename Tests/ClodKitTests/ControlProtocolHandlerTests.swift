//
//  ControlProtocolHandlerTests.swift
//  ClodKitTests
//
//  Unit tests for ControlProtocolHandler.
//

import XCTest
@testable import ClodKit

final class ControlProtocolHandlerTests: XCTestCase {

    // MARK: - Request ID Generation Tests

    func testGenerateRequestId_IsUnique() async {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        var ids = Set<String>()
        for _ in 0..<100 {
            let id = await handler.generateRequestId()
            XCTAssertFalse(ids.contains(id), "Generated duplicate ID: \(id)")
            ids.insert(id)
        }
    }

    func testGenerateRequestId_HasCorrectFormat() async {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        let id = await handler.generateRequestId()

        XCTAssertTrue(id.hasPrefix("req_"), "ID should start with 'req_'")
        let parts = id.split(separator: "_")
        XCTAssertEqual(parts.count, 3, "ID should have 3 parts")
    }

    // MARK: - Send Request Tests

    func testSendRequest_WritesToTransport() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Simulate response after a short delay
        Task {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            // Get the written data to extract request ID
            let writtenData = transport.getWrittenData()
            guard let data = writtenData.first,
                  let json = try? JSONDecoder().decode(FullControlRequest.self, from: data) else {
                return
            }

            // Inject success response
            let responsePayload = FullControlResponsePayload.success(requestId: json.requestId, response: nil)
            await handler.handleFullControlResponse(responsePayload)
        }

        let _ = try await handler.sendRequest(.interrupt, timeout: 5.0)

        let writtenData = transport.getWrittenData()
        XCTAssertEqual(writtenData.count, 1)

        // Verify the written data contains the request
        let decoded = try JSONDecoder().decode(FullControlRequest.self, from: writtenData[0])
        XCTAssertEqual(decoded.type, "control_request")
        XCTAssertEqual(decoded.request, .interrupt)
    }

    func testSendRequest_CorrelatesResponse() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Simulate response
        Task {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            let writtenData = transport.getWrittenData()
            guard let data = writtenData.first,
                  let json = try? JSONDecoder().decode(FullControlRequest.self, from: data) else {
                return
            }

            let responsePayload = FullControlResponsePayload.success(
                requestId: json.requestId,
                response: .string("test_result")
            )
            await handler.handleFullControlResponse(responsePayload)
        }

        let response = try await handler.sendRequest(.mcpStatus, timeout: 5.0)

        if case .success(_, let result) = response {
            XCTAssertEqual(result, .string("test_result"))
        } else {
            XCTFail("Expected success response")
        }
    }

    func testSendRequest_TimesOut() async {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport, defaultTimeout: 0.1)

        // Don't send any response - should timeout
        do {
            let _ = try await handler.sendRequest(.interrupt, timeout: 0.05)
            XCTFail("Expected timeout error")
        } catch let error as ControlProtocolError {
            if case .timeout(let requestId) = error {
                XCTAssertTrue(requestId.hasPrefix("req_"))
            } else {
                XCTFail("Expected timeout error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendRequest_HandlesError() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Simulate error response
        Task {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            let writtenData = transport.getWrittenData()
            guard let data = writtenData.first,
                  let json = try? JSONDecoder().decode(FullControlRequest.self, from: data) else {
                return
            }

            let responsePayload = FullControlResponsePayload.error(
                requestId: json.requestId,
                error: "Something went wrong",
                pendingPermissionRequests: nil
            )
            await handler.handleFullControlResponse(responsePayload)
        }

        let response = try await handler.sendRequest(.interrupt, timeout: 5.0)

        if case .error(_, let errorMsg, _) = response {
            XCTAssertEqual(errorMsg, "Something went wrong")
        } else {
            XCTFail("Expected error response")
        }
    }

    // MARK: - Handle Control Request Tests

    func testHandleControlRequest_InvokesHandler() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Use actor for thread-safe capture
        actor TestState {
            var handlerCalled = false
            var receivedToolName: String?

            func setCalled(toolName: String) {
                handlerCalled = true
                receivedToolName = toolName
            }
        }
        let state = TestState()

        await handler.setCanUseToolHandler { request in
            await state.setCalled(toolName: request.toolName)
            return .allowTool()
        }

        let request = FullControlRequest(
            requestId: "req_test",
            request: .canUseTool(CanUseToolRequest(
                toolName: "Bash",
                input: ["command": .string("ls")],
                toolUseId: "tool_1"
            ))
        )

        await handler.handleFullControlRequest(request)

        // Give time for async processing
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let handlerCalled = await state.handlerCalled
        let receivedToolName = await state.receivedToolName
        XCTAssertTrue(handlerCalled)
        XCTAssertEqual(receivedToolName, "Bash")
    }

    func testHandleControlRequest_SendsResponse() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        await handler.setCanUseToolHandler { _ in
            return .allowTool()
        }

        let request = FullControlRequest(
            requestId: "req_test_response",
            request: .canUseTool(CanUseToolRequest(
                toolName: "Read",
                input: [:],
                toolUseId: "tool_2"
            ))
        )

        await handler.handleFullControlRequest(request)

        // Give time for async processing
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let writtenData = transport.getWrittenData()
        XCTAssertEqual(writtenData.count, 1)

        // Verify response was sent
        let response = try JSONDecoder().decode(FullControlResponse.self, from: writtenData[0])
        XCTAssertEqual(response.type, "control_response")
        if case .success(let reqId, _) = response.response {
            XCTAssertEqual(reqId, "req_test_response")
        } else {
            XCTFail("Expected success response")
        }
    }

    func testHandleControlRequest_SendsErrorOnFailure() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Don't register any handler - should send error

        let request = FullControlRequest(
            requestId: "req_no_handler",
            request: .canUseTool(CanUseToolRequest(
                toolName: "Write",
                input: [:],
                toolUseId: "tool_3"
            ))
        )

        await handler.handleFullControlRequest(request)

        // Give time for async processing
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        let writtenData = transport.getWrittenData()
        XCTAssertEqual(writtenData.count, 1)

        // Verify error response was sent
        let response = try JSONDecoder().decode(FullControlResponse.self, from: writtenData[0])
        if case .error(let reqId, _, _) = response.response {
            XCTAssertEqual(reqId, "req_no_handler")
        } else {
            XCTFail("Expected error response")
        }
    }

    // MARK: - Cancel Request Tests

    func testHandleCancelRequest_CancelsPending() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Start a request that won't get a response
        let requestTask = Task {
            try await handler.sendRequest(.interrupt, timeout: 30.0)
        }

        // Give time for request to register
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms

        // Get the request ID from written data
        let writtenData = transport.getWrittenData()
        guard let data = writtenData.first,
              let request = try? JSONDecoder().decode(FullControlRequest.self, from: data) else {
            XCTFail("No request written")
            return
        }

        // Send cancel
        let cancelRequest = ControlCancelRequest(type: "control_cancel_request", requestId: request.requestId)
        await handler.handleCancelRequest(cancelRequest)

        // The request should now complete with cancelled error
        do {
            let _ = try await requestTask.value
            XCTFail("Expected cancelled error")
        } catch let error as ControlProtocolError {
            if case .cancelled(let reqId) = error {
                XCTAssertEqual(reqId, request.requestId)
            } else {
                XCTFail("Expected cancelled error, got: \(error)")
            }
        }
    }

    // MARK: - Convenience Methods Tests

    func testInterruptConvenience() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Simulate response
        Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            let writtenData = transport.getWrittenData()
            guard let data = writtenData.first,
                  let json = try? JSONDecoder().decode(FullControlRequest.self, from: data) else {
                return
            }
            await handler.handleFullControlResponse(.success(requestId: json.requestId, response: nil))
        }

        let _ = try await handler.interrupt()

        let writtenData = transport.getWrittenData()
        let decoded = try JSONDecoder().decode(FullControlRequest.self, from: writtenData[0])
        XCTAssertEqual(decoded.request, .interrupt)
    }
}
