# Gap Analysis: Claude Agent SDK v0.2.34

Comparison of the current API spec (`CLAUDE_AGENT_SDK_API_SPEC.md`, dated 2026-01-28) against the actual TypeScript type definitions shipped in `@anthropic-ai/claude-agent-sdk@0.2.34` (Claude Code v2.1.34).

**Source files analyzed:**
- `sdk.d.ts` — Primary type declarations (1835 lines)
- `sdk-tools.d.ts` — Tool input JSON schemas (1570 lines)
- `package.json` — Package metadata

**Analysis date:** 2026-02-07

---

## Table of Contents

1. [V2 Session API (Entirely New)](#1-v2-session-api-entirely-new)
2. [PermissionMode — New Values](#2-permissionmode--new-values)
3. [Query Interface — New Methods](#3-query-interface--new-methods)
4. [Options / ClaudeAgentOptions — New Fields](#4-options--claudeagentoptions--new-fields)
5. [AgentDefinition — New Fields](#5-agentdefinition--new-fields)
6. [Hook System — New Events and Updated Inputs](#6-hook-system--new-events-and-updated-inputs)
7. [SDKMessage Union — New Message Types](#7-sdkmessage-union--new-message-types)
8. [Updated Existing Message Types](#8-updated-existing-message-types)
9. [CanUseTool Callback — Expanded Signature](#9-canuseTool-callback--expanded-signature)
10. [MCP — New Config Type and Status Changes](#10-mcp--new-config-type-and-status-changes)
11. [tool() Function — New Parameter](#11-tool-function--new-parameter)
12. [Sandbox Settings — Schema Changes](#12-sandbox-settings--schema-changes)
13. [Tool Input Schemas — Renames and New Tools](#13-tool-input-schemas--renames-and-new-tools)
14. [Minor Type Changes](#14-minor-type-changes)
15. [New Supporting Types](#15-new-supporting-types)
16. [ClodKit Impact Assessment](#16-clodkit-impact-assessment)

---

## 1. V2 Session API (Entirely New)

The SDK exports an entirely new V2 multi-turn session API that does not appear anywhere in the existing spec. All three functions and both types are marked `@alpha` / `UNSTABLE`.

### 1.1 New Exported Functions

#### `unstable_v2_createSession()`

Creates a persistent session for multi-turn conversations.

```typescript
function unstable_v2_createSession(_options: SDKSessionOptions): SDKSession
```

#### `unstable_v2_prompt()`

One-shot convenience function for single prompts. Wraps session creation, message sending, and result collection into a single awaitable call.

```typescript
function unstable_v2_prompt(
  _message: string,
  _options: SDKSessionOptions
): Promise<SDKResultMessage>
```

#### `unstable_v2_resumeSession()`

Resumes an existing session by its ID.

```typescript
function unstable_v2_resumeSession(
  _sessionId: string,
  _options: SDKSessionOptions
): SDKSession
```

### 1.2 `SDKSession` Interface

| Member | Signature | Description |
|--------|-----------|-------------|
| `sessionId` | `readonly string` | Session ID. Available after first message, or immediately for resumed sessions. Throws if accessed before initialization. |
| `send()` | `(message: string \| SDKUserMessage) => Promise<void>` | Send a message to the agent |
| `stream()` | `AsyncGenerator<SDKMessage, void>` | Stream messages from the agent |
| `close()` | `void` | Close the session |
| `[Symbol.asyncDispose]()` | `Promise<void>` | Async disposal support (calls close if not already closed) |

### 1.3 `SDKSessionOptions` Type

A subset of `Options` with `model` as the only required field:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | `string` | **Yes** | Model to use |
| `pathToClaudeCodeExecutable` | `string` | No | Path to CLI executable |
| `executable` | `'node' \| 'bun'` | No | JS runtime (note: `'deno'` absent unlike `Options`) |
| `executableArgs` | `string[]` | No | Arguments to pass to executable |
| `env` | `Record<string, string \| undefined>` | No | Environment variables (defaults to `process.env`) |
| `allowedTools` | `string[]` | No | Auto-allowed tool names |
| `disallowedTools` | `string[]` | No | Blocked tool names |
| `canUseTool` | `CanUseTool` | No | Custom permission handler |
| `hooks` | `Partial<Record<HookEvent, HookCallbackMatcher[]>>` | No | Hook callbacks |
| `permissionMode` | `PermissionMode` | No | Permission mode |

**Notable differences from `Options`:** `SDKSessionOptions` does not include `mcpServers`, `systemPrompt`, `agents`, `sandbox`, `betas`, `outputFormat`, `maxTurns`, `maxBudgetUsd`, or any of the session resume/fork fields. This is a much more constrained surface.

---

## 2. PermissionMode — New Values

The spec documents 4 permission mode values. The SDK defines 6.

| Value | Spec | SDK | Description |
|-------|------|-----|-------------|
| `'default'` | Yes | Yes | Standard permission behavior, prompts for dangerous operations |
| `'acceptEdits'` | Yes | Yes | Auto-accept file edit operations |
| `'bypassPermissions'` | Yes | Yes | Bypass all permission checks (requires `allowDangerouslySkipPermissions`) |
| `'plan'` | Yes | Yes | Planning mode, no actual tool execution |
| **`'delegate'`** | **No** | **Yes** | Delegate mode — restricts team leader to only Teammate and Task tools |
| **`'dontAsk'`** | **No** | **Yes** | Don't prompt for permissions, deny if not pre-approved |

The `'delegate'` mode implies a "team leader" concept, suggesting deeper multi-agent orchestration. The `'dontAsk'` mode is useful for fully automated pipelines where any permission denial should be silent rather than interactive.

Both new values appear consistently throughout the SDK:
- In the `PermissionMode` type
- In the `SDKSystemMessage` JSDoc
- In the `SDKControlSetPermissionModeRequest` JSDoc
- In the `AgentInput.mode` field for spawned teammates
- In the `SDKSessionOptions.permissionMode` field

---

## 3. Query Interface — New Methods

The spec documents 8 methods on `Query`. The SDK defines 14. Six are entirely new, and one has a changed signature.

### 3.1 New Methods

#### `initializationResult()`

Returns the full initialization response, including data not available through the individual convenience methods.

```typescript
initializationResult(): Promise<SDKControlInitializeResponse>
```

**`SDKControlInitializeResponse`:**

| Field | Type | Description |
|-------|------|-------------|
| `commands` | `SlashCommand[]` | Available slash commands / skills |
| `output_style` | `string` | Current output style |
| `available_output_styles` | `string[]` | All available output styles |
| `models` | `ModelInfo[]` | Available models |
| `account` | `AccountInfo` | Logged-in user's account info |

This is a superset of what `supportedCommands()`, `supportedModels()`, and `accountInfo()` return individually, plus `output_style` and `available_output_styles` which have no individual accessor.

#### `reconnectMcpServer()`

Reconnects a failed or disconnected MCP server by name. Throws on failure.

```typescript
reconnectMcpServer(serverName: string): Promise<void>
```

#### `toggleMcpServer()`

Enables or disables an MCP server by name. Throws on failure.

```typescript
toggleMcpServer(serverName: string, enabled: boolean): Promise<void>
```

#### `setMcpServers()`

Dynamically replaces the set of SDK-managed MCP servers. Servers that are removed get disconnected; new servers get connected. Does not affect servers configured via settings files.

Supports both process-based servers (stdio, sse, http) and SDK servers (in-process).

```typescript
setMcpServers(
  servers: Record<string, McpServerConfig>
): Promise<McpSetServersResult>
```

**`McpSetServersResult`** (new type):

| Field | Type | Description |
|-------|------|-------------|
| `added` | `string[]` | Names of servers that were added |
| `removed` | `string[]` | Names of servers that were removed |
| `errors` | `Record<string, string>` | Map of server names to error messages for failed connections |

#### `streamInput()`

Streams input messages to the query. Used internally for multi-turn conversations.

```typescript
streamInput(stream: AsyncIterable<SDKUserMessage>): Promise<void>
```

#### `close()`

Forcefully ends the query, cleaning up all resources including pending requests, MCP transports, and the CLI subprocess. After calling `close()`, no further messages will be received.

```typescript
close(): void
```

### 3.2 Changed Method: `rewindFiles()`

**Spec signature:**
```typescript
rewindFiles(): Promise<void>
```

**SDK signature:**
```typescript
rewindFiles(
  userMessageId: string,
  options?: { dryRun?: boolean }
): Promise<RewindFilesResult>
```

The method now takes the target user message ID as a parameter (spec described it as restoring "to state at specified message UUID" but didn't show the parameter). It also supports a dry-run mode and returns a structured result.

**`RewindFilesResult`** (new type):

| Field | Type | Description |
|-------|------|-------------|
| `canRewind` | `boolean` | Whether the rewind is possible |
| `error` | `string \| undefined` | Error message if rewind failed |
| `filesChanged` | `string[] \| undefined` | List of file paths that were (or would be) changed |
| `insertions` | `number \| undefined` | Number of line insertions |
| `deletions` | `number \| undefined` | Number of line deletions |

---

## 4. Options / ClaudeAgentOptions — New Fields

The spec documents ~35 fields. The SDK adds 6 new ones.

### 4.1 `agent`

```typescript
agent?: string
```

Agent name for the main thread. When specified, the agent's system prompt, tool restrictions, and model will be applied to the main conversation. The agent must be defined either in the `agents` option or in settings. Equivalent to the `--agent` CLI flag.

**Example:**
```typescript
{
  agent: 'code-reviewer',
  agents: {
    'code-reviewer': {
      description: 'Reviews code for best practices',
      prompt: 'You are a code reviewer...'
    }
  }
}
```

### 4.2 `persistSession`

```typescript
persistSession?: boolean  // default: true
```

When `false`, disables session persistence to disk. Sessions will not be saved to `~/.claude/projects/` and cannot be resumed later. Useful for ephemeral or automated workflows where session history is not needed.

### 4.3 `sessionId`

```typescript
sessionId?: string
```

Use a specific session ID (must be a valid UUID) instead of an auto-generated one. Cannot be used with `continue` or `resume` unless `forkSession` is also set (to specify a custom ID for the forked session).

### 4.4 `debug`

```typescript
debug?: boolean
```

Enable debug mode for the Claude Code process. Equivalent to the `--debug` CLI flag. Debug output can be captured via the `stderr` callback.

### 4.5 `debugFile`

```typescript
debugFile?: string
```

Write debug logs to a specific file path. Implicitly enables debug mode. Equivalent to `--debug-file <path>` CLI flag.

### 4.6 `spawnClaudeCodeProcess`

```typescript
spawnClaudeCodeProcess?: (options: SpawnOptions) => SpawnedProcess
```

Custom function to spawn the Claude Code process. Enables running Claude Code in VMs, containers, or remote environments. When provided, replaces the default local spawn behavior.

See [Section 15](#15-new-supporting-types) for `SpawnOptions` and `SpawnedProcess` definitions.

---

## 5. AgentDefinition — New Fields

The spec documents 4 fields (`description`, `tools`, `prompt`, `model`). The SDK defines 9 — five are new.

### 5.1 `disallowedTools`

```typescript
disallowedTools?: string[]
```

Array of tool names to explicitly disallow for this agent. Complements `tools` (allowlist) with a denylist, giving finer-grained control without needing to enumerate every allowed tool.

### 5.2 `mcpServers`

```typescript
mcpServers?: AgentMcpServerSpec[]
```

Per-agent MCP server configurations. Each element is either a string (server name reference) or a `Record<string, McpServerConfigForProcessTransport>` (inline server definitions).

```typescript
type AgentMcpServerSpec = string | Record<string, McpServerConfigForProcessTransport>
```

### 5.3 `criticalSystemReminder_EXPERIMENTAL`

```typescript
criticalSystemReminder_EXPERIMENTAL?: string
```

Experimental field. Adds a critical reminder to the agent's system prompt. The `_EXPERIMENTAL` suffix indicates this API may change or be removed.

### 5.4 `skills`

```typescript
skills?: string[]
```

Array of skill names to preload into the agent context. Skills are the SDK's term for slash commands / invocable capabilities.

### 5.5 `maxTurns`

```typescript
maxTurns?: number
```

Maximum number of agentic turns (API round-trips) before stopping. Provides per-agent turn limits independent of the global `maxTurns` option.

---

## 6. Hook System — New Events and Updated Inputs

### 6.1 New Hook Events

The spec documents 12 hook events. The SDK defines 15 — three are new.

#### `Setup`

Fires during session setup or maintenance initialization.

```typescript
type SetupHookInput = BaseHookInput & {
  hook_event_name: 'Setup';
  trigger: 'init' | 'maintenance';
};

type SetupHookSpecificOutput = {
  hookEventName: 'Setup';
  additionalContext?: string;
};
```

#### `TeammateIdle`

Fires when a teammate in a multi-agent setup becomes idle.

```typescript
type TeammateIdleHookInput = BaseHookInput & {
  hook_event_name: 'TeammateIdle';
  teammate_name: string;
  team_name: string;
};
```

No hook-specific output type (uses base `SyncHookJSONOutput`).

#### `TaskCompleted`

Fires when a task (subagent) completes.

```typescript
type TaskCompletedHookInput = BaseHookInput & {
  hook_event_name: 'TaskCompleted';
  task_id: string;
  task_subject: string;
  task_description?: string;
  teammate_name?: string;
  team_name?: string;
};
```

No hook-specific output type.

### 6.2 Updated Hook Inputs

Several existing hook input types have gained new fields:

#### `PreToolUseHookInput`

| Field | Status |
|-------|--------|
| `hook_event_name` | Unchanged |
| `tool_name` | Unchanged |
| `tool_input` | Unchanged |
| **`tool_use_id`** | **New** — Unique identifier for this specific tool call |

#### `PostToolUseHookInput`

| Field | Status |
|-------|--------|
| `hook_event_name` | Unchanged |
| `tool_name` | Unchanged |
| `tool_input` | Unchanged |
| `tool_response` | Unchanged |
| **`tool_use_id`** | **New** — Matching tool use identifier |

#### `SessionStartHookInput`

| Field | Status |
|-------|--------|
| `hook_event_name` | Unchanged |
| `source` | Unchanged |
| **`agent_type?`** | **New** — Type of agent that started the session |
| **`model?`** | **New** — Model being used |

#### `SubagentStopHookInput`

| Field | Status |
|-------|--------|
| `hook_event_name` | Unchanged |
| `stop_hook_active` | Unchanged |
| `agent_transcript_path` | Unchanged |
| **`agent_id`** | **New** — Identifier of the stopped subagent |
| **`agent_type`** | **New** — Type of the stopped subagent |

### 6.3 Updated Hook-Specific Outputs

#### `PreToolUseHookSpecificOutput`

| Field | Status |
|-------|--------|
| `hookEventName` | Unchanged |
| `permissionDecision` | Unchanged |
| `permissionDecisionReason` | Unchanged |
| `updatedInput` | Unchanged |
| **`additionalContext?`** | **New** — Additional context to inject |

#### `PostToolUseHookSpecificOutput`

| Field | Status |
|-------|--------|
| `hookEventName` | Unchanged |
| `additionalContext` | Unchanged |
| **`updatedMCPToolOutput?`** | **New** — Allows modifying MCP tool output after execution |

### 6.4 New Hook-Specific Output Types

These were not in the spec's `hookSpecificOutput` union:

- `SetupHookSpecificOutput` — `{ hookEventName: 'Setup', additionalContext?: string }`
- `SessionStartHookSpecificOutput` — `{ hookEventName: 'SessionStart', additionalContext?: string }`
- `SubagentStartHookSpecificOutput` — `{ hookEventName: 'SubagentStart', additionalContext?: string }`
- `PostToolUseFailureHookSpecificOutput` — `{ hookEventName: 'PostToolUseFailure', additionalContext?: string }`
- `NotificationHookSpecificOutput` — `{ hookEventName: 'Notification', additionalContext?: string }`
- `PermissionRequestHookSpecificOutput` — See below

#### `PermissionRequestHookSpecificOutput` (restructured)

The spec showed a simple `decision` field. The SDK uses a discriminated union:

```typescript
type PermissionRequestHookSpecificOutput = {
  hookEventName: 'PermissionRequest';
  decision: {
    behavior: 'allow';
    updatedInput?: Record<string, unknown>;
    updatedPermissions?: PermissionUpdate[];
  } | {
    behavior: 'deny';
    message?: string;
    interrupt?: boolean;
  };
};
```

### 6.5 HookJSONOutput — Now a Union

The spec documented a single flat type. The SDK splits it into two variants:

```typescript
type HookJSONOutput = AsyncHookJSONOutput | SyncHookJSONOutput;
```

#### `AsyncHookJSONOutput` (new)

```typescript
type AsyncHookJSONOutput = {
  async: true;
  asyncTimeout?: number;
};
```

Enables hooks to declare themselves as asynchronous, running in the background with an optional timeout. This is a new execution model not in the spec.

#### `SyncHookJSONOutput` (renamed from `HookJSONOutput`)

Contains all the original fields from the spec:

```typescript
type SyncHookJSONOutput = {
  continue?: boolean;
  suppressOutput?: boolean;
  stopReason?: string;
  decision?: 'approve' | 'block';
  systemMessage?: string;
  reason?: string;
  hookSpecificOutput?: PreToolUseHookSpecificOutput
    | UserPromptSubmitHookSpecificOutput
    | SessionStartHookSpecificOutput
    | SetupHookSpecificOutput
    | SubagentStartHookSpecificOutput
    | PostToolUseHookSpecificOutput
    | PostToolUseFailureHookSpecificOutput
    | NotificationHookSpecificOutput
    | PermissionRequestHookSpecificOutput;
};
```

The `hookSpecificOutput` union itself has expanded to include the new output types.

### 6.6 Complete Hook Event List (SDK v0.2.34)

For reference, the full `HOOK_EVENTS` constant:

```typescript
const HOOK_EVENTS = [
  "PreToolUse",
  "PostToolUse",
  "PostToolUseFailure",
  "Notification",
  "UserPromptSubmit",
  "SessionStart",
  "SessionEnd",
  "Stop",
  "SubagentStart",
  "SubagentStop",
  "PreCompact",
  "PermissionRequest",
  "Setup",            // NEW
  "TeammateIdle",     // NEW
  "TaskCompleted"     // NEW
] as const;
```

---

## 7. SDKMessage Union — New Message Types

The spec documents 7 message types in the `SDKMessage` union. The SDK defines **16**. Nine are entirely new.

### 7.1 `SDKStatusMessage`

System status updates (e.g., compaction in progress).

```typescript
type SDKStatusMessage = {
  type: 'system';
  subtype: 'status';
  status: SDKStatus;            // 'compacting' | null
  permissionMode?: PermissionMode;
  uuid: UUID;
  session_id: string;
};
```

### 7.2 `SDKHookStartedMessage`

Emitted when a hook begins execution.

```typescript
type SDKHookStartedMessage = {
  type: 'system';
  subtype: 'hook_started';
  hook_id: string;
  hook_name: string;
  hook_event: string;
  uuid: UUID;
  session_id: string;
};
```

### 7.3 `SDKHookProgressMessage`

Emitted during hook execution with stdout/stderr output.

```typescript
type SDKHookProgressMessage = {
  type: 'system';
  subtype: 'hook_progress';
  hook_id: string;
  hook_name: string;
  hook_event: string;
  stdout: string;
  stderr: string;
  output: string;
  uuid: UUID;
  session_id: string;
};
```

### 7.4 `SDKHookResponseMessage`

Emitted when a hook completes or fails.

```typescript
type SDKHookResponseMessage = {
  type: 'system';
  subtype: 'hook_response';
  hook_id: string;
  hook_name: string;
  hook_event: string;
  output: string;
  stdout: string;
  stderr: string;
  exit_code?: number;
  outcome: 'success' | 'error' | 'cancelled';
  uuid: UUID;
  session_id: string;
};
```

### 7.5 `SDKToolProgressMessage`

Emitted periodically during long-running tool executions.

```typescript
type SDKToolProgressMessage = {
  type: 'tool_progress';
  tool_use_id: string;
  tool_name: string;
  parent_tool_use_id: string | null;
  elapsed_time_seconds: number;
  uuid: UUID;
  session_id: string;
};
```

Note: This uses `type: 'tool_progress'` — a new top-level type discriminator, not a system subtype.

### 7.6 `SDKAuthStatusMessage`

Emitted during authentication flows.

```typescript
type SDKAuthStatusMessage = {
  type: 'auth_status';
  isAuthenticating: boolean;
  output: string[];
  error?: string;
  uuid: UUID;
  session_id: string;
};
```

Note: Uses `type: 'auth_status'` — another new top-level type discriminator.

### 7.7 `SDKTaskNotificationMessage`

Emitted when a background task (subagent) completes, fails, or is stopped.

```typescript
type SDKTaskNotificationMessage = {
  type: 'system';
  subtype: 'task_notification';
  task_id: string;
  status: 'completed' | 'failed' | 'stopped';
  output_file: string;
  summary: string;
  uuid: UUID;
  session_id: string;
};
```

### 7.8 `SDKFilesPersistedEvent`

Emitted when files are persisted (e.g., uploaded to cloud storage).

```typescript
type SDKFilesPersistedEvent = {
  type: 'system';
  subtype: 'files_persisted';
  files: { filename: string; file_id: string }[];
  failed: { filename: string; error: string }[];
  processed_at: string;
  uuid: UUID;
  session_id: string;
};
```

### 7.9 `SDKToolUseSummaryMessage`

Provides a human-readable summary of preceding tool uses.

```typescript
type SDKToolUseSummaryMessage = {
  type: 'tool_use_summary';
  summary: string;
  preceding_tool_use_ids: string[];
  uuid: UUID;
  session_id: string;
};
```

Note: Uses `type: 'tool_use_summary'` — yet another new top-level type discriminator.

### 7.10 Complete SDKMessage Union (SDK v0.2.34)

```typescript
type SDKMessage =
  | SDKAssistantMessage          // existing
  | SDKUserMessage               // existing
  | SDKUserMessageReplay         // existing
  | SDKResultMessage             // existing
  | SDKSystemMessage             // existing
  | SDKPartialAssistantMessage   // existing
  | SDKCompactBoundaryMessage    // existing
  | SDKStatusMessage             // NEW
  | SDKHookStartedMessage        // NEW
  | SDKHookProgressMessage       // NEW
  | SDKHookResponseMessage       // NEW
  | SDKToolProgressMessage       // NEW
  | SDKAuthStatusMessage         // NEW
  | SDKTaskNotificationMessage   // NEW
  | SDKFilesPersistedEvent       // NEW
  | SDKToolUseSummaryMessage;    // NEW
```

---

## 8. Updated Existing Message Types

### 8.1 `SDKSystemMessage` (init subtype)

New fields added to the initialization system message:

| Field | Type | Status |
|-------|------|--------|
| `type` | `'system'` | Unchanged |
| `subtype` | `'init'` | Unchanged |
| `apiKeySource` | `ApiKeySource` | Unchanged |
| `cwd` | `string` | Unchanged |
| `tools` | `string[]` | Unchanged |
| `mcp_servers` | `{ name, status }[]` | Unchanged |
| `model` | `string` | Unchanged |
| `permissionMode` | `PermissionMode` | Unchanged |
| `slash_commands` | `string[]` | Unchanged |
| **`agents?`** | **`string[]`** | **New** — List of defined agent names |
| **`betas?`** | **`string[]`** | **New** — Active beta features |
| **`claude_code_version`** | **`string`** | **New** — CLI version string |
| **`output_style`** | **`string`** | **New** — Current output style |
| **`skills`** | **`string[]`** | **New** — Available skill names |
| **`plugins`** | **`{ name: string; path: string }[]`** | **New** — Loaded plugins |
| `uuid` | `UUID` | Unchanged |
| `session_id` | `string` | Unchanged |

Note: The spec listed `output_style` but as part of the system message section, without marking it as a field on `SDKSystemMessage`. The SDK confirms it is a direct field.

### 8.2 `SDKResultMessage` (both subtypes)

Both `SDKResultSuccess` and `SDKResultError` gain a new field:

| Field | Type | Status |
|-------|------|--------|
| **`stop_reason`** | **`string \| null`** | **New** — Why the result stopped (e.g., model stop reason) |

All other fields remain unchanged.

### 8.3 `SDKAssistantMessage`

| Field | Type | Status |
|-------|------|--------|
| `type` | `'assistant'` | Unchanged |
| `message` | `BetaMessage` | Unchanged |
| `parent_tool_use_id` | `string \| null` | Unchanged |
| `uuid` | `UUID` | Unchanged |
| `session_id` | `string` | Unchanged |
| **`error?`** | **`SDKAssistantMessageError`** | **New** — Error type if the message failed |

**`SDKAssistantMessageError`** (new type):

```typescript
type SDKAssistantMessageError =
  | 'authentication_failed'
  | 'billing_error'
  | 'rate_limit'
  | 'invalid_request'
  | 'server_error'
  | 'unknown';
```

### 8.4 `SDKUserMessage`

| Field | Type | Status |
|-------|------|--------|
| `type` | `'user'` | Unchanged |
| `message` | `MessageParam` | Unchanged |
| `parent_tool_use_id` | `string \| null` | Unchanged |
| `uuid` | `UUID` (optional) | Unchanged |
| `session_id` | `string` | Unchanged |
| **`isSynthetic?`** | **`boolean`** | **New** — Whether the message was generated by the system |
| **`tool_use_result?`** | **`unknown`** | **New** — Tool result data attached to the message |

### 8.5 `SDKUserMessageReplay`

Gains the same new fields as `SDKUserMessage`, plus the existing `isReplay: true`.

---

## 9. CanUseTool Callback — Expanded Signature

The permission callback's `options` parameter has been significantly expanded.

**Spec:**
```typescript
(toolName: string, input: Record<string, unknown>, options: {
  signal: AbortSignal;
  suggestions?: PermissionUpdate[];
}) => Promise<PermissionResult>
```

**SDK v0.2.34:**
```typescript
(toolName: string, input: Record<string, unknown>, options: {
  signal: AbortSignal;
  suggestions?: PermissionUpdate[];
  blockedPath?: string;       // NEW
  decisionReason?: string;    // NEW
  toolUseID: string;          // NEW (required)
  agentID?: string;           // NEW
}) => Promise<PermissionResult>
```

| Field | Type | Required | Status | Description |
|-------|------|----------|--------|-------------|
| `signal` | `AbortSignal` | Yes | Unchanged | Abort signal |
| `suggestions?` | `PermissionUpdate[]` | No | Unchanged | Suggested permission updates |
| **`blockedPath?`** | `string` | No | **New** | File path that triggered the permission request (e.g., access outside allowed directories) |
| **`decisionReason?`** | `string` | No | **New** | Explanation of why this permission request was triggered |
| **`toolUseID`** | `string` | **Yes** | **New** | Unique identifier for this specific tool call within the assistant message |
| **`agentID?`** | `string` | No | **New** | Sub-agent's ID if running within a sub-agent context |

Additionally, `PermissionResult` gains an optional `toolUseID` field on both the `'allow'` and `'deny'` variants:

```typescript
type PermissionResult = {
  behavior: 'allow';
  updatedInput?: Record<string, unknown>;
  updatedPermissions?: PermissionUpdate[];
  toolUseID?: string;          // NEW
} | {
  behavior: 'deny';
  message: string;
  interrupt?: boolean;
  toolUseID?: string;          // NEW
};
```

---

## 10. MCP — New Config Type and Status Changes

### 10.1 New: `McpClaudeAIProxyServerConfig`

An entirely new MCP server transport type for Claude.ai proxy connections:

```typescript
type McpClaudeAIProxyServerConfig = {
  type: 'claudeai-proxy';
  url: string;
  id: string;
};
```

This type appears in `McpServerStatusConfig` (what's returned in status queries) but **not** in the main `McpServerConfig` union (what you pass to configure servers). This suggests it's a server-side config type that users observe but don't create.

### 10.2 `McpServerStatus` — New Fields and Values

**New status value:** `'disabled'`

Updated type:

| Field | Type | Status |
|-------|------|--------|
| `name` | `string` | Unchanged |
| `status` | `'connected' \| 'failed' \| 'needs-auth' \| 'pending' \| 'disabled'` | **`'disabled'` added** |
| `serverInfo?` | `{ name, version }` | Unchanged |
| **`error?`** | `string` | **New** — Error message when status is `'failed'` |
| **`config?`** | `McpServerStatusConfig` | **New** — Server configuration (includes URL for HTTP/SSE) |
| **`scope?`** | `string` | **New** — Config scope (project, user, local, claudeai, managed) |
| **`tools?`** | `{ name, description?, annotations? }[]` | **New** — Tools provided by this server when connected |

The `tools` array includes MCP tool annotations:

```typescript
tools?: {
  name: string;
  description?: string;
  annotations?: {
    readOnly?: boolean;
    destructive?: boolean;
    openWorld?: boolean;
  };
}[]
```

### 10.3 `McpServerStatusConfig`

New union type for status reporting:

```typescript
type McpServerStatusConfig =
  | McpServerConfigForProcessTransport
  | McpClaudeAIProxyServerConfig;
```

### 10.4 `McpServerConfigForProcessTransport`

New type that includes all serializable (non-instance) server configs:

```typescript
type McpServerConfigForProcessTransport =
  | McpStdioServerConfig
  | McpSSEServerConfig
  | McpHttpServerConfig
  | McpSdkServerConfig;  // note: without instance
```

This is used in `AgentMcpServerSpec` and `SDKControlMcpSetServersRequest` where live `McpServer` instances can't be serialized.

---

## 11. tool() Function — New Parameter

The `tool()` helper function gains an optional 5th parameter for MCP tool annotations:

**Spec:**
```typescript
function tool<Schema>(name, description, inputSchema, handler): SdkMcpToolDefinition<Schema>
```

**SDK v0.2.34:**
```typescript
function tool<Schema>(
  _name: string,
  _description: string,
  _inputSchema: Schema,
  _handler: (args: InferShape<Schema>, extra: unknown) => Promise<CallToolResult>,
  _extras?: { annotations?: ToolAnnotations }
): SdkMcpToolDefinition<Schema>
```

Additionally, `SdkMcpToolDefinition` itself now includes `annotations`:

```typescript
type SdkMcpToolDefinition<Schema> = {
  name: string;
  description: string;
  inputSchema: Schema;
  annotations?: ToolAnnotations;  // NEW
  handler: (args: InferShape<Schema>, extra: unknown) => Promise<CallToolResult>;
};
```

`ToolAnnotations` comes from `@modelcontextprotocol/sdk/types.js` and describes tool behavior characteristics (`readOnly`, `destructive`, `openWorld`, etc.).

The SDK also now supports both Zod 3 and Zod 4 schemas:

```typescript
type AnyZodRawShape = ZodRawShape | ZodRawShape_2;  // Zod 3 | Zod 4
```

---

## 12. Sandbox Settings — Schema Changes

### 12.1 `ignoreViolations` — Type Change

**Spec:**
```typescript
ignoreViolations?: {
  file: string[];
  network: string[];
}
```

**SDK v0.2.34:**
```typescript
ignoreViolations: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodArray<z.ZodString>>>
// Resolves to: Record<string, string[]> | undefined
```

Changed from a fixed two-field object to an open `Record<string, string[]>`, allowing arbitrary violation categories beyond just `file` and `network`.

### 12.2 Network Config — New Fields

**New fields in `SandboxNetworkConfigSchema`:**

| Field | Type | Status |
|-------|------|--------|
| `allowLocalBinding` | `boolean` | Unchanged |
| `allowUnixSockets` | `string[]` | Unchanged |
| `allowAllUnixSockets` | `boolean` | Unchanged |
| `httpProxyPort` | `number` | Unchanged |
| `socksProxyPort` | `number` | Unchanged |
| **`allowedDomains`** | `string[]` | **New** — Explicit domain allowlist |
| **`allowManagedDomainsOnly`** | `boolean` | **New** — Restrict to managed domains only |

### 12.3 New: `ripgrep` Config

The sandbox settings schema now includes a ripgrep configuration:

```typescript
ripgrep: z.ZodOptional<z.ZodObject<{
  command: z.ZodString;
  args: z.ZodOptional<z.ZodArray<z.ZodString>>;
}>>
```

Allows overriding the ripgrep binary path and arguments, relevant for sandboxed environments where the default ripgrep location may differ.

### 12.4 Schema Style Change

The `SandboxSettingsSchema` uses `z.core.$loose` instead of `z.core.$strip`, meaning unknown keys are preserved rather than stripped. This is a breaking change for strict parsers.

---

## 13. Tool Input Schemas — Renames and New Tools

### 13.1 Renamed Tools

#### `BashOutput` → `TaskOutputInput`

**Spec (old):**
```typescript
{ bash_id: string; filter?: string }
```

**SDK (new):**
```typescript
{
  task_id: string;     // was bash_id
  block: boolean;      // NEW — whether to wait for completion
  timeout: number;     // NEW — max wait time in ms
}
```

The `filter` field has been removed. The tool now supports blocking/non-blocking reads with timeouts instead of regex filtering.

#### `KillBash` → `TaskStopInput`

**Spec (old):**
```typescript
{ shell_id: string }
```

**SDK (new):**
```typescript
{
  task_id?: string;    // was shell_id (now optional)
  shell_id?: string;   // deprecated alias
}
```

### 13.2 New Tool: `ConfigInput`

A runtime settings management tool:

```typescript
interface ConfigInput {
  setting: string;                    // Setting key (e.g., "theme", "model")
  value?: string | boolean | number;  // New value; omit to get current value
}
```

### 13.3 `AgentInput` (Task Tool) — New Fields

| Field | Type | Status |
|-------|------|--------|
| `description` | `string` | Unchanged |
| `prompt` | `string` | Unchanged |
| `subagent_type` | `string` | Unchanged |
| `model?` | `'sonnet' \| 'opus' \| 'haiku'` | Unchanged |
| `resume?` | `string` | Unchanged |
| `run_in_background?` | `boolean` | Unchanged |
| `max_turns?` | `number` | Unchanged |
| **`name?`** | `string` | **New** — Name for the spawned agent |
| **`team_name?`** | `string` | **New** — Team name for spawning (uses current team context if omitted) |
| **`mode?`** | `PermissionMode` | **New** — Permission mode for spawned teammate |

### 13.4 `ExitPlanModeInput` — Complete Overhaul

**Spec:**
```typescript
{ plan: string }
```

**SDK v0.2.34:**
```typescript
interface ExitPlanModeInput {
  allowedPrompts?: {
    tool: "Bash";
    prompt: string;    // Semantic action description (e.g., "run tests")
  }[];
  pushToRemote?: boolean;
  remoteSessionId?: string;
  remoteSessionUrl?: string;
  remoteSessionTitle?: string;
  [k: string]: unknown;          // Open for additional properties
}
```

The `plan: string` field is **gone entirely**. The tool now focuses on:
1. **Permission pre-authorization** — declaring what Bash actions the plan needs
2. **Remote execution** — pushing plans to Claude.ai remote sessions

---

## 14. Minor Type Changes

### 14.1 `ModelUsage`

| Field | Type | Status |
|-------|------|--------|
| `inputTokens` | `number` | Unchanged |
| `outputTokens` | `number` | Unchanged |
| `cacheReadInputTokens` | `number` | Unchanged |
| `cacheCreationInputTokens` | `number` | Unchanged |
| `webSearchRequests` | `number` | Unchanged |
| `costUSD` | `number` | Unchanged |
| `contextWindow` | `number` | Unchanged |
| **`maxOutputTokens`** | `number` | **New** |

### 14.2 `PermissionUpdateDestination`

**Spec:** `'userSettings' | 'projectSettings' | 'localSettings' | 'session'`

**SDK:** `'userSettings' | 'projectSettings' | 'localSettings' | 'session' | 'cliArg'`

New value **`'cliArg'`** — allows permission updates to target CLI argument scope.

### 14.3 `ExitReason` (new type, not in spec)

```typescript
type ExitReason =
  | 'clear'
  | 'logout'
  | 'prompt_input_exit'
  | 'other'
  | 'bypass_permissions_disabled';

const EXIT_REASONS = [
  "clear", "logout", "prompt_input_exit", "other", "bypass_permissions_disabled"
] as const;
```

Used by `SessionEndHookInput.reason`.

### 14.4 `ConfigScope`

**Spec:** `SettingSource = 'user' | 'project' | 'local'`

**SDK also exports:** `ConfigScope = 'local' | 'user' | 'project'` — same values, different type name. Both are present.

### 14.5 `SdkBeta`

Unchanged: still only `'context-1m-2025-08-07'`.

---

## 15. New Supporting Types

### 15.1 `SpawnedProcess` Interface

Abstracts the spawned process, allowing custom process implementations (VMs, containers, remote).

```typescript
interface SpawnedProcess {
  stdin: Writable;
  stdout: Readable;
  readonly killed: boolean;
  readonly exitCode: number | null;
  kill(signal: NodeJS.Signals): boolean;
  on(event: 'exit', listener: (code: number | null, signal: NodeJS.Signals | null) => void): void;
  on(event: 'error', listener: (error: Error) => void): void;
  once(event: 'exit', listener: ...): void;
  once(event: 'error', listener: ...): void;
  off(event: 'exit', listener: ...): void;
  off(event: 'error', listener: ...): void;
}
```

`ChildProcess` already satisfies this interface, so the default behavior works without changes.

### 15.2 `SpawnOptions` Interface

Options passed to `spawnClaudeCodeProcess`:

```typescript
interface SpawnOptions {
  command: string;
  args: string[];
  cwd?: string;
  env: Record<string, string | undefined>;
  signal: AbortSignal;
}
```

### 15.3 `Transport` Interface

Abstracts the communication layer for process and WebSocket transports:

```typescript
interface Transport {
  write(data: string): void | Promise<void>;
  close(): void;
  isReady(): boolean;
  readMessages(): AsyncGenerator<StdoutMessage, void, unknown>;
  endInput(): void;
}
```

### 15.4 `SDKControlInitializeResponse`

Returned by `Query.initializationResult()`:

```typescript
type SDKControlInitializeResponse = {
  commands: SlashCommand[];
  output_style: string;
  available_output_styles: string[];
  models: ModelInfo[];
  account: AccountInfo;
};
```

### 15.5 Control Protocol Types (internal)

The SDK exposes these as `declare` types (visible in `.d.ts` but not in the public API surface). Documented here for completeness:

- `SDKControlRequest` — Wrapper: `{ type: 'control_request', request_id, request }`
- `SDKControlResponse` — Wrapper: `{ type: 'control_response', response }`
- `SDKControlCancelRequest` — `{ type: 'control_cancel_request', request_id }`
- `SDKKeepAliveMessage` — `{ type: 'keep_alive' }`
- Various `SDKControl*Request` subtypes for each control operation

### 15.6 `StdoutMessage` (internal)

The complete union of all possible messages on stdout, including internal types:

```typescript
type StdoutMessage =
  | SDKMessage
  | SDKStreamlinedTextMessage      // not exported
  | SDKStreamlinedToolUseSummaryMessage  // not exported
  | SDKControlResponse
  | SDKControlRequest
  | SDKControlCancelRequest
  | SDKKeepAliveMessage;
```

---

## 16. ClodKit Impact Assessment

### 16.1 High Priority — Affects Working Features

These gaps affect types and behaviors that ClodKit already models or should model for correctness.

| Gap | Impact | Effort |
|-----|--------|--------|
| `PermissionMode` — add `'delegate'`, `'dontAsk'` | Enum update, affects all permission-related types | Low |
| `ExitPlanModeInput` — completely changed | Breaking: old `plan: string` no longer valid | Medium |
| 9 new `SDKMessage` types | Must model for exhaustive message handling | Medium-High |
| `SDKAssistantMessage.error` field | Must handle assistant-level errors | Low |
| `SDKResultMessage.stop_reason` field | Affects result processing | Low |
| `SDKSystemMessage` init — 6 new fields | Affects session initialization | Low |
| Hook system — 3 new events, updated inputs | Must update hook routing and type definitions | Medium |
| `HookJSONOutput` split into sync/async | Affects hook response handling | Medium |
| `CanUseTool` expanded options (4 new fields, 1 now required) | Affects permission callback interface | Medium |
| `PreToolUseHookInput`/`PostToolUseHookInput` — new `tool_use_id` | Must pass through in hook handling | Low |

### 16.2 Medium Priority — New Capabilities

These are new features that ClodKit should add for API parity.

| Gap | Impact | Effort |
|-----|--------|--------|
| V2 Session API (3 functions, 2 types) | Entirely new API surface; marked unstable | High |
| 6 new `Query` methods | New control protocol messages | High |
| `rewindFiles()` signature change + `RewindFilesResult` | Affects existing rewind implementation | Medium |
| 6 new `Options` fields | Configuration expansion | Medium |
| `AgentDefinition` — 5 new fields | Subagent configuration | Low-Medium |
| `tool()` — `annotations` parameter | MCP tool metadata | Low |
| `McpSetServersResult`, dynamic MCP management | New MCP lifecycle control | Medium |
| Custom spawn (`SpawnedProcess`, `SpawnOptions`) | Remote/container execution | Medium |

### 16.3 Low Priority — Incremental Changes

| Gap | Impact | Effort |
|-----|--------|--------|
| Tool renames: `BashOutput` → `TaskOutput`, `KillBash` → `TaskStop` | Naming consistency | Low |
| New `ConfigInput` tool | Settings management | Low |
| `AgentInput` — `name`, `team_name`, `mode` fields | Task tool expansion | Low |
| Sandbox config changes (`ignoreViolations` type, `ripgrep`, network fields) | Edge case configs | Low |
| `McpClaudeAIProxyServerConfig` | Observability type | Low |
| `ModelUsage.maxOutputTokens` | Token tracking | Trivial |
| `PermissionUpdateDestination` — `'cliArg'` value | Permission scope | Trivial |
| `ExitReason` type | Hook input typing | Trivial |
| `McpServerStatus` — `'disabled'` value, new fields | Status reporting | Low |

---

## Appendix A: Version Correlation

| Component | Version |
|-----------|---------|
| npm package | `@anthropic-ai/claude-agent-sdk@0.2.34` |
| Claude Code CLI | `2.1.34` |
| Existing spec date | 2026-01-28 |
| Zod peer dependency | `^4.0.0` |
| Node.js requirement | `>=18.0.0` |

## Appendix B: Files Analyzed

| File | Lines | Description |
|------|-------|-------------|
| `sdk.d.ts` | 1835 | Primary type declarations — all public types, interfaces, functions |
| `sdk-tools.d.ts` | 1570 | Tool input JSON schemas — auto-generated from JSON Schema |
| `package.json` | 41 | Package metadata, version, dependencies |
