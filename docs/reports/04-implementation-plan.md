# Implementation Plan: Swift ClaudeCodeSDK API Parity (Bridge Approach)

## Executive Summary

This document provides a comprehensive implementation plan to bring the Swift ClaudeCodeSDK to complete feature parity with the TypeScript SDK. The plan uses the existing TypeScript bridge approach via `sdk-wrapper.mjs`, prioritizing SDK MCP tools, hooks, and query control methods.

**Current State**:
- Basic query execution via `AgentSDKBackend` using Node.js wrapper
- Combine publishers for streaming (needs AsyncSequence migration)
- No control protocol, hooks, SDK MCP tools, or permission callbacks

**Target State**:
- Full TypeScript SDK API parity
- AsyncSequence-based streaming
- Bidirectional control protocol
- In-process SDK MCP tools
- Complete hooks system (13 event types)
- Dynamic query control methods

---

## Architecture Overview

### Current Architecture

```
┌─────────────────────────────────┐
│         Swift SDK               │
│  ClaudeCodeClient               │
│       ↓                         │
│  AgentSDKBackend                │
│  - Spawns Node.js process       │
│  - Passes config via CLI arg    │
│  - Reads stdout (one-way)       │
└──────────────┬──────────────────┘
               │ subprocess (stdout only)
┌──────────────▼──────────────────┐
│      sdk-wrapper.mjs            │
│  - Maps options                 │
│  - Calls query()                │
│  - Streams JSONL to stdout      │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│  @anthropic-ai/claude-agent-sdk │
│  - Manages CLI subprocess       │
│  - Handles control protocol     │
└─────────────────────────────────┘
```

### Target Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Swift SDK Process                               │
│                                                                          │
│  ┌──────────────────┐    ┌────────────────────┐    ┌─────────────────┐  │
│  │  SDKMCPServer    │◀───│ ControlProtocol    │◀───│  Process I/O    │  │
│  │  (in-process     │    │ Handler (actor)    │    │  Manager        │  │
│  │   tool handlers) │    │                    │    │                 │  │
│  │                  │───▶│  - Route requests  │───▶│  stdin/stdout   │  │
│  │  - tools/list    │    │  - Correlate IDs   │    │  pipes          │  │
│  │  - tools/call    │    │  - Handle hooks    │    │                 │  │
│  └──────────────────┘    └────────────────────┘    └────────┬────────┘  │
│                                                              │           │
│  ┌──────────────────┐    ┌────────────────────┐              │           │
│  │  HookCallbacks   │───▶│  PermissionHandler │──────────────┘           │
│  │  (PreToolUse,    │    │  (canUseTool)      │                          │
│  │   PostToolUse,   │    │                    │                          │
│  │   etc.)          │    │                    │                          │
│  └──────────────────┘    └────────────────────┘                          │
└───────────────────────────────────────────────────────────────│──────────┘
                                                                │
                                                     subprocess │ bidirectional
                                                                │
┌───────────────────────────────────────────────────────────────▼──────────┐
│                        sdk-wrapper.mjs Process                            │
│                                                                          │
│  - Keeps stdin open for control responses from Swift                     │
│  - Forwards control_request messages to Swift via stdout                 │
│  - Waits for control_response from Swift via stdin                       │
│  - Routes mcp_message, hook_callback, can_use_tool to Swift              │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                                                                │
┌───────────────────────────────────────────────────────────────▼──────────┐
│                  @anthropic-ai/claude-agent-sdk                          │
│                                                                          │
│  - Spawns Claude CLI subprocess                                          │
│  - Manages bidirectional control protocol with CLI                       │
│  - Sends control_request for SDK MCP tools, hooks, permissions           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: AsyncSequence Migration

**Priority**: Foundation (must complete first)

**Complexity**: Medium (M)

**Goal**: Replace Combine publishers with Swift structured concurrency.

#### Files to Modify

| File | Changes |
|------|---------|
| `Backend/AgentSDKBackend.swift` | Replace `PassthroughSubject` with `AsyncThrowingStream.Continuation` |
| `Backend/HeadlessBackend.swift` | Same migration as AgentSDKBackend |
| `API/ClaudeCodeResult.swift` | Change `.stream` case from `AnyPublisher` to `QueryStream` |
| New: `API/QueryStream.swift` | New AsyncSequence wrapper type |

#### Swift API Design

```swift
// New QueryStream type replacing AnyPublisher
public final class QueryStream: AsyncSequence, @unchecked Sendable {
    public typealias Element = ResponseChunk

    private let underlyingStream: AsyncThrowingStream<ResponseChunk, Error>
    private var initMessage: InitSystemMessage?

    // AsyncSequence conformance
    public struct AsyncIterator: AsyncIteratorProtocol {
        public mutating func next() async throws -> ResponseChunk?
    }

    public func makeAsyncIterator() -> AsyncIterator
}

// Updated result type
public enum ClaudeCodeResult {
    case text(String)
    case json(ResultMessage)
    case stream(QueryStream)  // Was: AnyPublisher<ResponseChunk, Error>
}

// Backward compatibility (deprecated)
extension QueryStream {
    @available(*, deprecated, message: "Use async iteration instead")
    public var publisher: AnyPublisher<ResponseChunk, Error> {
        // Bridge to Combine for existing code
    }
}
```

#### Implementation Details

**AgentSDKBackend changes**:

```swift
private func handleStreamJsonOutput(...) async throws -> ClaudeCodeResult {
    // Create continuation-based stream
    let (stream, continuation) = AsyncThrowingStream<ResponseChunk, Error>.makeStream()

    // Keep existing StreamBuffer actor (already good pattern)
    let streamBuffer = StreamBuffer()

    outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
        let data = fileHandle.availableData
        guard !data.isEmpty else {
            continuation.finish()
            return
        }

        Task {
            await streamBuffer.append(data)
            // ... existing JSON line parsing ...
            for chunk in parsedChunks {
                continuation.yield(chunk)
            }
        }
    }

    process.terminationHandler = { process in
        if process.terminationStatus != 0 {
            continuation.finish(throwing: ClaudeCodeError.executionFailed(...))
        } else {
            continuation.finish()
        }
    }

    return .stream(QueryStream(underlyingStream: stream))
}
```

#### Testing Approach

**Unit Tests** (`Tests/ClaudeCodeSDKTests/Unit/AsyncSequenceTests.swift`):

```swift
func testStreamIteration() async throws {
    let mock = MockSubprocessTransport()
    mock.setResponses([
        MockResponses.initMessage(),
        MockResponses.assistantMessage(text: "Hello"),
        MockResponses.resultMessage()
    ])

    let backend = AgentSDKBackend(transport: mock)
    let result = try await backend.runSinglePrompt(...)

    guard case .stream(let stream) = result else { XCTFail(); return }

    var count = 0
    for try await _ in stream { count += 1 }
    XCTAssertEqual(count, 3)
}

func testStreamCancellation() async throws {
    // Test that Task cancellation propagates to stream
}

func testBackwardCompatibilityPublisher() async throws {
    // Test deprecated publisher bridge still works
}
```

**Integration Tests**:
- Full query lifecycle with AsyncSequence
- Concurrent queries in parallel

#### Task Checklist

**1.1 Create QueryStream type**
- [ ] Create `API/QueryStream.swift`
- [ ] Define `QueryStream` class conforming to `AsyncSequence`
- [ ] Implement `AsyncIterator` with `next() async throws -> ResponseChunk?`
- [ ] Add internal `underlyingStream: AsyncThrowingStream<ResponseChunk, Error>` property
- [ ] Add internal `initMessage: InitSystemMessage?` property for caching init
- [ ] Add initializer accepting `AsyncThrowingStream`
- [ ] Write unit test: `testQueryStreamIteration`
- [ ] Write unit test: `testQueryStreamAsyncIteratorProtocol`

**1.2 Update ClaudeCodeResult**
- [ ] Modify `API/ClaudeCodeResult.swift`
- [ ] Change `.stream` case from `AnyPublisher<ResponseChunk, Error>` to `QueryStream`
- [ ] Update all switch statements handling `.stream` case
- [ ] Write unit test: `testClaudeCodeResultStreamCase`

**1.3 Migrate AgentSDKBackend**
- [ ] Import `AsyncThrowingStream` (remove Combine import if unused)
- [ ] Replace `PassthroughSubject` declaration with `AsyncThrowingStream.Continuation`
- [ ] Update `handleStreamJsonOutput()` to create stream via `makeStream()`
- [ ] Replace `subject.send(.initSystem(...))` with `continuation.yield(.initSystem(...))`
- [ ] Replace `subject.send(.assistant(...))` with `continuation.yield(.assistant(...))`
- [ ] Replace `subject.send(.user(...))` with `continuation.yield(.user(...))`
- [ ] Replace `subject.send(.result(...))` with `continuation.yield(.result(...))`
- [ ] Replace `subject.send(completion: .finished)` with `continuation.finish()`
- [ ] Replace `subject.send(completion: .failure(error))` with `continuation.finish(throwing: error)`
- [ ] Return `QueryStream(underlyingStream: stream)` instead of publisher
- [ ] Write unit test: `testAgentSDKBackendReturnsQueryStream`
- [ ] Write integration test: `testAgentSDKBackendFullLifecycle`

**1.4 Migrate HeadlessBackend**
- [ ] Same changes as AgentSDKBackend for `handleStreamJsonOutput()`
- [ ] Update all Combine references to AsyncThrowingStream
- [ ] Write unit test: `testHeadlessBackendReturnsQueryStream`

**1.5 Add backward compatibility bridge**
- [ ] Add `@available(*, deprecated)` extension on `QueryStream`
- [ ] Implement `var publisher: AnyPublisher<ResponseChunk, Error>` computed property
- [ ] Bridge AsyncSequence to Combine using internal Task + PassthroughSubject
- [ ] Write unit test: `testBackwardCompatibilityPublisher`

**1.6 Update example app and documentation**
- [ ] Update example app to use `for try await chunk in stream`
- [ ] Remove Combine imports where no longer needed
- [ ] Update README with new async iteration pattern

---

### Phase 2: Control Protocol Foundation

**Priority**: High (blocks Phases 3-6)

**Complexity**: Large (L)

**Goal**: Enable bidirectional communication between Swift and sdk-wrapper.mjs.

#### Files to Create/Modify

| File | Purpose |
|------|---------|
| New: `ControlProtocol/ControlProtocolHandler.swift` | Actor managing bidirectional communication |
| New: `ControlProtocol/ControlMessages.swift` | Request/response types |
| `Resources/sdk-wrapper.mjs` | Add stdin reading, control message routing |
| `Backend/AgentSDKBackend.swift` | Integrate control protocol handler |

#### Swift API Design

```swift
// Control request subtypes
public enum ControlRequestSubtype: String, Codable, Sendable {
    case initialize
    case interrupt
    case setPermissionMode = "set_permission_mode"
    case setModel = "set_model"
    case setMaxThinkingTokens = "set_max_thinking_tokens"
    case rewindFiles = "rewind_files"
    case mcpStatus = "mcp_status"
    case mcpMessage = "mcp_message"
    case mcpReconnect = "mcp_reconnect"
    case mcpToggle = "mcp_toggle"
    case mcpSetServers = "mcp_set_servers"
    case hookCallback = "hook_callback"
    case canUseTool = "can_use_tool"
}

// Control request structure
public struct ControlRequest: Codable, Sendable {
    public let type: String = "control_request"
    public let requestId: String
    public let request: ControlRequestPayload

    enum CodingKeys: String, CodingKey {
        case type
        case requestId = "request_id"
        case request
    }
}

// Control response structure
public struct ControlResponse: Codable, Sendable {
    public let type: String = "control_response"
    public let response: ControlResponsePayload
}

public struct ControlResponsePayload: Codable, Sendable {
    public let subtype: String  // "success" or "error"
    public let requestId: String
    public let response: [String: AnyCodable]?
    public let error: String?
}

// Actor managing control protocol
public actor ControlProtocolHandler {
    private var pendingRequests: [String: CheckedContinuation<ControlResponsePayload, Error>] = [:]
    private var requestCounter: Int = 0
    private let stdinHandle: FileHandle
    private let sdkMcpServers: [String: SDKMCPServer]
    private let hookCallbacks: [String: HookCallback]
    private let canUseToolHandler: CanUseToolHandler?

    /// Send a control request and wait for response
    public func sendRequest(_ request: ControlRequest) async throws -> ControlResponsePayload {
        let data = try JSONEncoder().encode(request)
        try stdinHandle.write(contentsOf: data)
        try stdinHandle.write(contentsOf: "\n".data(using: .utf8)!)

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.requestId] = continuation
        }
    }

    /// Handle incoming control request from CLI (via wrapper)
    public func handleIncomingRequest(_ request: ControlRequest) async throws -> ControlResponse {
        switch request.request.subtype {
        case .mcpMessage:
            return try await handleMCPMessage(request)
        case .hookCallback:
            return try await handleHookCallback(request)
        case .canUseTool:
            return try await handleCanUseTool(request)
        default:
            throw ControlProtocolError.unknownRequestType(request.request.subtype)
        }
    }

    /// Resolve a pending request when response arrives
    public func resolveRequest(_ requestId: String, response: ControlResponsePayload) {
        pendingRequests[requestId]?.resume(returning: response)
        pendingRequests[requestId] = nil
    }

    private func nextRequestId() -> String {
        requestCounter += 1
        return "swift_req_\(requestCounter)_\(UUID().uuidString.prefix(8))"
    }
}
```

#### sdk-wrapper.mjs Changes

```javascript
import { query } from '@anthropic-ai/claude-agent-sdk';
import * as readline from 'readline';

// Track pending control responses from Swift
const pendingControlResponses = new Map();

async function main() {
    const config = JSON.parse(process.argv[2]);
    const { prompt, options = {}, sdkMcpServerConfigs = [] } = config;

    // Set up stdin reader for control responses from Swift
    const rl = readline.createInterface({
        input: process.stdin,
        crlfDelay: Infinity
    });

    rl.on('line', (line) => {
        try {
            const message = JSON.parse(line);
            if (message.type === 'control_response') {
                const pending = pendingControlResponses.get(message.response.request_id);
                if (pending) {
                    pending.resolve(message.response);
                    pendingControlResponses.delete(message.response.request_id);
                }
            }
        } catch (e) {
            console.error('[SDK-WRAPPER] Error parsing stdin:', e.message);
        }
    });

    // Build SDK options
    const sdkOptions = mapOptions(options);

    // Register SDK MCP servers (type: "sdk")
    if (sdkMcpServerConfigs.length > 0) {
        sdkOptions.mcpServers = sdkOptions.mcpServers || {};
        for (const serverConfig of sdkMcpServerConfigs) {
            sdkOptions.mcpServers[serverConfig.name] = { type: "sdk", name: serverConfig.name };
        }
    }

    // Execute query
    const result = query({ prompt, options: sdkOptions });

    // Process messages
    for await (const message of result) {
        if (message.type === 'control_request') {
            // Forward control request to Swift
            console.log(JSON.stringify(message));

            // Wait for Swift's response
            const response = await waitForControlResponse(message.request_id);

            // The SDK expects us to handle this internally
            // Response is automatically processed by SDK
        } else {
            // Regular message - forward to Swift
            console.log(JSON.stringify(message));
        }
    }
}

function waitForControlResponse(requestId, timeoutMs = 60000) {
    return new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
            pendingControlResponses.delete(requestId);
            reject(new Error(`Control request ${requestId} timed out`));
        }, timeoutMs);

        pendingControlResponses.set(requestId, {
            resolve: (value) => {
                clearTimeout(timeout);
                resolve(value);
            },
            reject
        });
    });
}
```

#### Testing Approach

**Unit Tests** (`Tests/ClaudeCodeSDKTests/Unit/ControlProtocolTests.swift`):

```swift
func testRequestIdCorrelation() async throws {
    let mock = MockSubprocessTransport()
    mock.setResponses([
        """{"type":"control_response","response":{"subtype":"success","request_id":"req_0","response":{}}}"""
    ])

    let handler = ControlProtocolHandler(stdinHandle: mock.stdinHandle)
    let response = try await handler.sendRequest(ControlRequest(subtype: .interrupt))

    XCTAssertEqual(response.subtype, "success")
}

func testConcurrentRequests() async throws {
    // Test multiple concurrent requests with different IDs are correctly correlated
}

func testRequestTimeout() async throws {
    // Test that requests timeout after 60 seconds
}

func testMalformedResponseIgnored() async throws {
    // Test that malformed JSON responses don't crash
}
```

#### Task Checklist

**2.1 Create control message types**
- [ ] Create `ControlProtocol/ControlMessages.swift`
- [ ] Define `ControlRequestSubtype` enum with all 13 subtypes
- [ ] Define `ControlRequest` struct with `type`, `requestId`, `request` fields
- [ ] Define `ControlRequestPayload` struct with subtype-specific data
- [ ] Define `ControlResponse` struct
- [ ] Define `ControlResponsePayload` struct with `subtype`, `requestId`, `response`, `error`
- [ ] Add `CodingKeys` for snake_case ↔ camelCase conversion
- [ ] Define `ControlProtocolError` enum (timeout, unknownRequestType, etc.)
- [ ] Write unit test: `testControlRequestEncoding`
- [ ] Write unit test: `testControlResponseDecoding`
- [ ] Write unit test: `testSnakeCaseCamelCaseConversion`

**2.2 Create ControlProtocolHandler actor**
- [ ] Create `ControlProtocol/ControlProtocolHandler.swift`
- [ ] Define `actor ControlProtocolHandler`
- [ ] Add `pendingRequests: [String: CheckedContinuation<ControlResponsePayload, Error>]`
- [ ] Add `requestCounter: Int` for generating unique IDs
- [ ] Add `stdinHandle: FileHandle` for writing to subprocess
- [ ] Add `sdkMcpServers: [String: SDKMCPServer]` (empty initially)
- [ ] Add `hookCallbacks: [String: HookCallback]` (empty initially)
- [ ] Implement `nextRequestId() -> String`
- [ ] Implement `sendRequest(_ request:) async throws -> ControlResponsePayload`
- [ ] Implement `resolveRequest(_ requestId:, response:)`
- [ ] Implement `handleIncomingRequest(_ request:) async throws -> ControlResponse`
- [ ] Add 60-second timeout for pending requests
- [ ] Write unit test: `testSendRequestWritesToStdin`
- [ ] Write unit test: `testRequestIdCorrelation`
- [ ] Write unit test: `testConcurrentRequestsCorrelatedCorrectly`
- [ ] Write unit test: `testRequestTimeout`
- [ ] Write unit test: `testResolveRequestResumesCorrectContinuation`

**2.3 Integrate with AgentSDKBackend**
- [ ] Add `controlHandler: ControlProtocolHandler` property to AgentSDKBackend
- [ ] Create ControlProtocolHandler in `executeSDKCommand()` with process stdin
- [ ] Pass stdinHandle from process to handler
- [ ] Update stream processing to detect `control_request` messages
- [ ] When `control_request` detected, call `controlHandler.handleIncomingRequest()`
- [ ] Write `control_response` back to stdin after handling
- [ ] Write integration test: `testControlRequestHandledDuringStream`

**2.4 Update sdk-wrapper.mjs for bidirectional communication**
- [ ] Import `readline` module
- [ ] Create readline interface on `process.stdin`
- [ ] Add `pendingControlResponses` Map for tracking
- [ ] Add `rl.on('line', ...)` handler to parse control_response from Swift
- [ ] When `control_response` received, resolve pending promise
- [ ] Implement `waitForControlResponse(requestId, timeoutMs)` function
- [ ] In message loop, detect `control_request` messages
- [ ] Forward `control_request` to Swift via `console.log()`
- [ ] Wait for response from Swift via `waitForControlResponse()`
- [ ] Remove `process.exit(0)` for no-tools case (keep stdin open)
- [ ] Write manual test: verify wrapper doesn't exit prematurely

**2.5 Create test infrastructure**
- [ ] Create `Mocks/MockSubprocessTransport.swift` protocol and mock
- [ ] Implement `setResponses(_ lines:)` for canned responses
- [ ] Implement `stdinReceived` to capture writes
- [ ] Implement `setControlResponse(forSubtype:response:)` for control responses
- [ ] Create `Mocks/ControlProtocolMocks.swift` with response factories
- [ ] Add `MockResponses.controlRequest(...)` factory
- [ ] Add `MockResponses.controlResponse(...)` factory

---

### Phase 3: SDK MCP Tools

**Priority**: Highest (main user-facing feature)

**Complexity**: Large (L)

**Goal**: Define tools in Swift that Claude can invoke in-process.

#### Files to Create/Modify

| File | Purpose |
|------|---------|
| New: `MCP/SDKMCPServer.swift` | In-process MCP server |
| New: `MCP/MCPToolDefinition.swift` | Tool definition types |
| New: `MCP/MCPToolResult.swift` | Tool result types |
| New: `MCP/JSONSchema.swift` | JSON Schema generation from Codable |
| `API/ClaudeCodeOptions.swift` | Add `sdkMcpServers` property |
| `Resources/sdk-wrapper.mjs` | Route mcp_message to Swift |
| `ControlProtocol/ControlProtocolHandler.swift` | Handle mcp_message routing |

#### Swift API Design

```swift
// MARK: - Tool Result Types

public enum MCPToolResult: Sendable {
    case text(String)
    case image(data: Data, mimeType: String)
    case resource(uri: String, mimeType: String?, text: String?)
    case error(String, isRetryable: Bool = false)

    func toMCPContent() -> [[String: Any]] {
        switch self {
        case .text(let text):
            return [["type": "text", "text": text]]
        case .image(let data, let mimeType):
            return [["type": "image", "data": data.base64EncodedString(), "mimeType": mimeType]]
        case .resource(let uri, let mimeType, let text):
            var content: [String: Any] = ["type": "resource", "resource": ["uri": uri]]
            if let mimeType { content["mimeType"] = mimeType }
            if let text { content["text"] = text }
            return [content]
        case .error(let message, let isRetryable):
            return [["type": "text", "text": message, "isError": true, "isRetryable": isRetryable]]
        }
    }
}

// MARK: - Type-Erased Tool

public struct AnyMCPTool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]
    private let handler: @Sendable (Data) async throws -> MCPToolResult

    public init<Input: Decodable & Sendable>(
        name: String,
        description: String,
        inputSchema: [String: Any],
        inputType: Input.Type,
        handler: @escaping @Sendable (Input) async throws -> MCPToolResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.handler = { data in
            let decoder = JSONDecoder()
            let input = try decoder.decode(Input.self, from: data)
            return try await handler(input)
        }
    }

    func execute(inputData: Data) async throws -> MCPToolResult {
        try await handler(inputData)
    }
}

// MARK: - Tool Builder Function

public func tool<Input: Decodable & Sendable>(
    _ name: String,
    description: String,
    inputSchema: [String: Any],
    handler: @escaping @Sendable (Input) async throws -> MCPToolResult
) -> AnyMCPTool {
    AnyMCPTool(
        name: name,
        description: description,
        inputSchema: inputSchema,
        inputType: Input.self,
        handler: handler
    )
}

// MARK: - Result Builder

@resultBuilder
public struct MCPToolBuilder {
    public static func buildBlock(_ tools: AnyMCPTool...) -> [AnyMCPTool] {
        tools
    }

    public static func buildArray(_ components: [[AnyMCPTool]]) -> [AnyMCPTool] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [AnyMCPTool]?) -> [AnyMCPTool] {
        component ?? []
    }
}

// MARK: - SDK MCP Server

public final class SDKMCPServer: Sendable {
    public let name: String
    public let version: String
    private let tools: [String: AnyMCPTool]

    public init(
        name: String,
        version: String = "1.0.0",
        @MCPToolBuilder tools: () -> [AnyMCPTool]
    ) {
        self.name = name
        self.version = version
        let toolList = tools()
        self.tools = Dictionary(uniqueKeysWithValues: toolList.map { ($0.name, $0) })
    }

    /// Handle JSONRPC request from CLI
    public func handleRequest(_ request: JSONRPCRequest) async throws -> JSONRPCResponse {
        switch request.method {
        case "initialize":
            return JSONRPCResponse(
                id: request.id,
                result: [
                    "protocolVersion": "2024-11-05",
                    "capabilities": ["tools": [:]],
                    "serverInfo": ["name": name, "version": version]
                ]
            )

        case "notifications/initialized":
            return JSONRPCResponse(id: request.id, result: [:])

        case "tools/list":
            let toolDefs = tools.values.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": tool.inputSchema
                ] as [String: Any]
            }
            return JSONRPCResponse(id: request.id, result: ["tools": toolDefs])

        case "tools/call":
            guard let params = request.params,
                  let toolName = params["name"] as? String,
                  let arguments = params["arguments"] as? [String: Any],
                  let tool = tools[toolName] else {
                throw MCPError.toolNotFound(request.params?["name"] as? String ?? "unknown")
            }

            let inputData = try JSONSerialization.data(withJSONObject: arguments)
            let result = try await tool.execute(inputData: inputData)

            return JSONRPCResponse(
                id: request.id,
                result: ["content": result.toMCPContent()]
            )

        default:
            throw MCPError.unknownMethod(request.method)
        }
    }
}

// MARK: - JSONRPC Types

public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: Int?
    public let method: String
    public let params: [String: Any]?
}

public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String = "2.0"
    public let id: Int?
    public let result: [String: Any]?
    public let error: JSONRPCError?
}

// MARK: - ClaudeCodeOptions Extension

extension ClaudeCodeOptions {
    /// In-process MCP servers with tools defined in Swift
    public var sdkMcpServers: [String: SDKMCPServer]?
}
```

#### Usage Example

```swift
// Define input type
struct CalculatorInput: Codable, Sendable {
    let a: Double
    let b: Double
    let operation: String
}

// Create tool
let calculator = tool(
    "calculate",
    description: "Performs basic arithmetic operations",
    inputSchema: [
        "type": "object",
        "properties": [
            "a": ["type": "number", "description": "First operand"],
            "b": ["type": "number", "description": "Second operand"],
            "operation": ["type": "string", "enum": ["add", "subtract", "multiply", "divide"]]
        ],
        "required": ["a", "b", "operation"]
    ]
) { (input: CalculatorInput) -> MCPToolResult in
    let result: Double
    switch input.operation {
    case "add": result = input.a + input.b
    case "subtract": result = input.a - input.b
    case "multiply": result = input.a * input.b
    case "divide":
        guard input.b != 0 else { return .error("Division by zero") }
        result = input.a / input.b
    default:
        return .error("Unknown operation: \(input.operation)")
    }
    return .text("\(result)")
}

// Create server
let mathServer = SDKMCPServer(name: "math-tools") {
    calculator
}

// Use in options
var options = ClaudeCodeOptions()
options.sdkMcpServers = ["math-tools": mathServer]

let result = try await client.runSinglePrompt(
    prompt: "What is 15 * 7?",
    outputFormat: .streamJson,
    options: options
)
```

#### Message Flow

```
1. Swift creates SDKMCPServer with tools

2. Swift passes sdkMcpServerConfigs to sdk-wrapper.mjs:
   { "sdkMcpServerConfigs": [{ "name": "math-tools" }] }

3. sdk-wrapper registers with SDK:
   mcpServers: { "math-tools": { type: "sdk", name: "math-tools" } }

4. Claude decides to use calculator tool

5. CLI sends control_request to sdk-wrapper:
   {
     "type": "control_request",
     "request_id": "req_42",
     "request": {
       "subtype": "mcp_message",
       "server_name": "math-tools",
       "message": {
         "jsonrpc": "2.0",
         "id": 1,
         "method": "tools/call",
         "params": { "name": "calculate", "arguments": { "a": 15, "b": 7, "operation": "multiply" } }
       }
     }
   }

6. sdk-wrapper forwards to Swift via stdout

7. Swift's ControlProtocolHandler routes to SDKMCPServer

8. SDKMCPServer.handleRequest() invokes tool handler

9. Swift sends control_response via stdin:
   {
     "type": "control_response",
     "response": {
       "subtype": "success",
       "request_id": "req_42",
       "response": {
         "mcp_response": {
           "jsonrpc": "2.0",
           "id": 1,
           "result": { "content": [{ "type": "text", "text": "105" }] }
         }
       }
     }
   }

10. sdk-wrapper routes response back to SDK
```

#### Testing Approach

**Unit Tests**:

```swift
func testToolSchemaGeneration() async throws {
    let tool = tool("test", description: "Test", inputSchema: [...]) { ... }
    XCTAssertEqual(tool.inputSchema["type"] as? String, "object")
}

func testToolHandlerExecution() async throws {
    var handlerCalled = false
    let tool = tool("test", description: "Test", inputSchema: [:]) { (input: TestInput) in
        handlerCalled = true
        return .text("result")
    }

    let inputData = try JSONEncoder().encode(TestInput())
    let result = try await tool.execute(inputData: inputData)

    XCTAssertTrue(handlerCalled)
    XCTAssertEqual(result, .text("result"))
}

func testSDKMCPServerToolsList() async throws {
    let server = SDKMCPServer(name: "test") {
        tool("greet", ...) { ... }
        tool("farewell", ...) { ... }
    }

    let request = JSONRPCRequest(jsonrpc: "2.0", id: 1, method: "tools/list", params: nil)
    let response = try await server.handleRequest(request)

    let tools = response.result?["tools"] as? [[String: Any]]
    XCTAssertEqual(tools?.count, 2)
}

func testSDKMCPServerToolsCall() async throws {
    let server = SDKMCPServer(name: "calc") {
        tool("add", description: "Add", inputSchema: [...]) { (input: AddInput) in
            .text("\(input.a + input.b)")
        }
    }

    let request = JSONRPCRequest(
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: ["name": "add", "arguments": ["a": 5, "b": 3]]
    )
    let response = try await server.handleRequest(request)

    let content = response.result?["content"] as? [[String: Any]]
    XCTAssertEqual(content?.first?["text"] as? String, "8")
}
```

**Integration Tests**:

```swift
func testEndToEndToolCall() async throws {
    let mock = MockSubprocessTransport()
    // Set up mock to send mcp_message control request
    mock.setResponses([
        MockResponses.initMessage(),
        MockResponses.mcpMessageRequest(
            requestId: "req_1",
            serverName: "calc",
            method: "tools/call",
            params: ["name": "add", "arguments": ["a": 2, "b": 3]]
        ),
        MockResponses.resultMessage()
    ])

    let calcServer = SDKMCPServer(name: "calc") {
        tool("add", ...) { (input: AddInput) in .text("\(input.a + input.b)") }
    }

    var options = ClaudeCodeOptions()
    options.sdkMcpServers = ["calc": calcServer]

    let backend = AgentSDKBackend(transport: mock, controlHandler: ...)
    _ = try await backend.runSinglePrompt(prompt: "Add 2 + 3", options: options)

    // Verify control response was sent
    let responses = mock.stdinReceived.compactMap { try? JSONDecoder().decode(ControlResponse.self, from: $0) }
    XCTAssertEqual(responses.first?.response.response?["mcp_response"]?["result"]?["content"]?[0]?["text"], "5")
}
```

#### Task Checklist

**3.1 Create MCPToolResult types**
- [ ] Create `MCP/MCPToolResult.swift`
- [ ] Define `MCPToolResult` enum with cases: `text`, `image`, `resource`, `error`
- [ ] Implement `toMCPContent() -> [[String: Any]]` for each case
- [ ] Handle `isError` and `isRetryable` flags for error case
- [ ] Write unit test: `testMCPToolResultTextSerialization`
- [ ] Write unit test: `testMCPToolResultImageSerialization`
- [ ] Write unit test: `testMCPToolResultErrorSerialization`

**3.2 Create AnyMCPTool type-erased wrapper**
- [ ] Create `MCP/MCPToolDefinition.swift`
- [ ] Define `AnyMCPTool` struct with `name`, `description`, `inputSchema`
- [ ] Add private `handler: @Sendable (Data) async throws -> MCPToolResult`
- [ ] Implement generic initializer that wraps typed handler
- [ ] Implement `execute(inputData:) async throws -> MCPToolResult`
- [ ] Write unit test: `testAnyMCPToolExecution`
- [ ] Write unit test: `testAnyMCPToolInputDecoding`

**3.3 Create tool() builder function**
- [ ] Add `public func tool<Input>(_ name:description:inputSchema:handler:) -> AnyMCPTool`
- [ ] Ensure `Input` conforms to `Decodable & Sendable`
- [ ] Write unit test: `testToolBuilderCreatesValidTool`

**3.4 Create MCPToolBuilder result builder**
- [ ] Define `@resultBuilder public struct MCPToolBuilder`
- [ ] Implement `buildBlock(_ tools: AnyMCPTool...) -> [AnyMCPTool]`
- [ ] Implement `buildArray(_ components:) -> [AnyMCPTool]`
- [ ] Implement `buildOptional(_ component:) -> [AnyMCPTool]`
- [ ] Implement `buildEither(first:)` and `buildEither(second:)`
- [ ] Write unit test: `testMCPToolBuilderMultipleTools`
- [ ] Write unit test: `testMCPToolBuilderConditional`

**3.5 Create SDKMCPServer**
- [ ] Create `MCP/SDKMCPServer.swift`
- [ ] Define `public final class SDKMCPServer: Sendable`
- [ ] Add `name: String` and `version: String` properties
- [ ] Add `tools: [String: AnyMCPTool]` private dictionary
- [ ] Implement initializer with `@MCPToolBuilder tools` parameter
- [ ] Implement `handleRequest(_ request: JSONRPCRequest) async throws -> JSONRPCResponse`
- [ ] Handle `initialize` method - return protocol version, capabilities, serverInfo
- [ ] Handle `notifications/initialized` method - return empty result
- [ ] Handle `tools/list` method - return tool definitions
- [ ] Handle `tools/call` method - route to handler, return result
- [ ] Throw `MCPError.unknownMethod` for unrecognized methods
- [ ] Throw `MCPError.toolNotFound` for unknown tool names
- [ ] Write unit test: `testSDKMCPServerInitialize`
- [ ] Write unit test: `testSDKMCPServerToolsList`
- [ ] Write unit test: `testSDKMCPServerToolsCall`
- [ ] Write unit test: `testSDKMCPServerUnknownMethod`
- [ ] Write unit test: `testSDKMCPServerUnknownTool`

**3.6 Create JSONRPC types**
- [ ] Create `MCP/JSONRPCTypes.swift`
- [ ] Define `JSONRPCRequest` struct with `jsonrpc`, `id`, `method`, `params`
- [ ] Define `JSONRPCResponse` struct with `jsonrpc`, `id`, `result`, `error`
- [ ] Define `JSONRPCError` struct with `code`, `message`, `data`
- [ ] Define `MCPError` enum (toolNotFound, unknownMethod, invalidParams)
- [ ] Write unit test: `testJSONRPCRequestDecoding`
- [ ] Write unit test: `testJSONRPCResponseEncoding`

**3.7 Add sdkMcpServers to ClaudeCodeOptions**
- [ ] Add `public var sdkMcpServers: [String: SDKMCPServer]?` to `ClaudeCodeOptions`
- [ ] Update `ClaudeCodeOptions.init()` if needed

**3.8 Update ControlProtocolHandler for MCP routing**
- [ ] Add `sdkMcpServers` parameter to ControlProtocolHandler init
- [ ] Implement `handleMCPMessage(_ request:) async throws -> ControlResponse`
- [ ] Extract `server_name` from request
- [ ] Look up server in `sdkMcpServers` dictionary
- [ ] Extract `message` as JSONRPCRequest
- [ ] Call `server.handleRequest(message)`
- [ ] Wrap response in ControlResponse with `mcp_response` field
- [ ] Write unit test: `testControlHandlerRoutesMCPMessage`
- [ ] Write unit test: `testControlHandlerMCPUnknownServer`

**3.9 Update AgentSDKBackend to pass SDK server configs**
- [ ] Extract `sdkMcpServers` from options in `executeSDKCommand()`
- [ ] Build `sdkMcpServerConfigs` array with server names
- [ ] Add to config JSON: `"sdkMcpServerConfigs": [{"name": "..."}]`
- [ ] Pass `sdkMcpServers` dictionary to ControlProtocolHandler
- [ ] Write integration test: `testAgentSDKBackendPassesServerConfigs`

**3.10 Update sdk-wrapper.mjs for SDK server registration**
- [ ] Extract `sdkMcpServerConfigs` from config
- [ ] Register each as `{ type: "sdk", name: "..." }` in mcpServers
- [ ] Ensure SDK MCP type triggers control protocol routing in Agent SDK
- [ ] Write manual test: verify SDK server appears in init message

**3.11 End-to-end integration test**
- [ ] Write test: Create calculator tool, mock MCP message control request
- [ ] Verify tool handler invoked with correct input
- [ ] Verify control response contains correct result
- [ ] Write test: Multiple tools on same server
- [ ] Write test: Multiple SDK servers

---

### Phase 4: Hooks System

**Priority**: High

**Complexity**: Medium (M)

**Goal**: Intercept lifecycle events for tool use, permissions, sessions.

#### Files to Create/Modify

| File | Purpose |
|------|---------|
| New: `Hooks/HooksConfiguration.swift` | Hook registration and configuration |
| New: `Hooks/HookEventTypes.swift` | All 13 hook event types |
| New: `Hooks/HookInputTypes.swift` | Input structs for each hook type |
| New: `Hooks/HookOutput.swift` | Output types for hook responses |
| `API/ClaudeCodeOptions.swift` | Add `hooks` property |
| `ControlProtocol/ControlProtocolHandler.swift` | Handle hook_callback routing |

#### Swift API Design

```swift
// MARK: - Hook Event Types (all 13)

public enum HookEventType: String, Codable, Sendable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case notification = "Notification"
    case userPromptSubmit = "UserPromptSubmit"
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case stop = "Stop"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case permissionRequest = "PermissionRequest"
    case setup = "Setup"
}

// MARK: - Hook Input Types

/// Base fields present in all hook inputs
public protocol HookInput: Sendable, Decodable {
    var sessionId: String { get }
    var transcriptPath: String { get }
    var cwd: String { get }
    var permissionMode: PermissionMode? { get }
    var hookEventName: String { get }
}

public struct PreToolUseInput: HookInput {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode?
    public let hookEventName: String
    public let toolName: String
    public let toolInput: [String: AnyCodable]
    public let toolUseId: String
}

public struct PostToolUseInput: HookInput {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode?
    public let hookEventName: String
    public let toolName: String
    public let toolInput: [String: AnyCodable]
    public let toolResponse: [String: AnyCodable]
    public let toolUseId: String
}

public struct PostToolUseFailureInput: HookInput {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode?
    public let hookEventName: String
    public let toolName: String
    public let toolInput: [String: AnyCodable]
    public let toolUseId: String
    public let error: String
    public let isInterrupt: Bool?
}

public struct NotificationInput: HookInput {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode?
    public let hookEventName: String
    public let message: String
    public let notificationType: String
    public let title: String?
}

public struct SessionStartInput: HookInput {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode?
    public let hookEventName: String
    public let source: String  // "startup" | "resume" | "clear" | "compact"
    public let agentType: String?
    public let model: String?
}

public struct SessionEndInput: HookInput {
    public let sessionId: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode?
    public let hookEventName: String
    public let reason: String  // ExitReason
}

// ... similar structs for Stop, SubagentStart, SubagentStop, PreCompact, PermissionRequest, Setup

// MARK: - Hook Output

public struct HookOutput: Sendable, Codable {
    /// Whether to continue execution (default: true)
    public var shouldContinue: Bool = true

    /// Suppress output from this hook
    public var suppressOutput: Bool = false

    /// Reason for stopping (if shouldContinue = false)
    public var stopReason: String?

    /// System message to inject
    public var systemMessage: String?

    /// Hook-specific output (varies by hook type)
    public var hookSpecificOutput: HookSpecificOutput?

    public init(
        shouldContinue: Bool = true,
        suppressOutput: Bool = false,
        stopReason: String? = nil,
        systemMessage: String? = nil,
        hookSpecificOutput: HookSpecificOutput? = nil
    ) {
        self.shouldContinue = shouldContinue
        self.suppressOutput = suppressOutput
        self.stopReason = stopReason
        self.systemMessage = systemMessage
        self.hookSpecificOutput = hookSpecificOutput
    }

    /// Convenience: Allow execution to continue
    public static var allow: HookOutput { HookOutput() }

    /// Convenience: Block execution
    public static func block(reason: String) -> HookOutput {
        HookOutput(shouldContinue: false, stopReason: reason)
    }
}

public enum HookSpecificOutput: Sendable, Codable {
    case preToolUse(PreToolUseHookOutput)
    case postToolUse(PostToolUseHookOutput)
    case permissionRequest(PermissionRequestHookOutput)
}

public struct PreToolUseHookOutput: Sendable, Codable {
    public var permissionDecision: PermissionDecision?
    public var permissionDecisionReason: String?
    public var updatedInput: [String: AnyCodable]?
    public var additionalContext: String?
}

public enum PermissionDecision: String, Sendable, Codable {
    case allow
    case deny
    case ask
}

// MARK: - Hook Matcher

public struct HookMatcher<Input: HookInput>: Sendable {
    public let matcher: String?  // Regex pattern for tool name filtering
    public let timeout: TimeInterval
    public let handler: @Sendable (Input, String?) async throws -> HookOutput

    public init(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60,
        handler: @escaping @Sendable (Input, String?) async throws -> HookOutput
    ) {
        self.matcher = pattern
        self.timeout = timeout
        self.handler = handler
    }
}

// MARK: - Hooks Configuration

public struct HooksConfiguration: Sendable {
    public var preToolUse: [HookMatcher<PreToolUseInput>] = []
    public var postToolUse: [HookMatcher<PostToolUseInput>] = []
    public var postToolUseFailure: [HookMatcher<PostToolUseFailureInput>] = []
    public var notification: [HookMatcher<NotificationInput>] = []
    public var userPromptSubmit: [HookMatcher<UserPromptSubmitInput>] = []
    public var sessionStart: [HookMatcher<SessionStartInput>] = []
    public var sessionEnd: [HookMatcher<SessionEndInput>] = []
    public var stop: [HookMatcher<StopInput>] = []
    public var subagentStart: [HookMatcher<SubagentStartInput>] = []
    public var subagentStop: [HookMatcher<SubagentStopInput>] = []
    public var preCompact: [HookMatcher<PreCompactInput>] = []
    public var permissionRequest: [HookMatcher<PermissionRequestInput>] = []
    public var setup: [HookMatcher<SetupInput>] = []

    public init() {}
}

// MARK: - ClaudeCodeOptions Extension

extension ClaudeCodeOptions {
    /// Hook configuration for lifecycle interception
    public var hooks: HooksConfiguration?

    /// Fluent API for adding PreToolUse hooks
    public mutating func onPreToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60,
        handler: @escaping @Sendable (PreToolUseInput, String?) async throws -> HookOutput
    ) {
        if hooks == nil { hooks = HooksConfiguration() }
        hooks?.preToolUse.append(HookMatcher(matching: pattern, timeout: timeout, handler: handler))
    }

    /// Fluent API for adding PostToolUse hooks
    public mutating func onPostToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60,
        handler: @escaping @Sendable (PostToolUseInput, String?) async throws -> HookOutput
    ) {
        if hooks == nil { hooks = HooksConfiguration() }
        hooks?.postToolUse.append(HookMatcher(matching: pattern, timeout: timeout, handler: handler))
    }

    // ... similar methods for all 13 hook types
}
```

#### Usage Example

```swift
var options = ClaudeCodeOptions()

// Block dangerous Bash commands
options.onPreToolUse(matching: "Bash") { input, toolUseId in
    let command = input.toolInput["command"]?.stringValue ?? ""

    if command.contains("rm -rf") || command.contains("sudo") {
        return .block(reason: "Dangerous command blocked: \(command)")
    }

    return .allow
}

// Log all tool completions
options.onPostToolUse { input, toolUseId in
    print("Tool \(input.toolName) completed")
    return .allow
}

// Handle session start
options.hooks?.sessionStart.append(HookMatcher { input, _ in
    print("Session started: \(input.sessionId), source: \(input.source)")
    return .allow
})

let result = try await client.runSinglePrompt(
    prompt: "Delete all files",
    outputFormat: .streamJson,
    options: options
)
```

#### Testing Approach

```swift
func testPreToolUseBlocksDangerousCommand() async throws {
    let mock = MockSubprocessTransport()
    mock.setResponses([
        MockResponses.initMessage(),
        MockResponses.hookCallbackRequest(
            requestId: "hook_1",
            callbackId: "hook_0",
            toolName: "Bash",
            toolInput: ["command": "rm -rf /"],
            toolUseId: "tool_123"
        ),
        MockResponses.resultMessage()
    ])

    var options = ClaudeCodeOptions()
    options.onPreToolUse(matching: "Bash") { input, _ in
        if input.toolInput["command"]?.stringValue?.contains("rm -rf") == true {
            return .block(reason: "Blocked")
        }
        return .allow
    }

    let backend = AgentSDKBackend(transport: mock, ...)
    _ = try await backend.runSinglePrompt(prompt: "...", options: options)

    // Verify hook response was sent with shouldContinue = false
    let responses = mock.stdinReceived.compactMap { try? JSONDecoder().decode(ControlResponse.self, from: $0) }
    let hookResponse = responses.first
    XCTAssertEqual(hookResponse?.response.response?["continue"] as? Bool, false)
}

func testHookPatternMatching() async throws {
    var hookCalled = false
    var options = ClaudeCodeOptions()
    options.onPreToolUse(matching: "Read|Write") { input, _ in
        hookCalled = true
        return .allow
    }

    // Simulate Bash tool (should NOT match pattern)
    // ... test that hookCalled remains false

    // Simulate Read tool (should match pattern)
    // ... test that hookCalled becomes true
}
```

#### Task Checklist

**4.1 Create hook event types enum**
- [ ] Create `Hooks/HookEventTypes.swift`
- [ ] Define `HookEventType` enum with all 13 cases
- [ ] Add raw values matching TypeScript: "PreToolUse", "PostToolUse", etc.
- [ ] Conform to `String`, `Codable`, `Sendable`
- [ ] Write unit test: `testHookEventTypeRawValues`

**4.2 Create HookInput protocol and types**
- [ ] Create `Hooks/HookInputTypes.swift`
- [ ] Define `HookInput` protocol with common fields
- [ ] Implement `PreToolUseInput` with `toolName`, `toolInput`, `toolUseId`
- [ ] Implement `PostToolUseInput` with `toolName`, `toolInput`, `toolResponse`, `toolUseId`
- [ ] Implement `PostToolUseFailureInput` with `error`, `isInterrupt`
- [ ] Implement `NotificationInput` with `message`, `notificationType`, `title`
- [ ] Implement `UserPromptSubmitInput` with `prompt`
- [ ] Implement `SessionStartInput` with `source`, `agentType`, `model`
- [ ] Implement `SessionEndInput` with `reason`
- [ ] Implement `StopInput` with `stopHookActive`
- [ ] Implement `SubagentStartInput` with `agentId`, `agentType`
- [ ] Implement `SubagentStopInput` with `agentId`, `agentTranscriptPath`, `stopHookActive`
- [ ] Implement `PreCompactInput` with `trigger`, `customInstructions`
- [ ] Implement `PermissionRequestInput` with `toolName`, `toolInput`, `permissionSuggestions`
- [ ] Implement `SetupInput` with `trigger`
- [ ] Write unit test: `testPreToolUseInputDecoding`
- [ ] Write unit test: `testSessionStartInputDecoding`

**4.3 Create HookOutput types**
- [ ] Create `Hooks/HookOutput.swift`
- [ ] Define `HookOutput` struct with `shouldContinue`, `suppressOutput`, `stopReason`, `systemMessage`
- [ ] Add `hookSpecificOutput: HookSpecificOutput?`
- [ ] Add static `var allow: HookOutput`
- [ ] Add static `func block(reason:) -> HookOutput`
- [ ] Define `HookSpecificOutput` enum with cases for each hook type
- [ ] Define `PreToolUseHookOutput` with `permissionDecision`, `updatedInput`, `additionalContext`
- [ ] Define `PostToolUseHookOutput` with `additionalContext`, `updatedMCPToolOutput`
- [ ] Define `PermissionDecision` enum: `allow`, `deny`, `ask`
- [ ] Write unit test: `testHookOutputEncoding`
- [ ] Write unit test: `testHookOutputAllowConvenience`
- [ ] Write unit test: `testHookOutputBlockConvenience`

**4.4 Create HookMatcher generic struct**
- [ ] Create `Hooks/HookMatcher.swift`
- [ ] Define `HookMatcher<Input: HookInput>` struct
- [ ] Add `matcher: String?` for regex pattern
- [ ] Add `timeout: TimeInterval` with default 60
- [ ] Add `handler: @Sendable (Input, String?) async throws -> HookOutput`
- [ ] Implement `matches(toolName:) -> Bool` using regex
- [ ] Write unit test: `testHookMatcherPatternMatches`
- [ ] Write unit test: `testHookMatcherPatternNoMatch`
- [ ] Write unit test: `testHookMatcherNilPatternMatchesAll`

**4.5 Create HooksConfiguration**
- [ ] Create `Hooks/HooksConfiguration.swift`
- [ ] Define `HooksConfiguration` struct
- [ ] Add array property for each of 13 hook types
- [ ] Initialize all arrays to empty
- [ ] Write unit test: `testHooksConfigurationInit`

**4.6 Add hooks to ClaudeCodeOptions**
- [ ] Add `public var hooks: HooksConfiguration?` to ClaudeCodeOptions
- [ ] Add `onPreToolUse(matching:timeout:handler:)` fluent method
- [ ] Add `onPostToolUse(matching:timeout:handler:)` fluent method
- [ ] Add `onPostToolUseFailure(matching:timeout:handler:)` fluent method
- [ ] Add `onNotification(handler:)` fluent method
- [ ] Add `onUserPromptSubmit(handler:)` fluent method
- [ ] Add `onSessionStart(handler:)` fluent method
- [ ] Add `onSessionEnd(handler:)` fluent method
- [ ] Add `onStop(handler:)` fluent method
- [ ] Add `onSubagentStart(handler:)` fluent method
- [ ] Add `onSubagentStop(handler:)` fluent method
- [ ] Add `onPreCompact(handler:)` fluent method
- [ ] Add `onPermissionRequest(handler:)` fluent method
- [ ] Add `onSetup(handler:)` fluent method
- [ ] Write unit test: `testOptionsOnPreToolUseAddsHook`
- [ ] Write unit test: `testOptionsMultipleHooks`

**4.7 Update ControlProtocolHandler for hook callbacks**
- [ ] Add `hookCallbacks` parameter to init
- [ ] Generate unique callback IDs for each registered hook
- [ ] Build hook config for initialize request
- [ ] Implement `handleHookCallback(_ request:) async throws -> ControlResponse`
- [ ] Extract `callback_id` and `input` from request
- [ ] Look up hook by callback ID
- [ ] Parse input to correct HookInput type based on event
- [ ] Invoke handler with parsed input and tool_use_id
- [ ] Apply timeout using `withTimeout()`
- [ ] Convert HookOutput to control response format
- [ ] Write unit test: `testControlHandlerRoutesHookCallback`
- [ ] Write unit test: `testHookCallbackTimeout`

**4.8 Update AgentSDKBackend for hooks**
- [ ] Extract hooks from options
- [ ] Build callback registry mapping callback_id → handler
- [ ] Pass hooks config in initialize control request
- [ ] Pass hookCallbacks to ControlProtocolHandler
- [ ] Write integration test: `testPreToolUseHookBlocks`
- [ ] Write integration test: `testPostToolUseHookLogs`

**4.9 Update sdk-wrapper.mjs for hooks**
- [ ] Extract hooks config from options
- [ ] Pass hooks to SDK query options
- [ ] Ensure hook_callback control requests flow correctly
- [ ] Write manual test: verify hook fires during tool use

---

### Phase 5: Query Control Methods

**Priority**: Medium

**Complexity**: Medium (M)

**Goal**: Dynamic control of running queries.

#### Files to Modify

| File | Changes |
|------|---------|
| `API/QueryStream.swift` | Add control methods |
| `ControlProtocol/ControlProtocolHandler.swift` | Add sendRequest implementations |
| New: `API/QueryControlTypes.swift` | Result types for control methods |

#### Swift API Design

```swift
extension QueryStream {
    // MARK: - Control Methods

    /// Interrupt the current operation
    public func interrupt() async throws {
        try await controlHandler.sendRequest(
            ControlRequest(subtype: .interrupt)
        )
    }

    /// Change the model during execution
    public func setModel(_ model: String) async throws {
        try await controlHandler.sendRequest(
            ControlRequest(subtype: .setModel, data: ["model": model])
        )
    }

    /// Change permission mode during execution
    public func setPermissionMode(_ mode: PermissionMode) async throws {
        try await controlHandler.sendRequest(
            ControlRequest(subtype: .setPermissionMode, data: ["mode": mode.rawValue])
        )
    }

    /// Set maximum thinking tokens
    public func setMaxThinkingTokens(_ tokens: Int?) async throws {
        try await controlHandler.sendRequest(
            ControlRequest(subtype: .setMaxThinkingTokens, data: ["value": tokens as Any])
        )
    }

    // MARK: - MCP Management

    /// Reconnect a specific MCP server
    public func reconnectMcpServer(_ serverName: String) async throws {
        try await controlHandler.sendRequest(
            ControlRequest(subtype: .mcpReconnect, data: ["server_name": serverName])
        )
    }

    /// Toggle MCP server enabled state
    public func toggleMcpServer(_ serverName: String, enabled: Bool) async throws {
        try await controlHandler.sendRequest(
            ControlRequest(subtype: .mcpToggle, data: ["server_name": serverName, "enabled": enabled])
        )
    }

    /// Set MCP servers dynamically
    public func setMcpServers(_ servers: [String: McpServerConfiguration]) async throws -> McpSetServersResult {
        let response = try await controlHandler.sendRequest(
            ControlRequest(subtype: .mcpSetServers, data: ["servers": servers.encoded()])
        )
        return try JSONDecoder().decode(McpSetServersResult.self, from: response.data)
    }

    // MARK: - State Management

    /// Restore files to a previous message state
    public func rewindFiles(to userMessageId: String, dryRun: Bool = false) async throws -> RewindFilesResult {
        let response = try await controlHandler.sendRequest(
            ControlRequest(subtype: .rewindFiles, data: [
                "user_message_id": userMessageId,
                "dry_run": dryRun
            ])
        )
        return try JSONDecoder().decode(RewindFilesResult.self, from: response.data)
    }

    // MARK: - Query Information

    /// Available slash commands (from init message)
    public var supportedCommands: [SlashCommand] {
        get async throws {
            guard let initMessage = initMessage else {
                throw ClaudeCodeError.notInitialized
            }
            return initMessage.slashCommands ?? []
        }
    }

    /// MCP server status (from init message)
    public var mcpServerStatus: [MCPServerStatus] {
        get async {
            initMessage?.mcpServers.map { MCPServerStatus(name: $0.name, status: $0.status) } ?? []
        }
    }

    /// Get account information
    public func accountInfo() async throws -> AccountInfo {
        let response = try await controlHandler.sendRequest(
            ControlRequest(subtype: .accountInfo)
        )
        return try JSONDecoder().decode(AccountInfo.self, from: response.data)
    }

    /// Get available models
    public func supportedModels() async throws -> [ModelInfo] {
        let response = try await controlHandler.sendRequest(
            ControlRequest(subtype: .supportedModels)
        )
        return try JSONDecoder().decode([ModelInfo].self, from: response.data)
    }
}

// MARK: - Result Types

public struct RewindFilesResult: Codable, Sendable {
    public let canRewind: Bool
    public let error: String?
    public let filesChanged: [String]?
    public let insertions: Int?
    public let deletions: Int?
}

public struct McpSetServersResult: Codable, Sendable {
    public let added: [String]
    public let removed: [String]
    public let errors: [String: String]
}

public struct SlashCommand: Codable, Sendable {
    public let name: String
    public let description: String
    public let argumentHint: String
}

public struct ModelInfo: Codable, Sendable {
    public let value: String
    public let displayName: String
    public let description: String
}

public struct AccountInfo: Codable, Sendable {
    public let email: String?
    public let organization: String?
    public let subscriptionType: String?
    public let tokenSource: String?
}
```

#### Testing Approach

```swift
func testInterrupt() async throws {
    let mock = MockSubprocessTransport()
    // ... setup

    let stream = try await backend.runSinglePrompt(...)
    guard case .stream(let queryStream) = stream else { XCTFail(); return }

    try await queryStream.interrupt()

    // Verify interrupt request was sent
    let requests = mock.stdinReceived.compactMap { try? JSONDecoder().decode(ControlRequest.self, from: $0) }
    XCTAssertTrue(requests.contains { $0.request.subtype == .interrupt })
}

func testSetModel() async throws {
    // ... similar test for setModel
}

func testRewindFiles() async throws {
    let mock = MockSubprocessTransport()
    mock.setControlResponse(
        forSubtype: .rewindFiles,
        response: ["canRewind": true, "filesChanged": ["file1.txt"], "insertions": 5, "deletions": 2]
    )

    let result = try await queryStream.rewindFiles(to: "msg_123")

    XCTAssertTrue(result.canRewind)
    XCTAssertEqual(result.filesChanged, ["file1.txt"])
}
```

#### Task Checklist

**5.1 Create result types for control methods**
- [ ] Create `API/QueryControlTypes.swift`
- [ ] Define `RewindFilesResult` with `canRewind`, `error`, `filesChanged`, `insertions`, `deletions`
- [ ] Define `McpSetServersResult` with `added`, `removed`, `errors`
- [ ] Define `SlashCommand` with `name`, `description`, `argumentHint`
- [ ] Define `ModelInfo` with `value`, `displayName`, `description`
- [ ] Define `AccountInfo` with `email`, `organization`, `subscriptionType`, `tokenSource`
- [ ] Define `MCPServerStatus` with `name`, `status`, `error`, `tools`
- [ ] Write unit test: `testRewindFilesResultDecoding`
- [ ] Write unit test: `testMcpSetServersResultDecoding`

**5.2 Add controlHandler to QueryStream**
- [ ] Add `internal let controlHandler: ControlProtocolHandler` property
- [ ] Update QueryStream initializer to accept controlHandler
- [ ] Update AgentSDKBackend to pass controlHandler when creating QueryStream

**5.3 Implement interrupt()**
- [ ] Add `public func interrupt() async throws` to QueryStream
- [ ] Create ControlRequest with subtype `.interrupt`
- [ ] Call `controlHandler.sendRequest()`
- [ ] Write unit test: `testInterruptSendsCorrectRequest`

**5.4 Implement setModel()**
- [ ] Add `public func setModel(_ model: String) async throws`
- [ ] Create ControlRequest with subtype `.setModel`
- [ ] Include `["model": model]` in request data
- [ ] Write unit test: `testSetModelSendsCorrectRequest`

**5.5 Implement setPermissionMode()**
- [ ] Add `public func setPermissionMode(_ mode: PermissionMode) async throws`
- [ ] Create ControlRequest with subtype `.setPermissionMode`
- [ ] Include `["mode": mode.rawValue]` in request data
- [ ] Write unit test: `testSetPermissionModeSendsCorrectRequest`

**5.6 Implement setMaxThinkingTokens()**
- [ ] Add `public func setMaxThinkingTokens(_ tokens: Int?) async throws`
- [ ] Create ControlRequest with subtype `.setMaxThinkingTokens`
- [ ] Include `["value": tokens]` in request data (handle nil)
- [ ] Write unit test: `testSetMaxThinkingTokensSendsCorrectRequest`

**5.7 Implement reconnectMcpServer()**
- [ ] Add `public func reconnectMcpServer(_ serverName: String) async throws`
- [ ] Create ControlRequest with subtype `.mcpReconnect`
- [ ] Include `["server_name": serverName]` in request data
- [ ] Write unit test: `testReconnectMcpServerSendsCorrectRequest`

**5.8 Implement toggleMcpServer()**
- [ ] Add `public func toggleMcpServer(_ serverName: String, enabled: Bool) async throws`
- [ ] Create ControlRequest with subtype `.mcpToggle`
- [ ] Include `["server_name": serverName, "enabled": enabled]` in request data
- [ ] Write unit test: `testToggleMcpServerSendsCorrectRequest`

**5.9 Implement setMcpServers()**
- [ ] Add `public func setMcpServers(_ servers:) async throws -> McpSetServersResult`
- [ ] Create ControlRequest with subtype `.mcpSetServers`
- [ ] Encode servers dictionary and include in request
- [ ] Decode response as `McpSetServersResult`
- [ ] Write unit test: `testSetMcpServersSendsCorrectRequest`
- [ ] Write unit test: `testSetMcpServersDecodesResponse`

**5.10 Implement rewindFiles()**
- [ ] Add `public func rewindFiles(to userMessageId: String, dryRun: Bool = false) async throws -> RewindFilesResult`
- [ ] Create ControlRequest with subtype `.rewindFiles`
- [ ] Include `["user_message_id": userMessageId, "dry_run": dryRun]`
- [ ] Decode response as `RewindFilesResult`
- [ ] Write unit test: `testRewindFilesSendsCorrectRequest`
- [ ] Write unit test: `testRewindFilesDecodesResponse`

**5.11 Implement query information properties**
- [ ] Add `public var supportedCommands: [SlashCommand]` async throws getter
- [ ] Return `initMessage.slashCommands` or throw if not initialized
- [ ] Add `public var mcpServerStatus: [MCPServerStatus]` async getter
- [ ] Return mapped `initMessage.mcpServers`
- [ ] Write unit test: `testSupportedCommandsFromInitMessage`
- [ ] Write unit test: `testMcpServerStatusFromInitMessage`

**5.12 Implement accountInfo() and supportedModels()**
- [ ] Add `public func accountInfo() async throws -> AccountInfo`
- [ ] Send `.accountInfo` control request, decode response
- [ ] Add `public func supportedModels() async throws -> [ModelInfo]`
- [ ] Send `.supportedModels` control request, decode response
- [ ] Write unit test: `testAccountInfoSendsRequest`
- [ ] Write unit test: `testSupportedModelsSendsRequest`

**5.13 Integration tests**
- [ ] Write test: `testInterruptStopsQuery`
- [ ] Write test: `testSetModelChangesModelMidQuery`
- [ ] Write test: `testRewindFilesRestoresState`

---

### Phase 6: Permission Callbacks

**Priority**: Medium-Low

**Complexity**: Small (S)

**Goal**: Programmatic permission handling via `canUseTool` callback.

#### Files to Modify

| File | Changes |
|------|---------|
| `API/ClaudeCodeOptions.swift` | Add `canUseTool` property |
| New: `Permissions/PermissionTypes.swift` | Permission types |
| `ControlProtocol/ControlProtocolHandler.swift` | Handle can_use_tool requests |

#### Swift API Design

```swift
// MARK: - Permission Callback Type

public typealias CanUseToolHandler = @Sendable (
    _ toolName: String,
    _ input: [String: Any],
    _ context: PermissionContext
) async throws -> PermissionResult

public struct PermissionContext: Sendable {
    public let signal: AbortSignal
    public let suggestions: [PermissionUpdate]?
    public let blockedPath: String?
    public let decisionReason: String?
    public let toolUseID: String
    public let agentID: String?
}

// MARK: - Permission Result

public enum PermissionResult: Sendable {
    case allow(updatedInput: [String: Any]? = nil, updatedPermissions: [PermissionUpdate]? = nil)
    case deny(message: String, interrupt: Bool = false)
}

// MARK: - Permission Update

public struct PermissionUpdate: Codable, Sendable {
    public enum UpdateType: String, Codable {
        case addRules
        case replaceRules
        case removeRules
        case setMode
        case addDirectories
        case removeDirectories
    }

    public let type: UpdateType
    public let rules: [PermissionRule]?
    public let behavior: PermissionBehavior?
    public let destination: PermissionDestination?
    public let directories: [String]?
}

public struct PermissionRule: Codable, Sendable {
    public let toolName: String
    public let ruleContent: String?
}

public enum PermissionBehavior: String, Codable, Sendable {
    case allow
    case deny
    case ask
}

public enum PermissionDestination: String, Codable, Sendable {
    case userSettings
    case projectSettings
    case localSettings
    case session
    case cliArg
}

// MARK: - ClaudeCodeOptions Extension

extension ClaudeCodeOptions {
    /// Permission callback for tool usage decisions
    public var canUseTool: CanUseToolHandler?
}
```

#### Usage Example

```swift
var options = ClaudeCodeOptions()

options.canUseTool = { toolName, input, context in
    // Block writes outside project directory
    if toolName == "Write" {
        let filePath = input["file_path"] as? String ?? ""
        if !filePath.hasPrefix("/Users/me/project/") {
            return .deny(message: "Cannot write outside project directory", interrupt: false)
        }
    }

    // Allow with updated permissions
    if toolName == "Bash" {
        return .allow(updatedPermissions: [
            PermissionUpdate(
                type: .addRules,
                rules: [PermissionRule(toolName: "Bash", ruleContent: "allow")],
                behavior: .allow,
                destination: .session
            )
        ])
    }

    return .allow()
}
```

#### Task Checklist

**6.1 Create permission types**
- [ ] Create `Permissions/PermissionTypes.swift`
- [ ] Define `CanUseToolHandler` typealias for permission callback
- [ ] Define `PermissionContext` struct with `signal`, `suggestions`, `blockedPath`, `decisionReason`, `toolUseID`, `agentID`
- [ ] Define `PermissionResult` enum with `allow` and `deny` cases
- [ ] Allow case: `updatedInput: [String: Any]?`, `updatedPermissions: [PermissionUpdate]?`
- [ ] Deny case: `message: String`, `interrupt: Bool`
- [ ] Write unit test: `testPermissionResultAllowEncoding`
- [ ] Write unit test: `testPermissionResultDenyEncoding`

**6.2 Create PermissionUpdate types**
- [ ] Define `PermissionUpdate` struct
- [ ] Define `PermissionUpdate.UpdateType` enum: `addRules`, `replaceRules`, `removeRules`, `setMode`, `addDirectories`, `removeDirectories`
- [ ] Add `rules: [PermissionRule]?`, `behavior: PermissionBehavior?`, `destination: PermissionDestination?`, `directories: [String]?`
- [ ] Define `PermissionRule` with `toolName`, `ruleContent`
- [ ] Define `PermissionBehavior` enum: `allow`, `deny`, `ask`
- [ ] Define `PermissionDestination` enum: `userSettings`, `projectSettings`, `localSettings`, `session`, `cliArg`
- [ ] Write unit test: `testPermissionUpdateEncoding`

**6.3 Add canUseTool to ClaudeCodeOptions**
- [ ] Add `public var canUseTool: CanUseToolHandler?` to ClaudeCodeOptions

**6.4 Update ControlProtocolHandler for can_use_tool**
- [ ] Add `canUseToolHandler: CanUseToolHandler?` parameter to init
- [ ] Implement `handleCanUseTool(_ request:) async throws -> ControlResponse`
- [ ] Extract `tool_name`, `input` from request
- [ ] Build `PermissionContext` from request data
- [ ] Invoke `canUseToolHandler(toolName, input, context)`
- [ ] Convert `PermissionResult` to control response format
- [ ] Handle `.allow` with optional `updatedInput` and `updatedPermissions`
- [ ] Handle `.deny` with `message` and optional `interrupt`
- [ ] Write unit test: `testControlHandlerRoutesCanUseTool`
- [ ] Write unit test: `testCanUseToolAllowResponse`
- [ ] Write unit test: `testCanUseToolDenyResponse`
- [ ] Write unit test: `testCanUseToolDenyWithInterrupt`

**6.5 Update AgentSDKBackend**
- [ ] Extract `canUseTool` from options
- [ ] Pass to ControlProtocolHandler init
- [ ] Write integration test: `testCanUseToolBlocksWrite`
- [ ] Write integration test: `testCanUseToolAllowsWithUpdatedInput`

**6.6 Integration tests**
- [ ] Write test: Permission callback blocks file write outside project
- [ ] Write test: Permission callback modifies tool input
- [ ] Write test: Permission callback adds session permission rules

---

## Testing Architecture

### Testability Design Principles

1. **Protocol-based dependencies**: All external interactions (subprocess, file system) abstracted behind protocols
2. **Dependency injection**: No hardcoded dependencies; all injected via initializers
3. **Actor isolation**: Clear boundaries that can be mocked independently
4. **Deterministic behavior**: No hidden state preventing reproducible tests

### Protocol Definitions

```swift
/// Abstract subprocess I/O for testing
public protocol SubprocessTransport: Sendable {
    func start() async throws
    func write(_ data: Data) async throws
    func closeStdin() async throws
    var stdout: AsyncThrowingStream<Data, Error> { get }
    var stderr: AsyncThrowingStream<Data, Error> { get }
    func terminate() async throws
    func waitUntilExit() async throws -> Int32
    var isRunning: Bool { get }
}

/// Mock implementation for unit tests
final class MockSubprocessTransport: SubprocessTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [String] = []
    private var stdinReceived: [Data] = []
    private var controlResponses: [String: [String: Any]] = [:]

    func setResponses(_ lines: [String]) {
        lock.lock()
        responses = lines
        lock.unlock()
    }

    func setControlResponse(forSubtype subtype: ControlRequestSubtype, response: [String: Any]) {
        lock.lock()
        controlResponses[subtype.rawValue] = response
        lock.unlock()
    }

    var stdout: AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            for line in self.responses {
                continuation.yield((line + "\n").data(using: .utf8)!)
            }
            continuation.finish()
        }
    }

    // ... other protocol methods
}
```

### Test Directory Structure

```
Tests/
├── ClaudeCodeSDKTests/
│   ├── Mocks/
│   │   ├── MockSubprocessTransport.swift
│   │   ├── MockMCPServer.swift
│   │   ├── MockControlProtocolHandler.swift
│   │   └── ControlProtocolMocks.swift
│   │
│   ├── Unit/
│   │   ├── AsyncSequenceTests.swift
│   │   ├── ControlProtocolTests.swift
│   │   ├── MCPToolRoutingTests.swift
│   │   ├── HookInvocationTests.swift
│   │   ├── PermissionCallbackTests.swift
│   │   └── MessageParsingTests.swift
│   │
│   ├── Integration/
│   │   ├── QueryLifecycleTests.swift
│   │   ├── ErrorScenarioTests.swift
│   │   ├── SessionManagementTests.swift
│   │   └── ToolCallEndToEndTests.swift
│   │
│   ├── Live/
│   │   ├── LiveTestCase.swift
│   │   ├── SmokeTests.swift
│   │   ├── FeatureVerificationTests.swift
│   │   └── RegressionTests.swift
│   │
│   └── Utilities/
│       ├── AsyncSequenceTestHelpers.swift
│       ├── JSONLBuilder.swift
│       └── AssertionHelpers.swift
│
└── Mocks/
    └── SharedMockImplementations.swift
```

### Coverage Requirements

- **100% code coverage** enforced in CI
- Every line of production code exercised by tests
- Every branch taken (both true and false paths)
- Every error handling path tested
- Coverage measured via `swift test --enable-code-coverage`

---

## Implementation Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Phase 1: AsyncSequence Migration                               │
│  ─────────────────────────────────                              │
│  • Replace Combine with AsyncThrowingStream                     │
│  • Create QueryStream type                                      │
│  • Add backward compatibility bridge                            │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Phase 2: Control Protocol Foundation                           │
│  ────────────────────────────────────                           │
│  • ControlProtocolHandler actor                                 │
│  • Bidirectional stdin/stdout in sdk-wrapper.mjs                │
│  • Request/response correlation                                 │
│                                                                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
┌─────────────────┐ ┌───────────────┐ ┌─────────────────┐
│                 │ │               │ │                 │
│  Phase 3:       │ │  Phase 4:     │ │  Phase 5:       │
│  SDK MCP Tools  │ │  Hooks System │ │  Query Control  │
│  ─────────────  │ │  ────────────│ │  ─────────────  │
│                 │ │               │ │                 │
│  • SDKMCPServer │ │  • 13 events  │ │  • interrupt()  │
│  • tool() func  │ │  • matchers   │ │  • setModel()   │
│  • JSONRPC      │ │  • callbacks  │ │  • rewindFiles()│
│                 │ │               │ │                 │
└────────┬────────┘ └───────┬───────┘ └────────┬────────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Phase 6: Permission Callbacks                                  │
│  ────────────────────────────                                   │
│  • canUseTool handler                                           │
│  • PermissionResult type                                        │
│  • Permission updates                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Dependencies

| Phase | Depends On | Blocks |
|-------|------------|--------|
| 1 | None | 2, 3, 4, 5, 6 |
| 2 | 1 | 3, 4, 5, 6 |
| 3 | 2 | None |
| 4 | 2 | 6 |
| 5 | 2 | None |
| 6 | 2, 4 | None |

---

## Complexity Summary

| Phase | Feature | Complexity | Est. Files | Est. Lines |
|-------|---------|------------|------------|------------|
| 1 | AsyncSequence Migration | Medium | 4 | ~400 |
| 2 | Control Protocol Foundation | Large | 5 | ~800 |
| 3 | SDK MCP Tools | Large | 6 | ~1000 |
| 4 | Hooks System | Medium | 4 | ~600 |
| 5 | Query Control Methods | Medium | 2 | ~400 |
| 6 | Permission Callbacks | Small | 2 | ~200 |

**Total estimated new/modified code**: ~3,400 lines

---

## Verification Checklist

After implementation is complete, verify:

### Unit Tests
```bash
swift test --filter Unit
```

### Integration Tests
```bash
swift test --filter Integration
```

### Live Smoke Tests (requires API key)
```bash
ANTHROPIC_API_KEY=sk-... swift test --filter Live
```

### Coverage Report
```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/ClaudeCodeSDKPackageTests.xctest/Contents/MacOS/ClaudeCodeSDKPackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

### Example App Verification
1. Open `ClaudeCodeSDK/Example/ClaudeCodeSDKExample/ClaudeCodeSDKExample.xcodeproj`
2. Test SDK MCP tools with a simple calculator
3. Test hooks by logging tool usage
4. Test control methods by interrupting a long query

---

## Appendix: Message Type Reference

### Control Request Subtypes

| Subtype | Direction | Purpose |
|---------|-----------|---------|
| `initialize` | SDK → CLI | Register hooks, SDK MCP servers |
| `interrupt` | SDK → CLI | Stop current operation |
| `set_permission_mode` | SDK → CLI | Change permission mode |
| `set_model` | SDK → CLI | Change active model |
| `set_max_thinking_tokens` | SDK → CLI | Change thinking limit |
| `rewind_files` | SDK → CLI | Restore file state |
| `mcp_status` | SDK → CLI | Get MCP server status |
| `mcp_message` | CLI → SDK | Route MCP JSONRPC to SDK server |
| `mcp_reconnect` | SDK → CLI | Reconnect MCP server |
| `mcp_toggle` | SDK → CLI | Enable/disable MCP server |
| `mcp_set_servers` | SDK → CLI | Set MCP servers dynamically |
| `hook_callback` | CLI → SDK | Invoke registered hook |
| `can_use_tool` | CLI → SDK | Request permission for tool |

### MCP JSONRPC Methods

| Method | Purpose |
|--------|---------|
| `initialize` | MCP handshake, return capabilities |
| `notifications/initialized` | Acknowledge initialization |
| `tools/list` | Return available tool schemas |
| `tools/call` | Invoke tool and return result |

---

## Master Task Summary

### Phase 1: AsyncSequence Migration (16 tasks)
- [ ] 1.1 Create QueryStream type (8 subtasks)
- [ ] 1.2 Update ClaudeCodeResult (3 subtasks)
- [ ] 1.3 Migrate AgentSDKBackend (12 subtasks)
- [ ] 1.4 Migrate HeadlessBackend (3 subtasks)
- [ ] 1.5 Add backward compatibility bridge (4 subtasks)
- [ ] 1.6 Update example app and documentation (3 subtasks)

### Phase 2: Control Protocol Foundation (23 tasks)
- [ ] 2.1 Create control message types (11 subtasks)
- [ ] 2.2 Create ControlProtocolHandler actor (14 subtasks)
- [ ] 2.3 Integrate with AgentSDKBackend (6 subtasks)
- [ ] 2.4 Update sdk-wrapper.mjs for bidirectional communication (10 subtasks)
- [ ] 2.5 Create test infrastructure (6 subtasks)

### Phase 3: SDK MCP Tools (38 tasks)
- [ ] 3.1 Create MCPToolResult types (7 subtasks)
- [ ] 3.2 Create AnyMCPTool type-erased wrapper (6 subtasks)
- [ ] 3.3 Create tool() builder function (2 subtasks)
- [ ] 3.4 Create MCPToolBuilder result builder (7 subtasks)
- [ ] 3.5 Create SDKMCPServer (15 subtasks)
- [ ] 3.6 Create JSONRPC types (8 subtasks)
- [ ] 3.7 Add sdkMcpServers to ClaudeCodeOptions (2 subtasks)
- [ ] 3.8 Update ControlProtocolHandler for MCP routing (10 subtasks)
- [ ] 3.9 Update AgentSDKBackend to pass SDK server configs (5 subtasks)
- [ ] 3.10 Update sdk-wrapper.mjs for SDK server registration (4 subtasks)
- [ ] 3.11 End-to-end integration test (5 subtasks)

### Phase 4: Hooks System (35 tasks)
- [ ] 4.1 Create hook event types enum (4 subtasks)
- [ ] 4.2 Create HookInput protocol and types (18 subtasks)
- [ ] 4.3 Create HookOutput types (12 subtasks)
- [ ] 4.4 Create HookMatcher generic struct (7 subtasks)
- [ ] 4.5 Create HooksConfiguration (3 subtasks)
- [ ] 4.6 Add hooks to ClaudeCodeOptions (17 subtasks)
- [ ] 4.7 Update ControlProtocolHandler for hook callbacks (12 subtasks)
- [ ] 4.8 Update AgentSDKBackend for hooks (6 subtasks)
- [ ] 4.9 Update sdk-wrapper.mjs for hooks (4 subtasks)

### Phase 5: Query Control Methods (30 tasks)
- [ ] 5.1 Create result types for control methods (8 subtasks)
- [ ] 5.2 Add controlHandler to QueryStream (3 subtasks)
- [ ] 5.3 Implement interrupt() (3 subtasks)
- [ ] 5.4 Implement setModel() (3 subtasks)
- [ ] 5.5 Implement setPermissionMode() (3 subtasks)
- [ ] 5.6 Implement setMaxThinkingTokens() (3 subtasks)
- [ ] 5.7 Implement reconnectMcpServer() (3 subtasks)
- [ ] 5.8 Implement toggleMcpServer() (3 subtasks)
- [ ] 5.9 Implement setMcpServers() (4 subtasks)
- [ ] 5.10 Implement rewindFiles() (4 subtasks)
- [ ] 5.11 Implement query information properties (4 subtasks)
- [ ] 5.12 Implement accountInfo() and supportedModels() (4 subtasks)
- [ ] 5.13 Integration tests (3 subtasks)

### Phase 6: Permission Callbacks (17 tasks)
- [ ] 6.1 Create permission types (8 subtasks)
- [ ] 6.2 Create PermissionUpdate types (7 subtasks)
- [ ] 6.3 Add canUseTool to ClaudeCodeOptions (1 subtask)
- [ ] 6.4 Update ControlProtocolHandler for can_use_tool (11 subtasks)
- [ ] 6.5 Update AgentSDKBackend (4 subtasks)
- [ ] 6.6 Integration tests (3 subtasks)

---

## Final Verification Checklist

After all phases complete, verify the following:

### Build Verification
- [ ] `swift build` succeeds with no warnings
- [ ] `swift build -c release` succeeds
- [ ] Example app builds and runs

### Test Verification
- [ ] `swift test` passes all tests
- [ ] `swift test --filter Unit` passes
- [ ] `swift test --filter Integration` passes
- [ ] `swift test --filter Live` passes (with API key)
- [ ] Code coverage ≥ 100%

### Feature Verification
- [ ] SDK MCP tool can be defined and invoked by Claude
- [ ] PreToolUse hook can block dangerous commands
- [ ] PostToolUse hook receives tool results
- [ ] SessionStart/SessionEnd hooks fire correctly
- [ ] `interrupt()` stops running query
- [ ] `setModel()` changes model mid-query
- [ ] `canUseTool` callback can deny file writes
- [ ] Backward compatibility: Combine publisher bridge works

### Documentation Verification
- [ ] README updated with AsyncSequence examples
- [ ] SDK MCP tools usage documented
- [ ] Hooks usage documented
- [ ] Migration guide from Combine written
