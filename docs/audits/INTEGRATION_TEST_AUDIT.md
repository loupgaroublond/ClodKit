# Integration Test Audit: NativeClaudeCodeSDK

**Date**: 2026-01-31
**Status**: IMPLEMENTED

## Executive Summary

The SDK now has comprehensive integration test coverage. Previously only **IntegrationTests.swift** used the real Claude CLI. Now there are 5 additional integration test files covering hooks, MCP tools, permissions, control protocol, and error scenarios.

See also: `TEST_CATEGORIES.md` for complete test organization documentation.

---

## Current Test Coverage

### Integration Tests (Real CLI) - IntegrationTests.swift

| Code Path | Status |
|-----------|--------|
| ProcessTransport start/read/write/EOF/termination | ✅ Covered |
| QueryOptions (model, maxTurns, systemPrompt) | ✅ Covered |
| QueryOptions (workingDirectory, environment) | ✅ Covered |
| QueryOptions (allowedTools, blockedTools) | ✅ Covered |
| NativeBackend validateSetup | ✅ Covered |
| NativeBackend runSinglePrompt | ✅ Covered |
| NativeBackend cancel | ✅ Covered |
| Message reception (system init, assistant) | ✅ Covered |
| Multiple sequential queries | ✅ Covered |

### Unit Tests (Mocks) - Well Covered

- MockTransportTests.swift - Transport behavior
- JSONLineParserTests.swift - JSON-line parsing
- ControlProtocolHandlerTests.swift - Protocol handler logic
- HookRegistryTests.swift - Hook registration/invocation
- MCPServerRouterTests.swift - MCP routing logic
- MCPToolTests.swift - Tool schema/execution
- SDKMCPServerTests.swift - Server functionality
- ClaudeSessionTests.swift - Session management
- ClaudeQueryTests.swift - Query iteration
- NativeBackendTests.swift - Backend configuration
- FullCoverageTests.swift - Edge cases (~57KB)
- AdditionalCoverageTests.swift - More edge cases (~28KB)
- FinalCoverageTests.swift - Final coverage push (~39KB)

---

## Critical Gaps (NOT Tested with Real CLI)

### Gap 1: Hooks System - CRITICAL

**Zero integration coverage.** The hooks system is tested only with mocks.

| Missing Test | What It Would Validate |
|--------------|------------------------|
| PreToolUse hook invocation | CLI sends hook_callback, SDK receives tool_name/tool_input |
| PreToolUse blocks tool | permissionDecision: "deny" prevents execution |
| PreToolUse modifies input | updatedInput field honored by CLI |
| PostToolUse receives response | tool_response contains actual output |
| Hook timeout handling | CLI handles slow hooks gracefully |
| Multiple hooks same event | All callbacks invoked in order |
| Hook matcher pattern | Regex filtering works correctly |

**Files involved:**
- `HookRegistry.swift:65-180` (registration, invocation)
- `ControlProtocolHandler.swift:174-226` (hook_callback handling)
- `HookInputTypes.swift` (12 input types)

### Gap 2: Control Protocol Bidirectional - CRITICAL

**Zero integration coverage.** Control request/response flow never tested end-to-end.

| Missing Test | What It Would Validate |
|--------------|------------------------|
| Initialize control request | SDK sends init with hooks/MCP config |
| Control response correlation | Responses matched by request_id |
| Interrupt command | CLI stops processing on interrupt |
| setModel mid-session | Model actually changes |
| setPermissionMode | Mode change takes effect |
| rewindFiles | Files restored to previous state |

**Files involved:**
- `ControlProtocolHandler.swift:87-136` (send request, await response)
- `ControlRequests.swift` (request types)
- `ControlResponses.swift` (response types)
- `ClaudeSession.swift:153-194` (initialize flow)

### Gap 3: SDK MCP Tools - CRITICAL

**Zero integration coverage.** In-process MCP tools never invoked by real CLI.

| Missing Test | What It Would Validate |
|--------------|------------------------|
| SDK tool registration | Tools appear in session, CLI can discover |
| SDK tool invocation | CLI sends mcp_message, handler executes |
| MCP initialize handshake | initialize/initialized flow works |
| tools/list response | Correct schema returned |
| Tool error handling | Errors communicated to Claude |
| Multiple MCP servers | Routing by server_name works |

**Files involved:**
- `MCPServerRouter.swift:65-105` (message routing)
- `SDKMCPServer.swift` (tool hosting)
- `MCPTool.swift` (tool definitions)
- `QueryAPI.swift:60-90` (MCP config creation)

### Gap 4: Permission Callbacks - HIGH

**Zero integration coverage.** canUseTool callback never tested with real CLI.

| Missing Test | What It Would Validate |
|--------------|------------------------|
| canUseTool invocation | CLI sends can_use_tool request |
| Allow with modified input | updatedInput used by tool |
| Deny with message | Tool blocked, message to Claude |
| Permission updates | Rules updated for future calls |

**Files involved:**
- `ControlProtocolHandler.swift:174-226` (can_use_tool handling)
- `PermissionResult.swift` (result types)
- `QueryOptions.swift` (callback registration)

### Gap 5: Dynamic Control - MEDIUM

| Missing Test | What It Would Validate |
|--------------|------------------------|
| query.interrupt() | Stream terminates gracefully |
| query.setModel() | Subsequent responses use new model |
| query.rewindFiles() | Files restored, session continues |

### Gap 6: Error Scenarios - MEDIUM

| Missing Test | What It Would Validate |
|--------------|------------------------|
| CLI not available | Clear error, no hang |
| Malformed CLI output | Graceful error handling |
| Process crash mid-query | Error surfaced, cleanup |
| Control protocol timeout | Timeout enforced |

---

## Implementation Status

| Test File | Status | Tests |
|-----------|--------|-------|
| `Integration/IntegrationTestHelpers.swift` | ✅ Created | Shared utilities |
| `Integration/MCPIntegrationTests.swift` | ✅ Created | 6 tests |
| `Integration/HooksIntegrationTests.swift` | ✅ Created | 8 tests |
| `Integration/PermissionCallbackIntegrationTests.swift` | ✅ Created | 6 tests |
| `Integration/ControlProtocolIntegrationTests.swift` | ✅ Created | 8 tests |
| `Integration/ErrorIntegrationTests.swift` | ✅ Created | 10 tests |

**Total new integration tests**: ~38 tests

## Test Details

### HooksIntegrationTests.swift

```swift
func testPreToolUseHookInvocation() async throws
// Register PreToolUse hook, trigger Bash, verify hook called

func testPreToolUseHookBlocksTool() async throws
// Return deny, verify tool doesn't execute

func testPostToolUseHookReceivesResponse() async throws
// Capture tool_response after execution
```

### New File: MCPIntegrationTests.swift

```swift
func testSDKMCPToolRegistration() async throws
// Register SDKMCPServer, verify tools in session

func testSDKMCPToolInvocation() async throws
// Register echo tool, ask Claude to use it, verify handler called

func testSDKMCPToolError() async throws
// Register throwing tool, verify error to Claude
```

### New File: PermissionCallbackIntegrationTests.swift

```swift
func testCanUseToolCallbackInvocation() async throws
// Register callback, trigger tool, verify called

func testPermissionDenyWithMessage() async throws
// Return deny, verify tool blocked
```

### New File: ControlProtocolIntegrationTests.swift

```swift
func testInterruptCommand() async throws
// Start query, call interrupt(), verify stream stops

func testControlResponseCorrelation() async throws
// Concurrent requests, verify correct correlation
```

### New File: ErrorIntegrationTests.swift

```swift
func testCLINotAvailable() async throws
// Invalid cliPath, verify error

func testProcessCrashDuringQuery() async throws
// Kill CLI mid-query, verify cleanup
```

### New File: IntegrationTestHelpers.swift

```swift
static var isClaudeAvailable: Bool
func withTestDirectory(_ work: (URL) async throws -> Void) async throws
static func echoTool() -> MCPTool
static func failingTool() -> MCPTool
```

---

## Architecture Reference

```
User Code
    ↓
ClaudeCode.query(prompt, options)     ← QueryAPI.swift
    ↓
ProcessTransport                       ← spawns `claude` CLI
    ↓
ClaudeSession (actor)                  ← orchestrates components
    ├→ ControlProtocolHandler          ← request/response correlation
    ├→ HookRegistry                    ← callback storage/invocation
    └→ MCPServerRouter                 ← in-process tool routing
        ↓
    Message Loop
        ├→ regular(SDKMessage)         → yield to user
        ├→ controlRequest              → dispatch to handler
        │   ├→ can_use_tool            → permission callback
        │   ├→ hook_callback           → hook invocation
        │   └→ mcp_message             → MCP routing
        └→ controlResponse             → resume pending request
```

---

## Known Concurrency Bugs (From Prior Audits)

These exist but are **out of scope** for this testing task:

1. **CRITICAL**: Request/response race in ControlProtocolHandler
   - Continuation registered in unstructured Task
   - CLI can respond before registration → response dropped

2. **CRITICAL**: Multiple readMessages() calls orphan first stream
   - Second call replaces continuation
   - First consumer hangs forever

3. **HIGH**: TOCTOU race in closeInternal()
   - Concurrent closes both pass guard check
   - Double terminate/closeFile calls

4. **MEDIUM**: Temp file leak in QueryAPI
   - MCP config files never deleted

Integration tests will help surface these bugs more reliably.

---

## Verification

```bash
# Run all integration tests
swift test --filter Integration

# Run with verbose output
swift test --filter Integration -v

# Run specific test file
swift test --filter HooksIntegrationTests
```

## Cost Considerations

- Each test makes real API calls (~100-1000 tokens)
- Estimated: ~20 tests × 500 tokens = 10K tokens total
- Consider tagging expensive tests for selective CI runs
