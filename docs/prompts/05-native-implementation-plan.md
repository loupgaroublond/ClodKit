# Task: Implementation Plan for Native Swift Claude Subprocess Management

Create an implementation plan to bring the Swift ClaudeCodeSDK to complete feature parity with the TypeScript SDK by implementing native subprocess management and the control protocol directly in Swift.

## Context

ClodeMonster/ClaudeCodeSDK is a Swift SDK for Claude Code. It currently has:
- `HeadlessBackend` - Direct CLI subprocess (limited features)
- `AgentSDKBackend` - Uses a Node.js wrapper (`sdk-wrapper.mjs`) that calls the TypeScript SDK

**Goal**: Achieve complete feature parity with the TypeScript SDK while eliminating the TypeScript bridge. Every capability exposed by the TypeScript SDK should have a corresponding Swift API. Implement the same subprocess + control protocol approach that the TypeScript and Python SDKs use, but natively in Swift. The TypeScript SDK is the reference implementation - match its features exactly.

## How the Official SDKs Work

Both TypeScript and Python SDKs use the same architecture (see reports):

1. **Spawn CLI subprocess** with flags:
   - `--output-format stream-json`
   - `--input-format stream-json`
   - `--verbose`

2. **JSON lines protocol** over stdin/stdout:
   - Regular messages: `user`, `assistant`, `system`, `result`, `stream_event`
   - Control messages: `control_request`, `control_response`, `control_cancel_request`

3. **Bidirectional control protocol** for:
   - **SDK → CLI**: `initialize`, `interrupt`, `set_permission_mode`, `set_model`, `mcp_status`, `mcp_reconnect`, `mcp_toggle`, `mcp_set_servers`, `mcp_message`
   - **CLI → SDK**: `can_use_tool`, `hook_callback`, `mcp_message`

4. **SDK MCP servers** run in-process, with JSONRPC calls routed through control protocol

## Files to Review

Swift SDK:
- `/Users/yankee/Documents/Projects/ClodeMonster/ClaudeCodeSDK/Sources/ClaudeCodeSDK/` - Current implementation

Reference docs:
- `/Users/yankee/Documents/Projects/ClodeMonster/CLAUDE_AGENT_SDK_API_SPEC.md` - Full API spec
- `/Users/yankee/Documents/Projects/ClodeMonster/GAP_ANALYSIS.md` - Identified gaps
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/SDK_INTERNALS_ANALYSIS.md` - How SDKs work
- `/Users/yankee/Documents/Projects/ClodeMonster/CLAUDE.md` - Project requirements

SDK analysis reports:
- `/Users/yankee/Documents/Projects/ClodeMonster/reports/02-typescript-sdk-report.md` - TypeScript SDK internals
- `/Users/yankee/Documents/Projects/ClodeMonster/reports/03-python-sdk-report.md` - Python SDK internals

TypeScript SDK types:
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/sdk.d.ts`

## Requirements

- Use AsyncSequence (not Combine) for streaming
- macOS only, cutting edge Swift
- **Native subprocess management** - no TypeScript/Node.js bridge
- Implement bidirectional control protocol directly in Swift
- Actor-based state management for thread safety

## Plan Should Cover

### 1. **Transport Layer** (foundation)
   - Swift `Process` wrapper for CLI subprocess
   - stdin/stdout pipe management
   - JSON line parsing/writing over pipes
   - Graceful shutdown (SIGTERM then SIGKILL after timeout)

### 2. **Control Protocol Handler** (core)
   - Request/response correlation with unique IDs
   - `control_request` / `control_response` message routing
   - Pending request tracking with async/await
   - Timeout handling for control requests

### 3. **SDK MCP Tools** (highest priority feature)
   - Swift API for defining tools (Codable + macros preferred)
   - In-process MCP server implementation
   - JSONRPC routing for `initialize`, `tools/list`, `tools/call`
   - How `mcp_message` control requests route to Swift tool handlers

### 4. **Hooks**
   - Swift API for registering hooks (callback ID pattern from TS/Python)
   - `hook_callback` control request handling
   - All hook event types (PreToolUse, PostToolUse, etc.)
   - Hook output types and field mappings

### 5. **Permission Handling**
   - `can_use_tool` control request handling
   - Permission result types (allow, deny, ask)
   - Custom permission handler callback API

### 6. **Query Control Methods**
   - `interrupt()` - send interrupt control request
   - `setModel()` - change AI model mid-query
   - `setPermissionMode()` - change permission behavior
   - `setMaxThinkingTokens()` - thinking token limit
   - `rewindFiles()` - restore files to checkpoint

### 7. **Dynamic MCP Management**
   - `setMcpServers()` - add/remove servers dynamically
   - `reconnectMcpServer()` - reconnect a server
   - `toggleMcpServer()` - enable/disable server
   - `mcpStatus()` - query server status

### 8. **Message Type Parity**
   - All TypeScript message types as Swift Codable types
   - Proper discriminated union handling
   - Partial message streaming support

### 9. **Session API**
   - Single-shot query mode (prompt as string)
   - Streaming mode (prompt as AsyncSequence)
   - V2-style session interface for multi-turn

### 10. **Migration Path**
   - How to migrate from current `AgentSDKBackend` to native implementation
   - How to migrate Combine-based code to AsyncSequence
   - Backwards compatibility considerations

## Testing & Code Quality Requirements

The plan MUST include comprehensive testing architecture. Work is not complete until tests achieve 100% code coverage.

### Testability Architecture

Every component must be designed for testability from the start:
- **Protocol-based dependencies** - All external dependencies (subprocess, pipes, file system) abstracted behind protocols
- **Dependency injection** - No hardcoded dependencies; all injected via initializers
- **Actor isolation boundaries** - Clear boundaries that can be mocked independently
- **Deterministic behavior** - No hidden state or side effects that prevent reproducible tests
- **Transport abstraction** - Subprocess communication behind protocol for mock injection

### Unit Testing (Mocked)

Full unit test coverage with mocked dependencies:
- **Protocol mocks** - Mock implementations for all protocol dependencies
- **Isolated component testing** - Each type tested in isolation
- **JSON parsing** - All message types with valid/invalid JSON
- **Control protocol handler** - Request correlation, timeouts, cancellation
- **MCP routing** - Tool definition, invocation, response handling
- **Edge cases** - Error paths, timeouts, malformed input, concurrent access
- **State machine coverage** - All state transitions tested

### Integration Testing (Mocked)

End-to-end flows with mocked subprocess:
- **Mock transport** - Simulated stdin/stdout pipes returning canned responses
- **Full message flow** - Query → streaming → completion with mock CLI output
- **Control protocol sequences** - Initialize → tool calls → hooks → completion
- **Bidirectional communication** - SDK→CLI and CLI→SDK control messages
- **Error scenarios** - Subprocess crashes, SIGTERM handling, malformed JSON, pipe errors

### Integration Testing (Live)

Real integration with actual Claude CLI:
- **Smoke tests** - Basic query/response with real CLI
- **Feature verification** - Each feature validated against real CLI behavior
- **Control protocol verification** - Real tool calls, hooks, permissions
- **Regression suite** - Catch breaking changes from CLI updates
- **Skip markers** - Tests marked to skip in CI when API key unavailable

### Code Coverage Requirement

**100% code coverage is required for completion.** This means:
- Every line of production code exercised by tests
- Every branch taken (both true and false paths)
- Every error handling path tested
- Coverage measured and enforced in CI

### Test Organization

```
Tests/
├── ClaudeCodeSDKTests/
│   ├── Unit/              # Isolated component tests with mocks
│   │   ├── Transport/     # Pipe management, JSON parsing
│   │   ├── Protocol/      # Control protocol handler
│   │   ├── MCP/           # Tool routing, JSONRPC
│   │   └── Messages/      # All message type parsing
│   ├── Integration/       # End-to-end with mock subprocess
│   └── Live/              # Real CLI tests (requires API key)
└── Mocks/                 # Shared mock implementations
    ├── MockTransport.swift
    ├── MockProcess.swift
    └── MockMCPServer.swift
```

## Output

Create `/Users/yankee/Documents/Projects/ClodeMonster/reports/05-native-implementation-plan.md` with:
- Prioritized list of work items
- For each item: Swift API design, implementation approach, testing approach
- **Testing section for each item**: specific unit tests, integration tests, mocks needed
- Dependencies between items (dependency graph)
- Estimated complexity (S/M/L) for each item
- Key code snippets showing proposed Swift APIs
- **Testability architecture**: protocols and abstractions enabling mock injection
