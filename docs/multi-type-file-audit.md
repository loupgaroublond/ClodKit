# Multi-Type File Audit

Audit of all 31 files (out of 66 total) under `Sources/ClodKit/` containing more than one top-level type definition.

**Legend:** KEEP = types should stay together | SPLIT = candidates for extraction

---

## KEEP — Discriminated Unions

These files implement a discriminated union (enum + its associated payload structs). Splitting them would scatter a single algebraic data type across dozens of files with no benefit.

### Hooks/HookInputTypes.swift (17 types)

`enum HookInput` + 15 input structs (`PreToolUseInput`, `PostToolUseInput`, `StopInput`, etc.) + `enum ExitReason`

> Each struct is a case payload for `HookInput`. They share no independent lifecycle — you never import `PreToolUseInput` without `HookInput`.

### Hooks/HookOutputTypes.swift (14 types)

`enum HookSpecificOutput` + `enum HookJSONOutput` + `struct HookOutput` + `struct AsyncHookOutput` + 8 output structs + `enum PermissionRequestDecision`

> Same pattern as inputs — output structs are payloads for `HookSpecificOutput`.

### ControlProtocol/ControlRequests.swift (13 types)

`enum ControlRequestPayload` + `struct FullControlRequest` + 10 request structs (`InitializeRequest`, `SetModelRequest`, etc.)

> Each request struct is a case payload for `ControlRequestPayload`.

### ControlProtocol/ControlResponses.swift (5 types)

`enum FullControlResponsePayload` + `struct FullControlResponse` + `struct SuccessResponsePayload` + `struct ErrorResponsePayload` + `struct McpSetServersResult` + `struct RewindFilesResult`

> Response payloads for the control protocol enum.

---

## KEEP — Parallel Config Structs

### Query/HookConfigs.swift (15 types)

15 hook config structs (`PreToolUseHookConfig`, `PostToolUseHookConfig`, `StopHookConfig`, etc.)

> One config struct per `HookEvent` case. They are structurally identical (all hold a single callback closure of varying signature). Splitting into 15 separate files would add navigation overhead with zero semantic benefit.

---

## KEEP — Wire Protocol Message Families

These are message types that travel together over the same wire format. Splitting them breaks the mental model of "here's what goes over the wire."

### Transport/SDKMessage.swift (6 types)

`struct SDKMessage`, `struct ControlRequest`, `struct ControlResponse`, `struct ControlResponsePayload`, `struct ControlCancelRequest`, `enum SDKAssistantMessageError`

> All are JSON-line message shapes exchanged over stdin/stdout. Defined together because they share the same transport envelope.

### Transport/SDKHookMessages.swift (3 types)

`struct SDKHookStartedMessage`, `struct SDKHookProgressMessage`, `struct SDKHookResponseMessage`

> Three phases of a single hook lifecycle over the wire.

### Transport/SDKStatusMessage.swift (2 types)

`struct SDKStatusMessage`, `enum SDKStatus`

> The message and its status enum. `SDKStatus` is only used inside `SDKStatusMessage`.

### Transport/SDKInitMessage.swift (2 types)

`struct SDKInitMessage`, `struct PluginInfo`

> `PluginInfo` is a nested data shape only used inside `SDKInitMessage`.

### Transport/SDKFilesPersistedEvent.swift (3 types)

`struct SDKFilesPersistedEvent`, `struct PersistedFile`, `struct FailedFile`

> Sub-structs only used as fields of `SDKFilesPersistedEvent`.

### ControlProtocol/SDKControlInitializeResponse.swift (4 types)

`struct SDKControlInitializeResponse`, `struct SlashCommand`, `struct ModelInfo`, `struct AccountInfo`

> Sub-structs only used as fields of the initialize response.

### ControlProtocol/JSONRPCTypes.swift (2 types)

`struct JSONRPCMessage`, `struct JSONRPCError`

> `JSONRPCError` is a field inside `JSONRPCMessage`. Standard JSON-RPC pair.

---

## KEEP — Type + Its Error Enum

A type and its dedicated error enum belong together — the error describes failure modes of that specific type.

### Session/ClaudeSession.swift (2 types)

`actor ClaudeSession`, `enum SessionError`

> `SessionError` is thrown exclusively by `ClaudeSession` methods.

### Hooks/HookRegistry.swift (4 types)

`actor HookRegistry`, `enum HookError`, private `protocol AnyCallbackBox`, private `struct CallbackBox`

> `HookError` is specific to `HookRegistry`. The callback box types are private implementation details.

### Transport/Transport.swift (2 types)

`protocol Transport`, `enum TransportError`

> `TransportError` is the error type for `Transport` conformers.

### Transport/JSONLineParser.swift (2 types)

`struct JSONLineParser`, `enum JSONLineParserError`

> Parser-specific error enum.

### MCP/ToolArgs.swift (2 types)

`struct ToolArgs`, `enum ToolArgError`

> Argument extraction type and its error.

### Query/QueryAPI.swift (2 types)

`enum Clod` (namespace), `enum QueryError`

> `Clod` is the SDK namespace; `QueryError` is thrown by `Clod.query()`.

---

## KEEP — Tightly Coupled Small Structs

Types that only exist as fields/components of each other, with no independent use.

### Query/SDKUserMessage.swift (2 types)

`struct SDKUserMessage`, `struct UserMessageContent`

> `UserMessageContent` is only used as a field of `SDKUserMessage`.

### Query/QueryOptions.swift (2 types)

`struct QueryOptions`, `struct OutputFormat`

> `OutputFormat` is only used as a field of `QueryOptions`.

### Query/AgentDefinition.swift (2 types)

`struct AgentDefinition`, `enum AgentModel`

> `AgentModel` is only used as a field of `AgentDefinition`.

### Permissions/ExitPlanModeInput.swift (2 types)

`struct ExitPlanModeInput`, `struct AllowedPrompt`

> `AllowedPrompt` is only used as a field of `ExitPlanModeInput`.

### MCP/MCPTool.swift (2 types)

`struct MCPTool`, `struct MCPToolAnnotations`

> `MCPToolAnnotations` is only used as a field of `MCPTool`.

### MCP/MCPToolResult.swift (2 types)

`struct MCPToolResult`, `enum MCPContent`

> `MCPContent` is the content payload inside `MCPToolResult`.

### MCP/JSONSchema.swift (3 types)

`struct JSONSchema`, `struct PropertySchema`, private `class Box`

> `PropertySchema` is used inside `JSONSchema`. `Box` is a private recursive-type wrapper needed for `JSONSchema`'s self-referential structure.

### Transport/ProcessTransport.swift (2 types)

`actor ProcessTransport`, internal `struct ProcessConfiguration`

> `ProcessConfiguration` is an internal testable seam extracted from `ProcessTransport`. Not public API.

### Backend/SpawnTypes.swift (2 types)

`protocol SpawnedProcess`, `struct SpawnOptions`

> Both are the interface contract for spawning subprocesses. Always used together.

---

## SPLIT — Candidates for Extraction

### MCP/ToolParam.swift (3 types)

`struct ToolParam`, `enum ParamType`, `struct ParamBuilder`

> `ParamType` could stay (it's a field of `ToolParam`), but **`ParamBuilder`** is a result builder DSL with its own API surface. It's a consumer of `ToolParam`, not a component of it.

**Recommendation:** Extract `ParamBuilder` to `MCP/ParamBuilder.swift`.

### Session/V2SessionTypes.swift (3 types)

`protocol SDKSession`, `struct SDKSessionOptions`, `struct SDKResultMessage`

> These are three distinct public API types that happen to all relate to V2 sessions. `SDKSession` is a protocol, `SDKSessionOptions` configures it, `SDKResultMessage` is its output. As the V2 API matures, these will grow independently.

**Recommendation:** Extract to `Session/SDKSession.swift`, `Session/SDKSessionOptions.swift`, `Session/SDKResultMessage.swift`.

### Query/McpServerStatus.swift (4 types)

`struct McpServerStatus`, `struct McpServerInfo`, `struct McpToolInfo`, `struct McpToolAnnotations`

> Three-level nesting of data types. While related, `McpToolInfo` and `McpToolAnnotations` describe MCP tool metadata that could be referenced independently of `McpServerStatus`.

**Recommendation:** Extract `McpToolInfo` + `McpToolAnnotations` to `Query/McpToolInfo.swift`. Keep `McpServerStatus` + `McpServerInfo` together.

### Query/SandboxSettings.swift (3 types)

`struct SandboxSettings`, `struct SandboxNetworkConfig`, `struct RipgrepConfig`

> `SandboxNetworkConfig` is a sub-field of `SandboxSettings` (keep). **`RipgrepConfig`** is a sibling configuration struct with no structural relationship to sandbox networking.

**Recommendation:** Extract `RipgrepConfig` to `Query/RipgrepConfig.swift`.

---

## Summary

| Verdict | Files | Types |
|---------|-------|-------|
| KEEP — Discriminated unions | 4 | 49 |
| KEEP — Parallel configs | 1 | 15 |
| KEEP — Wire protocol families | 7 | 22 |
| KEEP — Type + error enum | 6 | 13 |
| KEEP — Tightly coupled structs | 11 | 24 |
| **SPLIT** | **4** | **5 types to extract** |
| **Total** | **31** | **~128** |

4 files have types worth splitting. The remaining 27 files have legitimate reasons to keep their types co-located.
