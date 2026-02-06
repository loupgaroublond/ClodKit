//
//  ControlProtocolHandler.swift
//  ClodKit
//
//  Actor managing bidirectional control protocol with request/response correlation.
//

import Foundation

/// Handler type for can_use_tool requests.
public typealias CanUseToolHandler = @Sendable (CanUseToolRequest) async throws -> PermissionResult

/// Handler type for hook_callback requests.
public typealias HookCallbackHandler = @Sendable (HookCallbackRequest) async throws -> HookOutput

/// Handler type for MCP messages.
public typealias MCPMessageHandler = @Sendable (String, JSONRPCMessage) async throws -> JSONRPCMessage

/// Actor managing bidirectional control protocol communication.
/// Handles request/response correlation, timeout management, and handler dispatch.
public actor ControlProtocolHandler {
    /// The transport for sending/receiving messages.
    private let transport: Transport

    /// Default timeout for requests.
    private let defaultTimeout: TimeInterval

    /// Request counter for ID generation.
    private var requestCounter: Int = 0

    /// Pending requests waiting for responses.
    private var pendingRequests: [String: CheckedContinuation<FullControlResponsePayload, Error>] = [:]

    /// Handler for can_use_tool requests.
    private var canUseToolHandler: CanUseToolHandler?

    /// Handler for hook_callback requests.
    private var hookCallbackHandler: HookCallbackHandler?

    /// Handler for MCP messages.
    private var mcpMessageHandler: MCPMessageHandler?

    /// JSON encoder for sending messages.
    private let encoder: JSONEncoder

    /// Creates a new control protocol handler.
    /// - Parameters:
    ///   - transport: The transport for communication.
    ///   - defaultTimeout: Default timeout for requests (default 60 seconds).
    public init(transport: Transport, defaultTimeout: TimeInterval = 60.0) {
        self.transport = transport
        self.defaultTimeout = defaultTimeout

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        self.encoder = encoder
    }

    // MARK: - Handler Registration

    /// Register handler for can_use_tool requests.
    public func setCanUseToolHandler(_ handler: @escaping CanUseToolHandler) {
        canUseToolHandler = handler
    }

    /// Register handler for hook_callback requests.
    public func setHookCallbackHandler(_ handler: @escaping HookCallbackHandler) {
        hookCallbackHandler = handler
    }

    /// Register handler for MCP messages.
    public func setMCPMessageHandler(_ handler: @escaping MCPMessageHandler) {
        mcpMessageHandler = handler
    }

    // MARK: - Request ID Generation

    /// Generate a unique request ID.
    public func generateRequestId() -> String {
        requestCounter += 1
        let hex = String(format: "%08x", UInt32.random(in: 0...UInt32.max))
        return "req_\(requestCounter)_\(hex)"
    }

    // MARK: - Sending Requests

    /// Send a control request and wait for response.
    /// - Parameters:
    ///   - payload: The request payload to send.
    ///   - timeout: Timeout for the request (uses default if nil).
    /// - Returns: The response payload.
    public func sendRequest(_ payload: ControlRequestPayload, timeout: TimeInterval? = nil) async throws -> FullControlResponsePayload {
        let requestId = generateRequestId()
        let request = FullControlRequest(requestId: requestId, request: payload)

        // Wait for response with timeout
        let effectiveTimeout = timeout ?? defaultTimeout

        return try await withThrowingTaskGroup(of: FullControlResponsePayload.self) { group in
            // Response task - MUST register continuation BEFORE sending request
            // to avoid race where response arrives before we're listening
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    Task {
                        // Step 1: Register continuation FIRST
                        await self.registerPendingRequest(requestId: requestId, continuation: continuation)

                        // Step 2: THEN encode and send request
                        do {
                            let data = try self.encoder.encode(request)
                            try await self.transport.write(data)
                        } catch {
                            // If sending fails, clean up and resume with error
                            await self.removePendingRequest(requestId: requestId)
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }

            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
                throw ControlProtocolError.timeout(requestId: requestId)
            }

            // Wait for first completion
            do {
                let result = try await group.next()!
                group.cancelAll()

                // Clean up pending request
                await self.removePendingRequest(requestId: requestId)

                return result
            } catch {
                group.cancelAll()

                // Clean up and cancel pending
                await self.cancelPendingRequest(requestId: requestId, error: error)
                throw error
            }
        }
    }

    // MARK: - Response Handling

    /// Handle a control response from CLI.
    public func handleControlResponse(_ response: ControlResponse) {
        // Convert to full response payload
        let payload: FullControlResponsePayload
        switch response.response.subtype {
        case "success":
            payload = .success(requestId: response.response.requestId, response: response.response.response)
        case "error":
            payload = .error(
                requestId: response.response.requestId,
                error: response.response.error ?? "Unknown error",
                pendingPermissionRequests: nil
            )
        default:
            // Unknown subtype - ignore
            return
        }

        // Resume pending request
        if let continuation = pendingRequests.removeValue(forKey: payload.requestId) {
            continuation.resume(returning: payload)
        }
    }

    /// Handle a full control response.
    public func handleFullControlResponse(_ payload: FullControlResponsePayload) {
        if let continuation = pendingRequests.removeValue(forKey: payload.requestId) {
            continuation.resume(returning: payload)
        }
    }

    // MARK: - Request Handling

    /// Handle an incoming control request from CLI.
    public func handleControlRequest(_ request: ControlRequest) async {
        // Parse the request payload from JSONValue
        guard let payload = parseControlRequestPayload(from: request.request) else {
            // Send error response for unparseable request
            await sendErrorResponse(requestId: request.requestId, error: "Failed to parse request payload")
            return
        }

        await handleControlRequestPayload(requestId: request.requestId, payload: payload)
    }

    /// Handle a full control request with typed payload.
    public func handleFullControlRequest(_ request: FullControlRequest) async {
        await handleControlRequestPayload(requestId: request.requestId, payload: request.request)
    }

    private func handleControlRequestPayload(requestId: String, payload: ControlRequestPayload) async {
        do {
            let responseValue: JSONValue

            switch payload {
            case .canUseTool(let req):
                guard let handler = canUseToolHandler else {
                    throw ControlProtocolError.invalidMessage("No can_use_tool handler registered")
                }
                let result = try await handler(req)
                responseValue = try JSONValue.from(result.toDictionary())

            case .hookCallback(let req):
                guard let handler = hookCallbackHandler else {
                    throw ControlProtocolError.invalidMessage("No hook_callback handler registered")
                }
                let result = try await handler(req)
                responseValue = try JSONValue.from(result.toDictionary())

            case .mcpMessage(let req):
                guard let handler = mcpMessageHandler else {
                    throw ControlProtocolError.invalidMessage("No mcp_message handler registered")
                }
                let result = try await handler(req.serverName, req.message)
                // CLI expects the JSONRPC response wrapped in "mcp_response"
                let resultData = try encoder.encode(result)
                let jsonrpcValue = try JSONDecoder().decode(JSONValue.self, from: resultData)
                responseValue = .object(["mcp_response": jsonrpcValue])

            default:
                throw ControlProtocolError.invalidMessage("Unexpected request type: \(payload.subtype)")
            }

            await sendSuccessResponse(requestId: requestId, response: responseValue)

        } catch {
            await sendErrorResponse(requestId: requestId, error: error.localizedDescription)
        }
    }

    // MARK: - Cancel Handling

    /// Handle a cancel request from CLI.
    public func handleCancelRequest(_ cancel: ControlCancelRequest) {
        if let continuation = pendingRequests.removeValue(forKey: cancel.requestId) {
            continuation.resume(throwing: ControlProtocolError.cancelled(requestId: cancel.requestId))
        }
    }

    // MARK: - Convenience Methods

    /// Send an initialize request.
    public func initialize(
        hooks: [String: [HookMatcherConfig]]? = nil,
        sdkMcpServers: [String]? = nil,
        systemPrompt: String? = nil,
        appendSystemPrompt: String? = nil
    ) async throws -> FullControlResponsePayload {
        let req = InitializeRequest(
            hooks: hooks,
            sdkMcpServers: sdkMcpServers,
            systemPrompt: systemPrompt,
            appendSystemPrompt: appendSystemPrompt
        )
        return try await sendRequest(.initialize(req))
    }

    /// Send an interrupt request.
    public func interrupt() async throws -> FullControlResponsePayload {
        try await sendRequest(.interrupt)
    }

    /// Set the model.
    public func setModel(_ model: String?) async throws -> FullControlResponsePayload {
        try await sendRequest(.setModel(SetModelRequest(model: model)))
    }

    /// Set the permission mode.
    public func setPermissionMode(_ mode: PermissionMode) async throws -> FullControlResponsePayload {
        try await sendRequest(.setPermissionMode(SetPermissionModeRequest(mode: mode)))
    }

    /// Set max thinking tokens.
    public func setMaxThinkingTokens(_ tokens: Int?) async throws -> FullControlResponsePayload {
        try await sendRequest(.setMaxThinkingTokens(SetMaxThinkingTokensRequest(maxThinkingTokens: tokens)))
    }

    /// Rewind files to a previous state.
    public func rewindFiles(userMessageId: String, dryRun: Bool? = nil) async throws -> FullControlResponsePayload {
        try await sendRequest(.rewindFiles(RewindFilesRequest(userMessageId: userMessageId, dryRun: dryRun)))
    }

    /// Get MCP status.
    public func mcpStatus() async throws -> FullControlResponsePayload {
        try await sendRequest(.mcpStatus)
    }

    /// Reconnect an MCP server.
    public func mcpReconnect(serverName: String) async throws -> FullControlResponsePayload {
        try await sendRequest(.mcpReconnect(MCPReconnectRequest(serverName: serverName)))
    }

    /// Toggle an MCP server.
    public func mcpToggle(serverName: String, enabled: Bool) async throws -> FullControlResponsePayload {
        try await sendRequest(.mcpToggle(MCPToggleRequest(serverName: serverName, enabled: enabled)))
    }

    // MARK: - Private Helpers

    private func registerPendingRequest(requestId: String, continuation: CheckedContinuation<FullControlResponsePayload, Error>) {
        pendingRequests[requestId] = continuation
    }

    private func removePendingRequest(requestId: String) {
        pendingRequests.removeValue(forKey: requestId)
    }

    private func cancelPendingRequest(requestId: String, error: Error) {
        if let continuation = pendingRequests.removeValue(forKey: requestId) {
            continuation.resume(throwing: error)
        }
    }

    private func sendSuccessResponse(requestId: String, response: JSONValue?) async {
        let responsePayload = FullControlResponsePayload.success(requestId: requestId, response: response)
        let fullResponse = FullControlResponse(response: responsePayload)

        do {
            let data = try encoder.encode(fullResponse)
            try await transport.write(data)
        } catch {
            // Log error but don't throw - response sending failures are non-fatal
        }
    }

    private func sendErrorResponse(requestId: String, error: String) async {
        let responsePayload = FullControlResponsePayload.error(
            requestId: requestId,
            error: error,
            pendingPermissionRequests: nil
        )
        let fullResponse = FullControlResponse(response: responsePayload)

        do {
            let data = try encoder.encode(fullResponse)
            try await transport.write(data)
        } catch {
            // Log error but don't throw - response sending failures are non-fatal
        }
    }

    private func parseControlRequestPayload(from value: JSONValue) -> ControlRequestPayload? {
        do {
            let data = try encoder.encode(value)
            return try JSONDecoder().decode(ControlRequestPayload.self, from: data)
        } catch {
            return nil
        }
    }
}
