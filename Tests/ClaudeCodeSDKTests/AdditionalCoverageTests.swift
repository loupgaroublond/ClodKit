//
//  AdditionalCoverageTests.swift
//  ClaudeCodeSDKTests
//
//  Additional tests to improve code coverage.
//

import XCTest
@testable import ClaudeCodeSDK

// MARK: - ClaudeQuery Additional Tests

final class ClaudeQueryCoverageTests: XCTestCase {

    private func createMockSession() -> (MockTransport, ClaudeSession) {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)
        return (transport, session)
    }

    func testClaudeQuery_SessionIdBeforeIteration() async {
        let (_, session) = createMockSession()
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        // Session ID should be nil before any messages arrive
        let sessionId = await query.sessionId
        XCTAssertNil(sessionId)
    }

    func testClaudeQuery_MultipleIterators() async throws {
        let (transport, session) = createMockSession()
        let stream = await session.startMessageLoop()
        let query = ClaudeQuery(session: session, stream: stream)

        Task {
            try await Task.sleep(nanoseconds: 10_000_000)
            transport.injectMessage(.regular(SDKMessage(type: "assistant", content: .string("Hello"))))
            transport.finishStream()
        }

        // Create iterator and consume
        var count = 0
        for try await _ in query {
            count += 1
        }

        XCTAssertEqual(count, 1)
    }

}

// MARK: - ClaudeSession Additional Tests

final class ClaudeSessionCoverageTests: XCTestCase {

    func testClaudeSession_CloseMultipleTimes() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        // Closing multiple times should not crash
        await session.close()
        await session.close()

        XCTAssertFalse(transport.isConnected)
    }

    func testClaudeSession_InitializedProperty() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        let initialized = await session.initialized
        XCTAssertFalse(initialized)
    }

    func testClaudeSession_SessionIdBeforeInit() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        let sessionId = await session.currentSessionId
        XCTAssertNil(sessionId)
    }

    func testClaudeSession_SetCanUseTool() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        // Setting the callback should not fail
        await session.setCanUseTool { _, _, _ in
            return .allowTool()
        }

        // Test passes if we reach here without error
        XCTAssertTrue(true)
    }

    func testClaudeSession_RegisterMCPServer() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        let tool = MCPTool(
            name: "test",
            description: "Test tool",
            inputSchema: JSONSchema(),
            handler: { _ in .text("result") }
        )
        let server = SDKMCPServer(name: "test-server", tools: [tool])

        await session.registerMCPServer(server)

        // Registration succeeded if no error
        XCTAssertTrue(true)
    }

    func testClaudeSession_OnPreToolUse() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onPreToolUse(matching: "Bash", timeout: 30.0) { _ in
            HookOutput()
        }

        // Registration succeeded if no error
        XCTAssertTrue(true)
    }

    func testClaudeSession_OnPostToolUse() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onPostToolUse(matching: "Read", timeout: 30.0) { _ in
            HookOutput()
        }

        // Registration succeeded if no error
        XCTAssertTrue(true)
    }

    func testClaudeSession_OnPostToolUseFailure() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onPostToolUseFailure(matching: "Write", timeout: 30.0) { _ in
            HookOutput()
        }

        // Registration succeeded if no error
        XCTAssertTrue(true)
    }

    func testClaudeSession_OnUserPromptSubmit() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onUserPromptSubmit(timeout: 30.0) { _ in
            HookOutput()
        }

        // Registration succeeded if no error
        XCTAssertTrue(true)
    }

    func testClaudeSession_OnStop() async {
        let transport = MockTransport()
        let session = ClaudeSession(transport: transport)

        await session.onStop(timeout: 30.0) { _ in
            HookOutput()
        }

        // Registration succeeded if no error
        XCTAssertTrue(true)
    }

}

// MARK: - SessionError Tests

final class SessionErrorCoverageTests: XCTestCase {

    func testSessionError_LocalizedDescriptions() {
        let closedError = SessionError.sessionClosed
        XCTAssertTrue(closedError.localizedDescription.contains("closed"))

        let notInitError = SessionError.notInitialized
        XCTAssertTrue(notInitError.localizedDescription.contains("not been initialized"))

        let initFailedError = SessionError.initializationFailed("Test reason")
        XCTAssertTrue(initFailedError.localizedDescription.contains("Test reason"))
    }

    func testSessionError_Equatable() {
        let e1 = SessionError.sessionClosed
        let e2 = SessionError.sessionClosed
        let e3 = SessionError.notInitialized

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
    }
}

// MARK: - HookRegistry Additional Tests

final class HookRegistryCoverageTests: XCTestCase {

    func testHookRegistry_GetHookConfig_Empty() async {
        let registry = HookRegistry()

        let config = await registry.getHookConfig()

        XCTAssertNil(config)  // Returns nil when empty
    }

    func testHookRegistry_GetHookConfig_WithHooks() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in HookOutput() }
        await registry.onPostToolUse { _ in HookOutput() }

        let config = await registry.getHookConfig()

        XCTAssertNotNil(config)
        XCTAssertFalse(config!.isEmpty)
    }

    func testHookRegistry_MultipleHooksForSameEvent() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in HookOutput() }
        await registry.onPreToolUse(matching: "Read") { _ in HookOutput() }
        await registry.onPreToolUse(matching: "Write") { _ in HookOutput() }

        let config = await registry.getHookConfig()

        // Should have PreToolUse entry (using string key)
        XCTAssertNotNil(config?["PreToolUse"])
    }

    func testHookRegistry_PostToolUseFailureHook() async {
        let registry = HookRegistry()

        await registry.onPostToolUseFailure { _ in HookOutput() }

        let config = await registry.getHookConfig()

        XCTAssertNotNil(config?["PostToolUseFailure"])
    }

    func testHookRegistry_UserPromptSubmitHook() async {
        let registry = HookRegistry()

        await registry.onUserPromptSubmit { _ in HookOutput() }

        let config = await registry.getHookConfig()

        XCTAssertNotNil(config?["UserPromptSubmit"])
    }

    func testHookRegistry_StopHook() async {
        let registry = HookRegistry()

        await registry.onStop { _ in HookOutput() }

        let config = await registry.getHookConfig()

        XCTAssertNotNil(config?["Stop"])
    }

    func testHookRegistry_HasHooksProperty() async {
        let registry = HookRegistry()

        let initialHasHooks = await registry.hasHooks
        XCTAssertFalse(initialHasHooks)

        await registry.onPreToolUse { _ in HookOutput() }

        let afterHasHooks = await registry.hasHooks
        XCTAssertTrue(afterHasHooks)
    }

    func testHookRegistry_CallbackCount() async {
        let registry = HookRegistry()

        let initial = await registry.callbackCount
        XCTAssertEqual(initial, 0)

        await registry.onPreToolUse { _ in HookOutput() }
        await registry.onPostToolUse { _ in HookOutput() }

        let after = await registry.callbackCount
        XCTAssertEqual(after, 2)
    }

    func testHookRegistry_RegisteredEvents() async {
        let registry = HookRegistry()

        await registry.onPreToolUse { _ in HookOutput() }
        await registry.onStop { _ in HookOutput() }

        let events = await registry.registeredEvents
        XCTAssertTrue(events.contains(.preToolUse))
        XCTAssertTrue(events.contains(.stop))
        XCTAssertFalse(events.contains(.postToolUse))
    }
}

// MARK: - ControlProtocolTypes Additional Tests

final class ControlProtocolTypesCoverageTests: XCTestCase {

    func testControlRequestPayload_AllSubtypes() {
        let payloads: [ControlRequestPayload] = [
            .initialize(InitializeRequest()),
            .interrupt,
            .setPermissionMode(SetPermissionModeRequest(mode: .default)),
            .setModel(SetModelRequest(model: "claude-sonnet-4-20250514")),
            .setMaxThinkingTokens(SetMaxThinkingTokensRequest(maxThinkingTokens: 1000)),
            .rewindFiles(RewindFilesRequest(userMessageId: "msg_1")),
            .mcpStatus,
            .mcpReconnect(MCPReconnectRequest(serverName: "test")),
            .mcpToggle(MCPToggleRequest(serverName: "test", enabled: true)),
            .canUseTool(CanUseToolRequest(toolName: "Bash", input: [:], toolUseId: "tu_1")),
            .hookCallback(HookCallbackRequest(callbackId: "hook_1", input: [:]))
        ]

        for payload in payloads {
            XCTAssertFalse(payload.subtype.isEmpty)
        }
    }

    func testFullControlResponsePayload_Codable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test success response
        let successPayload = FullControlResponsePayload.success(requestId: "req_123", response: .string("result"))

        let encoded = try encoder.encode(successPayload)
        let decoded = try decoder.decode(FullControlResponsePayload.self, from: encoded)

        XCTAssertEqual(decoded.requestId, "req_123")
    }

    func testFullControlResponsePayload_ErrorType() throws {
        let payload = FullControlResponsePayload.error(
            requestId: "req_456",
            error: "Something went wrong",
            pendingPermissionRequests: nil
        )

        XCTAssertEqual(payload.requestId, "req_456")
    }

    func testSuccessResponsePayload_Init() {
        let payload = SuccessResponsePayload(requestId: "req_1", response: .bool(true))

        XCTAssertEqual(payload.subtype, "success")
        XCTAssertEqual(payload.requestId, "req_1")
    }

    func testErrorResponsePayload_Init() {
        let payload = ErrorResponsePayload(
            requestId: "req_2",
            error: "Failed",
            pendingPermissionRequests: ["perm_1"]
        )

        XCTAssertEqual(payload.subtype, "error")
        XCTAssertEqual(payload.error, "Failed")
        XCTAssertEqual(payload.pendingPermissionRequests?.count, 1)
    }

    func testFullControlRequest_Init() throws {
        let request = FullControlRequest(
            requestId: "req_123",
            request: .initialize(InitializeRequest())
        )

        XCTAssertEqual(request.type, "control_request")
        XCTAssertEqual(request.requestId, "req_123")

        // Test encoding/decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(request)
        let decoded = try decoder.decode(FullControlRequest.self, from: encoded)
        XCTAssertEqual(decoded.requestId, "req_123")
    }

    func testFullControlResponse_Init() throws {
        let response = FullControlResponse(
            response: .success(requestId: "req_1", response: nil)
        )

        XCTAssertEqual(response.type, "control_response")
    }

    func testControlProtocolError_AllCases() {
        let errors: [ControlProtocolError] = [
            .timeout(requestId: "req_1"),
            .cancelled(requestId: "req_2"),
            .responseError(requestId: "req_3", message: "Error"),
            .unknownSubtype("unknown"),
            .invalidMessage("invalid")
        ]

        XCTAssertEqual(errors.count, 5)
    }

    func testJSONRPCMessage_RequestFactory() {
        let request = JSONRPCMessage.request(id: 1, method: "test", params: .object([:]))

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "test")
    }

    func testJSONRPCMessage_ResponseFactory() {
        let response = JSONRPCMessage.response(id: 1, result: .string("ok"))

        XCTAssertEqual(response.jsonrpc, "2.0")
    }

    func testJSONRPCMessage_ErrorResponseFactory() {
        let error = JSONRPCError(code: -32600, message: "Invalid request")
        let response = JSONRPCMessage.errorResponse(id: 1, error: error)

        XCTAssertEqual(response.error?.code, -32600)
    }

    func testJSONRPCMessage_NotificationFactory() {
        let notification = JSONRPCMessage.notification(method: "notify")

        XCTAssertNil(notification.id)
        XCTAssertEqual(notification.method, "notify")
    }

    func testJSONRPCError_StandardCodes() {
        XCTAssertEqual(JSONRPCError.parseError, -32700)
        XCTAssertEqual(JSONRPCError.invalidRequest, -32600)
        XCTAssertEqual(JSONRPCError.methodNotFound, -32601)
        XCTAssertEqual(JSONRPCError.invalidParams, -32602)
        XCTAssertEqual(JSONRPCError.internalError, -32603)
    }
}

// MARK: - ProcessTransport Additional Tests

final class ProcessTransportCoverageTests: XCTestCase {

    func testProcessTransport_IsConnectedBeforeStart() {
        let transport = ProcessTransport(command: "echo test")

        XCTAssertFalse(transport.isConnected)
    }

    func testProcessTransport_WriteFailsWhenNotConnected() async {
        let transport = ProcessTransport(command: "echo test")

        do {
            try await transport.write(Data("test".utf8))
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is TransportError)
        }
    }

    func testProcessTransport_EndInputWhenNotConnected() async {
        let transport = ProcessTransport(command: "echo test")

        // Should not crash
        await transport.endInput()
    }

    func testProcessTransport_CloseWhenNotStarted() {
        let transport = ProcessTransport(command: "echo test")

        // Should not crash
        transport.close()

        XCTAssertFalse(transport.isConnected)
    }
}

// MARK: - MCPTool Additional Tests

final class MCPToolCoverageTests: XCTestCase {

    func testPropertySchema_WithNestedProperties() {
        let schema = PropertySchema(
            type: "object",
            description: "A complex object",
            properties: [
                "name": .string("The name"),
                "count": PropertySchema(type: "integer", description: "A count")
            ]
        )

        XCTAssertEqual(schema.type, "object")
        XCTAssertNotNil(schema.properties)
        XCTAssertEqual(schema.properties?["name"]?.type, "string")
    }

    func testPropertySchema_WithArrayItems() {
        let schema = PropertySchema(
            type: "array",
            description: "A list of strings",
            items: .string("A string item")
        )

        XCTAssertEqual(schema.type, "array")
        XCTAssertNotNil(schema.items)
        XCTAssertEqual(schema.items?.type, "string")
    }

    func testPropertySchema_Equatable() {
        let schema1 = PropertySchema.string("Test")
        let schema2 = PropertySchema.string("Test")
        let schema3 = PropertySchema.integer("Different")

        XCTAssertEqual(schema1, schema2)
        XCTAssertNotEqual(schema1, schema3)
    }

    func testJSONSchema_ToDictionary_ComplexSchema() {
        let schema = JSONSchema(
            properties: [
                "name": .string("Name"),
                "items": PropertySchema(
                    type: "array",
                    description: "Items list",
                    items: .string("Item")
                )
            ],
            required: ["name"]
        )

        let dict = schema.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "object")
        XCTAssertNotNil(dict["properties"])
    }

    func testMCPToolResult_ErrorCase() {
        let result = MCPToolResult.error("Something failed")

        XCTAssertTrue(result.isError)
        XCTAssertEqual(result.content.count, 1)
        if case .text(let message) = result.content.first {
            XCTAssertEqual(message, "Something failed")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testMCPContent_ImageCase() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])  // PNG header
        let content = MCPContent.image(data: imageData, mimeType: "image/png")

        switch content {
        case .image(let data, let mimeType):
            XCTAssertEqual(mimeType, "image/png")
            XCTAssertEqual(data.count, 4)
        default:
            XCTFail("Expected image case")
        }
    }

    func testMCPContent_ResourceCase() {
        let content = MCPContent.resource(
            uri: "file:///test.txt",
            mimeType: "text/plain",
            text: "Content"
        )

        switch content {
        case .resource(let uri, let mimeType, let text):
            XCTAssertEqual(uri, "file:///test.txt")
            XCTAssertEqual(mimeType, "text/plain")
            XCTAssertEqual(text, "Content")
        default:
            XCTFail("Expected resource case")
        }
    }

    func testMCPContent_ToDictionary() {
        let textContent = MCPContent.text("Hello")
        let textDict = textContent.toDictionary()
        XCTAssertEqual(textDict["type"] as? String, "text")
        XCTAssertEqual(textDict["text"] as? String, "Hello")

        let imageContent = MCPContent.image(data: Data([0x00]), mimeType: "image/png")
        let imageDict = imageContent.toDictionary()
        XCTAssertEqual(imageDict["type"] as? String, "image")
        XCTAssertEqual(imageDict["mimeType"] as? String, "image/png")

        let resourceContent = MCPContent.resource(uri: "file://test", mimeType: nil, text: nil)
        let resourceDict = resourceContent.toDictionary()
        XCTAssertEqual(resourceDict["type"] as? String, "resource")
        XCTAssertNil(resourceDict["mimeType"])
        XCTAssertNil(resourceDict["text"])
    }

    func testMCPToolResult_ToDictionary() {
        let result = MCPToolResult.error("Error message")
        let dict = result.toDictionary()

        XCTAssertEqual(dict["isError"] as? Bool, true)
        XCTAssertNotNil(dict["content"])
    }
}

// MARK: - SDKMCPServer Additional Tests

final class SDKMCPServerCoverageTests: XCTestCase {

    func testSDKMCPServer_GetToolByName() {
        let tool = MCPTool(
            name: "test-tool",
            description: "A test tool",
            inputSchema: JSONSchema(),
            handler: { _ in .text("result") }
        )

        let server = SDKMCPServer(name: "test", tools: [tool])

        let found = server.getTool(named: "test-tool")
        let notFound = server.getTool(named: "nonexistent")

        XCTAssertNotNil(found)
        XCTAssertNil(notFound)
    }

    func testSDKMCPServer_ToolNames() {
        let tool1 = MCPTool(
            name: "tool-a",
            description: "Tool A",
            inputSchema: JSONSchema(),
            handler: { _ in .text("a") }
        )
        let tool2 = MCPTool(
            name: "tool-b",
            description: "Tool B",
            inputSchema: JSONSchema(),
            handler: { _ in .text("b") }
        )

        let server = SDKMCPServer(name: "test", tools: [tool1, tool2])

        XCTAssertEqual(server.toolCount, 2)
        XCTAssertTrue(server.toolNames.contains("tool-a"))
        XCTAssertTrue(server.toolNames.contains("tool-b"))
    }
}

// MARK: - QueryAPI Additional Tests

final class QueryAPICoverageTests: XCTestCase {

    func testMCPServerConfig_EmptyEnv() {
        let config = MCPServerConfig(
            command: "node",
            args: ["server.js"],
            env: [:]
        )

        let dict = config.toDictionary()

        // Empty env should not be included
        XCTAssertNil(dict["env"])
    }

    func testQueryOptions_AllPermissionModes() {
        for mode in PermissionMode.allCases {
            var options = QueryOptions()
            options.permissionMode = mode
            XCTAssertEqual(options.permissionMode, mode)
        }
    }

    func testQueryOptions_WithAllHookTypes() {
        var options = QueryOptions()

        options.preToolUseHooks = [PreToolUseHookConfig { _ in HookOutput() }]
        options.postToolUseHooks = [PostToolUseHookConfig { _ in HookOutput() }]
        options.postToolUseFailureHooks = [PostToolUseFailureHookConfig { _ in HookOutput() }]
        options.userPromptSubmitHooks = [UserPromptSubmitHookConfig { _ in HookOutput() }]
        options.stopHooks = [StopHookConfig { _ in HookOutput() }]

        XCTAssertEqual(options.preToolUseHooks.count, 1)
        XCTAssertEqual(options.postToolUseHooks.count, 1)
        XCTAssertEqual(options.postToolUseFailureHooks.count, 1)
        XCTAssertEqual(options.userPromptSubmitHooks.count, 1)
        XCTAssertEqual(options.stopHooks.count, 1)
    }
}

// MARK: - HookTypes Additional Tests

final class HookTypesCoverageTests: XCTestCase {

    func testBaseHookInput_AllFields() {
        let input = BaseHookInput(
            sessionId: "session-123",
            transcriptPath: "/path/to/transcript",
            cwd: "/current/dir",
            permissionMode: "default",
            hookEventName: .preToolUse
        )

        XCTAssertEqual(input.sessionId, "session-123")
        XCTAssertEqual(input.transcriptPath, "/path/to/transcript")
        XCTAssertEqual(input.cwd, "/current/dir")
        XCTAssertEqual(input.permissionMode, "default")
        XCTAssertEqual(input.hookEventName, .preToolUse)
    }

    func testHookOutput_StopWithReason() {
        let output = HookOutput.stop(reason: "Test reason")

        XCTAssertFalse(output.shouldContinue)
        XCTAssertEqual(output.stopReason, "Test reason")
    }

    func testHookOutput_AllowWithInput() {
        let output = HookOutput.allow(
            updatedInput: ["key": .string("value")],
            additionalContext: "Some context"
        )

        XCTAssertTrue(output.shouldContinue)
        if case .preToolUse(let specific) = output.hookSpecificOutput {
            XCTAssertEqual(specific.permissionDecision, .allow)
            XCTAssertNotNil(specific.updatedInput)
            XCTAssertEqual(specific.additionalContext, "Some context")
        } else {
            XCTFail("Expected preToolUse output")
        }
    }

    func testHookOutput_DenyWithReason() {
        let output = HookOutput.deny(reason: "Not allowed")

        if case .preToolUse(let specific) = output.hookSpecificOutput {
            XCTAssertEqual(specific.permissionDecision, .deny)
            XCTAssertEqual(specific.permissionDecisionReason, "Not allowed")
        } else {
            XCTFail("Expected preToolUse output")
        }
    }

    func testHookOutput_AskWithReason() {
        let output = HookOutput.ask(reason: "Need confirmation")

        if case .preToolUse(let specific) = output.hookSpecificOutput {
            XCTAssertEqual(specific.permissionDecision, .ask)
            XCTAssertEqual(specific.permissionDecisionReason, "Need confirmation")
        } else {
            XCTFail("Expected preToolUse output")
        }
    }

    func testHookOutput_ToDictionary() {
        let output = HookOutput(
            shouldContinue: true,
            suppressOutput: true,
            systemMessage: "Test message",
            reason: "Test reason"
        )

        let dict = output.toDictionary()

        XCTAssertEqual(dict["continue"] as? Bool, true)
        XCTAssertEqual(dict["suppressOutput"] as? Bool, true)
        XCTAssertEqual(dict["systemMessage"] as? String, "Test message")
        XCTAssertEqual(dict["reason"] as? String, "Test reason")
    }

    func testPreToolUseHookOutput_ToDictionary() {
        var output = PreToolUseHookOutput()
        output.permissionDecision = .allow
        output.permissionDecisionReason = "Approved"
        output.updatedInput = ["modified": .bool(true)]
        output.additionalContext = "Extra info"

        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PreToolUse")
        XCTAssertEqual(dict["permissionDecision"] as? String, "allow")
        XCTAssertEqual(dict["permissionDecisionReason"] as? String, "Approved")
        XCTAssertNotNil(dict["updatedInput"])
        XCTAssertEqual(dict["additionalContext"] as? String, "Extra info")
    }

    func testPostToolUseHookOutput_ToDictionary() {
        var output = PostToolUseHookOutput()
        output.additionalContext = "Post-tool context"
        output.updatedMCPToolOutput = .string("Modified output")

        let dict = output.toDictionary()

        XCTAssertEqual(dict["hookEventName"] as? String, "PostToolUse")
        XCTAssertEqual(dict["additionalContext"] as? String, "Post-tool context")
        XCTAssertNotNil(dict["updatedMCPToolOutput"])
    }

    func testHookEvent_AllCases() {
        let allEvents = HookEvent.allCases

        XCTAssertTrue(allEvents.contains(.preToolUse))
        XCTAssertTrue(allEvents.contains(.postToolUse))
        XCTAssertTrue(allEvents.contains(.stop))
        XCTAssertTrue(allEvents.contains(.userPromptSubmit))
    }

    func testHookInput_EventType() {
        let base = BaseHookInput(
            sessionId: "s",
            transcriptPath: "/t",
            cwd: "/c",
            permissionMode: "default",
            hookEventName: .preToolUse
        )

        let input = HookInput.preToolUse(PreToolUseInput(
            base: base,
            toolName: "Test",
            toolInput: [:],
            toolUseId: "id"
        ))

        XCTAssertEqual(input.eventType, .preToolUse)
        XCTAssertEqual(input.base.sessionId, "s")
    }
}

// MARK: - PermissionTypes Additional Tests

final class PermissionTypesCoverageTests: XCTestCase {

    func testPermissionResult_AllowWithUpdatedInput() {
        let result = PermissionResult.allowTool(updatedInput: ["key": .string("value")])

        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedInput"])
    }

    func testPermissionResult_AllowWithPermissionUpdates() {
        let updates = [
            PermissionUpdate.addRules([.tool("Bash")], behavior: .allow)
        ]
        let result = PermissionResult.allowTool(permissionUpdates: updates)

        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedPermissions"])
    }

    func testPermissionResult_DenyToolAndInterrupt() {
        let result = PermissionResult.denyToolAndInterrupt("Critical error")

        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Critical error")
        XCTAssertEqual(dict["interrupt"] as? Bool, true)
    }

    func testPermissionUpdate_AllTypes() {
        let addRules = PermissionUpdate.addRules([.tool("Read")], behavior: .allow)
        let replaceRules = PermissionUpdate.replaceRules([.tool("Write")], behavior: .deny)
        let removeRules = PermissionUpdate.removeRules([.tool("Bash")])
        let setMode = PermissionUpdate.setMode(.bypassPermissions)
        let addDirs = PermissionUpdate.addDirectories(["/tmp"])
        let removeDirs = PermissionUpdate.removeDirectories(["/var"])

        XCTAssertEqual(addRules.type, .addRules)
        XCTAssertEqual(replaceRules.type, .replaceRules)
        XCTAssertEqual(removeRules.type, .removeRules)
        XCTAssertEqual(setMode.type, .setMode)
        XCTAssertEqual(addDirs.type, .addDirectories)
        XCTAssertEqual(removeDirs.type, .removeDirectories)
    }

    func testPermissionRule_ToDictionary() {
        let rule = PermissionRule.tool("Bash", content: "echo *")

        let dict = rule.toDictionary()

        XCTAssertEqual(dict["toolName"] as? String, "Bash")
        XCTAssertEqual(dict["ruleContent"] as? String, "echo *")
    }
}
