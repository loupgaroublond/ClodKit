# Native Swift Claude Subprocess Implementation Plan

## Executive Summary

This plan details how to bring the Swift ClaudeCodeSDK to full feature parity with the TypeScript/Python SDKs through native subprocess management, eliminating the Node.js bridge dependency. The architecture centers on:

1. **Protocol-based Transport Layer** for testability and mock injection
2. **Actor-based Control Protocol Handler** for thread-safe request/response correlation
3. **In-process SDK MCP Server** implementation with JSONRPC routing
4. **AsyncSequence-based streaming** replacing Combine publishers
5. **Type-safe Hook system** with Swift closures

---

## Architecture Overview

### Module Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Public API Layer                               │
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────────────┐ │
│  │  ClaudeQuery    │  │  QueryOptions    │  │  SDKMCPServer           │ │
│  │  (AsyncSequence)│  │  (hooks, perms)  │  │  (tool definitions)     │ │
│  └────────┬────────┘  └────────┬─────────┘  └───────────┬─────────────┘ │
└───────────│────────────────────│────────────────────────│───────────────┘
            │                    │                        │
            ▼                    ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Session Layer                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                        ClaudeSession (actor)                         ││
│  │  - Owns transport, control handler, MCP router                      ││
│  │  - Manages message stream lifecycle                                 ││
│  │  - Coordinates hooks and permissions                                ││
│  └─────────────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────────────┘
            │                    │                        │
            ▼                    ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Core Components                                  │
│ ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────────┐  │
│ │ControlProtocol   │ │  HookRegistry    │ │  MCPServerRouter         │  │
│ │Handler (actor)   │ │  (actor)         │ │  (actor)                 │  │
│ │- request/response│ │- callback storage│ │- server instances        │  │
│ │- pending tracking│ │- ID generation   │ │- JSONRPC dispatch        │  │
│ │- timeout mgmt    │ │- invocation      │ │- response correlation    │  │
│ └────────┬─────────┘ └────────┬─────────┘ └───────────┬──────────────┘  │
└──────────│────────────────────│────────────────────────│────────────────┘
           │                    │                        │
           ▼                    ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Transport Layer                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                    Transport (protocol)                              ││
│  │  - write(data:) async throws                                        ││
│  │  - readMessages() -> AsyncThrowingStream<StdoutMessage>             ││
│  │  - endInput()                                                       ││
│  │  - close()                                                          ││
│  └─────────────────────────────────────────────────────────────────────┘│
│           ▲                                           ▲                  │
│           │                                           │                  │
│  ┌────────┴─────────┐                       ┌────────┴─────────┐        │
│  │ProcessTransport  │                       │MockTransport     │        │
│  │(real subprocess) │                       │(for testing)     │        │
│  └──────────────────┘                       └──────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
```

### Build Order (Dependency-Aware)

```
Phase 1: Foundation
├── 1.1 Transport Protocol + ProcessTransport    (no deps)
├── 1.2 Message Types (control protocol types)   (no deps)
└── 1.3 JSON Line Parser                         (no deps)

Phase 2: Core Infrastructure
├── 2.1 ControlProtocolHandler (actor)           (deps: 1.1, 1.2, 1.3)
└── 2.2 MockTransport                            (deps: 1.1)

Phase 3: MCP System (Highest Priority Feature)
├── 3.1 MCPTool + SDKMCPServer types            (no deps)
├── 3.2 MCPServerRouter (actor)                  (deps: 2.1, 3.1)
└── 3.3 JSONRPC routing (init, tools/list, tools/call)  (deps: 3.2)

Phase 4: Hook System
├── 4.1 Hook types (input/output structs)        (no deps)
├── 4.2 HookRegistry (actor)                     (deps: 4.1)
└── 4.3 Hook callback invocation                 (deps: 2.1, 4.2)

Phase 5: Permission System
├── 5.1 Permission types                         (deps: 4.1)
└── 5.2 canUseTool integration                   (deps: 2.1, 5.1)

Phase 6: Session & Query API
├── 6.1 ClaudeSession (actor)                    (deps: 2.1, 3.2, 4.2, 5.2)
├── 6.2 ClaudeQuery (AsyncSequence)              (deps: 6.1)
└── 6.3 Query control methods                    (deps: 6.2)

Phase 7: Migrate HeadlessBackend
├── 7.1 Replace Combine with AsyncSequence       (deps: 6.2)
└── 7.2 Integrate control protocol               (deps: 2.1, 6.1)
```

---

## Work Items

### Phase 1: Transport Layer (Foundation)

#### 1.1 Transport Protocol

**Complexity: S (Small)**

**Description:** Abstract interface for CLI communication enabling mock injection for testing.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Transport/Transport.swift

/// Protocol abstracting CLI communication for testability
public protocol Transport: Sendable {
    /// Write data to the CLI's stdin
    func write(_ data: Data) async throws

    /// Stream of messages from CLI stdout
    func readMessages() -> AsyncThrowingStream<StdoutMessage, Error>

    /// Signal end of input (close stdin)
    func endInput() async

    /// Close the transport and terminate the process
    func close()

    /// Whether the transport is still connected
    var isConnected: Bool { get }
}

/// Message types received from CLI stdout
public enum StdoutMessage: Sendable {
    case regular(SDKMessage)           // user, assistant, result, system
    case controlRequest(ControlRequest)
    case controlResponse(ControlResponse)
    case controlCancelRequest(ControlCancelRequest)
    case keepAlive
}
```

**Testing Approach:**
- Protocol itself doesn't need tests
- Enables MockTransport injection for all dependent components

---

#### 1.2 JSON Line Parser

**Complexity: S (Small)**

**Description:** Parse newline-delimited JSON from CLI stdout, handling incomplete buffers.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Transport/JSONLineParser.swift

/// Parses JSON lines from CLI output
public struct JSONLineParser: Sendable {
    private let decoder: JSONDecoder

    public init() {
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// Parse a complete JSON line from buffer
    /// - Returns: Parsed message and remaining buffer, or nil if incomplete
    public func parseLine(from buffer: Data) -> (StdoutMessage, Data)? {
        guard let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) else {
            return nil
        }

        let lineData = buffer[buffer.startIndex..<newlineIndex]
        let remaining = buffer[buffer.index(after: newlineIndex)...]

        guard !lineData.isEmpty else {
            return parseLine(from: Data(remaining))
        }

        do {
            let message = try parseMessage(from: Data(lineData))
            return (message, Data(remaining))
        } catch {
            // Log but continue - malformed lines shouldn't crash
            return parseLine(from: Data(remaining))
        }
    }

    private func parseMessage(from data: Data) throws -> StdoutMessage {
        // Peek at type field to determine message kind
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            throw JSONLineParserError.missingType
        }

        switch type {
        case "control_request":
            return .controlRequest(try decoder.decode(ControlRequest.self, from: data))
        case "control_response":
            return .controlResponse(try decoder.decode(ControlResponse.self, from: data))
        case "control_cancel_request":
            return .controlCancelRequest(try decoder.decode(ControlCancelRequest.self, from: data))
        case "keep_alive":
            return .keepAlive
        default:
            return .regular(try decoder.decode(SDKMessage.self, from: data))
        }
    }
}

public enum JSONLineParserError: Error {
    case missingType
    case unknownType(String)
}
```

**Testing Approach:**
- Unit tests for each message type parsing
- Tests for incomplete buffers (no newline yet)
- Tests for malformed JSON (should skip, not crash)
- Tests for empty lines
- Tests for multiple messages in one buffer

**Unit Tests Needed:**
```swift
func testParseUserMessage()
func testParseAssistantMessage()
func testParseResultMessage()
func testParseSystemMessage()
func testParseControlRequest()
func testParseControlResponse()
func testParseKeepAlive()
func testIncompleteBuffer_ReturnsNil()
func testMalformedJSON_SkipsLine()
func testEmptyLine_SkipsToNext()
func testMultipleMessages_ParsesAll()
```

---

#### 1.3 ProcessTransport

**Complexity: M (Medium)**

**Description:** Real subprocess transport using Foundation.Process with stdin/stdout pipes.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Transport/ProcessTransport.swift

/// Real subprocess transport using Foundation.Process
public actor ProcessTransport: Transport {
    private let process: Process
    private let stdinPipe: Pipe
    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe
    private let jsonLineParser: JSONLineParser
    private let logger: Logger?

    private var _isConnected = false
    public nonisolated var isConnected: Bool { process.isRunning }

    /// Initialize with CLI arguments
    public init(
        cliPath: String = "claude",
        arguments: [String],
        environment: [String: String] = [:],
        workingDirectory: URL? = nil,
        logger: Logger? = nil
    ) {
        self.logger = logger
        self.jsonLineParser = JSONLineParser()

        self.process = Process()
        self.stdinPipe = Pipe()
        self.stdoutPipe = Pipe()
        self.stderrPipe = Pipe()

        // Configure process
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let fullCommand = ([cliPath] + arguments).joined(separator: " ")
        process.arguments = ["-l", "-c", fullCommand]

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        env["CLAUDE_CODE_ENTRYPOINT"] = "sdk-swift"
        process.environment = env

        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
    }

    /// Start the subprocess
    public func start() throws {
        try process.run()
        _isConnected = true
    }

    public func write(_ data: Data) async throws {
        guard _isConnected else { throw TransportError.notConnected }
        try stdinPipe.fileHandleForWriting.write(contentsOf: data)
        try stdinPipe.fileHandleForWriting.write(contentsOf: Data("\n".utf8))
    }

    public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
        AsyncThrowingStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            Task { await self.readLoop(continuation: continuation) }
        }
    }

    private func readLoop(
        continuation: AsyncThrowingStream<StdoutMessage, Error>.Continuation
    ) async {
        let fileHandle = stdoutPipe.fileHandleForReading
        var buffer = Data()

        while _isConnected {
            let data = fileHandle.availableData
            if data.isEmpty { break }  // EOF

            buffer.append(data)

            while let (message, remaining) = jsonLineParser.parseLine(from: buffer) {
                buffer = remaining
                continuation.yield(message)
            }
        }

        continuation.finish()
    }

    public func endInput() async {
        try? stdinPipe.fileHandleForWriting.close()
    }

    public func close() {
        _isConnected = false
        if process.isRunning {
            process.terminate()

            // Graceful shutdown: wait then SIGKILL
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5s
                if process.isRunning {
                    process.interrupt()  // SIGKILL
                }
            }
        }
    }
}

public enum TransportError: Error, Sendable {
    case notConnected
    case writeFailed(underlying: Error)
    case processTerminated(exitCode: Int32, stderr: String)
}
```

**Testing Approach:**
- Integration tests with real CLI (Live tests)
- Most testing via MockTransport in dependent components

**Mock Strategy:**
```swift
// File: Sources/ClaudeCodeSDK/Transport/MockTransport.swift

/// Mock transport for unit testing
public actor MockTransport: Transport {
    private var writtenData: [Data] = []
    private var continuation: AsyncThrowingStream<StdoutMessage, Error>.Continuation?
    private var _isConnected = true

    public var isConnected: Bool { _isConnected }

    /// Inject messages that readMessages() will return
    public func injectMessage(_ message: StdoutMessage) {
        continuation?.yield(message)
    }

    /// Inject an error
    public func injectError(_ error: Error) {
        continuation?.finish(throwing: error)
    }

    /// Get all data written to the transport
    public func getWrittenData() -> [Data] { writtenData }

    /// Clear written data
    public func clearWrittenData() { writtenData.removeAll() }

    public func write(_ data: Data) async throws {
        writtenData.append(data)
    }

    public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    public func endInput() async {}

    public func close() {
        _isConnected = false
        continuation?.finish()
    }
}
```

---

### Phase 2: Control Protocol Handler

#### 2.1 Control Protocol Types

**Complexity: S (Small)**

**Description:** Codable types for bidirectional control protocol messages.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/ControlProtocol/ControlProtocolTypes.swift

/// Control request sent between SDK and CLI
public struct ControlRequest: Codable, Sendable {
    public let type: String  // "control_request"
    public let requestId: String
    public let request: ControlRequestPayload

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case request
    }
}

/// Discriminated union for control request payloads
public enum ControlRequestPayload: Codable, Sendable {
    // SDK -> CLI requests
    case initialize(InitializeRequest)
    case interrupt
    case setPermissionMode(SetPermissionModeRequest)
    case setModel(SetModelRequest)
    case setMaxThinkingTokens(SetMaxThinkingTokensRequest)
    case rewindFiles(RewindFilesRequest)
    case mcpStatus
    case mcpReconnect(MCPReconnectRequest)
    case mcpToggle(MCPToggleRequest)
    case setMcpServers(SetMcpServersRequest)
    case mcpMessage(MCPMessageRequest)

    // CLI -> SDK requests
    case canUseTool(CanUseToolRequest)
    case hookCallback(HookCallbackRequest)

    // Custom Codable implementation for discriminated union
    private enum CodingKeys: String, CodingKey {
        case subtype
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let subtype = try container.decode(String.self, forKey: .subtype)

        switch subtype {
        case "initialize": self = .initialize(try InitializeRequest(from: decoder))
        case "interrupt": self = .interrupt
        case "set_permission_mode": self = .setPermissionMode(try SetPermissionModeRequest(from: decoder))
        case "set_model": self = .setModel(try SetModelRequest(from: decoder))
        case "set_max_thinking_tokens": self = .setMaxThinkingTokens(try SetMaxThinkingTokensRequest(from: decoder))
        case "rewind_files": self = .rewindFiles(try RewindFilesRequest(from: decoder))
        case "mcp_status": self = .mcpStatus
        case "mcp_reconnect": self = .mcpReconnect(try MCPReconnectRequest(from: decoder))
        case "mcp_toggle": self = .mcpToggle(try MCPToggleRequest(from: decoder))
        case "mcp_set_servers": self = .setMcpServers(try SetMcpServersRequest(from: decoder))
        case "mcp_message": self = .mcpMessage(try MCPMessageRequest(from: decoder))
        case "can_use_tool": self = .canUseTool(try CanUseToolRequest(from: decoder))
        case "hook_callback": self = .hookCallback(try HookCallbackRequest(from: decoder))
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Unknown subtype: \(subtype)")
            )
        }
    }
}

// SDK -> CLI request types
public struct InitializeRequest: Codable, Sendable {
    public let subtype: String = "initialize"
    public let hooks: [String: [HookMatcherConfig]]?
    public let sdkMcpServers: [String]?
    public let systemPrompt: String?
    public let appendSystemPrompt: String?
}

public struct SetPermissionModeRequest: Codable, Sendable {
    public let subtype: String = "set_permission_mode"
    public let mode: PermissionMode
}

public struct SetModelRequest: Codable, Sendable {
    public let subtype: String = "set_model"
    public let model: String?
}

public struct SetMaxThinkingTokensRequest: Codable, Sendable {
    public let subtype: String = "set_max_thinking_tokens"
    public let maxThinkingTokens: Int?

    enum CodingKeys: String, CodingKey {
        case subtype
        case maxThinkingTokens = "max_thinking_tokens"
    }
}

public struct RewindFilesRequest: Codable, Sendable {
    public let subtype: String = "rewind_files"
    public let userMessageId: String
    public let dryRun: Bool?

    enum CodingKeys: String, CodingKey {
        case subtype
        case userMessageId = "user_message_id"
        case dryRun = "dry_run"
    }
}

public struct MCPReconnectRequest: Codable, Sendable {
    public let subtype: String = "mcp_reconnect"
    public let serverName: String

    enum CodingKeys: String, CodingKey {
        case subtype
        case serverName = "server_name"
    }
}

public struct MCPToggleRequest: Codable, Sendable {
    public let subtype: String = "mcp_toggle"
    public let serverName: String
    public let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case subtype
        case serverName = "server_name"
        case enabled
    }
}

public struct SetMcpServersRequest: Codable, Sendable {
    public let subtype: String = "mcp_set_servers"
    public let servers: [String: AnyCodable]
}

public struct MCPMessageRequest: Codable, Sendable {
    public let subtype: String = "mcp_message"
    public let serverName: String
    public let message: JSONRPCMessage

    enum CodingKeys: String, CodingKey {
        case subtype
        case serverName = "server_name"
        case message
    }
}

// CLI -> SDK request types
public struct CanUseToolRequest: Codable, Sendable {
    public let subtype: String = "can_use_tool"
    public let toolName: String
    public let input: [String: AnyCodable]
    public let permissionSuggestions: [PermissionUpdate]?
    public let blockedPath: String?
    public let decisionReason: String?
    public let toolUseId: String
    public let agentId: String?

    enum CodingKeys: String, CodingKey {
        case subtype
        case toolName = "tool_name"
        case input
        case permissionSuggestions = "permission_suggestions"
        case blockedPath = "blocked_path"
        case decisionReason = "decision_reason"
        case toolUseId = "tool_use_id"
        case agentId = "agent_id"
    }
}

public struct HookCallbackRequest: Codable, Sendable {
    public let subtype: String = "hook_callback"
    public let callbackId: String
    public let input: [String: AnyCodable]
    public let toolUseId: String?

    enum CodingKeys: String, CodingKey {
        case subtype
        case callbackId = "callback_id"
        case input
        case toolUseId = "tool_use_id"
    }
}

/// Control response from CLI
public struct ControlResponse: Codable, Sendable {
    public let type: String  // "control_response"
    public let response: ControlResponsePayload
}

public enum ControlResponsePayload: Codable, Sendable {
    case success(requestId: String, response: AnyCodable?)
    case error(requestId: String, error: String, pendingPermissionRequests: [String]?)

    enum CodingKeys: String, CodingKey {
        case subtype
        case requestId = "request_id"
        case response
        case error
        case pendingPermissionRequests = "pending_permission_requests"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let subtype = try container.decode(String.self, forKey: .subtype)
        let requestId = try container.decode(String.self, forKey: .requestId)

        switch subtype {
        case "success":
            let response = try container.decodeIfPresent(AnyCodable.self, forKey: .response)
            self = .success(requestId: requestId, response: response)
        case "error":
            let error = try container.decode(String.self, forKey: .error)
            let pending = try container.decodeIfPresent([String].self, forKey: .pendingPermissionRequests)
            self = .error(requestId: requestId, error: error, pendingPermissionRequests: pending)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Unknown subtype")
            )
        }
    }
}

public struct ControlCancelRequest: Codable, Sendable {
    public let type: String = "control_cancel_request"
    public let requestId: String

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
    }
}

/// JSONRPC message for MCP communication
public struct JSONRPCMessage: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int?
    public let method: String?
    public let params: [String: AnyCodable]?
    public let result: AnyCodable?
    public let error: JSONRPCError?

    public init(
        jsonrpc: String = "2.0",
        id: Int? = nil,
        method: String? = nil,
        params: [String: AnyCodable]? = nil,
        result: AnyCodable? = nil,
        error: JSONRPCError? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }
}

public struct JSONRPCError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: AnyCodable?
}
```

**Testing Approach:**
- Round-trip encoding/decoding tests for each type
- Tests for each discriminated union case
- Tests for malformed input handling

---

#### 2.2 ControlProtocolHandler

**Complexity: M (Medium)**

**Description:** Actor managing bidirectional control protocol with request/response correlation.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/ControlProtocol/ControlProtocolHandler.swift

/// Actor managing bidirectional control protocol communication
public actor ControlProtocolHandler {
    private let transport: Transport
    private let logger: Logger?

    // Request tracking
    private var requestCounter: Int = 0
    private var pendingRequests: [String: CheckedContinuation<ControlResponsePayload, Error>] = [:]
    private let defaultTimeout: TimeInterval = 60.0

    // Handlers for CLI-initiated requests
    private var canUseToolHandler: ((CanUseToolRequest) async throws -> PermissionResult)?
    private var hookCallbackHandler: ((HookCallbackRequest) async throws -> HookOutput)?
    private var mcpMessageHandler: ((MCPMessageRequest) async throws -> JSONRPCResponse)?

    public init(transport: Transport, logger: Logger? = nil) {
        self.transport = transport
        self.logger = logger
    }

    // MARK: - Handler Registration

    public func setCanUseToolHandler(
        _ handler: @escaping (CanUseToolRequest) async throws -> PermissionResult
    ) {
        canUseToolHandler = handler
    }

    public func setHookCallbackHandler(
        _ handler: @escaping (HookCallbackRequest) async throws -> HookOutput
    ) {
        hookCallbackHandler = handler
    }

    public func setMCPMessageHandler(
        _ handler: @escaping (MCPMessageRequest) async throws -> JSONRPCResponse
    ) {
        mcpMessageHandler = handler
    }

    // MARK: - Outgoing Requests (SDK -> CLI)

    /// Generate unique request ID: req_{counter}_{randomHex}
    private func generateRequestId() -> String {
        requestCounter += 1
        let randomHex = String(format: "%08x", UInt32.random(in: 0...UInt32.max))
        return "req_\(requestCounter)_\(randomHex)"
    }

    /// Send a control request and wait for response
    public func sendRequest<R: Decodable>(
        _ payload: ControlRequestPayload,
        timeout: TimeInterval? = nil
    ) async throws -> R {
        let requestId = generateRequestId()
        let request = ControlRequest(
            type: "control_request",
            requestId: requestId,
            request: payload
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        return try await withThrowingTaskGroup(of: R.self) { group in
            // Timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64((timeout ?? self.defaultTimeout) * 1_000_000_000))
                throw ControlProtocolError.timeout(requestId: requestId)
            }

            // Request task
            group.addTask {
                let response = try await withCheckedThrowingContinuation { continuation in
                    self.pendingRequests[requestId] = continuation
                }

                switch response {
                case .success(_, let responseData):
                    if let data = responseData {
                        let jsonData = try JSONEncoder().encode(data)
                        return try JSONDecoder().decode(R.self, from: jsonData)
                    } else if R.self == EmptyResponse.self {
                        return EmptyResponse() as! R
                    } else {
                        throw ControlProtocolError.unexpectedEmptyResponse
                    }

                case .error(_, let errorMessage, _):
                    throw ControlProtocolError.cliError(message: errorMessage)
                }
            }

            // Write request to transport
            try await transport.write(data)

            // Return first result (either timeout or response)
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Incoming Message Handling

    /// Handle incoming control response
    public func handleControlResponse(_ response: ControlResponse) {
        switch response.response {
        case .success(let requestId, _), .error(let requestId, _, _):
            if let continuation = pendingRequests.removeValue(forKey: requestId) {
                continuation.resume(returning: response.response)
            } else {
                logger?.warning("Received response for unknown request: \(requestId)")
            }
        }
    }

    /// Handle incoming control request from CLI
    public func handleControlRequest(_ request: ControlRequest) async {
        do {
            let responsePayload: [String: Any]

            switch request.request {
            case .canUseTool(let canUseToolReq):
                guard let handler = canUseToolHandler else {
                    throw ControlProtocolError.noHandlerRegistered("canUseTool")
                }
                let result = try await handler(canUseToolReq)
                responsePayload = result.toDictionary()

            case .hookCallback(let hookReq):
                guard let handler = hookCallbackHandler else {
                    throw ControlProtocolError.noHandlerRegistered("hookCallback")
                }
                let result = try await handler(hookReq)
                responsePayload = result.toDictionary()

            case .mcpMessage(let mcpReq):
                guard let handler = mcpMessageHandler else {
                    throw ControlProtocolError.noHandlerRegistered("mcpMessage")
                }
                let result = try await handler(mcpReq)
                responsePayload = ["mcp_response": result.toDictionary()]

            default:
                throw ControlProtocolError.unexpectedRequestType
            }

            try await sendControlResponse(requestId: request.requestId, success: true, payload: responsePayload)

        } catch {
            try? await sendControlResponse(requestId: request.requestId, success: false, errorMessage: error.localizedDescription)
        }
    }

    private func sendControlResponse(
        requestId: String,
        success: Bool,
        payload: [String: Any]? = nil,
        errorMessage: String? = nil
    ) async throws {
        var response: [String: Any] = ["type": "control_response"]

        if success {
            response["response"] = [
                "subtype": "success",
                "request_id": requestId,
                "response": payload ?? [:]
            ]
        } else {
            response["response"] = [
                "subtype": "error",
                "request_id": requestId,
                "error": errorMessage ?? "Unknown error"
            ]
        }

        let data = try JSONSerialization.data(withJSONObject: response)
        try await transport.write(data)
    }

    /// Handle cancel request
    public func handleCancelRequest(_ cancel: ControlCancelRequest) {
        if let continuation = pendingRequests.removeValue(forKey: cancel.requestId) {
            continuation.resume(throwing: ControlProtocolError.cancelled)
        }
    }

    // MARK: - Convenience Methods

    public func initialize(
        hooks: [String: [HookMatcherConfig]]? = nil,
        sdkMcpServers: [String]? = nil,
        systemPrompt: String? = nil
    ) async throws {
        let request = InitializeRequest(
            hooks: hooks,
            sdkMcpServers: sdkMcpServers,
            systemPrompt: systemPrompt,
            appendSystemPrompt: nil
        )
        let _: EmptyResponse = try await sendRequest(.initialize(request))
    }

    public func interrupt() async throws {
        let _: EmptyResponse = try await sendRequest(.interrupt)
    }

    public func setModel(_ model: String?) async throws {
        let _: EmptyResponse = try await sendRequest(.setModel(SetModelRequest(subtype: "set_model", model: model)))
    }

    public func setPermissionMode(_ mode: PermissionMode) async throws {
        let _: EmptyResponse = try await sendRequest(.setPermissionMode(SetPermissionModeRequest(subtype: "set_permission_mode", mode: mode)))
    }

    public func setMaxThinkingTokens(_ tokens: Int?) async throws {
        let _: EmptyResponse = try await sendRequest(.setMaxThinkingTokens(SetMaxThinkingTokensRequest(subtype: "set_max_thinking_tokens", maxThinkingTokens: tokens)))
    }

    public func rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> RewindFilesResult {
        try await sendRequest(.rewindFiles(RewindFilesRequest(subtype: "rewind_files", userMessageId: messageId, dryRun: dryRun)))
    }

    public func mcpStatus() async throws -> MCPStatusResult {
        try await sendRequest(.mcpStatus)
    }

    public func reconnectMcpServer(name: String) async throws {
        let _: EmptyResponse = try await sendRequest(.mcpReconnect(MCPReconnectRequest(subtype: "mcp_reconnect", serverName: name)))
    }

    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        let _: EmptyResponse = try await sendRequest(.mcpToggle(MCPToggleRequest(subtype: "mcp_toggle", serverName: name, enabled: enabled)))
    }
}

public struct EmptyResponse: Codable, Sendable {}

public struct RewindFilesResult: Codable, Sendable {
    public let filesModified: [String]?
    public let success: Bool
}

public struct MCPStatusResult: Codable, Sendable {
    public let servers: [String: MCPServerStatus]
}

public struct MCPServerStatus: Codable, Sendable {
    public let status: String
    public let enabled: Bool
    public let tools: [String]?
}

public enum ControlProtocolError: Error, Sendable {
    case timeout(requestId: String)
    case cliError(message: String)
    case unexpectedEmptyResponse
    case unexpectedRequestType
    case noHandlerRegistered(String)
    case cancelled
}
```

**Testing Approach:**
- MockTransport to verify request writing
- Inject responses to test correlation
- Timeout tests with short timeout
- Handler invocation tests
- Cancel request handling

**Unit Tests Needed:**
```swift
func testSendRequest_WritesToTransport()
func testSendRequest_CorrelatesResponse()
func testSendRequest_TimesOut()
func testSendRequest_HandlesError()
func testHandleControlRequest_InvokesHandler()
func testHandleControlRequest_SendsResponse()
func testHandleControlRequest_SendsErrorOnFailure()
func testHandleCancelRequest_CancelsPending()
func testGenerateRequestId_IsUnique()
```

---

### Phase 3: SDK MCP Tools (Highest Priority)

#### 3.1 MCPTool + SDKMCPServer

**Complexity: S (Small)**

**Description:** Type-safe tool definitions and in-process MCP server.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/MCP/MCPTool.swift

/// Definition for an SDK MCP tool
public struct MCPTool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    public let handler: @Sendable ([String: Any]) async throws -> MCPToolResult

    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        handler: @escaping @Sendable ([String: Any]) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.handler = handler
    }
}

/// Result from MCP tool execution
public struct MCPToolResult: Sendable {
    public let content: [MCPContent]
    public let isError: Bool

    public init(content: [MCPContent], isError: Bool = false) {
        self.content = content
        self.isError = isError
    }

    public static func text(_ text: String) -> MCPToolResult {
        MCPToolResult(content: [.text(text)])
    }

    public static func error(_ message: String) -> MCPToolResult {
        MCPToolResult(content: [.text(message)], isError: true)
    }
}

/// MCP content types
public enum MCPContent: Sendable {
    case text(String)
    case image(data: Data, mimeType: String)
    case resource(uri: String, mimeType: String?, text: String?)

    public func toDictionary() -> [String: Any] {
        switch self {
        case .text(let text):
            return ["type": "text", "text": text]
        case .image(let data, let mimeType):
            return ["type": "image", "data": data.base64EncodedString(), "mimeType": mimeType]
        case .resource(let uri, let mimeType, let text):
            var dict: [String: Any] = ["type": "resource", "uri": uri]
            if let mimeType { dict["mimeType"] = mimeType }
            if let text { dict["text"] = text }
            return dict
        }
    }
}

/// JSON Schema for tool input
public struct JSONSchema: Sendable, Codable {
    public let type: String
    public let properties: [String: PropertySchema]?
    public let required: [String]?
    public let additionalProperties: Bool?

    public init(
        type: String = "object",
        properties: [String: PropertySchema]? = nil,
        required: [String]? = nil,
        additionalProperties: Bool? = nil
    ) {
        self.type = type
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let properties {
            dict["properties"] = Dictionary(uniqueKeysWithValues: properties.map { ($0.key, $0.value.toDictionary()) })
        }
        if let required { dict["required"] = required }
        if let additionalProperties { dict["additionalProperties"] = additionalProperties }
        return dict
    }
}

public struct PropertySchema: Sendable, Codable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let items: PropertySchema?
    public let properties: [String: PropertySchema]?

    public init(
        type: String,
        description: String? = nil,
        enum: [String]? = nil,
        items: PropertySchema? = nil,
        properties: [String: PropertySchema]? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self.items = items
        self.properties = properties
    }

    public static func string(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "string", description: description)
    }

    public static func number(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "number", description: description)
    }

    public static func integer(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "integer", description: description)
    }

    public static func boolean(_ description: String? = nil) -> PropertySchema {
        PropertySchema(type: "boolean", description: description)
    }

    public static func array(of items: PropertySchema, description: String? = nil) -> PropertySchema {
        PropertySchema(type: "array", description: description, items: items)
    }

    public static func object(properties: [String: PropertySchema], description: String? = nil) -> PropertySchema {
        PropertySchema(type: "object", description: description, properties: properties)
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type]
        if let description { dict["description"] = description }
        if let `enum` { dict["enum"] = `enum` }
        if let items { dict["items"] = items.toDictionary() }
        if let properties {
            dict["properties"] = Dictionary(uniqueKeysWithValues: properties.map { ($0.key, $0.value.toDictionary()) })
        }
        return dict
    }
}

// File: Sources/ClaudeCodeSDK/MCP/SDKMCPServer.swift

/// In-process MCP server for SDK tools
public final class SDKMCPServer: @unchecked Sendable {
    public let name: String
    public let version: String
    private let tools: [String: MCPTool]

    public init(name: String, version: String = "1.0.0", tools: [MCPTool]) {
        self.name = name
        self.version = version
        self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    }

    /// Get tool definitions for tools/list response
    public func listTools() -> [[String: Any]] {
        tools.values.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "inputSchema": tool.inputSchema.toDictionary()
            ]
        }
    }

    /// Call a tool
    public func callTool(name: String, arguments: [String: Any]) async throws -> MCPToolResult {
        guard let tool = tools[name] else {
            throw MCPServerError.toolNotFound(name)
        }
        return try await tool.handler(arguments)
    }

    /// Get server capabilities
    public var capabilities: [String: Any] {
        ["tools": ["listChanged": false]]
    }

    /// Get server info
    public var serverInfo: [String: Any] {
        ["name": name, "version": version]
    }
}

public enum MCPServerError: Error, Sendable {
    case toolNotFound(String)
    case invalidArguments(String)
}

// Result builder for convenient tool definition
@resultBuilder
public struct MCPToolBuilder {
    public static func buildBlock(_ tools: MCPTool...) -> [MCPTool] { tools }
    public static func buildArray(_ components: [[MCPTool]]) -> [MCPTool] { components.flatMap { $0 } }
}

/// Convenience function to create MCP server
public func createSDKMCPServer(
    name: String,
    version: String = "1.0.0",
    @MCPToolBuilder tools: () -> [MCPTool]
) -> SDKMCPServer {
    SDKMCPServer(name: name, version: version, tools: tools())
}
```

**Testing Approach:**
- Unit tests for tool definition and schema generation
- Unit tests for tool calling
- Tests for error handling (tool not found, handler throws)

---

#### 3.2 MCPServerRouter

**Complexity: M (Medium)**

**Description:** Actor routing JSONRPC messages to in-process SDK MCP servers.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/MCP/MCPServerRouter.swift

/// Actor routing MCP messages to in-process SDK servers
public actor MCPServerRouter {
    private var servers: [String: SDKMCPServer] = [:]
    private var initialized: Set<String> = []
    private let logger: Logger?

    public init(logger: Logger? = nil) {
        self.logger = logger
    }

    /// Register an SDK MCP server
    public func registerServer(_ server: SDKMCPServer) {
        servers[server.name] = server
        logger?.info("Registered SDK MCP server: \(server.name)")
    }

    /// Unregister an SDK MCP server
    public func unregisterServer(name: String) {
        servers.removeValue(forKey: name)
        initialized.remove(name)
    }

    /// Get registered server names for CLI config
    public func getServerNames() -> [String] {
        Array(servers.keys)
    }

    /// Route a JSONRPC message to the appropriate server
    public func route(_ request: MCPMessageRequest) async throws -> JSONRPCResponse {
        guard let server = servers[request.serverName] else {
            return JSONRPCResponse.error(
                id: request.message.id,
                code: -32601,
                message: "Server not found: \(request.serverName)"
            )
        }

        let message = request.message

        switch message.method {
        case "initialize":
            return handleInitialize(server: server, id: message.id)

        case "notifications/initialized":
            initialized.insert(request.serverName)
            return JSONRPCResponse.success(id: message.id ?? 0, result: [:])

        case "tools/list":
            return handleToolsList(server: server, id: message.id)

        case "tools/call":
            return await handleToolsCall(server: server, message: message)

        default:
            return JSONRPCResponse.error(
                id: message.id,
                code: -32601,
                message: "Method not found: \(message.method ?? "nil")"
            )
        }
    }

    private func handleInitialize(server: SDKMCPServer, id: Int?) -> JSONRPCResponse {
        JSONRPCResponse.success(id: id ?? 0, result: [
            "protocolVersion": "2024-11-05",
            "capabilities": server.capabilities,
            "serverInfo": server.serverInfo
        ])
    }

    private func handleToolsList(server: SDKMCPServer, id: Int?) -> JSONRPCResponse {
        JSONRPCResponse.success(id: id ?? 0, result: ["tools": server.listTools()])
    }

    private func handleToolsCall(server: SDKMCPServer, message: JSONRPCMessage) async -> JSONRPCResponse {
        guard let params = message.params,
              let name = params["name"]?.value as? String else {
            return JSONRPCResponse.error(id: message.id, code: -32602, message: "Invalid params: missing tool name")
        }

        let arguments = (params["arguments"]?.value as? [String: Any]) ?? [:]

        do {
            let result = try await server.callTool(name: name, arguments: arguments)
            return JSONRPCResponse.success(id: message.id ?? 0, result: [
                "content": result.content.map { $0.toDictionary() },
                "isError": result.isError
            ])
        } catch {
            return JSONRPCResponse.error(id: message.id, code: -32000, message: error.localizedDescription)
        }
    }
}

/// JSONRPC response builder
public struct JSONRPCResponse: Sendable {
    public let jsonrpc: String = "2.0"
    public let id: Int
    public let result: [String: Any]?
    public let error: JSONRPCError?

    public static func success(id: Int, result: [String: Any]) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: result, error: nil)
    }

    public static func error(id: Int?, code: Int, message: String) -> JSONRPCResponse {
        JSONRPCResponse(id: id ?? 0, result: nil, error: JSONRPCError(code: code, message: message, data: nil))
    }

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["jsonrpc": jsonrpc, "id": id]
        if let result { dict["result"] = result }
        if let error { dict["error"] = ["code": error.code, "message": error.message] }
        return dict
    }
}
```

**Testing Approach:**
- Test each JSONRPC method (initialize, tools/list, tools/call)
- Test server not found error
- Test method not found error
- Test tool execution with mock handler

---

### Phase 4: Hook System

#### 4.1 Hook Types

**Complexity: S (Small)**

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Hooks/HookTypes.swift

/// Hook event types (11 total)
public enum HookEvent: String, Codable, Sendable, CaseIterable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case userPromptSubmit = "UserPromptSubmit"
    case stop = "Stop"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case permissionRequest = "PermissionRequest"
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case notification = "Notification"
}

/// Hook matcher config for initialize request
public struct HookMatcherConfig: Codable, Sendable {
    public let matcher: String?
    public let hookCallbackIds: [String]
    public let timeout: TimeInterval?

    public init(matcher: String? = nil, hookCallbackIds: [String], timeout: TimeInterval? = nil) {
        self.matcher = matcher
        self.hookCallbackIds = hookCallbackIds
        self.timeout = timeout
    }
}

/// Base fields present in all hook inputs
public struct BaseHookInput: Sendable {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: String
    public let hookEventName: HookEvent
}

/// Input for PreToolUse hook
public struct PreToolUseInput: Sendable {
    public let base: BaseHookInput
    public let toolName: String
    public let toolInput: [String: Any]
    public let toolUseId: String
}

/// Input for PostToolUse hook
public struct PostToolUseInput: Sendable {
    public let base: BaseHookInput
    public let toolName: String
    public let toolInput: [String: Any]
    public let toolResponse: Any
    public let toolUseId: String
}

/// Input for PostToolUseFailure hook
public struct PostToolUseFailureInput: Sendable {
    public let base: BaseHookInput
    public let toolName: String
    public let toolInput: [String: Any]
    public let error: String
    public let isInterrupt: Bool
    public let toolUseId: String
}

/// Input for UserPromptSubmit hook
public struct UserPromptSubmitInput: Sendable {
    public let base: BaseHookInput
    public let prompt: String
}

/// Input for Stop hook
public struct StopInput: Sendable {
    public let base: BaseHookInput
    public let stopHookActive: Bool
}

/// Hook output structure
public struct HookOutput: Sendable {
    public var shouldContinue: Bool = true
    public var suppressOutput: Bool = false
    public var stopReason: String?
    public var systemMessage: String?
    public var reason: String?
    public var hookSpecificOutput: HookSpecificOutput?

    public init() {}

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["continue": shouldContinue]
        if suppressOutput { dict["suppressOutput"] = true }
        if let stopReason { dict["stopReason"] = stopReason }
        if let systemMessage { dict["systemMessage"] = systemMessage }
        if let reason { dict["reason"] = reason }
        if let hookSpecificOutput { dict["hookSpecificOutput"] = hookSpecificOutput.toDictionary() }
        return dict
    }
}

/// Hook-specific output types
public enum HookSpecificOutput: Sendable {
    case preToolUse(PreToolUseHookOutput)
    case postToolUse(PostToolUseHookOutput)

    public func toDictionary() -> [String: Any] {
        switch self {
        case .preToolUse(let output):
            var dict: [String: Any] = ["hookEventName": "PreToolUse"]
            if let decision = output.permissionDecision { dict["permissionDecision"] = decision.rawValue }
            if let reason = output.permissionDecisionReason { dict["permissionDecisionReason"] = reason }
            if let updatedInput = output.updatedInput { dict["updatedInput"] = updatedInput }
            if let additionalContext = output.additionalContext { dict["additionalContext"] = additionalContext }
            return dict
        case .postToolUse(let output):
            var dict: [String: Any] = ["hookEventName": "PostToolUse"]
            if let additionalContext = output.additionalContext { dict["additionalContext"] = additionalContext }
            if let updatedOutput = output.updatedMCPToolOutput { dict["updatedMCPToolOutput"] = updatedOutput }
            return dict
        }
    }
}

public struct PreToolUseHookOutput: Sendable {
    public var permissionDecision: PermissionDecision?
    public var permissionDecisionReason: String?
    public var updatedInput: [String: Any]?
    public var additionalContext: String?

    public init() {}
}

public struct PostToolUseHookOutput: Sendable {
    public var additionalContext: String?
    public var updatedMCPToolOutput: Any?

    public init() {}
}

public enum PermissionDecision: String, Sendable {
    case allow
    case deny
    case ask
}

/// Hook callback type
public typealias HookCallback<Input> = @Sendable (Input) async throws -> HookOutput
```

---

#### 4.2 HookRegistry

**Complexity: M (Medium)**

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Hooks/HookRegistry.swift

/// Actor managing hook registration and invocation
public actor HookRegistry {
    private var callbackIdCounter: Int = 0
    private var callbacks: [String: Any] = [:]  // callback_id -> callback
    private var hookConfig: [HookEvent: [HookMatcherConfig]] = [:]
    private let logger: Logger?

    public init(logger: Logger? = nil) {
        self.logger = logger
    }

    // MARK: - Registration Methods

    public func onPreToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PreToolUseInput>
    ) {
        let callbackId = generateCallbackId()
        callbacks[callbackId] = callback
        hookConfig[.preToolUse, default: []].append(
            HookMatcherConfig(matcher: pattern, hookCallbackIds: [callbackId], timeout: timeout)
        )
    }

    public func onPostToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PostToolUseInput>
    ) {
        let callbackId = generateCallbackId()
        callbacks[callbackId] = callback
        hookConfig[.postToolUse, default: []].append(
            HookMatcherConfig(matcher: pattern, hookCallbackIds: [callbackId], timeout: timeout)
        )
    }

    public func onUserPromptSubmit(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<UserPromptSubmitInput>
    ) {
        let callbackId = generateCallbackId()
        callbacks[callbackId] = callback
        hookConfig[.userPromptSubmit, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
    }

    public func onStop(
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<StopInput>
    ) {
        let callbackId = generateCallbackId()
        callbacks[callbackId] = callback
        hookConfig[.stop, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
    }

    // Additional hook registration methods for other events...

    // MARK: - Configuration

    public func getHookConfig() -> [String: [HookMatcherConfig]]? {
        guard !hookConfig.isEmpty else { return nil }
        return Dictionary(uniqueKeysWithValues: hookConfig.map { ($0.key.rawValue, $0.value) })
    }

    public var hasHooks: Bool { !hookConfig.isEmpty }

    // MARK: - Invocation

    public func invokeCallback(
        callbackId: String,
        input: [String: Any]
    ) async throws -> HookOutput {
        guard let callback = callbacks[callbackId] else {
            throw HookError.callbackNotFound(callbackId)
        }

        let baseInput = parseBaseInput(from: input)

        // Route based on hook event type
        switch baseInput.hookEventName {
        case .preToolUse:
            let typedInput = parsePreToolUseInput(from: input, base: baseInput)
            let typedCallback = callback as! HookCallback<PreToolUseInput>
            return try await typedCallback(typedInput)

        case .postToolUse:
            let typedInput = parsePostToolUseInput(from: input, base: baseInput)
            let typedCallback = callback as! HookCallback<PostToolUseInput>
            return try await typedCallback(typedInput)

        case .userPromptSubmit:
            let typedInput = parseUserPromptSubmitInput(from: input, base: baseInput)
            let typedCallback = callback as! HookCallback<UserPromptSubmitInput>
            return try await typedCallback(typedInput)

        case .stop:
            let typedInput = parseStopInput(from: input, base: baseInput)
            let typedCallback = callback as! HookCallback<StopInput>
            return try await typedCallback(typedInput)

        default:
            throw HookError.unsupportedHookEvent(baseInput.hookEventName)
        }
    }

    private func generateCallbackId() -> String {
        callbackIdCounter += 1
        return "hook_\(callbackIdCounter)"
    }

    private func parseBaseInput(from input: [String: Any]) -> BaseHookInput {
        BaseHookInput(
            sessionId: input["session_id"] as? String ?? "",
            transcriptPath: input["transcript_path"] as? String ?? "",
            cwd: input["cwd"] as? String ?? "",
            permissionMode: input["permission_mode"] as? String ?? "",
            hookEventName: HookEvent(rawValue: input["hook_event_name"] as? String ?? "") ?? .preToolUse
        )
    }

    private func parsePreToolUseInput(from input: [String: Any], base: BaseHookInput) -> PreToolUseInput {
        PreToolUseInput(
            base: base,
            toolName: input["tool_name"] as? String ?? "",
            toolInput: input["tool_input"] as? [String: Any] ?? [:],
            toolUseId: input["tool_use_id"] as? String ?? ""
        )
    }

    // Additional parse methods...
}

public enum HookError: Error, Sendable {
    case callbackNotFound(String)
    case unsupportedHookEvent(HookEvent)
    case invalidInput
}
```

---

### Phase 5: Permission System

#### 5.1 Permission Types

**Complexity: S (Small)**

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Permissions/PermissionTypes.swift

/// Permission modes
public enum PermissionMode: String, Codable, Sendable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case bypassPermissions = "bypassPermissions"
    case plan = "plan"
}

/// Context provided to permission callback
public struct ToolPermissionContext: Sendable {
    public let suggestions: [PermissionUpdate]
    public let blockedPath: String?
    public let decisionReason: String?
    public let agentId: String?
}

/// Result from permission callback
public enum PermissionResult: Sendable {
    case allow(updatedInput: [String: Any]? = nil, permissionUpdates: [PermissionUpdate]? = nil)
    case deny(message: String, interrupt: Bool = false)

    public func toDictionary() -> [String: Any] {
        switch self {
        case .allow(let updatedInput, let updates):
            var dict: [String: Any] = ["behavior": "allow"]
            if let updatedInput { dict["updatedInput"] = updatedInput }
            if let updates { dict["updatedPermissions"] = updates.map { $0.toDictionary() } }
            return dict
        case .deny(let message, let interrupt):
            return ["behavior": "deny", "message": message, "interrupt": interrupt]
        }
    }
}

/// Permission update for rule changes
public struct PermissionUpdate: Codable, Sendable {
    public enum UpdateType: String, Codable, Sendable {
        case addRules
        case replaceRules
        case removeRules
        case setMode
        case addDirectories
        case removeDirectories
    }

    public enum Behavior: String, Codable, Sendable {
        case allow, deny, ask
    }

    public enum Destination: String, Codable, Sendable {
        case userSettings, projectSettings, localSettings, session
    }

    public let type: UpdateType
    public let rules: [PermissionRule]?
    public let behavior: Behavior?
    public let mode: PermissionMode?
    public let directories: [String]?
    public let destination: Destination?

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["type": type.rawValue]
        if let rules { dict["rules"] = rules.map { $0.toDictionary() } }
        if let behavior { dict["behavior"] = behavior.rawValue }
        if let mode { dict["mode"] = mode.rawValue }
        if let directories { dict["directories"] = directories }
        if let destination { dict["destination"] = destination.rawValue }
        return dict
    }
}

public struct PermissionRule: Codable, Sendable {
    public let toolName: String
    public let ruleContent: String?

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["toolName": toolName]
        if let ruleContent { dict["ruleContent"] = ruleContent }
        return dict
    }
}

/// Permission callback type
public typealias CanUseToolCallback = @Sendable (
    _ toolName: String,
    _ input: [String: Any],
    _ context: ToolPermissionContext
) async throws -> PermissionResult
```

---

### Phase 6: Session & Query API

#### 6.1 ClaudeSession

**Complexity: L (Large)**

**Description:** Main actor integrating all components - transport, control protocol, MCP routing, hooks, permissions.

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Session/ClaudeSession.swift

/// Actor managing a Claude Code session with control protocol
public actor ClaudeSession {
    private let transport: Transport
    private let controlHandler: ControlProtocolHandler
    private let hookRegistry: HookRegistry
    private let mcpRouter: MCPServerRouter
    private let logger: Logger?

    private var sessionId: String?
    private var isInitialized = false
    private var continuation: AsyncThrowingStream<SDKMessage, Error>.Continuation?

    public private(set) var canUseToolCallback: CanUseToolCallback?

    public init(transport: Transport, logger: Logger? = nil) {
        self.transport = transport
        self.logger = logger
        self.controlHandler = ControlProtocolHandler(transport: transport, logger: logger)
        self.hookRegistry = HookRegistry(logger: logger)
        self.mcpRouter = MCPServerRouter(logger: logger)
    }

    // MARK: - Configuration

    public func setCanUseTool(_ callback: @escaping CanUseToolCallback) {
        canUseToolCallback = callback
    }

    public func registerMCPServer(_ server: SDKMCPServer) async {
        await mcpRouter.registerServer(server)
    }

    public func onPreToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PreToolUseInput>
    ) async {
        await hookRegistry.onPreToolUse(matching: pattern, timeout: timeout, callback: callback)
    }

    public func onPostToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PostToolUseInput>
    ) async {
        await hookRegistry.onPostToolUse(matching: pattern, timeout: timeout, callback: callback)
    }

    // Additional hook registration methods...

    // MARK: - Session Lifecycle

    public func initialize() async throws {
        guard !isInitialized else { return }

        // Set up control protocol handlers
        await controlHandler.setCanUseToolHandler { [weak self] request in
            guard let self, let callback = await self.canUseToolCallback else {
                return .allow()
            }
            let context = ToolPermissionContext(
                suggestions: request.permissionSuggestions ?? [],
                blockedPath: request.blockedPath,
                decisionReason: request.decisionReason,
                agentId: request.agentId
            )
            return try await callback(
                request.toolName,
                request.input.mapValues { $0.value },
                context
            )
        }

        await controlHandler.setHookCallbackHandler { [weak self] request in
            guard let self else { throw SessionError.sessionClosed }
            return try await self.hookRegistry.invokeCallback(
                callbackId: request.callbackId,
                input: request.input.mapValues { $0.value }
            )
        }

        await controlHandler.setMCPMessageHandler { [weak self] request in
            guard let self else { throw SessionError.sessionClosed }
            return try await self.mcpRouter.route(request)
        }

        // Send initialize control request
        let hookConfig = await hookRegistry.getHookConfig()
        let mcpServers = await mcpRouter.getServerNames()
        try await controlHandler.initialize(
            hooks: hookConfig,
            sdkMcpServers: mcpServers.isEmpty ? nil : mcpServers
        )

        isInitialized = true
    }

    // MARK: - Message Processing

    public func startMessageLoop() -> AsyncThrowingStream<SDKMessage, Error> {
        AsyncThrowingStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }
            Task { await self.runMessageLoop(continuation: continuation) }
        }
    }

    private func runMessageLoop(
        continuation: AsyncThrowingStream<SDKMessage, Error>.Continuation
    ) async {
        self.continuation = continuation

        do {
            for try await message in transport.readMessages() {
                switch message {
                case .regular(let sdkMessage):
                    if case .system(let sysMsg) = sdkMessage, sysMsg.subtype == "init" {
                        sessionId = sysMsg.sessionId
                    }
                    continuation.yield(sdkMessage)

                case .controlRequest(let request):
                    await controlHandler.handleControlRequest(request)

                case .controlResponse(let response):
                    await controlHandler.handleControlResponse(response)

                case .controlCancelRequest(let cancel):
                    await controlHandler.handleCancelRequest(cancel)

                case .keepAlive:
                    break
                }
            }
        } catch {
            continuation.finish(throwing: error)
            return
        }

        continuation.finish()
    }

    // MARK: - Control Methods

    public func interrupt() async throws {
        try await controlHandler.interrupt()
    }

    public func setModel(_ model: String?) async throws {
        try await controlHandler.setModel(model)
    }

    public func setPermissionMode(_ mode: PermissionMode) async throws {
        try await controlHandler.setPermissionMode(mode)
    }

    public func setMaxThinkingTokens(_ tokens: Int?) async throws {
        try await controlHandler.setMaxThinkingTokens(tokens)
    }

    public func rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> RewindFilesResult {
        try await controlHandler.rewindFiles(to: messageId, dryRun: dryRun)
    }

    public func mcpStatus() async throws -> MCPStatusResult {
        try await controlHandler.mcpStatus()
    }

    public func reconnectMcpServer(name: String) async throws {
        try await controlHandler.reconnectMcpServer(name: name)
    }

    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        try await controlHandler.toggleMcpServer(name: name, enabled: enabled)
    }

    public func close() async {
        transport.close()
    }

    public var currentSessionId: String? { sessionId }
}

public enum SessionError: Error, Sendable {
    case sessionClosed
    case notInitialized
}
```

---

#### 6.2 ClaudeQuery (AsyncSequence)

**Complexity: M (Medium)**

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Query/ClaudeQuery.swift

/// AsyncSequence wrapper providing iteration and control methods
public final class ClaudeQuery: AsyncSequence, @unchecked Sendable {
    public typealias Element = ResponseChunk

    private let session: ClaudeSession
    private let underlyingStream: AsyncThrowingStream<SDKMessage, Error>

    internal init(session: ClaudeSession, stream: AsyncThrowingStream<SDKMessage, Error>) {
        self.session = session
        self.underlyingStream = stream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: underlyingStream)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<SDKMessage, Error>.Iterator

        init(stream: AsyncThrowingStream<SDKMessage, Error>) {
            self.iterator = stream.makeAsyncIterator()
        }

        public mutating func next() async throws -> ResponseChunk? {
            guard let message = try await iterator.next() else { return nil }
            return ResponseChunk(from: message)
        }
    }

    // MARK: - Control Methods

    public func interrupt() async throws {
        try await session.interrupt()
    }

    public func setModel(_ model: String?) async throws {
        try await session.setModel(model)
    }

    public func setPermissionMode(_ mode: PermissionMode) async throws {
        try await session.setPermissionMode(mode)
    }

    public func setMaxThinkingTokens(_ tokens: Int?) async throws {
        try await session.setMaxThinkingTokens(tokens)
    }

    public func rewindFiles(to messageId: String, dryRun: Bool = false) async throws -> RewindFilesResult {
        try await session.rewindFiles(to: messageId, dryRun: dryRun)
    }

    public func mcpStatus() async throws -> MCPStatusResult {
        try await session.mcpStatus()
    }

    public func reconnectMcpServer(name: String) async throws {
        try await session.reconnectMcpServer(name: name)
    }

    public func toggleMcpServer(name: String, enabled: Bool) async throws {
        try await session.toggleMcpServer(name: name, enabled: enabled)
    }

    public var sessionId: String? {
        get async { await session.currentSessionId }
    }
}
```

---

#### 6.3 Query API (Public Entry Point)

**Complexity: M (Medium)**

**Swift API:**
```swift
// File: Sources/ClaudeCodeSDK/Query/QueryAPI.swift

/// Main entry point for creating queries
public func query(
    prompt: String,
    options: QueryOptions = QueryOptions()
) async throws -> ClaudeQuery {
    // Build CLI arguments
    var arguments = [
        "-p",
        "--output-format", "stream-json",
        "--input-format", "stream-json",
        "--verbose"
    ]

    if let model = options.model {
        arguments.append(contentsOf: ["--model", model])
    }
    if let maxTurns = options.maxTurns {
        arguments.append(contentsOf: ["--max-turns", String(maxTurns)])
    }
    if let maxThinkingTokens = options.maxThinkingTokens {
        arguments.append(contentsOf: ["--max-thinking-tokens", String(maxThinkingTokens)])
    }
    if let permissionMode = options.permissionMode {
        arguments.append(contentsOf: ["--permission-mode", permissionMode.rawValue])
    }
    if let systemPrompt = options.systemPrompt {
        arguments.append(contentsOf: ["--system-prompt", systemPrompt])
    }

    // Build MCP config if needed
    let hasSdkMcp = !options.sdkMcpServers.isEmpty
    let hasExternalMcp = !options.mcpServers.isEmpty
    if hasSdkMcp || hasExternalMcp {
        let configPath = try buildMCPConfigFile(
            external: options.mcpServers,
            sdk: options.sdkMcpServers
        )
        arguments.append(contentsOf: ["--mcp-config", configPath])
    }

    // Create transport
    let transport = ProcessTransport(
        cliPath: options.cliPath ?? "claude",
        arguments: arguments,
        environment: options.environment,
        workingDirectory: options.workingDirectory.map { URL(fileURLWithPath: $0) },
        logger: options.logger
    )

    // Create session
    let session = ClaudeSession(transport: transport, logger: options.logger)

    // Register SDK MCP servers
    for (_, server) in options.sdkMcpServers {
        await session.registerMCPServer(server)
    }

    // Register hooks
    for hook in options.preToolUseHooks {
        await session.onPreToolUse(matching: hook.pattern, timeout: hook.timeout, callback: hook.callback)
    }
    for hook in options.postToolUseHooks {
        await session.onPostToolUse(matching: hook.pattern, timeout: hook.timeout, callback: hook.callback)
    }

    // Set permission callback
    if let canUseTool = options.canUseTool {
        await session.setCanUseTool(canUseTool)
    }

    // Start transport
    try await transport.start()

    // Initialize control protocol if needed
    let needsControlProtocol = await session.hookRegistry.hasHooks ||
                               !options.sdkMcpServers.isEmpty ||
                               options.canUseTool != nil
    if needsControlProtocol {
        try await session.initialize()
    }

    // Send prompt
    let promptMessage: [String: Any] = [
        "type": "user",
        "message": ["role": "user", "content": prompt]
    ]
    let promptData = try JSONSerialization.data(withJSONObject: promptMessage)
    try await transport.write(promptData)

    // For single-shot mode without control protocol, close stdin
    if !needsControlProtocol {
        await transport.endInput()
    }

    // Start message loop
    let stream = await session.startMessageLoop()

    return ClaudeQuery(session: session, stream: stream)
}

/// Options for query
public struct QueryOptions: Sendable {
    public var model: String?
    public var maxTurns: Int?
    public var maxThinkingTokens: Int?
    public var permissionMode: PermissionMode?
    public var systemPrompt: String?
    public var workingDirectory: String?
    public var environment: [String: String] = [:]
    public var cliPath: String?
    public var logger: Logger?

    // MCP servers
    public var mcpServers: [String: McpServerConfiguration] = [:]
    public var sdkMcpServers: [String: SDKMCPServer] = [:]

    // Hooks
    public var preToolUseHooks: [PreToolUseHookConfig] = []
    public var postToolUseHooks: [PostToolUseHookConfig] = []

    // Permission callback
    public var canUseTool: CanUseToolCallback?

    public init() {}
}

public struct PreToolUseHookConfig: Sendable {
    public let pattern: String?
    public let timeout: TimeInterval
    public let callback: HookCallback<PreToolUseInput>

    public init(
        pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PreToolUseInput>
    ) {
        self.pattern = pattern
        self.timeout = timeout
        self.callback = callback
    }
}

public struct PostToolUseHookConfig: Sendable {
    public let pattern: String?
    public let timeout: TimeInterval
    public let callback: HookCallback<PostToolUseInput>

    public init(
        pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping HookCallback<PostToolUseInput>
    ) {
        self.pattern = pattern
        self.timeout = timeout
        self.callback = callback
    }
}

private func buildMCPConfigFile(
    external: [String: McpServerConfiguration],
    sdk: [String: SDKMCPServer]
) throws -> String {
    var servers: [String: Any] = [:]

    for (name, config) in external {
        servers[name] = config.toDictionary()
    }

    for (name, server) in sdk {
        servers[name] = ["type": "sdk", "name": server.name]
    }

    let config: [String: Any] = ["mcpServers": servers]
    let tempDir = FileManager.default.temporaryDirectory
    let configFile = tempDir.appendingPathComponent("mcp-config-\(UUID().uuidString).json")
    let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
    try data.write(to: configFile)
    return configFile.path
}
```

---

## Files to Create

```
Sources/ClaudeCodeSDK/
├── Transport/
│   ├── Transport.swift              # Protocol + StdoutMessage enum
│   ├── ProcessTransport.swift       # Foundation.Process implementation
│   ├── JSONLineParser.swift         # JSON line parsing
│   └── MockTransport.swift          # Actor for testing
├── ControlProtocol/
│   ├── ControlProtocolTypes.swift   # All request/response types
│   └── ControlProtocolHandler.swift # Actor for protocol handling
├── MCP/
│   ├── MCPTool.swift                # Tool, Result, Content, Schema types
│   ├── SDKMCPServer.swift           # In-process server
│   └── MCPServerRouter.swift        # JSONRPC routing actor
├── Hooks/
│   ├── HookTypes.swift              # Events, inputs, outputs
│   └── HookRegistry.swift           # Registration and invocation
├── Permissions/
│   └── PermissionTypes.swift        # Mode, Result, Update types
├── Session/
│   └── ClaudeSession.swift          # Main session actor
├── Query/
│   ├── ClaudeQuery.swift            # AsyncSequence wrapper
│   └── QueryAPI.swift               # Public query() function
└── Backend/
    └── NativeBackend.swift          # ClaudeCodeBackend implementation
```

## Files to Modify

| File | Change |
|------|--------|
| `Backend/BackendFactory.swift` | Add `.native` case |
| `Backend/ClaudeCodeBackend.swift` | Add to `BackendType` enum |
| `API/ClaudeCodeOptions.swift` | Add hooks, canUseTool, sdkMcpServers properties |
| `API/ResponseChunk.swift` | Add conversion from SDKMessage |

---

## Testing Architecture

### Test File Structure

```
Tests/ClaudeCodeSDKTests/
├── Unit/
│   ├── Transport/
│   │   ├── JSONLineParserTests.swift
│   │   └── MockTransportTests.swift
│   ├── Protocol/
│   │   ├── ControlProtocolTypesTests.swift
│   │   └── ControlProtocolHandlerTests.swift
│   ├── MCP/
│   │   ├── MCPToolTests.swift
│   │   ├── SDKMCPServerTests.swift
│   │   └── MCPServerRouterTests.swift
│   ├── Hooks/
│   │   ├── HookTypesTests.swift
│   │   └── HookRegistryTests.swift
│   └── Permissions/
│       └── PermissionTypesTests.swift
├── Integration/
│   ├── SessionIntegrationTests.swift    # Full flow with MockTransport
│   ├── MCPIntegrationTests.swift        # SDK MCP tool execution
│   └── HookIntegrationTests.swift       # Hook callback flow
└── Live/
    ├── BasicQueryTests.swift            # Real CLI (skip if no API key)
    └── MCPToolLiveTests.swift           # Real SDK MCP tool execution
```

### Mock Strategy Summary

| Component | Mock |
|-----------|------|
| Transport | MockTransport actor - inject messages, capture writes |
| SDKMCPServer | Mock tool handlers returning canned results |
| HookRegistry | Mock callbacks verifying invocation |
| ControlProtocolHandler | MockTransport + handler verification |

### Coverage Requirement

100% code coverage required:
- Every line exercised
- Every branch (true/false) taken
- Every error path tested
- Coverage enforced in CI

---

## Verification Steps

1. **Build**: `swift build` succeeds

2. **Unit Tests**: `swift test` with 100% coverage

3. **SDK MCP Tool Works**:
   ```swift
   let server = SDKMCPServer(name: "test", tools: [
       MCPTool(name: "echo", description: "Echo input", inputSchema: ...) { args in
           .text("Echo: \(args["message"] ?? "")")
       }
   ])

   let query = try await query(
       prompt: "Use the echo tool with message 'hello'",
       options: QueryOptions(sdkMcpServers: ["test": server])
   )

   for try await chunk in query {
       // Should see tool use and result
   }
   ```

4. **Hooks Fire**:
   ```swift
   var hookCalled = false
   var options = QueryOptions()
   options.preToolUseHooks.append(PreToolUseHookConfig { input in
       hookCalled = true
       return HookOutput()
   })

   let query = try await query(prompt: "Read a file", options: options)
   for try await _ in query {}

   assert(hookCalled)
   ```

5. **Permission Callback Works**:
   ```swift
   var options = QueryOptions()
   options.canUseTool = { toolName, input, context in
       if toolName == "Bash" { return .deny(message: "No bash") }
       return .allow()
   }

   let query = try await query(prompt: "Run a command", options: options)
   // Should see permission denied
   ```

6. **Control Methods Work**:
   ```swift
   let query = try await query(prompt: "Long task", options: options)

   Task {
       try await Task.sleep(for: .seconds(1))
       try await query.interrupt()  // Should stop iteration
   }

   for try await chunk in query {
       // Should terminate early
   }
   ```

---

## Complexity Summary

| Complexity | Items | Effort |
|------------|-------|--------|
| **S (Small)** | Transport protocol, JSONLineParser, MockTransport, Control types, MCP types, Hook types, Permission types | 1-2 days each |
| **M (Medium)** | ProcessTransport, ControlProtocolHandler, MCPServerRouter, HookRegistry, ClaudeQuery, QueryAPI, NativeBackend | 3-5 days each |
| **L (Large)** | ClaudeSession | 1-2 weeks |

**Total Estimate**: 5-6 weeks for full implementation with tests

---

## Implementation Checklist

See **[05-native-implementation-checklist.md](./05-native-implementation-checklist.md)** for the detailed task checklist.

Progress is tracked via Beads issues. The checklist is for later-stage verification.
