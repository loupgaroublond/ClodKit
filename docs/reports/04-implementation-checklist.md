# ClaudeCodeSDK Implementation Checklist

**Reference Document**: `04-implementation-plan.md`

**Usage**: This checklist is for tracking final verification. During implementation, use **beads** to track progress. Each main task (1.1, 1.2, etc.) has a corresponding bead. Agents should:
- Use open beads as work indicators
- Close beads when task is complete
- Log progress to bead comments prolifically
- NOT update this checklist directly

---

## Phase 1: AsyncSequence Migration

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

## Phase 2: Control Protocol Foundation

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

## Phase 3: SDK MCP Tools

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

## Phase 4: Hooks System

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

## Phase 5: Query Control Methods

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

## Phase 6: Permission Callbacks

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

## Final Verification

- [ ] `swift build` succeeds with no warnings
- [ ] `swift build -c release` succeeds
- [ ] `swift test` passes all tests
- [ ] Code coverage ≥ 100%
- [ ] Example app builds and runs
- [ ] SDK MCP tool can be defined and invoked
- [ ] PreToolUse hook can block commands
- [ ] `interrupt()` stops running query
- [ ] `canUseTool` callback can deny writes
- [ ] Backward compatibility publisher bridge works
