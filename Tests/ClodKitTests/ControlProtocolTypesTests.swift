//
//  ControlProtocolTypesTests.swift
//  ClodKitTests
//
//  Unit tests for control protocol types.
//

import XCTest
@testable import ClodKit

// MARK: - Request Types Tests

final class InitializeRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = InitializeRequest(
            hooks: nil,
            sdkMcpServers: ["server1", "server2"],
            systemPrompt: "You are helpful.",
            appendSystemPrompt: nil
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(InitializeRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "initialize")
        XCTAssertEqual(decoded.sdkMcpServers, ["server1", "server2"])
        XCTAssertEqual(decoded.systemPrompt, "You are helpful.")
    }

    func testSubtypeIsCorrect() {
        let request = InitializeRequest()
        XCTAssertEqual(request.subtype, "initialize")
    }
}

final class SetPermissionModeRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = SetPermissionModeRequest(mode: .acceptEdits)

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SetPermissionModeRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "set_permission_mode")
        XCTAssertEqual(decoded.mode, .acceptEdits)
    }
}

final class SetModelRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = SetModelRequest(model: "claude-3-opus")

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SetModelRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "set_model")
        XCTAssertEqual(decoded.model, "claude-3-opus")
    }

    func testNullModel() throws {
        let request = SetModelRequest(model: nil)

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SetModelRequest.self, from: data)

        XCTAssertNil(decoded.model)
    }
}

final class RewindFilesRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = RewindFilesRequest(userMessageId: "msg_123", dryRun: true)

        // Type has custom CodingKeys, so don't use encoding strategies
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(RewindFilesRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "rewind_files")
        XCTAssertEqual(decoded.userMessageId, "msg_123")
        XCTAssertEqual(decoded.dryRun, true)
    }
}

final class MCPReconnectRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = MCPReconnectRequest(serverName: "my-server")

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(MCPReconnectRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "mcp_reconnect")
        XCTAssertEqual(decoded.serverName, "my-server")
    }
}

final class MCPToggleRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = MCPToggleRequest(serverName: "server", enabled: false)

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(MCPToggleRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "mcp_toggle")
        XCTAssertEqual(decoded.serverName, "server")
        XCTAssertFalse(decoded.enabled)
    }
}

final class CanUseToolRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = CanUseToolRequest(
            toolName: "Bash",
            input: ["command": .string("ls -la")],
            toolUseId: "tool_123",
            blockedPath: "/etc/passwd",
            agentId: "agent_1"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(CanUseToolRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "can_use_tool")
        XCTAssertEqual(decoded.toolName, "Bash")
        XCTAssertEqual(decoded.toolUseId, "tool_123")
        XCTAssertEqual(decoded.blockedPath, "/etc/passwd")
        XCTAssertEqual(decoded.agentId, "agent_1")
    }
}

final class HookCallbackRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = HookCallbackRequest(
            callbackId: "callback_1",
            input: ["type": .string("pre_tool_use"), "tool": .string("Write")],
            toolUseId: "tool_456"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(HookCallbackRequest.self, from: data)

        XCTAssertEqual(decoded.subtype, "hook_callback")
        XCTAssertEqual(decoded.callbackId, "callback_1")
        XCTAssertEqual(decoded.toolUseId, "tool_456")
    }
}

// MARK: - ControlRequestPayload Tests

final class ControlRequestPayloadTests: XCTestCase {

    func testDecodeInitialize() throws {
        let json = """
        {"subtype":"initialize","system_prompt":"Be helpful"}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(ControlRequestPayload.self, from: data)

        if case .initialize(let req) = payload {
            XCTAssertEqual(req.systemPrompt, "Be helpful")
        } else {
            XCTFail("Expected initialize payload")
        }
    }

    func testDecodeInterrupt() throws {
        let json = """
        {"subtype":"interrupt"}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(ControlRequestPayload.self, from: data)

        if case .interrupt = payload {
            // Success
        } else {
            XCTFail("Expected interrupt payload")
        }
    }

    func testDecodeMcpStatus() throws {
        let json = """
        {"subtype":"mcp_status"}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(ControlRequestPayload.self, from: data)

        if case .mcpStatus = payload {
            // Success
        } else {
            XCTFail("Expected mcpStatus payload")
        }
    }

    func testDecodeCanUseTool() throws {
        let json = """
        {"subtype":"can_use_tool","tool_name":"Read","input":{"path":"/tmp/test.txt"},"tool_use_id":"tool_1"}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(ControlRequestPayload.self, from: data)

        if case .canUseTool(let req) = payload {
            XCTAssertEqual(req.toolName, "Read")
            XCTAssertEqual(req.toolUseId, "tool_1")
        } else {
            XCTFail("Expected canUseTool payload")
        }
    }

    func testDecodeHookCallback() throws {
        let json = """
        {"subtype":"hook_callback","callback_id":"cb_1","input":{"event":"test"}}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(ControlRequestPayload.self, from: data)

        if case .hookCallback(let req) = payload {
            XCTAssertEqual(req.callbackId, "cb_1")
        } else {
            XCTFail("Expected hookCallback payload")
        }
    }

    func testDecodeUnknownSubtype_Throws() {
        let json = """
        {"subtype":"unknown_type"}
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(ControlRequestPayload.self, from: data))
    }

    func testEncodeInterrupt() throws {
        let payload = ControlRequestPayload.interrupt
        let data = try JSONEncoder().encode(payload)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"subtype\":\"interrupt\""))
    }

    func testSubtypeProperty() {
        XCTAssertEqual(ControlRequestPayload.interrupt.subtype, "interrupt")
        XCTAssertEqual(ControlRequestPayload.mcpStatus.subtype, "mcp_status")
        XCTAssertEqual(ControlRequestPayload.initialize(InitializeRequest()).subtype, "initialize")
    }
}

// MARK: - Response Payload Tests

final class FullControlResponsePayloadTests: XCTestCase {

    func testDecodeSuccess() throws {
        let json = """
        {"subtype":"success","request_id":"req_1","response":{"session_id":"sess_123"}}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)

        if case .success(let requestId, let response) = payload {
            XCTAssertEqual(requestId, "req_1")
            XCTAssertNotNil(response)
        } else {
            XCTFail("Expected success payload")
        }
    }

    func testDecodeSuccessNullResponse() throws {
        let json = """
        {"subtype":"success","request_id":"req_2"}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)

        if case .success(let requestId, let response) = payload {
            XCTAssertEqual(requestId, "req_2")
            XCTAssertNil(response)
        } else {
            XCTFail("Expected success payload")
        }
    }

    func testDecodeError() throws {
        let json = """
        {"subtype":"error","request_id":"req_3","error":"Something went wrong","pending_permission_requests":["perm_1"]}
        """
        let data = Data(json.utf8)
        let payload = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)

        if case .error(let requestId, let error, let pending) = payload {
            XCTAssertEqual(requestId, "req_3")
            XCTAssertEqual(error, "Something went wrong")
            XCTAssertEqual(pending, ["perm_1"])
        } else {
            XCTFail("Expected error payload")
        }
    }

    func testRequestIdProperty() throws {
        let success = FullControlResponsePayload.success(requestId: "req_a", response: nil)
        let error = FullControlResponsePayload.error(requestId: "req_b", error: "err", pendingPermissionRequests: nil)

        XCTAssertEqual(success.requestId, "req_a")
        XCTAssertEqual(error.requestId, "req_b")
    }

    func testCodableRoundTrip() throws {
        let original = FullControlResponsePayload.success(requestId: "req_rt", response: .string("result"))

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)

        XCTAssertEqual(original, decoded)
    }
}

// MARK: - JSONRPC Tests

final class JSONRPCMessageTests: XCTestCase {

    func testRequestFactory() {
        let msg = JSONRPCMessage.request(id: 1, method: "tools/list", params: nil)

        XCTAssertEqual(msg.jsonrpc, "2.0")
        XCTAssertEqual(msg.id, .int(1))
        XCTAssertEqual(msg.method, "tools/list")
        XCTAssertNil(msg.params)
    }

    func testResponseFactory() {
        let msg = JSONRPCMessage.response(id: 2, result: .object(["tools": .array([])]))

        XCTAssertEqual(msg.jsonrpc, "2.0")
        XCTAssertEqual(msg.id, .int(2))
        XCTAssertNotNil(msg.result)
        XCTAssertNil(msg.method)
    }

    func testErrorResponseFactory() {
        let error = JSONRPCError(code: -32601, message: "Method not found")
        let msg = JSONRPCMessage.errorResponse(id: 3, error: error)

        XCTAssertEqual(msg.jsonrpc, "2.0")
        XCTAssertEqual(msg.id, .int(3))
        XCTAssertNotNil(msg.error)
        XCTAssertEqual(msg.error?.code, JSONRPCError.methodNotFound)
    }

    func testNotificationFactory() {
        let msg = JSONRPCMessage.notification(method: "initialized", params: nil)

        XCTAssertEqual(msg.jsonrpc, "2.0")
        XCTAssertNil(msg.id)
        XCTAssertEqual(msg.method, "initialized")
    }

    func testCodableRoundTrip() throws {
        let original = JSONRPCMessage.request(
            id: 42,
            method: "tools/call",
            params: .object(["name": .string("Bash"), "arguments": .object([:])])
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONRPCMessage.self, from: data)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.id, .int(42))
        XCTAssertEqual(decoded.method, "tools/call")
    }
}

final class JSONRPCErrorTests: XCTestCase {

    func testStandardErrorCodes() {
        XCTAssertEqual(JSONRPCError.parseError, -32700)
        XCTAssertEqual(JSONRPCError.invalidRequest, -32600)
        XCTAssertEqual(JSONRPCError.methodNotFound, -32601)
        XCTAssertEqual(JSONRPCError.invalidParams, -32602)
        XCTAssertEqual(JSONRPCError.internalError, -32603)
    }

    func testCodableRoundTrip() throws {
        let error = JSONRPCError(code: -32600, message: "Invalid Request", data: .string("extra"))

        let data = try JSONEncoder().encode(error)
        let decoded = try JSONDecoder().decode(JSONRPCError.self, from: data)

        XCTAssertEqual(decoded.code, -32600)
        XCTAssertEqual(decoded.message, "Invalid Request")
        XCTAssertEqual(decoded.data, .string("extra"))
    }
}

// MARK: - Control Protocol Error Tests

final class ControlProtocolErrorTests: XCTestCase {

    func testTimeoutEquatable() {
        let e1 = ControlProtocolError.timeout(requestId: "req_1")
        let e2 = ControlProtocolError.timeout(requestId: "req_1")
        let e3 = ControlProtocolError.timeout(requestId: "req_2")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }

    func testCancelledEquatable() {
        let e1 = ControlProtocolError.cancelled(requestId: "req_1")
        let e2 = ControlProtocolError.cancelled(requestId: "req_1")

        XCTAssertEqual(e1, e2)
    }

    func testResponseErrorEquatable() {
        let e1 = ControlProtocolError.responseError(requestId: "req_1", message: "error")
        let e2 = ControlProtocolError.responseError(requestId: "req_1", message: "error")
        let e3 = ControlProtocolError.responseError(requestId: "req_1", message: "different")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }
}

// MARK: - Full Request/Response Tests

final class FullControlRequestTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let request = FullControlRequest(
            requestId: "req_test",
            request: .interrupt
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(FullControlRequest.self, from: data)

        XCTAssertEqual(decoded.type, "control_request")
        XCTAssertEqual(decoded.requestId, "req_test")
        XCTAssertEqual(decoded.request, .interrupt)
    }
}

final class FullControlResponseTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let response = FullControlResponse(
            response: .success(requestId: "req_test", response: .bool(true))
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(FullControlResponse.self, from: data)

        XCTAssertEqual(decoded.type, "control_response")
        if case .success(let reqId, _) = decoded.response {
            XCTAssertEqual(reqId, "req_test")
        } else {
            XCTFail("Expected success response")
        }
    }
}
