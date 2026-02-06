# Integration Test Specification

This document specifies all features that require integration testing against the real Claude CLI.

## Feature Inventory

### 1. Core Query API

| Feature | Status | Test File |
|---------|--------|-----------|
| `ClaudeCode.query(prompt:options:)` | Tested | IntegrationTests.swift |
| AsyncSequence iteration | Tested | IntegrationTests.swift |
| Message types (system, assistant, result) | Tested | MessageTypeIntegrationTests |
| Stream completion | Tested | Various |

### 2. QueryOptions Configuration

| Option | Status | Test File |
|--------|--------|-----------|
| `model` | Tested | IntegrationTests.swift |
| `maxTurns` | Tested | IntegrationTests.swift |
| `maxThinkingTokens` | **NOT TESTED** | - |
| `permissionMode` | Tested | PermissionCallbackIntegrationTests |
| `systemPrompt` | Tested | IntegrationTests.swift |
| `appendSystemPrompt` | Tested | IntegrationTests.swift |
| `workingDirectory` | Tested | IntegrationTests.swift |
| `environment` | Tested | IntegrationTests.swift |
| `cliPath` | Tested | ErrorIntegrationTests.swift |
| `allowedTools` | Tested | IntegrationTests.swift |
| `blockedTools` | Tested | IntegrationTests.swift |
| `additionalDirectories` | Tested | IntegrationTests.swift |
| `resume` (session continuation) | **NOT TESTED** | - |
| `mcpServers` (external) | **NOT TESTED** | - |
| `sdkMcpServers` (in-process) | Tested | MCPIntegrationTests.swift |
| `stderrHandler` | **NOT TESTED** | - |

### 3. Control Methods (ClaudeQuery)

| Method | Status | Test File |
|--------|--------|-----------|
| `interrupt()` | Tested | ControlProtocolIntegrationTests |
| `setModel(_:)` | **NOT TESTED** | - |
| `setPermissionMode(_:)` | **NOT TESTED** | - |
| `setMaxThinkingTokens(_:)` | **NOT TESTED** | - |
| `rewindFiles(to:dryRun:)` | **NOT TESTED** | - |
| `mcpStatus()` | Tested | ControlProtocolIntegrationTests |
| `reconnectMcpServer(name:)` | **NOT TESTED** | - |
| `toggleMcpServer(name:enabled:)` | **NOT TESTED** | - |
| `sessionId` property | Tested | ControlProtocolIntegrationTests |

### 4. Hook System

| Hook Type | Status | Test File |
|-----------|--------|-----------|
| PreToolUse - invocation | Tested | HooksIntegrationTests.swift |
| PreToolUse - deny | Tested | HooksIntegrationTests.swift |
| PreToolUse - pattern matching | Tested | HooksIntegrationTests.swift |
| PreToolUse - modifyInput | **NOT TESTED** | - |
| PostToolUse - invocation | Tested | HooksIntegrationTests.swift |
| PostToolUse - modifyResponse | **NOT TESTED** | - |
| PostToolUseFailure - invocation | **NOT TESTED** | - |
| PostToolUseFailure - retry | **NOT TESTED** | - |
| UserPromptSubmit - invocation | Tested | HooksIntegrationTests.swift |
| UserPromptSubmit - modifyPrompt | **NOT TESTED** | - |
| Stop - invocation | Tested | HooksIntegrationTests.swift |
| Multiple hooks same event | Tested | HooksIntegrationTests.swift |
| Hook timeout handling | **NOT TESTED** | - |

### 5. SDK MCP Servers

| Feature | Status | Test File |
|---------|--------|-----------|
| Tool registration | Tested | MCPIntegrationTests.swift |
| Tool invocation | Tested | MCPIntegrationTests.swift |
| Tool error handling | Tested | MCPIntegrationTests.swift |
| Multiple servers | Tested | MCPIntegrationTests.swift |
| Complex input schema | Tested | MCPIntegrationTests.swift |
| Multiple content results | Tested | MCPIntegrationTests.swift |
| Image content result | **NOT TESTED** | - |
| Async tool handlers | **NOT TESTED** | - |

### 6. Permission System

| Feature | Status | Test File |
|---------|--------|-----------|
| `canUseTool` callback invocation | Tested | PermissionCallbackIntegrationTests |
| `allowTool()` | Tested | PermissionCallbackIntegrationTests |
| `allowToolWithModification(input:)` | **NOT TESTED** | - |
| `denyTool(reason:)` | Tested | PermissionCallbackIntegrationTests |
| `denyToolAndInterrupt(reason:)` | Tested | PermissionCallbackIntegrationTests |
| `requestUserConfirmation(question:)` | **NOT TESTED** | - |
| `bypassPermissions` mode | Tested | PermissionCallbackIntegrationTests |
| `requireExplicitApproval` mode | **NOT TESTED** | - |
| ToolPermissionContext fields | **NOT TESTED** | - |

### 7. Error Handling & Edge Cases

| Scenario | Status | Test File |
|----------|--------|-----------|
| CLI not available | Tested | ErrorIntegrationTests.swift |
| Invalid model | Tested | ErrorIntegrationTests.swift |
| Invalid working directory | Tested | ErrorIntegrationTests.swift |
| Operation timeout | Tested | ErrorIntegrationTests.swift |
| Resource cleanup | Tested | ErrorIntegrationTests.swift |
| Cleanup after interrupt | Tested | ErrorIntegrationTests.swift |
| Rapid sequential queries | Tested | ErrorIntegrationTests.swift |
| Concurrent parallel queries | **NOT TESTED** | - |
| Process crash handling | **NOT TESTED** | - |
| Network interruption | **NOT TESTED** | - |
| Very long responses | **NOT TESTED** | - |

---

## Gap Analysis Summary

### Critical Gaps (Core Functionality)

1. **Control Methods** - 5 of 8 untested
   - `setModel()` - Model switching mid-query
   - `setPermissionMode()` - Permission mode switching
   - `setMaxThinkingTokens()` - Thinking token adjustment
   - `rewindFiles()` - File rollback capability
   - `reconnectMcpServer()` / `toggleMcpServer()` - MCP management

2. **Session Continuation** - Resume with session ID untested

3. **Extended Thinking** - `maxThinkingTokens` option untested

### Important Gaps (Advanced Features)

4. **Hook Modifications**
   - PreToolUse input modification
   - PostToolUse response modification
   - UserPromptSubmit prompt modification
   - Hook timeout behavior

5. **PostToolUseFailure Hooks** - Entire hook type untested

6. **Permission Variants**
   - `allowToolWithModification` - Input modification
   - `requestUserConfirmation` - Interactive confirmation
   - `requireExplicitApproval` mode
   - ToolPermissionContext field verification

### Lower Priority Gaps

7. **External MCP Servers** - stdio/sse transport types

8. **Edge Cases**
   - Concurrent parallel queries
   - Process crash recovery
   - Very long responses (context limits)

9. **Observability**
   - `stderrHandler` callback

---

## Implementation Priority

### Phase 1: Critical Control Methods
1. `setModel()` integration test
2. `setPermissionMode()` integration test
3. `setMaxThinkingTokens()` integration test
4. Session `resume` integration test

### Phase 2: Hook Completeness
5. PreToolUse modifyInput test
6. PostToolUseFailure hook tests
7. Hook timeout handling test

### Phase 3: Permission System
8. `allowToolWithModification` test
9. `requestUserConfirmation` test (if supported by CLI)
10. `requireExplicitApproval` mode test
11. ToolPermissionContext verification

### Phase 4: MCP Management
12. `rewindFiles()` integration test
13. `reconnectMcpServer()` integration test
14. `toggleMcpServer()` integration test

### Phase 5: Edge Cases & Observability
15. Concurrent parallel queries test
16. `stderrHandler` callback test
17. Very long response handling test
