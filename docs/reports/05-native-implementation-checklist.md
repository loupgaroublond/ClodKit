# Native Swift Implementation Checklist

> **Note**: This checklist is for later-stage verification. Progress is tracked via Beads issues, not by updating this file.

## Phase 1: Transport Layer

- [x] **1.1 Transport Protocol** (S)
  - [x] Create `Sources/ClaudeCodeSDK/Transport/Transport.swift`
  - [x] Define `Transport` protocol with `write`, `readMessages`, `endInput`, `close`, `isConnected`
  - [x] Define `StdoutMessage` enum (regular, controlRequest, controlResponse, controlCancelRequest, keepAlive)
  - [x] Verify protocol compiles and is Sendable

- [x] **1.2 JSONLineParser** (S)
  - [x] Create `Sources/ClaudeCodeSDK/Transport/JSONLineParser.swift`
  - [x] Implement `parseLine(from:)` with buffer handling
  - [x] Handle incomplete buffers (return nil)
  - [x] Handle malformed JSON (skip line, don't crash)
  - [x] Handle empty lines
  - [x] Route by `type` field to appropriate message type
  - [x] Unit tests:
    - [x] `testParseUserMessage`
    - [x] `testParseAssistantMessage`
    - [x] `testParseResultMessage`
    - [x] `testParseSystemMessage`
    - [x] `testParseControlRequest`
    - [x] `testParseControlResponse`
    - [x] `testParseKeepAlive`
    - [x] `testIncompleteBuffer_ReturnsNil`
    - [x] `testMalformedJSON_SkipsLine`
    - [x] `testEmptyLine_SkipsToNext`
    - [x] `testMultipleMessages_ParsesAll`

- [x] **1.3 MockTransport** (S)
  - [x] Create `Sources/ClaudeCodeSDK/Transport/MockTransport.swift`
  - [x] Implement as class with NSLock (thread-safe)
  - [x] `injectMessage(_:)` to simulate CLI output
  - [x] `injectError(_:)` to simulate failures
  - [x] `getWrittenData()` to verify requests sent
  - [x] `clearWrittenData()` for test isolation
  - [x] Unit tests for mock behavior

- [x] **1.4 ProcessTransport** (M)
  - [x] Create `Sources/ClaudeCodeSDK/Transport/ProcessTransport.swift`
  - [x] Implement as class with NSLock (thread-safe)
  - [x] Configure Foundation.Process with zsh
  - [x] Set up stdin/stdout/stderr pipes
  - [x] Set CLAUDE_CODE_ENTRYPOINT=sdk-swift
  - [x] Implement `start()` to launch process
  - [x] Implement `write(_:)` with newline append
  - [x] Implement `readMessages()` with async stream
  - [x] Implement read loop with JSONLineParser
  - [x] Implement `endInput()` to close stdin
  - [x] Implement `close()` with graceful shutdown (SIGTERM, wait 5s, SIGKILL)
  - [ ] Integration test with real CLI (Live test) - requires API key

## Phase 2: Control Protocol

- [x] **2.1 Control Protocol Types** (S)
  - [x] Create `Sources/ClaudeCodeSDK/ControlProtocol/ControlProtocolTypes.swift`
  - [x] `ControlRequest` with type, request_id, request
  - [x] `ControlRequestPayload` discriminated union with all subtypes:
    - [x] SDK→CLI: initialize, interrupt, set_permission_mode, set_model, set_max_thinking_tokens, rewind_files, mcp_status, mcp_reconnect, mcp_toggle, mcp_set_servers, mcp_message
    - [x] CLI→SDK: can_use_tool, hook_callback
  - [x] `ControlResponse` with success/error variants
  - [x] `ControlCancelRequest`
  - [x] `JSONRPCMessage` for MCP communication
  - [x] All request/response structs (InitializeRequest, CanUseToolRequest, etc.)
  - [x] Unit tests:
    - [x] Round-trip encode/decode for each type
    - [x] Test each discriminated union case
    - [x] Test malformed input handling

- [x] **2.2 ControlProtocolHandler** (M)
  - [x] Create `Sources/ClaudeCodeSDK/ControlProtocol/ControlProtocolHandler.swift`
  - [x] Implement as actor
  - [x] Request counter and ID generation (`req_{counter}_{hex}`)
  - [x] Pending requests map with continuations
  - [x] Handler registration (canUseTool, hookCallback, mcpMessage)
  - [x] `sendRequest(_:timeout:)` with correlation
  - [x] Timeout handling with task group
  - [x] `handleControlResponse(_:)` - resume pending continuations
  - [x] `handleControlRequest(_:)` - invoke registered handlers
  - [x] `handleCancelRequest(_:)` - cancel pending requests
  - [x] Convenience methods: `initialize`, `interrupt`, `setModel`, `setPermissionMode`, etc.
  - [x] Unit tests:
    - [x] `testSendRequest_WritesToTransport`
    - [x] `testSendRequest_CorrelatesResponse`
    - [x] `testSendRequest_TimesOut`
    - [x] `testSendRequest_HandlesError`
    - [x] `testHandleControlRequest_InvokesHandler`
    - [x] `testHandleControlRequest_SendsResponse`
    - [x] `testHandleControlRequest_SendsErrorOnFailure`
    - [x] `testHandleCancelRequest_CancelsPending`
    - [x] `testGenerateRequestId_IsUnique`

## Phase 3: SDK MCP Tools (Highest Priority)

- [x] **3.1 MCPTool + Types** (S)
  - [x] Create `Sources/ClaudeCodeSDK/MCP/MCPTool.swift`
  - [x] `MCPTool` struct with name, description, inputSchema, handler
  - [x] `MCPToolResult` with content array and isError
  - [x] `MCPContent` enum (text, image, resource)
  - [x] `JSONSchema` with type, properties, required
  - [x] `PropertySchema` with static builders (string, number, boolean, array, object)
  - [x] `toDictionary()` methods for all types
  - [x] Unit tests for schema generation

- [x] **3.2 SDKMCPServer** (S)
  - [x] Create `Sources/ClaudeCodeSDK/MCP/SDKMCPServer.swift`
  - [x] Store tools by name
  - [x] `listTools()` returning tool definitions
  - [x] `callTool(name:arguments:)` executing handler
  - [x] `capabilities` property
  - [x] `serverInfo` property
  - [x] `MCPToolBuilder` result builder
  - [x] `createSDKMCPServer` convenience function
  - [x] Unit tests:
    - [x] Test tool listing
    - [x] Test tool calling
    - [x] Test tool not found error
    - [x] Test handler throws error

- [x] **3.3 MCPServerRouter** (M)
  - [x] Create `Sources/ClaudeCodeSDK/MCP/MCPServerRouter.swift`
  - [x] Implement as actor
  - [x] Server registration/unregistration
  - [x] `getServerNames()` for CLI config
  - [x] `route(_:)` dispatching by JSONRPC method
  - [x] Handle `initialize` - return capabilities
  - [x] Handle `notifications/initialized` - mark initialized
  - [x] Handle `tools/list` - return tool schemas
  - [x] Handle `tools/call` - execute and return result
  - [x] Error responses for unknown server/method
  - [x] Unit tests:
    - [x] Test initialize response
    - [x] Test tools/list response
    - [x] Test tools/call success
    - [x] Test tools/call error
    - [x] Test server not found
    - [x] Test method not found

## Phase 4: Hook System

- [x] **4.1 Hook Types** (S)
  - [x] Create `Sources/ClaudeCodeSDK/Hooks/HookTypes.swift`
  - [x] `HookEvent` enum with all 11 events (12 including Notification)
  - [x] `HookMatcherConfig` with matcher, callbackIds, timeout
  - [x] `BaseHookInput` with common fields
  - [x] Input types: PreToolUseInput, PostToolUseInput, PostToolUseFailureInput, UserPromptSubmitInput, StopInput (plus SubagentStart, SubagentStop, PreCompact, PermissionRequest, SessionStart, SessionEnd, Notification)
  - [x] `HookOutput` with continue, suppressOutput, stopReason, etc.
  - [x] `HookSpecificOutput` enum (preToolUse, postToolUse)
  - [x] `PreToolUseHookOutput`, `PostToolUseHookOutput`
  - [x] `PermissionDecision` enum
  - [x] `HookCallback` typealias
  - [x] Unit tests for toDictionary methods

- [x] **4.2 HookRegistry** (M)
  - [x] Create `Sources/ClaudeCodeSDK/Hooks/HookRegistry.swift`
  - [x] Implement as actor
  - [x] Callback ID generation
  - [x] Callback storage by ID
  - [x] Hook config by event type
  - [x] Registration methods: onPreToolUse, onPostToolUse, onUserPromptSubmit, onStop, etc. (plus all other events)
  - [x] `getHookConfig()` for initialize request
  - [x] `hasHooks` property
  - [x] `invokeCallback(callbackId:input:)` with type routing
  - [x] Input parsing methods
  - [x] Unit tests:
    - [x] Test registration adds callback
    - [x] Test getHookConfig format
    - [x] Test invokeCallback routes correctly
    - [x] Test callback not found error

## Phase 5: Permission System

- [x] **5.1 Permission Types** (S)
  - [x] Create `Sources/ClaudeCodeSDK/Permissions/PermissionTypes.swift`
  - [x] `PermissionMode` enum
  - [x] `ToolPermissionContext` with suggestions, blockedPath, decisionReason, agentId
  - [x] `PermissionResult` enum (allow, deny)
  - [x] `PermissionUpdate` with UpdateType, Behavior, Destination
  - [x] `PermissionRule` with toolName, ruleContent
  - [x] `CanUseToolCallback` typealias
  - [x] Unit tests for toDictionary methods

## Phase 6: Session & Query API

- [x] **6.1 ClaudeSession** (L)
  - [x] Create `Sources/ClaudeCodeSDK/Session/ClaudeSession.swift`
  - [x] Implement as actor
  - [x] Own transport, controlHandler, hookRegistry, mcpRouter
  - [x] `setCanUseTool(_:)` callback registration
  - [x] `registerMCPServer(_:)` delegation
  - [x] Hook registration methods delegation
  - [x] `initialize()`:
    - [x] Set up control handlers
    - [x] Send initialize control request with hooks and MCP servers
  - [x] `startMessageLoop()` returning AsyncThrowingStream
  - [x] Message routing in loop (regular vs control)
  - [x] Session ID extraction from init message
  - [x] Control methods: interrupt, setModel, setPermissionMode, setMaxThinkingTokens, rewindFiles, mcpStatus, reconnectMcpServer, toggleMcpServer
  - [x] `close()` method
  - [x] Integration tests with MockTransport

- [x] **6.2 ClaudeQuery** (M)
  - [x] Create `Sources/ClaudeCodeSDK/Query/ClaudeQuery.swift`
  - [x] Implement AsyncSequence conformance
  - [x] AsyncIterator wrapping underlying stream
  - [x] Control methods delegating to session
  - [x] `sessionId` async property
  - [x] Unit tests for iteration

- [x] **6.3 QueryAPI** (M)
  - [x] Create `Sources/ClaudeCodeSDK/Query/QueryAPI.swift`
  - [x] `query(prompt:options:)` function
  - [x] Build CLI arguments from options
  - [x] Build MCP config file if needed
  - [x] Create ProcessTransport
  - [x] Create ClaudeSession
  - [x] Register SDK MCP servers
  - [x] Register hooks
  - [x] Set permission callback
  - [x] Start transport
  - [x] Initialize control protocol if needed
  - [x] Send prompt message
  - [x] Close stdin if no control protocol
  - [x] Return ClaudeQuery
  - [x] `QueryOptions` struct with all properties
  - [x] `PreToolUseHookConfig`, `PostToolUseHookConfig` (plus PostToolUseFailure, UserPromptSubmit, Stop configs)
  - [x] Integration tests

## Phase 7: Integration

- [x] **7.1 NativeBackend** (M)
  - [x] Create `Sources/ClaudeCodeSDK/Backend/NativeBackend.swift`
  - [x] Implement NativeClaudeCodeBackend protocol
  - [x] Bridge existing API to new query API
  - [x] Unit tests

- [x] **7.2 BackendType.native** (S)
  - [x] Add `.native` case to BackendType enum
  - [x] Add NativeBackendFactory to create NativeBackend

- [x] **7.3 Update Existing Files** (N/A - NativeClaudeCodeSDK is a separate package)
  - N/A - This is a standalone implementation in `NativeClaudeCodeSDK/`, not modifying the existing `ClaudeCodeSDK/`

## Testing Milestones

- [x] **Unit Test Coverage**
  - [x] All Transport tests passing
  - [x] All ControlProtocol tests passing
  - [x] All MCP tests passing
  - [x] All Hook tests passing
  - [x] All Permission tests passing
  - [x] 279 tests passing (comprehensive coverage achieved)

- [x] **Integration Tests**
  - [x] Full query flow with MockTransport
  - [x] SDK MCP tool execution flow
  - [x] Hook callback flow
  - [x] Permission callback flow
  - [x] Control method flow (interrupt, setModel, etc.)

- [ ] **Live Tests** (require API key)
  - [ ] Basic query with real CLI
  - [ ] SDK MCP tool with real CLI
  - [ ] Hooks with real CLI
  - [ ] Control methods with real CLI

## Verification Checklist

- [x] `swift build` succeeds
- [x] `swift test` passes (279 tests, 0 failures)
- [x] SDK MCP tool can be defined and called
- [x] Hooks fire when tools are used
- [x] Permission callback can allow/deny tool use
- [x] `interrupt()` stops iteration
- [x] `setModel()` changes model mid-query
- [x] `rewindFiles()` restores file state
- [x] Node.js bridge can be removed (NativeBackend provides native alternative)
