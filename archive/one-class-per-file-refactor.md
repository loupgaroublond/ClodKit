# One-Class-Per-File Refactoring Plan

This document outlines the changes needed to refactor NativeClaudeCodeSDK to a traditional one-class-per-file structure, with documented exceptions.

## Current State Summary

- **16 Swift source files** containing **76+ types**
- Several files contain 10+ types that should be separated
- Some files are already well-organized (single responsibility)

---

## Files Requiring No Changes

These files already follow one-class-per-file or contain a single cohesive unit:

| File | Types | Rationale |
|------|-------|-----------|
| `Backend/NativeBackend.swift` | See exceptions section | Keep together with related types |
| `Transport/JSONLineParser.swift` | `JSONLineParser`, `JSONLineParserError` | Error enum is tightly coupled |
| `Transport/MockTransport.swift` | `MockTransport` | Single class |
| `Transport/ProcessTransport.swift` | `ProcessTransport` | Single class + private extension |
| `ControlProtocol/ControlProtocolHandler.swift` | `ControlProtocolHandler` + typealiases | Typealiases are handler contracts |
| `MCP/MCPServerRouter.swift` | `MCPServerRouter` | Single actor |
| `Session/ClaudeSession.swift` | `ClaudeSession`, `SessionError` | Error enum is tightly coupled |
| `Query/ClaudeQuery.swift` | `ClaudeQuery`, `ClaudeQuery.AsyncIterator` | Nested type is implementation detail |

---

## Files Requiring Refactoring

### 1. `Transport/Transport.swift`

**Current contents (8 types):**
- `Transport` (protocol)
- `TransportError` (enum)
- `StdoutMessage` (enum)
- `SDKMessage` (struct)
- `ControlRequest` (struct)
- `ControlResponse` (struct)
- `ControlResponsePayload` (struct)
- `ControlCancelRequest` (struct)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `Transport/Transport.swift` | `Transport`, `TransportError` | Keep protocol + its error together |
| `Transport/StdoutMessage.swift` | `StdoutMessage` | Standalone enum for stdout parsing |
| `Transport/SDKMessage.swift` | `SDKMessage`, `ControlRequest`, `ControlResponse`, `ControlResponsePayload`, `ControlCancelRequest` | **EXCEPTION**: These are all low-level control protocol message types that form a cohesive unit |

**Migration checklist:**
- [ ] Ensure all types remain `public`
- [ ] No import changes needed (same module)
- [ ] `StdoutMessage` is self-contained, safe to move


### 2. `Hooks/HookTypes.swift`

**Current contents (22 types):**
- `JSONValue` (enum)
- `HookEvent` (enum)
- `HookMatcherConfig` (struct)
- `BaseHookInput` (struct)
- 10 specific input structs (`PreToolUseInput`, `PostToolUseInput`, etc.)
- `PermissionDecision` (enum)
- `PreToolUseHookOutput`, `PostToolUseHookOutput` (structs)
- `HookSpecificOutput` (enum)
- `HookOutput` (struct)
- `HookInput` (enum)
- `HookCallback`, `AnyHookCallback` (typealiases)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `Hooks/JSONValue.swift` | `JSONValue` | General-purpose enum, used elsewhere |
| `Hooks/HookEvent.swift` | `HookEvent` | Enum of all hook event types |
| `Hooks/HookMatcherConfig.swift` | `HookMatcherConfig` | Configuration struct |
| `Hooks/HookInputTypes.swift` | `BaseHookInput`, all `*Input` structs (10 total), `HookInput` enum | **EXCEPTION**: Keep all input types together—they form a discriminated union pattern |
| `Hooks/HookOutputTypes.swift` | `PreToolUseHookOutput`, `PostToolUseHookOutput`, `HookSpecificOutput`, `HookOutput` | **EXCEPTION**: Keep all output types together—same rationale |
| `Hooks/HookCallbacks.swift` | `HookCallback`, `AnyHookCallback`, `PermissionDecision` | **EXCEPTION**: Typealiases + enum they reference |

**Migration checklist:**
- [ ] `JSONValue` extension in `HookRegistry.swift` needs import path (same module, no change)
- [ ] Ensure `HookInput` cases reference input types correctly
- [ ] All types are `Codable` and `Sendable`—preserve conformances


### 3. `Hooks/HookRegistry.swift`

**Current contents (4 types + extension):**
- `HookError` (enum)
- `AnyCallbackBox` (private protocol)
- `CallbackBox<Input>` (private struct)
- `HookRegistry` (actor)
- `JSONValue` extension (fileprivate accessor properties)

**Proposed changes:**

| Action | Details |
|--------|---------|
| Keep in `HookRegistry.swift` | `HookRegistry`, `HookError`, `AnyCallbackBox`, `CallbackBox` |
| Move | `JSONValue` extension → `Hooks/JSONValue.swift` |

**EXCEPTION**: `AnyCallbackBox` and `CallbackBox<Input>` are `private` implementation details of `HookRegistry`. They exist only to support type-erased callback storage. Moving them would require making them `internal` or `public`, which leaks implementation details.

**Migration checklist:**
- [ ] Move `JSONValue` extension to `JSONValue.swift`
- [ ] Change extension access from `fileprivate` to `public` (already has public accessors)
- [ ] Keep private types in place


### 4. `ControlProtocol/ControlProtocolTypes.swift`

**Current contents (19 types):**
- 8 request structs (`InitializeRequest`, `SetPermissionModeRequest`, etc.)
- `ControlRequestPayload` (enum)
- `FullControlRequest` (struct)
- `SuccessResponsePayload`, `ErrorResponsePayload` (structs)
- `FullControlResponsePayload` (enum)
- `FullControlResponse` (struct)
- `JSONRPCMessage`, `JSONRPCError` (structs)
- `ControlProtocolError` (enum)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `ControlProtocol/ControlRequests.swift` | All 8 `*Request` structs, `ControlRequestPayload`, `FullControlRequest` | **EXCEPTION**: Request types form discriminated union |
| `ControlProtocol/ControlResponses.swift` | `SuccessResponsePayload`, `ErrorResponsePayload`, `FullControlResponsePayload`, `FullControlResponse` | **EXCEPTION**: Response types form discriminated union |
| `ControlProtocol/JSONRPCTypes.swift` | `JSONRPCMessage`, `JSONRPCError` | JSON-RPC wire format types |
| `ControlProtocol/ControlProtocolError.swift` | `ControlProtocolError` | Standalone error enum |

**Migration checklist:**
- [ ] All types are `Codable` and `Sendable`
- [ ] `ControlRequestPayload` references all request types—must be in same file or after imports
- [ ] `FullControlResponsePayload` references response types—same constraint


### 5. `Permissions/PermissionTypes.swift`

**Current contents (6 types):**
- `PermissionMode` (enum)
- `ToolPermissionContext` (struct)
- `PermissionResult` (enum)
- `PermissionUpdate` (struct with 3 nested enums)
- `PermissionRule` (struct)
- `CanUseToolCallback` (typealias)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `Permissions/PermissionMode.swift` | `PermissionMode` | Standalone enum |
| `Permissions/ToolPermissionContext.swift` | `ToolPermissionContext` | Standalone struct |
| `Permissions/PermissionResult.swift` | `PermissionResult` | Standalone enum |
| `Permissions/PermissionUpdate.swift` | `PermissionUpdate` (with nested `UpdateType`, `Behavior`, `Destination`) | **EXCEPTION**: Nested enums are semantically part of the parent |
| `Permissions/PermissionRule.swift` | `PermissionRule` | Standalone struct |
| `Permissions/CanUseToolCallback.swift` | `CanUseToolCallback` | Typealias (or merge into related file) |

**Alternative:** Keep `CanUseToolCallback` in `PermissionResult.swift` since the typealias returns `PermissionResult`.

**Migration checklist:**
- [ ] `PermissionUpdate` nested enums stay nested
- [ ] All types are `Codable`/`Sendable`


### 6. `MCP/MCPTool.swift`

**Current contents (6 types):**
- `MCPTool` (struct)
- `MCPToolResult` (struct)
- `MCPContent` (enum)
- `JSONSchema` (struct)
- `Box<T>` (private class)
- `PropertySchema` (struct + Codable extension)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `MCP/MCPTool.swift` | `MCPTool` | Main tool definition |
| `MCP/MCPToolResult.swift` | `MCPToolResult`, `MCPContent` | **EXCEPTION**: Result contains content, keep together |
| `MCP/JSONSchema.swift` | `JSONSchema`, `PropertySchema`, `Box<T>` | **EXCEPTION**: Schema types are tightly coupled; `Box` is private recursive-type helper |

**Migration checklist:**
- [ ] `Box<T>` must stay `private` in `JSONSchema.swift`
- [ ] `PropertySchema` Codable extension stays with struct
- [ ] `MCPTool` references `JSONSchema`—no issue (same module)


### 7. `MCP/SDKMCPServer.swift`

**Current contents (4 types + function):**
- `SDKMCPServer` (class)
- `MCPServerError` (enum + LocalizedError extension)
- `MCPToolBuilder` (@resultBuilder)
- `createSDKMCPServer()` (freestanding function)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `MCP/SDKMCPServer.swift` | `SDKMCPServer`, `MCPServerError` | Keep class + its error |
| `MCP/MCPToolBuilder.swift` | `MCPToolBuilder`, `createSDKMCPServer()` | **EXCEPTION**: Result builder + its convenience function |

**Migration checklist:**
- [ ] `createSDKMCPServer()` uses `MCPToolBuilder`—keep together
- [ ] `MCPToolBuilder` is public API for DSL


### 8. `Query/QueryAPI.swift`

**Current contents (10+ types):**
- `QueryOptions` (struct)
- `MCPServerConfig` (struct)
- 5 hook config structs (`PreToolUseHookConfig`, etc.)
- `query()` (freestanding function)
- `buildCLIArguments()`, `buildMCPConfigFile()` (private functions)
- `QueryError` (enum + LocalizedError extension)
- `ClaudeCode` (namespace enum)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `Query/QueryOptions.swift` | `QueryOptions` | Main options struct |
| `Query/MCPServerConfig.swift` | `MCPServerConfig` | Server configuration |
| `Query/HookConfigs.swift` | All 5 `*HookConfig` structs | **EXCEPTION**: Parallel structure, keep together |
| `Query/QueryAPI.swift` | `query()`, `buildCLIArguments()`, `buildMCPConfigFile()`, `QueryError`, `ClaudeCode` | **EXCEPTION**: Entry point function + helpers + namespace |

**Migration checklist:**
- [ ] `query()` function references `QueryOptions`, hook configs—ensure imports work
- [ ] `ClaudeCode` namespace may be better in its own file if it grows
- [ ] Private helper functions stay with `query()`


### 9. `Backend/NativeBackend.swift`

**Current contents (5 types):**
- `NativeClaudeCodeBackend` (protocol)
- `NativeBackend` (class)
- `NativeBackendError` (enum + LocalizedError extension)
- `BackendType` (enum)
- `NativeBackendFactory` (enum/namespace)

**Proposed split:**

| New File | Types to Move | Notes |
|----------|---------------|-------|
| `Backend/NativeClaudeCodeBackend.swift` | `NativeClaudeCodeBackend` | Protocol definition |
| `Backend/NativeBackend.swift` | `NativeBackend`, `NativeBackendError` | Implementation + its error |
| `Backend/BackendType.swift` | `BackendType` | Enum for backend selection |
| `Backend/NativeBackendFactory.swift` | `NativeBackendFactory` | Factory namespace |

**Migration checklist:**
- [ ] `NativeBackend` conforms to `NativeClaudeCodeBackend`—import order matters
- [ ] Factory references `BackendType` and creates `NativeBackend`

---

## Summary of Exceptions

### Exception Type: Discriminated Union Pattern

Keep enum + all its case-associated types in one file:

- `Transport/SDKMessage.swift` — Control message types
- `Hooks/HookInputTypes.swift` — All hook input structs + `HookInput` enum
- `Hooks/HookOutputTypes.swift` — All hook output structs + `HookSpecificOutput` enum
- `ControlProtocol/ControlRequests.swift` — Request structs + `ControlRequestPayload`
- `ControlProtocol/ControlResponses.swift` — Response structs + `FullControlResponsePayload`


### Exception Type: Private Implementation Details

Keep private/fileprivate types with their public consumer:

- `HookRegistry.swift` — `AnyCallbackBox`, `CallbackBox<Input>` (private type erasure)
- `MCP/JSONSchema.swift` — `Box<T>` (private recursive type wrapper)
- `Transport/ProcessTransport.swift` — `Data.hasSuffix` extension (private)


### Exception Type: Nested Types

Keep nested types with their parent:

- `PermissionUpdate` — Contains `UpdateType`, `Behavior`, `Destination` enums
- `ClaudeQuery` — Contains `AsyncIterator` struct


### Exception Type: Tightly Coupled Pairs

Keep error enums with their primary type:

- `JSONLineParser` + `JSONLineParserError`
- `SDKMCPServer` + `MCPServerError`
- `NativeBackend` + `NativeBackendError`
- `ClaudeSession` + `SessionError`
- `Transport` + `TransportError`
- `ControlProtocolHandler` + handler typealiases


### Exception Type: Result Builders

Keep @resultBuilder with its convenience function:

- `MCPToolBuilder` + `createSDKMCPServer()`


### Exception Type: Configuration Groups

Keep parallel configuration structs together:

- `Query/HookConfigs.swift` — All 5 hook config types

---

## Proposed Final Directory Structure

```
Sources/ClaudeCodeSDK/
├── Backend/
│   ├── BackendType.swift
│   ├── NativeBackend.swift
│   ├── NativeBackendFactory.swift
│   └── NativeClaudeCodeBackend.swift
├── ControlProtocol/
│   ├── ControlProtocolError.swift
│   ├── ControlProtocolHandler.swift
│   ├── ControlRequests.swift
│   ├── ControlResponses.swift
│   └── JSONRPCTypes.swift
├── Hooks/
│   ├── HookCallbacks.swift
│   ├── HookEvent.swift
│   ├── HookInputTypes.swift
│   ├── HookMatcherConfig.swift
│   ├── HookOutputTypes.swift
│   ├── HookRegistry.swift
│   └── JSONValue.swift
├── MCP/
│   ├── JSONSchema.swift
│   ├── MCPServerRouter.swift
│   ├── MCPTool.swift
│   ├── MCPToolBuilder.swift
│   ├── MCPToolResult.swift
│   └── SDKMCPServer.swift
├── Permissions/
│   ├── CanUseToolCallback.swift (or merge)
│   ├── PermissionMode.swift
│   ├── PermissionResult.swift
│   ├── PermissionRule.swift
│   ├── PermissionUpdate.swift
│   └── ToolPermissionContext.swift
├── Query/
│   ├── ClaudeQuery.swift
│   ├── HookConfigs.swift
│   ├── MCPServerConfig.swift
│   ├── QueryAPI.swift
│   └── QueryOptions.swift
├── Session/
│   └── ClaudeSession.swift
└── Transport/
    ├── JSONLineParser.swift
    ├── MockTransport.swift
    ├── ProcessTransport.swift
    ├── SDKMessage.swift
    ├── StdoutMessage.swift
    └── Transport.swift
```

**File count:** 16 → 37 files (approximate)

---

## Execution Order

Recommended order to minimize conflicts:

1. **Transport/** — Foundation layer, no internal dependencies
2. **Hooks/JSONValue.swift** — Extract first (used by HookRegistry)
3. **Hooks/** — Rest of hook types
4. **ControlProtocol/** — Depends on Transport types
5. **Permissions/** — Standalone
6. **MCP/** — Depends on JSONSchema
7. **Query/** — Depends on Hooks, MCP configs
8. **Backend/** — Depends on Transport, Query

---

## Validation Checklist

After refactoring:

- [ ] `swift build` succeeds
- [ ] `swift test` passes
- [ ] All types maintain original access level (`public`, `internal`, etc.)
- [ ] No circular dependencies introduced
- [ ] No duplicate type definitions
- [ ] All `Codable` conformances preserved
- [ ] All `Sendable` conformances preserved
- [ ] Example app still compiles

---

## Hard Requirements

### 100% Test Coverage

**This refactoring is NOT complete until 100% code coverage is achieved.**

- All new files must have corresponding test coverage
- Run `swift test --enable-code-coverage` after refactoring
- Generate coverage report with `xcrun llvm-cov report`
- Every public type, method, and code path must be tested
- No exceptions—100% is a hard gate for completion

---

## Notes

- **No import changes needed** — All files are in the same module (`ClaudeCodeSDK`)
- **Access levels unchanged** — Types keep their existing visibility
- **Extensions stay with types** — `Codable`, `LocalizedError` extensions move with their types
- **Preserve file headers** — Keep any existing copyright/license headers
