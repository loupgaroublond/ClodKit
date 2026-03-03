//
//  SessionControlMethodTests.swift
//  ClodKitTests
//
//  Tests for ClaudeSession async control methods (mcpServerStatus, stopTask,
//  setMcpServers) and ClaudeQuery pass-through methods, all via MockTransport
//  with an initialized session.
//

import XCTest
@testable import ClodKit

final class SessionControlMethodTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Helper

    /// Creates an initialized ClaudeSession with a MockTransport that auto-responds
    /// to control requests. Returns the session, transport, stream, and read task.
    private func createInitializedSession() async throws -> (
        session: ClaudeSession,
        transport: MockTransport,
        stream: AsyncThrowingStream<StdoutMessage, Error>,
        readTask: Task<Void, Error>
    ) {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()

        // Auto-respond to all control requests
        transport.mockResponseHandler = { data in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "control_request",
                  let requestId = json["request_id"] as? String,
                  let request = json["request"] as? [String: Any],
                  let subtype = request["subtype"] as? String else {
                return
            }

            let responseValue: Any
            switch subtype {
            case "initialize":
                responseValue = [
                    "commands": [["name": "help", "description": "Show help"]],
                    "agents": [["name": "Explore", "description": "Explore codebase"]],
                    "output_style": "text",
                    "available_output_styles": ["text", "json"],
                    "models": [["value": "claude-sonnet-4-20250514", "display_name": "Sonnet", "description": "Fast"]],
                    "account": ["email": "test@example.com"]
                ] as [String: Any]
            case "mcp_status":
                responseValue = [
                    ["name": "test-server", "status": "connected"]
                ] as [[String: Any]]
            case "stop_task":
                responseValue = ["success": true] as [String: Any]
            case "mcp_set_servers":
                responseValue = [
                    "added": [String](),
                    "removed": [String](),
                    "errors": [String: String]()
                ] as [String: Any]
            case "rewind_files":
                responseValue = [
                    "can_rewind": true,
                    "error": NSNull()
                ] as [String: Any]
            case "apply_flag_settings":
                responseValue = [String: Any]()
            default:
                responseValue = [String: Any]()
            }

            let response: [String: Any] = [
                "type": "control_response",
                "response": [
                    "subtype": "success",
                    "request_id": requestId,
                    "response": responseValue
                ]
            ]

            if let responseData = try? JSONSerialization.data(withJSONObject: response),
               let responseStr = String(data: responseData, encoding: .utf8) {
                transport.injectRawLine(responseStr)
            }
        }

        // Start reading stream in background so message loop processes control responses
        let readTask = Task {
            for try await _ in stream { }
        }

        // Initialize the session
        try await session.initialize()

        return (session, transport, stream, readTask)
    }

    // MARK: - ClaudeSession Control Methods

    func testMcpServerStatus() async throws {
        let (session, transport, _, readTask) = try await createInitializedSession()

        let statuses = try await session.mcpServerStatus()
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses.first?.name, "test-server")
        XCTAssertEqual(statuses.first?.status, "connected")

        readTask.cancel()
        transport.close()
    }

    func testStopTask() async throws {
        let (session, transport, _, readTask) = try await createInitializedSession()

        // Should not throw
        try await session.stopTask(taskId: "task-42")

        readTask.cancel()
        transport.close()
    }

    func testSetMcpServers() async throws {
        let (session, transport, _, readTask) = try await createInitializedSession()

        let config = MCPServerConfig(command: "test", args: [])
        let result = try await session.setMcpServers(["test": config])
        // Should return a McpSetServersResult (possibly empty)
        _ = result

        readTask.cancel()
        transport.close()
    }

    // MARK: - ClaudeQuery Pass-Through Methods

    func testQuery_InitializationResult() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let initResult = try await query.initializationResult()
        XCTAssertEqual(initResult.commands.first?.name, "help")
        XCTAssertEqual(initResult.outputStyle, "text")

        readTask.cancel()
        transport.close()
    }

    func testQuery_SupportedCommands() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let commands = try await query.supportedCommands()
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.name, "help")

        readTask.cancel()
        transport.close()
    }

    func testQuery_SupportedModels() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let models = try await query.supportedModels()
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.value, "claude-sonnet-4-20250514")

        readTask.cancel()
        transport.close()
    }

    func testQuery_SupportedAgents() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let agents = try await query.supportedAgents()
        XCTAssertEqual(agents.count, 1)
        XCTAssertEqual(agents.first?.name, "Explore")

        readTask.cancel()
        transport.close()
    }

    func testQuery_AccountInfo() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let account = try await query.accountInfo()
        XCTAssertEqual(account.email, "test@example.com")

        readTask.cancel()
        transport.close()
    }

    func testQuery_McpServerStatus() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let statuses = try await query.mcpServerStatus()
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses.first?.name, "test-server")

        readTask.cancel()
        transport.close()
    }

    func testQuery_StopTask() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        try await query.stopTask(taskId: "task-99")

        readTask.cancel()
        transport.close()
    }

    func testQuery_SetMcpServers() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let config = MCPServerConfig(command: "test", args: [])
        let result = try await query.setMcpServers(["test": config])
        _ = result

        readTask.cancel()
        transport.close()
    }

    func testQuery_RewindFilesTyped() async throws {
        let (session, transport, stream, readTask) = try await createInitializedSession()
        let query = ClaudeQuery(session: session, stream: stream)

        let result = try await query.rewindFilesTyped(to: "msg-1", dryRun: true)
        XCTAssertTrue(result.canRewind ?? false)

        readTask.cancel()
        transport.close()
    }

    // MARK: - ControlProtocolHandler Convenience Methods

    func testControlHandler_StopTask() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        // Set up response handler
        transport.mockResponseHandler = { data in
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let requestId = json["request_id"] as? String {
                let response: [String: Any] = [
                    "type": "control_response",
                    "response": [
                        "subtype": "success",
                        "request_id": requestId,
                        "response": ["success": true]
                    ]
                ]
                if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                    if let controlResponse = try? JSONDecoder().decode(ControlResponse.self, from: responseData) {
                        Task { await handler.handleControlResponse(controlResponse) }
                    }
                }
            }
        }

        let response = try await handler.stopTask(taskId: "task-1")
        if case .success = response {
            // Expected
        } else {
            XCTFail("Expected success response")
        }

        transport.close()
    }

    func testControlHandler_ApplyFlagSettings() async throws {
        let transport = MockTransport()
        let handler = ControlProtocolHandler(transport: transport)

        transport.mockResponseHandler = { data in
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let requestId = json["request_id"] as? String {
                let response: [String: Any] = [
                    "type": "control_response",
                    "response": [
                        "subtype": "success",
                        "request_id": requestId,
                        "response": [String: Any]()
                    ]
                ]
                if let responseData = try? JSONSerialization.data(withJSONObject: response) {
                    if let controlResponse = try? JSONDecoder().decode(ControlResponse.self, from: responseData) {
                        Task { await handler.handleControlResponse(controlResponse) }
                    }
                }
            }
        }

        let settings = JSONValue.object(["debug": .bool(true)])
        let response = try await handler.applyFlagSettings(settings)
        if case .success = response {
            // Expected
        } else {
            XCTFail("Expected success response")
        }

        transport.close()
    }

    // MARK: - ClaudeSession handleCanUseToolRequest without callback

    func testHandleCanUseToolRequest_NoCallback_AllowsByDefault() async throws {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        let stream = await session.startMessageLoop()

        // Set up response handler for initialization - respond to all requests
        transport.mockResponseHandler = { data in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "control_request",
                  let requestId = json["request_id"] as? String,
                  let request = json["request"] as? [String: Any],
                  let subtype = request["subtype"] as? String else {
                return
            }

            let responseValue: Any
            if subtype == "initialize" {
                responseValue = [
                    "commands": [[String: Any]](),
                    "agents": [[String: Any]](),
                    "output_style": "text",
                    "available_output_styles": ["text"],
                    "models": [[String: Any]](),
                    "account": [String: Any]()
                ] as [String: Any]
            } else {
                responseValue = [String: Any]()
            }

            let response: [String: Any] = [
                "type": "control_response",
                "response": [
                    "subtype": "success",
                    "request_id": requestId,
                    "response": responseValue
                ]
            ]

            if let responseData = try? JSONSerialization.data(withJSONObject: response),
               let responseStr = String(data: responseData, encoding: .utf8) {
                transport.injectRawLine(responseStr)
            }
        }

        let readTask = Task { for try await _ in stream { } }

        // Initialize WITHOUT setting canUseTool callback
        try await session.initialize()

        // Now inject a can_use_tool control request - the handler should allow by default
        // because no callback is registered
        let canUseToolRequest: [String: Any] = [
            "type": "control_request",
            "request_id": "test_req_1",
            "request": [
                "subtype": "can_use_tool",
                "tool_name": "Bash",
                "input": ["command": "ls"],
                "tool_use_id": "tu_1"
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: canUseToolRequest),
           let str = String(data: data, encoding: .utf8) {
            // Small delay to ensure initialization is fully complete
            try await Task.sleep(nanoseconds: 50_000_000)
            transport.injectRawLine(str)
            // Give time for response to be written
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Verify a success response was written back (allow by default)
        let writtenData = transport.getWrittenData()
        // The last written data should be the control response for the can_use_tool request
        let lastFewWrites = writtenData.suffix(3)
        var foundAllowResponse = false
        for data in lastFewWrites {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String,
               type == "control_response",
               let response = json["response"] as? [String: Any],
               let requestId = response["request_id"] as? String,
               requestId == "test_req_1" {
                foundAllowResponse = true
            }
        }
        XCTAssertTrue(foundAllowResponse, "Should have sent an allow response for can_use_tool without callback")

        readTask.cancel()
        transport.close()
    }
}
