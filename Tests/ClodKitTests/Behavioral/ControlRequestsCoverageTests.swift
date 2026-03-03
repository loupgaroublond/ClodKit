//
//  ControlRequestsCoverageTests.swift
//  ClodKitTests
//
//  Encode/decode round-trip tests for previously uncovered ControlRequestPayload paths.
//

import XCTest
@testable import ClodKit

final class ControlRequestsCoverageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Individual Request Type Round-Trips

    func testSetMcpServersRequest_RoundTrip() throws {
        let req = SetMcpServersRequest(servers: ["test": .object(["type": .string("stdio")])])
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(SetMcpServersRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "mcp_set_servers")
        XCTAssertEqual(decoded.servers["test"], .object(["type": .string("stdio")]))
    }

    func testSetMcpServersRequest_EmptyServers() throws {
        let req = SetMcpServersRequest(servers: [:])
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(SetMcpServersRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "mcp_set_servers")
        XCTAssertTrue(decoded.servers.isEmpty)
    }

    func testMCPMessageRequest_RoundTrip() throws {
        let message = JSONRPCMessage(
            jsonrpc: "2.0",
            id: .int(1),
            method: "tools/list",
            params: .object(["cursor": .string("abc")])
        )
        let req = MCPMessageRequest(serverName: "my-server", message: message)
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(MCPMessageRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "mcp_message")
        XCTAssertEqual(decoded.serverName, "my-server")
        XCTAssertEqual(decoded.message.jsonrpc, "2.0")
        XCTAssertEqual(decoded.message.method, "tools/list")
        XCTAssertEqual(decoded.message.id, .int(1))
    }

    func testStopTaskRequest_RoundTrip() throws {
        let req = StopTaskRequest(taskId: "task_abc123")
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(StopTaskRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "stop_task")
        XCTAssertEqual(decoded.taskId, "task_abc123")
    }

    func testApplyFlagSettingsRequest_RoundTrip() throws {
        let settings: JSONValue = .object([
            "verbose": .bool(true),
            "maxTokens": .int(1024)
        ])
        let req = ApplyFlagSettingsRequest(settings: settings)
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(ApplyFlagSettingsRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "apply_flag_settings")
        XCTAssertEqual(decoded.settings, settings)
    }

    func testCanUseToolRequest_RoundTrip() throws {
        let req = CanUseToolRequest(
            toolName: "Read",
            input: ["path": .string("/tmp")],
            toolUseId: "tu_123",
            permissionSuggestions: nil,
            blockedPath: nil,
            decisionReason: nil,
            agentId: nil,
            description: "Read a file"
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(CanUseToolRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "can_use_tool")
        XCTAssertEqual(decoded.toolName, "Read")
        XCTAssertEqual(decoded.input["path"], .string("/tmp"))
        XCTAssertEqual(decoded.toolUseId, "tu_123")
        XCTAssertNil(decoded.permissionSuggestions)
        XCTAssertNil(decoded.blockedPath)
        XCTAssertNil(decoded.decisionReason)
        XCTAssertNil(decoded.agentId)
        XCTAssertEqual(decoded.description, "Read a file")
    }

    func testCanUseToolRequest_AllFields() throws {
        let req = CanUseToolRequest(
            toolName: "Bash",
            input: ["command": .string("ls")],
            toolUseId: "tu_456",
            permissionSuggestions: nil,
            blockedPath: "/restricted",
            decisionReason: "Path is restricted",
            agentId: "agent_1",
            description: "Run a shell command"
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(CanUseToolRequest.self, from: data)
        XCTAssertEqual(decoded.toolName, "Bash")
        XCTAssertEqual(decoded.blockedPath, "/restricted")
        XCTAssertEqual(decoded.decisionReason, "Path is restricted")
        XCTAssertEqual(decoded.agentId, "agent_1")
        XCTAssertEqual(decoded.description, "Run a shell command")
    }

    func testHookCallbackRequest_RoundTrip() throws {
        let req = HookCallbackRequest(
            callbackId: "cb_789",
            input: ["event": .string("preToolUse"), "toolName": .string("Bash")],
            toolUseId: "tu_abc"
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(HookCallbackRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "hook_callback")
        XCTAssertEqual(decoded.callbackId, "cb_789")
        XCTAssertEqual(decoded.input["event"], .string("preToolUse"))
        XCTAssertEqual(decoded.toolUseId, "tu_abc")
    }

    func testHookCallbackRequest_NilToolUseId() throws {
        let req = HookCallbackRequest(
            callbackId: "cb_000",
            input: ["key": .string("value")]
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(HookCallbackRequest.self, from: data)
        XCTAssertEqual(decoded.callbackId, "cb_000")
        XCTAssertNil(decoded.toolUseId)
    }

    func testElicitationControlRequest_RoundTrip() throws {
        let schema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object(["name": .object(["type": .string("string")])])
        ])
        let req = ElicitationControlRequest(
            mcpServerName: "auth-server",
            message: "Please enter your credentials",
            mode: "form",
            url: "https://example.com/auth",
            elicitationId: "elic_42",
            requestedSchema: schema
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(ElicitationControlRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "elicitation")
        XCTAssertEqual(decoded.mcpServerName, "auth-server")
        XCTAssertEqual(decoded.message, "Please enter your credentials")
        XCTAssertEqual(decoded.mode, "form")
        XCTAssertEqual(decoded.url, "https://example.com/auth")
        XCTAssertEqual(decoded.elicitationId, "elic_42")
        XCTAssertEqual(decoded.requestedSchema, schema)
    }

    func testElicitationControlRequest_MinimalFields() throws {
        let req = ElicitationControlRequest(
            mcpServerName: "srv",
            message: "Confirm?"
        )
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(ElicitationControlRequest.self, from: data)
        XCTAssertEqual(decoded.subtype, "elicitation")
        XCTAssertEqual(decoded.mcpServerName, "srv")
        XCTAssertEqual(decoded.message, "Confirm?")
        XCTAssertNil(decoded.mode)
        XCTAssertNil(decoded.url)
        XCTAssertNil(decoded.elicitationId)
        XCTAssertNil(decoded.requestedSchema)
    }

    // MARK: - ControlRequestPayload Round-Trips

    func testPayload_SetMcpServers_RoundTrip() throws {
        let req = SetMcpServersRequest(servers: ["s1": .object(["type": .string("stdio")])])
        let payload = ControlRequestPayload.setMcpServers(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "mcp_set_servers")
        if case .setMcpServers(let inner) = decoded {
            XCTAssertEqual(inner.servers["s1"], .object(["type": .string("stdio")]))
        } else {
            XCTFail("Expected .setMcpServers, got \(decoded)")
        }
    }

    func testPayload_McpMessage_RoundTrip() throws {
        let message = JSONRPCMessage(method: "ping")
        let req = MCPMessageRequest(serverName: "test-srv", message: message)
        let payload = ControlRequestPayload.mcpMessage(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "mcp_message")
        if case .mcpMessage(let inner) = decoded {
            XCTAssertEqual(inner.serverName, "test-srv")
            XCTAssertEqual(inner.message.method, "ping")
        } else {
            XCTFail("Expected .mcpMessage, got \(decoded)")
        }
    }

    func testPayload_StopTask_RoundTrip() throws {
        let req = StopTaskRequest(taskId: "t_1")
        let payload = ControlRequestPayload.stopTask(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "stop_task")
        if case .stopTask(let inner) = decoded {
            XCTAssertEqual(inner.taskId, "t_1")
        } else {
            XCTFail("Expected .stopTask, got \(decoded)")
        }
    }

    func testPayload_ApplyFlagSettings_RoundTrip() throws {
        let req = ApplyFlagSettingsRequest(settings: .object(["debug": .bool(true)]))
        let payload = ControlRequestPayload.applyFlagSettings(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "apply_flag_settings")
        if case .applyFlagSettings(let inner) = decoded {
            XCTAssertEqual(inner.settings, .object(["debug": .bool(true)]))
        } else {
            XCTFail("Expected .applyFlagSettings, got \(decoded)")
        }
    }

    func testPayload_CanUseTool_RoundTrip() throws {
        let req = CanUseToolRequest(
            toolName: "Write",
            input: ["file_path": .string("/tmp/out.txt")],
            toolUseId: "tu_999",
            description: "Write output"
        )
        let payload = ControlRequestPayload.canUseTool(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "can_use_tool")
        if case .canUseTool(let inner) = decoded {
            XCTAssertEqual(inner.toolName, "Write")
            XCTAssertEqual(inner.toolUseId, "tu_999")
        } else {
            XCTFail("Expected .canUseTool, got \(decoded)")
        }
    }

    func testPayload_HookCallback_RoundTrip() throws {
        let req = HookCallbackRequest(
            callbackId: "hk_1",
            input: ["action": .string("allow")],
            toolUseId: "tu_hk"
        )
        let payload = ControlRequestPayload.hookCallback(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "hook_callback")
        if case .hookCallback(let inner) = decoded {
            XCTAssertEqual(inner.callbackId, "hk_1")
            XCTAssertEqual(inner.toolUseId, "tu_hk")
        } else {
            XCTFail("Expected .hookCallback, got \(decoded)")
        }
    }

    func testPayload_Elicitation_RoundTrip() throws {
        let req = ElicitationControlRequest(
            mcpServerName: "elicit-srv",
            message: "Enter token",
            mode: "input",
            elicitationId: "e_1"
        )
        let payload = ControlRequestPayload.elicitation(req)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        XCTAssertEqual(decoded.subtype, "elicitation")
        if case .elicitation(let inner) = decoded {
            XCTAssertEqual(inner.mcpServerName, "elicit-srv")
            XCTAssertEqual(inner.message, "Enter token")
            XCTAssertEqual(inner.mode, "input")
            XCTAssertEqual(inner.elicitationId, "e_1")
        } else {
            XCTFail("Expected .elicitation, got \(decoded)")
        }
    }

    // MARK: - Subtype Computed Property

    func testPayload_Subtype_SetMcpServers() {
        let payload = ControlRequestPayload.setMcpServers(SetMcpServersRequest(servers: [:]))
        XCTAssertEqual(payload.subtype, "mcp_set_servers")
    }

    func testPayload_Subtype_McpMessage() {
        let payload = ControlRequestPayload.mcpMessage(
            MCPMessageRequest(serverName: "s", message: JSONRPCMessage(method: "m"))
        )
        XCTAssertEqual(payload.subtype, "mcp_message")
    }

    func testPayload_Subtype_StopTask() {
        let payload = ControlRequestPayload.stopTask(StopTaskRequest(taskId: "t"))
        XCTAssertEqual(payload.subtype, "stop_task")
    }

    func testPayload_Subtype_ApplyFlagSettings() {
        let payload = ControlRequestPayload.applyFlagSettings(
            ApplyFlagSettingsRequest(settings: .null)
        )
        XCTAssertEqual(payload.subtype, "apply_flag_settings")
    }

    func testPayload_Subtype_CanUseTool() {
        let payload = ControlRequestPayload.canUseTool(
            CanUseToolRequest(toolName: "T", input: [:], toolUseId: "id")
        )
        XCTAssertEqual(payload.subtype, "can_use_tool")
    }

    func testPayload_Subtype_HookCallback() {
        let payload = ControlRequestPayload.hookCallback(
            HookCallbackRequest(callbackId: "c", input: [:])
        )
        XCTAssertEqual(payload.subtype, "hook_callback")
    }

    func testPayload_Subtype_Elicitation() {
        let payload = ControlRequestPayload.elicitation(
            ElicitationControlRequest(mcpServerName: "s", message: "m")
        )
        XCTAssertEqual(payload.subtype, "elicitation")
    }

    // MARK: - Unknown Subtype

    func testPayload_UnknownSubtype_ThrowsError() {
        let json = #"{"subtype":"unknown_type"}"#
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ControlRequestPayload.self, from: data)) { error in
            guard case DecodingError.dataCorrupted(let context) = error else {
                XCTFail("Expected dataCorrupted, got \(error)")
                return
            }
            XCTAssertTrue(context.debugDescription.contains("Unknown control request subtype"))
        }
    }
}
