# Claude Agent SDK API Specification

This document comprehensively captures the current API for the official Claude Agent SDK (TypeScript and Python). It is organized analytically into discrete, checkable sections to enable verification of API parity in unofficial SDK implementations.

**Source**: [Anthropic Claude Agent SDK Documentation](https://platform.claude.com/docs/en/agent-sdk/overview)

**Last Updated**: 2026-03-01 (SDK v0.2.63 / Claude Code v2.1.63)

---

## Table of Contents

1. [Installation & Package Names](#1-installation--package-names)
2. [Core Functions](#2-core-functions)
3. [Client Classes](#3-client-classes)
4. [Configuration Options](#4-configuration-options)
5. [Message Types](#5-message-types)
6. [Content Block Types](#6-content-block-types)
7. [Tool Definitions](#7-tool-definitions)
8. [Tool Input Schemas](#8-tool-input-schemas)
9. [Tool Output Schemas](#9-tool-output-schemas)
10. [Hook System](#10-hook-system)
11. [Permission System](#11-permission-system)
12. [MCP (Model Context Protocol)](#12-mcp-model-context-protocol)
13. [Subagent System](#13-subagent-system)
14. [Session Management](#14-session-management)
15. [Sandbox Configuration](#15-sandbox-configuration)
16. [Error Types](#16-error-types)
17. [Beta Features](#17-beta-features)
18. [Additional Types](#18-additional-types)

---

## 1. Installation & Package Names

### 1.1 TypeScript

| Item | Value |
|------|-------|
| Package name | `@anthropic-ai/claude-agent-sdk` |
| Installation | `npm install @anthropic-ai/claude-agent-sdk` |
| Runtime requirement | Claude Code CLI installed |

### 1.2 Python

| Item | Value |
|------|-------|
| Package name | `claude-agent-sdk` |
| Installation | `pip install claude-agent-sdk` |
| Runtime requirement | Claude Code CLI installed |
| Python version | 3.10+ |

---

## 2. Core Functions

### 2.1 `query()`

The primary function for interacting with Claude Code.

#### TypeScript Signature

```typescript
function query({
  prompt,
  options
}: {
  prompt: string | AsyncIterable<SDKUserMessage>;
  options?: Options;
}): Query
```

#### Python Signature

```python
async def query(
    *,
    prompt: str | AsyncIterable[dict[str, Any]],
    options: ClaudeAgentOptions | None = None
) -> AsyncIterator[Message]
```

#### Parameters

| Parameter | Type (TS) | Type (Python) | Required | Description |
|-----------|-----------|---------------|----------|-------------|
| `prompt` | `string \| AsyncIterable<SDKUserMessage>` | `str \| AsyncIterable[dict]` | Yes | Input prompt or async iterable for streaming |
| `options` | `Options` | `ClaudeAgentOptions \| None` | No | Configuration object |

#### Returns

- **TypeScript**: `Query` (extends `AsyncGenerator<SDKMessage, void>`)
- **Python**: `AsyncIterator[Message]`


### 2.2 `tool()`

Creates type-safe MCP tool definitions.

#### TypeScript Signature

```typescript
function tool<Schema extends ZodRawShape>(
  name: string,
  description: string,
  inputSchema: Schema,
  handler: (args: z.infer<ZodObject<Schema>>, extra: unknown) => Promise<CallToolResult>
): SdkMcpToolDefinition<Schema>
```

#### Python Signature (Decorator)

```python
def tool(
    name: str,
    description: str,
    input_schema: type | dict[str, Any]
) -> Callable[[Callable[[Any], Awaitable[dict[str, Any]]]], SdkMcpTool[Any]]
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | `string` | Yes | Unique tool identifier |
| `description` | `string` | Yes | Human-readable description |
| `inputSchema` | Zod schema (TS) / type or dict (Python) | Yes | Input parameter schema |
| `handler` | Function | Yes | Async function implementing the tool |


### 2.3 `createSdkMcpServer()` / `create_sdk_mcp_server()`

Creates an in-process MCP server.

#### TypeScript Signature

```typescript
function createSdkMcpServer(options: {
  name: string;
  version?: string;
  tools?: Array<SdkMcpToolDefinition<any>>;
}): McpSdkServerConfigWithInstance
```

#### Python Signature

```python
def create_sdk_mcp_server(
    name: str,
    version: str = "1.0.0",
    tools: list[SdkMcpTool[Any]] | None = None
) -> McpSdkServerConfig
```

---

## 3. Client Classes

### 3.1 `Query` Interface (TypeScript only)

Returned by the `query()` function, extends `AsyncGenerator<SDKMessage, void>`.

#### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `interrupt()` | `Promise<void>` | Interrupts the query (streaming input mode only) |
| `rewindFiles(userMessageId, options?)` | `Promise<RewindFilesResult>` | Restores files to state at specified message UUID. Requires `enableFileCheckpointing: true` |
| `setPermissionMode(mode)` | `Promise<void>` | Changes permission mode dynamically |
| `setModel(model?)` | `Promise<void>` | Changes model dynamically |
| `setMaxThinkingTokens(n)` | `Promise<void>` | Changes max thinking tokens |
| `initializationResult()` | `Promise<SDKControlInitializeResponse>` | Returns the initialization result with commands, models, agents, and account info |
| `supportedCommands()` | `Promise<SlashCommand[]>` | Returns available slash commands |
| `supportedModels()` | `Promise<ModelInfo[]>` | Returns available models |
| `supportedAgents()` | `Promise<AgentInfo[]>` | Returns available agent types |
| `mcpServerStatus()` | `Promise<McpServerStatus[]>` | Returns MCP server connection status |
| `accountInfo()` | `Promise<AccountInfo>` | Returns account information |
| `reconnectMcpServer(serverName)` | `Promise<void>` | Reconnects a named MCP server |
| `toggleMcpServer(serverName, enabled)` | `Promise<void>` | Enables or disables a named MCP server |
| `setMcpServers(servers)` | `Promise<McpSetServersResult>` | Replaces the active set of MCP servers |
| `streamInput(stream)` | `Promise<void>` | Pipes an async iterable of `SDKUserMessage` into the query |
| `stopTask(taskId)` | `Promise<void>` | Stops a background task by ID |
| `close()` | `void` | Closes the query stream |


### 3.2 `ClaudeSDKClient` (Python only)

Maintains conversation session across multiple exchanges.

#### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `__init__()` | `(options: ClaudeAgentOptions \| None = None)` | Initialize client |
| `connect()` | `async (prompt: str \| AsyncIterable[dict] \| None = None) -> None` | Connect to Claude |
| `query()` | `async (prompt: str \| AsyncIterable[dict], session_id: str = "default") -> None` | Send request |
| `receive_messages()` | `async () -> AsyncIterator[Message]` | Receive all messages |
| `receive_response()` | `async () -> AsyncIterator[Message]` | Receive until ResultMessage |
| `interrupt()` | `async () -> None` | Send interrupt signal |
| `rewind_files()` | `async (user_message_uuid: str) -> None` | Restore files to specified state. Requires `enable_file_checkpointing=True` |
| `disconnect()` | `async () -> None` | Disconnect from Claude |

#### Context Manager Support

```python
async with ClaudeSDKClient() as client:
    await client.query("Hello")
    async for message in client.receive_response():
        print(message)
```

---

## 4. Configuration Options

### 4.1 Options / ClaudeAgentOptions

Complete configuration object for `query()`.

| Property | TS Name | Python Name | Type | Default | Description |
|----------|---------|-------------|------|---------|-------------|
| Abort controller | `abortController` | N/A | `AbortController` | `new AbortController()` | Cancellation controller |
| Additional directories | `additionalDirectories` | `add_dirs` | `string[]` / `list[str \| Path]` | `[]` | Extra directories Claude can access |
| Agents | `agents` | `agents` | `Record<string, AgentDefinition>` | `undefined` | Subagent definitions |
| Allow dangerous skip | `allowDangerouslySkipPermissions` | N/A | `boolean` | `false` | Required for `bypassPermissions` mode |
| Allowed tools | `allowedTools` | `allowed_tools` | `string[]` | All tools | Permitted tool names |
| Betas | `betas` | `betas` | `SdkBeta[]` | `[]` | Beta features to enable |
| Can use tool | `canUseTool` | `can_use_tool` | `CanUseTool` | `undefined` | Permission callback |
| Continue | `continue` | `continue_conversation` | `boolean` | `false` | Continue most recent conversation |
| Current working directory | `cwd` | `cwd` | `string` / `str \| Path \| None` | `process.cwd()` | Working directory |
| Disallowed tools | `disallowedTools` | `disallowed_tools` | `string[]` | `[]` | Blocked tool names |
| Enable file checkpointing | `enableFileCheckpointing` | `enable_file_checkpointing` | `boolean` | `false` | Track file changes for rewind |
| Environment | `env` | `env` | `Dict<string>` / `dict[str, str]` | `process.env` | Environment variables |
| Executable | `executable` | N/A | `'bun' \| 'deno' \| 'node'` | Auto-detected | JS runtime |
| Executable args | `executableArgs` | N/A | `string[]` | `[]` | Runtime arguments |
| Extra args | `extraArgs` | `extra_args` | `Record<string, string \| null>` | `{}` | Additional CLI arguments |
| Fallback model | `fallbackModel` | `fallback_model` | `string` | `undefined` | Backup model |
| Fork session | `forkSession` | `fork_session` | `boolean` | `false` | Fork instead of continue when resuming |
| Hooks | `hooks` | `hooks` | `Partial<Record<HookEvent, HookCallbackMatcher[]>>` | `{}` | Hook callbacks |
| Include partial messages | `includePartialMessages` | `include_partial_messages` | `boolean` | `false` | Include streaming events |
| Max budget USD | `maxBudgetUsd` | `max_budget_usd` | `number` / `float` | `undefined` | Cost limit |
| Max thinking tokens | `maxThinkingTokens` | `max_thinking_tokens` | `number` / `int` | `undefined` | Thinking process limit |
| Max turns | `maxTurns` | `max_turns` | `number` / `int` | `undefined` | Conversation turn limit |
| MCP servers | `mcpServers` | `mcp_servers` | `Record<string, McpServerConfig>` | `{}` | MCP server configs |
| Model | `model` | `model` | `string` | CLI default | Claude model |
| Output format | `outputFormat` | `output_format` | `{ type: 'json_schema', schema: JSONSchema }` | `undefined` | Structured output schema |
| Path to executable | `pathToClaudeCodeExecutable` | `cli_path` | `string` | Built-in | Custom CLI path |
| Permission mode | `permissionMode` | `permission_mode` | `PermissionMode` | `'default'` | Permission behavior |
| Permission prompt tool | `permissionPromptToolName` | `permission_prompt_tool_name` | `string` | `undefined` | MCP tool for prompts |
| Plugins | `plugins` | `plugins` | `SdkPluginConfig[]` | `[]` | Plugin configurations |
| Resume | `resume` | `resume` | `string` | `undefined` | Session ID to resume |
| Resume at | `resumeSessionAt` | N/A | `string` | `undefined` | Resume at specific message UUID |
| Sandbox | `sandbox` | `sandbox` | `SandboxSettings` | `undefined` | Sandbox configuration |
| Setting sources | `settingSources` | `setting_sources` | `SettingSource[]` | `[]` | Filesystem settings to load |
| Stderr callback | `stderr` | `stderr` | `(data: string) => void` | `undefined` | Stderr handler |
| Settings path | N/A | `settings` | `string` | `undefined` | Path to settings file (Python only) |
| Strict MCP | `strictMcpConfig` | N/A | `boolean` | `false` | Enforce strict MCP validation |
| System prompt | `systemPrompt` | `system_prompt` | `string \| SystemPromptPreset` | `undefined` | System prompt config |
| Thinking | `thinking` | N/A | `ThinkingConfig` | `undefined` | Thinking/reasoning configuration |
| Effort | `effort` | N/A | `'low' \| 'medium' \| 'high' \| 'max'` | `undefined` | Effort level hint |
| Persist session | `persistSession` | N/A | `boolean` | `true` | When false, disables session persistence |
| Prompt suggestions | `promptSuggestions` | N/A | `boolean` | `false` | Enable prompt suggestions in stream |
| Session ID | `sessionId` | N/A | `string` | `undefined` | Custom session ID for new sessions |
| On elicitation | `onElicitation` | N/A | `OnElicitation` | `undefined` | Callback for MCP elicitation requests |
| Agent | `agent` | N/A | `string` | `undefined` | Main thread agent name |
| Debug | `debug` | N/A | `boolean` | `false` | Enable debug mode |
| Debug file | `debugFile` | N/A | `string` | `undefined` | Path to debug log file |
| Spawn process | `spawnClaudeCodeProcess` | N/A | `(options: SpawnOptions) => SpawnedProcess` | `undefined` | Custom process spawner (advanced) |
| Tools | `tools` | `tools` | `string[] \| ToolsPreset` | `undefined` | Tool configuration |
| User | N/A | `user` | `string` | `undefined` | User identifier |
| Max buffer size | N/A | `max_buffer_size` | `int` | `None` | Maximum bytes when buffering CLI stdout (Python only) |


### 4.2 PermissionMode

```typescript
type PermissionMode =
  | 'default'           // Standard permission behavior
  | 'acceptEdits'       // Auto-accept file edits
  | 'bypassPermissions' // Bypass all permission checks
  | 'plan'              // Planning mode - no execution
```


### 4.3 SettingSource

```typescript
type SettingSource = 'user' | 'project' | 'local';
```

| Value | Location |
|-------|----------|
| `'user'` | `~/.claude/settings.json` |
| `'project'` | `.claude/settings.json` |
| `'local'` | `.claude/settings.local.json` |


### 4.4 SystemPromptPreset

```typescript
type SystemPromptPreset = {
  type: 'preset';
  preset: 'claude_code';
  append?: string;  // Additional instructions
}
```


### 4.5 OutputFormat

```typescript
type OutputFormat = {
  type: 'json_schema';
  schema: dict[str, Any];  // JSON Schema definition
}
```

---

## 5. Message Types

### 5.1 SDKMessage / Message (Union Type)

```typescript
type SDKMessage =
  | SDKAssistantMessage
  | SDKUserMessage
  | SDKUserMessageReplay
  | SDKResultMessage
  | SDKSystemMessage
  | SDKPartialAssistantMessage
  | SDKCompactBoundaryMessage
  | SDKStatusMessage
  | SDKLocalCommandOutputMessage
  | SDKHookStartedMessage
  | SDKHookProgressMessage
  | SDKHookResponseMessage
  | SDKToolProgressMessage
  | SDKAuthStatusMessage
  | SDKTaskNotificationMessage
  | SDKTaskStartedMessage
  | SDKTaskProgressMessage
  | SDKFilesPersistedEvent
  | SDKToolUseSummaryMessage
  | SDKRateLimitEvent
  // New in v0.2.63:
  | SDKElicitationCompleteMessage
  | SDKPromptSuggestionMessage;
```

```python
Message = UserMessage | AssistantMessage | SystemMessage | ResultMessage | StreamEvent
```


### 5.2 SDKAssistantMessage / AssistantMessage

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'assistant'` | Message type discriminator |
| `uuid` | `UUID` | Unique identifier |
| `session_id` | `string` | Session identifier |
| `message` (TS) / `content` (Python) | `APIAssistantMessage` / `list[ContentBlock]` | Message content |
| `model` (Python only) | `str` | Model used |
| `parent_tool_use_id` | `string \| null` | Parent subagent tool use ID |


### 5.3 SDKUserMessage / UserMessage

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'user'` | Message type discriminator |
| `uuid` | `UUID` (optional in creation) | Unique identifier |
| `session_id` | `string` | Session identifier |
| `message` (TS) / `content` (Python) | `APIUserMessage` / `str \| list[ContentBlock]` | Message content |
| `parent_tool_use_id` | `string \| null` | Parent subagent tool use ID |


### 5.4 SDKResultMessage / ResultMessage

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'result'` | Message type discriminator |
| `subtype` | `'success' \| 'error_max_turns' \| 'error_during_execution' \| 'error_max_budget_usd' \| 'error_max_structured_output_retries'` | Result type |
| `uuid` | `UUID` | Unique identifier |
| `session_id` | `string` | Session identifier |
| `duration_ms` | `number` / `int` | Total duration |
| `duration_api_ms` | `number` / `int` | API call duration |
| `is_error` | `boolean` / `bool` | Error indicator |
| `num_turns` | `number` / `int` | Number of turns |
| `result` | `string` (success only) | Final result text |
| `total_cost_usd` | `number` / `float \| None` | Total cost |
| `usage` | `NonNullableUsage` / `dict[str, Any] \| None` | Token usage |
| `modelUsage` | `Record<string, ModelUsage>` | Per-model usage breakdown |
| `fast_mode_state` | `FastModeState` (optional) | Fast mode state at result time |
| `permission_denials` | `SDKPermissionDenial[]` | Denied tool uses |
| `structured_output` | `unknown` / `Any` | Structured output result |
| `errors` | `string[]` (error subtypes only) | Error messages |


### 5.5 SDKSystemMessage / SystemMessage

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'system'` | Message type discriminator |
| `subtype` | `'init' \| 'compact_boundary'` | System message type |
| `uuid` | `UUID` | Unique identifier |
| `session_id` | `string` | Session identifier |
| `apiKeySource` (init) | `ApiKeySource` | Key source |
| `cwd` (init) | `string` | Working directory |
| `tools` (init) | `string[]` | Available tools |
| `mcp_servers` (init) | `Array<{name, status}>` | MCP server status |
| `model` (init) | `string` | Active model |
| `permissionMode` (init) | `PermissionMode` | Permission mode |
| `slash_commands` (init) | `string[]` | Available commands |
| `output_style` (init) | `string` | Output style |
| `skills` (init) | `string[]` | Active skill names |
| `plugins` (init) | `Array<{name, path}>` | Active plugin info |
| `fast_mode_state` (init) | `FastModeState` (optional) | Current fast mode state |
| `compact_metadata` (compact) | `{trigger, pre_tokens}` | Compaction info |


### 5.8 SDKElicitationCompleteMessage (New in v0.2.63)

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'system'` | Message type discriminator |
| `subtype` | `'elicitation_complete'` | Subtype discriminator |
| `mcp_server_name` | `string` | MCP server that requested elicitation |
| `elicitation_id` | `string` | Unique elicitation identifier |
| `uuid` | `UUID` | Unique message identifier |
| `session_id` | `string` | Session identifier |


### 5.9 SDKPromptSuggestionMessage (New in v0.2.63)

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'prompt_suggestion'` | Message type discriminator |
| `suggestion` | `string` | Suggested follow-up prompt |
| `uuid` | `UUID` | Unique message identifier |
| `session_id` | `string` | Session identifier |


### 5.6 SDKPartialAssistantMessage / StreamEvent

Only received when `includePartialMessages` / `include_partial_messages` is `true`.

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'stream_event'` | Message type |
| `event` | `RawMessageStreamEvent` / `dict[str, Any]` | Raw stream event |
| `parent_tool_use_id` | `string \| null` | Parent tool use ID |
| `uuid` | `UUID` / `str` | Unique identifier |
| `session_id` | `string` / `str` | Session identifier |


### 5.7 SDKPermissionDenial

| Field | Type | Description |
|-------|------|-------------|
| `tool_name` | `string` | Denied tool name |
| `tool_use_id` | `string` | Tool use identifier |
| `tool_input` | `ToolInput` | Input that was denied |

---

## 6. Content Block Types

### 6.1 ContentBlock (Union)

```typescript
ContentBlock = TextBlock | ThinkingBlock | ToolUseBlock | ToolResultBlock
```


### 6.2 TextBlock

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'text'` | Block type |
| `text` | `string` / `str` | Text content |


### 6.3 ThinkingBlock

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'thinking'` | Block type |
| `thinking` | `string` / `str` | Thinking content |
| `signature` | `string` / `str` | Signature |


### 6.4 ToolUseBlock

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'tool_use'` | Block type |
| `id` | `string` / `str` | Tool use identifier |
| `name` | `string` / `str` | Tool name |
| `input` | `dict[str, Any]` | Tool input parameters |


### 6.5 ToolResultBlock

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'tool_result'` | Block type |
| `tool_use_id` | `string` / `str` | Matching tool use ID |
| `content` | `string \| list[dict] \| None` | Result content |
| `is_error` | `boolean \| None` | Error indicator |

---

## 7. Tool Definitions

### 7.1 Built-in Tools List

| Tool Name | Description |
|-----------|-------------|
| `Read` | Read files (text, images, PDFs, notebooks) |
| `Write` | Create new files |
| `Edit` | Make precise edits to existing files |
| `Bash` | Run terminal commands |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents with regex |
| `WebSearch` | Search the web |
| `WebFetch` | Fetch and parse web content |
| `AskUserQuestion` | Ask user clarifying questions |
| `Task` | Launch subagents |
| `TodoWrite` | Create/manage task lists |
| `ExitPlanMode` | Exit planning mode |
| `TaskOutput` | Get output from a background task |
| `TaskStop` | Stop a background task |
| `NotebookEdit` | Edit Jupyter notebooks |
| `ListMcpResources` | List MCP resources |
| `ReadMcpResource` | Read MCP resource |
| `SubscribeMcpResource` | Subscribe to MCP resource updates |
| `UnsubscribeMcpResource` | Unsubscribe from MCP resource updates |
| `SubscribePolling` | Poll an MCP tool or resource periodically |
| `UnsubscribePolling` | Stop a polling subscription |
| `Config` | Read or write Claude configuration settings |
| `EnterWorktree` | Create and enter an isolated git worktree |


### 7.2 MCP Tool Naming Convention

```
mcp__<server-name>__<tool-name>
```

Example: `mcp__github__list_issues`

---

## 8. Tool Input Schemas

### 8.1 Task (Subagent)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | `string` | Yes | Short (3-5 word) task description |
| `prompt` | `string` | Yes | Task for agent to perform |
| `subagent_type` | `string` | Yes | Agent type to use |
| `model` | `'sonnet' \| 'opus' \| 'haiku'` | No | Model override for this agent |
| `resume` | `string` | No | Session ID to resume |
| `run_in_background` | `boolean` | No | Run in background; result includes output file path |
| `max_turns` | `number` | No | Maximum agentic turns |
| `name` | `string` | No | Name for the spawned agent |
| `team_name` | `string` | No | Team name to spawn into |
| `mode` | `'acceptEdits' \| 'bypassPermissions' \| 'default' \| 'dontAsk' \| 'plan'` | No | Permission mode for spawned agent |
| `isolation` | `'worktree'` | No | Isolation mode; `'worktree'` creates a temporary git worktree |


### 8.2 AskUserQuestion

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `questions` | `Array<Question>` | Yes | 1-4 questions to ask |
| `answers` | `Record<string, string>` | No | User answers (populated by system) |

**Question Object:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `question` | `string` | Yes | Complete question text |
| `header` | `string` | Yes | Short label (max 12 chars) |
| `options` | `Array<{label, description}>` | Yes | 2-4 choices |
| `multiSelect` | `boolean` | Yes | Allow multiple selections |


### 8.3 Bash

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `command` | `string` | Yes | Command to execute |
| `timeout` | `number` | No | Timeout in ms (max 600000) |
| `description` | `string` | No | Command description |
| `run_in_background` | `boolean` | No | Run in background |


### 8.4 TaskOutput

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task_id` | `string` | Yes | Background task ID |
| `block` | `boolean` | No | Block until output is available |
| `timeout` | `number` | No | Timeout in milliseconds |


### 8.5 Edit

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file_path` | `string` | Yes | Absolute file path |
| `old_string` | `string` | Yes | Text to replace |
| `new_string` | `string` | Yes | Replacement text |
| `replace_all` | `boolean` | No | Replace all occurrences (default: false) |


### 8.6 Read

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file_path` | `string` | Yes | Absolute file path |
| `offset` | `number` | No | Starting line number |
| `limit` | `number` | No | Number of lines to read |


### 8.7 Write

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file_path` | `string` | Yes | Absolute file path |
| `content` | `string` | Yes | Content to write |


### 8.8 Glob

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pattern` | `string` | Yes | Glob pattern |
| `path` | `string` | No | Directory to search (default: cwd) |


### 8.9 Grep

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `pattern` | `string` | Yes | Regex pattern |
| `path` | `string` | No | Search path (default: cwd) |
| `glob` | `string` | No | File glob filter |
| `type` | `string` | No | File type (js, py, etc.) |
| `output_mode` | `'content' \| 'files_with_matches' \| 'count'` | No | Output format |
| `-i` | `boolean` | No | Case insensitive |
| `-n` | `boolean` | No | Show line numbers |
| `-B` | `number` | No | Lines before match |
| `-A` | `number` | No | Lines after match |
| `-C` | `number` | No | Context lines |
| `head_limit` | `number` | No | Limit output |
| `multiline` | `boolean` | No | Multiline mode |


### 8.10 TaskStop

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task_id` | `string` | No | Task ID to stop |


### 8.11 NotebookEdit

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `notebook_path` | `string` | Yes | Absolute notebook path |
| `cell_id` | `string` | No | Cell ID to edit |
| `new_source` | `string` | Yes | New cell source |
| `cell_type` | `'code' \| 'markdown'` | No | Cell type |
| `edit_mode` | `'replace' \| 'insert' \| 'delete'` | No | Edit operation |


### 8.12 WebFetch

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `url` | `string` | Yes | URL to fetch |
| `prompt` | `string` | Yes | Prompt for content analysis |


### 8.13 WebSearch

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `query` | `string` | Yes | Search query |
| `allowed_domains` | `string[]` | No | Allowed domains |
| `blocked_domains` | `string[]` | No | Blocked domains |


### 8.14 TodoWrite

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `todos` | `Array<Todo>` | Yes | Todo list items |

**Todo Object:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `content` | `string` | Yes | Task description |
| `status` | `'pending' \| 'in_progress' \| 'completed'` | Yes | Task status |
| `activeForm` | `string` | Yes | Active form description |


### 8.15 ExitPlanMode

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `plan` | `string` | Yes | Plan for user approval |


### 8.16 ListMcpResources

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `server` | `string` | No | Server name filter |


### 8.17 ReadMcpResource

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `server` | `string` | Yes | MCP server name |
| `uri` | `string` | Yes | Resource URI |


### 8.18 Config

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `setting` | `string` | Yes | Setting name to read or modify |
| `value` | `string \| boolean \| number` | No | Value to set; omit to read |


### 8.19 EnterWorktree

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | `string` | No | Optional name for the worktree |


### 8.20 SubscribePolling

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `'tool' \| 'resource'` | Yes | Poll target type |
| `server` | `string` | Yes | MCP server name |
| `toolName` | `string` | No | Tool to poll (when type is `'tool'`) |
| `arguments` | `Record<string, unknown>` | No | Arguments for each tool call |
| `uri` | `string` | No | Resource URI to poll (when type is `'resource'`) |
| `intervalMs` | `number` | Yes | Polling interval (minimum 1000ms, default 5000ms) |
| `reason` | `string` | No | Reason for subscribing |


### 8.21 UnsubscribePolling

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `subscriptionId` | `string` | No | Subscription ID to cancel |
| `server` | `string` | No | Server name filter |
| `target` | `string` | No | Tool name or resource URI to unsubscribe |

---

## 9. Tool Output Schemas

### 9.1 Task Output (AgentOutput)

Discriminated union on `status`:

**Completed (`status: 'completed'`):**

| Field | Type | Description |
|-------|------|-------------|
| `status` | `'completed'` | Completion discriminator |
| `agentId` | `string` | Agent identifier |
| `content` | `Array<{type: 'text', text: string}>` | Response content |
| `totalToolUseCount` | `number` | Total tool uses |
| `totalDurationMs` | `number` | Total duration in ms |
| `totalTokens` | `number` | Total tokens consumed |
| `usage` | `AgentUsage` | Detailed token usage |
| `prompt` | `string` | Original prompt |

**Async Launched (`status: 'async_launched'`):**

| Field | Type | Description |
|-------|------|-------------|
| `status` | `'async_launched'` | Async discriminator |
| `agentId` | `string` | Agent identifier |
| `description` | `string` | Task description |
| `prompt` | `string` | Original prompt |
| `outputFile` | `string` | Path to output file |
| `canReadOutputFile` | `boolean` (optional) | Whether calling agent can read the output file |

**Sub Agent Entered (`status: 'sub_agent_entered'`):**

| Field | Type | Description |
|-------|------|-------------|
| `status` | `'sub_agent_entered'` | Sub-agent entered discriminator |
| `description` | `string` | Task description |
| `message` | `string` | Status message |


### 9.2 Bash Output

| Field | Type | Description |
|-------|------|-------------|
| `stdout` | `string` | Standard output |
| `stderr` | `string` | Standard error |
| `interrupted` | `boolean` | Whether the command was interrupted |
| `rawOutputPath` | `string` (optional) | Path to raw output file for large outputs |
| `isImage` | `boolean` (optional) | Whether stdout contains image data |
| `backgroundTaskId` | `string` (optional) | Background task ID if running in background |
| `backgroundedByUser` | `boolean` (optional) | True if user manually backgrounded with Ctrl+B |
| `dangerouslyDisableSandbox` | `boolean` (optional) | Whether sandbox was overridden |
| `returnCodeInterpretation` | `string` (optional) | Semantic meaning of non-error exit codes |
| `noOutputExpected` | `boolean` (optional) | Whether no output is expected on success |
| `structuredContent` | `unknown[]` (optional) | Structured content blocks |
| `persistedOutputPath` | `string` (optional) | Path to persisted output when output is too large |
| `persistedOutputSize` | `number` (optional) | Total size in bytes of persisted output |


### 9.3 Edit Output (FileEditOutput)

| Field | Type | Description |
|-------|------|-------------|
| `filePath` | `string` | Edited file path |
| `oldString` | `string` | Original text that was replaced |
| `newString` | `string` | Replacement text |
| `originalFile` | `string` | Full original file contents before edit |
| `structuredPatch` | `StructuredPatchHunk[]` | Diff hunks |
| `userModified` | `boolean` | Whether user modified proposed changes |
| `replaceAll` | `boolean` | Whether all occurrences were replaced |
| `gitDiff` | `GitDiff` (optional) | Git diff information |


### 9.4 Read Output (FileReadOutput)

Discriminated union on `type`:

**Text (`type: 'text'`):**

| Field | Type | Description |
|-------|------|-------------|
| `file.filePath` | `string` | File path |
| `file.content` | `string` | File contents |
| `file.numLines` | `number` | Lines returned |
| `file.startLine` | `number` | Starting line number |
| `file.totalLines` | `number` | Total lines in file |

**Image (`type: 'image'`):**

| Field | Type | Description |
|-------|------|-------------|
| `file.base64` | `string` | Base64-encoded image data |
| `file.type` | `'image/jpeg' \| 'image/png' \| 'image/gif' \| 'image/webp'` | MIME type |
| `file.originalSize` | `number` | File size in bytes |
| `file.dimensions` | `object` (optional) | Original and display dimensions |

**Notebook (`type: 'notebook'`):**

| Field | Type | Description |
|-------|------|-------------|
| `file.filePath` | `string` | Notebook path |
| `file.cells` | `unknown[]` | Notebook cells |

**PDF (`type: 'pdf'`):**

| Field | Type | Description |
|-------|------|-------------|
| `file.filePath` | `string` | PDF path |
| `file.base64` | `string` | Base64-encoded PDF data |
| `file.originalSize` | `number` | File size in bytes |

**Parts (`type: 'parts'`):**

| Field | Type | Description |
|-------|------|-------------|
| `file.filePath` | `string` | Source file path |
| `file.originalSize` | `number` | File size in bytes |
| `file.count` | `number` | Number of parts extracted |
| `file.outputDir` | `string` | Directory containing extracted parts |


### 9.5 Write Output (FileWriteOutput)

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'create' \| 'update'` | Whether file was created or updated |
| `filePath` | `string` | Written file path |
| `content` | `string` | Content that was written |
| `structuredPatch` | `StructuredPatchHunk[]` | Diff hunks |
| `originalFile` | `string \| null` | Original content (null for new files) |
| `gitDiff` | `GitDiff` (optional) | Git diff information |


### 9.6 Glob Output

| Field | Type | Description |
|-------|------|-------------|
| `matches` | `string[]` | Matching file paths |
| `count` | `number` | Match count |
| `search_path` | `string` | Search directory |


### 9.7 Grep Output (content mode)

| Field | Type | Description |
|-------|------|-------------|
| `matches` | `Array<{file, line_number, line, context}>` | Matching lines |
| `total_matches` | `number` | Total match count |


### 9.8 Grep Output (files_with_matches mode)

| Field | Type | Description |
|-------|------|-------------|
| `files` | `string[]` | Files with matches |
| `count` | `number` | File count |


### 9.9 WebFetch Output

| Field | Type | Description |
|-------|------|-------------|
| `response` | `string` | AI analysis response |
| `url` | `string` | Fetched URL |
| `final_url` | `string` | Final URL after redirects |
| `status_code` | `number` | HTTP status |


### 9.10 WebSearch Output

| Field | Type | Description |
|-------|------|-------------|
| `results` | `Array<{title, url, snippet, metadata}>` | Search results |
| `total_results` | `number` | Total results |
| `query` | `string` | Search query |


### 9.11 TaskStop Output

| Field | Type | Description |
|-------|------|-------------|
| `message` | `string` | Status message |
| `task_id` | `string` | ID of the stopped task |
| `task_type` | `string` | Type of the stopped task |
| `command` | `string` (optional) | Command or description of the stopped task |


### 9.12 Config Output

| Field | Type | Description |
|-------|------|-------------|
| `success` | `boolean` | Whether the operation succeeded |
| `operation` | `'get' \| 'set'` (optional) | Operation performed |
| `setting` | `string` (optional) | Setting name |
| `value` | `unknown` (optional) | Current value |
| `previousValue` | `unknown` (optional) | Previous value before set |
| `newValue` | `unknown` (optional) | New value after set |
| `error` | `string` (optional) | Error message on failure |


### 9.13 EnterWorktree Output

| Field | Type | Description |
|-------|------|-------------|
| `worktreePath` | `string` | Path to the created worktree |
| `worktreeBranch` | `string` (optional) | Branch created for the worktree |
| `message` | `string` | Status message |


### 9.14 SubscribePolling Output

| Field | Type | Description |
|-------|------|-------------|
| `subscribed` | `boolean` | Whether the subscription was successful |
| `subscriptionId` | `string` | Unique identifier for this subscription |


### 9.15 UnsubscribePolling Output

| Field | Type | Description |
|-------|------|-------------|
| `unsubscribed` | `boolean` | Whether the unsubscription was successful |


### 9.16 ExitPlanMode Output

| Field | Type | Description |
|-------|------|-------------|
| `plan` | `string \| null` | The plan presented to the user |
| `isAgent` | `boolean` | Whether in agent context |
| `filePath` | `string` (optional) | Path where plan was saved |
| `hasTaskTool` | `boolean` (optional) | Whether Agent tool is available |
| `awaitingLeaderApproval` | `boolean` (optional) | When true, plan approval request sent to team leader |
| `requestId` | `string` (optional) | Unique identifier for the plan approval request |


### 9.17 GitDiff (Shared Type)

Used in FileEditOutput and FileWriteOutput:

| Field | Type | Description |
|-------|------|-------------|
| `filename` | `string` | File that changed |
| `status` | `'modified' \| 'added'` | Change type |
| `additions` | `number` | Lines added |
| `deletions` | `number` | Lines deleted |
| `changes` | `number` | Total changes |
| `patch` | `string` | Diff patch content |


### 9.18 StructuredPatchHunk (Shared Type)

Used in FileEditOutput and FileWriteOutput:

| Field | Type | Description |
|-------|------|-------------|
| `oldStart` | `number` | Starting line in original |
| `oldLines` | `number` | Lines in original hunk |
| `newStart` | `number` | Starting line in new version |
| `newLines` | `number` | Lines in new version hunk |
| `lines` | `string[]` | Diff lines (prefixed with `+`, `-`, or ` `) |

---

## 10. Hook System

### 10.1 Hook Events

| Event | Python | TypeScript | Description |
|-------|--------|------------|-------------|
| `PreToolUse` | Yes | Yes | Before tool execution (can block/modify) |
| `PostToolUse` | Yes | Yes | After tool execution |
| `PostToolUseFailure` | No | Yes | After tool failure |
| `UserPromptSubmit` | Yes | Yes | User prompt submission |
| `Stop` | Yes | Yes | Agent execution stop |
| `SubagentStart` | No | Yes | Subagent initialization |
| `SubagentStop` | Yes | Yes | Subagent completion |
| `PreCompact` | Yes | Yes | Before conversation compaction |
| `PermissionRequest` | No | Yes | Permission dialog trigger |
| `SessionStart` | No | Yes | Session initialization |
| `SessionEnd` | No | Yes | Session termination |
| `Notification` | No | Yes | Agent status messages |
| `Setup` | No | Yes | Session setup (init or maintenance) |
| `TeammateIdle` | No | Yes | Teammate became idle |
| `TaskCompleted` | No | Yes | Task was completed |
| `Elicitation` | No | Yes | MCP server requests user input |
| `ElicitationResult` | No | Yes | Elicitation request received a result |
| `ConfigChange` | No | Yes | Configuration changed |
| `WorktreeCreate` | No | Yes | Git worktree was created |
| `WorktreeRemove` | No | Yes | Git worktree was removed |


### 10.2 HookCallback Signature

#### TypeScript

```typescript
type HookCallback = (
  input: HookInput,
  toolUseID: string | undefined,
  options: { signal: AbortSignal }
) => Promise<HookJSONOutput>;
```

#### Python

```python
HookCallback = Callable[
    [dict[str, Any], str | None, HookContext],
    Awaitable[dict[str, Any]]
]
```


### 10.3 HookCallbackMatcher / HookMatcher

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `matcher` | `string \| None` | No | Regex pattern for tool names |
| `hooks` | `HookCallback[]` | Yes | Callback functions |
| `timeout` | `number` / `float` | No | Timeout in seconds (default: 60) |


### 10.4 BaseHookInput (Common Fields)

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | `string` | Session identifier |
| `transcript_path` | `string` | Path to transcript |
| `cwd` | `string` | Working directory |
| `permission_mode` | `string` | Current permission mode |


### 10.5 Hook-Specific Input Fields

| Hook | Additional Fields |
|------|-------------------|
| `PreToolUse` | `tool_name`, `tool_input`, `tool_use_id` |
| `PostToolUse` | `tool_name`, `tool_input`, `tool_response`, `tool_use_id` |
| `PostToolUseFailure` | `tool_name`, `tool_input`, `error`, `is_interrupt`, `tool_use_id` |
| `UserPromptSubmit` | `prompt` |
| `Stop` | `stop_hook_active`, `last_assistant_message` (optional) |
| `SubagentStart` | `agent_id`, `agent_type` |
| `SubagentStop` | `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message` (optional) |
| `PreCompact` | `trigger` (`manual` \| `auto`), `custom_instructions` |
| `PermissionRequest` | `tool_name`, `tool_input`, `permission_suggestions` |
| `SessionStart` | `source` (`startup` \| `resume` \| `clear` \| `compact`), `agent_type` (optional), `model` (optional) |
| `SessionEnd` | `reason` (`clear` \| `logout` \| `prompt_input_exit` \| `bypass_permissions_disabled` \| `other`) |
| `Notification` | `message`, `notification_type` (`permission_prompt` \| `idle_prompt` \| `auth_success` \| `elicitation_dialog`), `title` |
| `Setup` | `trigger` (`init` \| `maintenance`) |
| `TeammateIdle` | `teammate_name`, `team_name` |
| `TaskCompleted` | `task_id`, `task_subject`, `task_description` (optional), `teammate_name` (optional), `team_name` (optional) |
| `Elicitation` | `mcp_server_name`, `message`, `mode` (`form` \| `url`), `url` (optional), `elicitation_id` (optional), `requested_schema` (optional) |
| `ElicitationResult` | `mcp_server_name`, `elicitation_id` (optional), `mode` (optional), `action` (`accept` \| `decline` \| `cancel`), `content` (optional) |
| `ConfigChange` | `source` (`user_settings` \| `project_settings` \| `local_settings` \| `policy_settings` \| `skills`), `file_path` (optional) |
| `WorktreeCreate` | `name` |
| `WorktreeRemove` | `worktree_path` |


### 10.6 HookJSONOutput

```typescript
type HookJSONOutput = AsyncHookJSONOutput | SyncHookJSONOutput;
```

#### AsyncHookJSONOutput

| Field | Type | Description |
|-------|------|-------------|
| `async` / `async_` | `true` | Defers hook execution |
| `asyncTimeout` | `number` | Timeout in milliseconds |

#### SyncHookJSONOutput

| Field | Type | Description |
|-------|------|-------------|
| `continue` / `continue_` | `boolean` | Whether to continue (default: true) |
| `suppressOutput` | `boolean` | Hide stdout from transcript |
| `stopReason` | `string` | Message when continue is false |
| `decision` | `'approve' \| 'block'` | Decision shortcut |
| `systemMessage` | `string` | Message to inject |
| `reason` | `string` | Feedback for Claude |
| `hookSpecificOutput` | `object` | Hook-specific return data (see below) |


### 10.7 hookSpecificOutput Variants

#### PreToolUse

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'PreToolUse'` | Event identifier |
| `permissionDecision` | `'allow' \| 'deny' \| 'ask'` | Permission decision |
| `permissionDecisionReason` | `string` | Explanation |
| `updatedInput` | `object` | Modified tool input (requires `permissionDecision: 'allow'`) |

#### UserPromptSubmit

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'UserPromptSubmit'` | Event identifier |
| `additionalContext` | `string` | Context added to the conversation |

#### SessionStart (TS only)

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'SessionStart'` | Event identifier |
| `additionalContext` | `string` | Context added to the conversation |

#### PostToolUse

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'PostToolUse'` | Event identifier |
| `additionalContext` | `string` | Context added to the conversation |

#### Elicitation

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'Elicitation'` | Event identifier |
| `action` | `'accept' \| 'decline' \| 'cancel'` (optional) | Response action |
| `content` | `Record<string, unknown>` (optional) | Form content for accepted requests |

#### ElicitationResult

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'ElicitationResult'` | Event identifier |
| `action` | `'accept' \| 'decline' \| 'cancel'` (optional) | Confirmed action |
| `content` | `Record<string, unknown>` (optional) | Form content |

---

## 11. Permission System

### 11.1 CanUseTool Callback

#### TypeScript

```typescript
type CanUseTool = (
  toolName: string,
  input: ToolInput,
  options: { signal: AbortSignal; suggestions?: PermissionUpdate[] }
) => Promise<PermissionResult>;
```

#### Python

```python
CanUseTool = Callable[
    [str, dict[str, Any], ToolPermissionContext],
    Awaitable[PermissionResult]
]
```


### 11.2 ToolPermissionContext (Python)

| Field | Type | Description |
|-------|------|-------------|
| `signal` | `Any \| None` | Reserved for abort signal |
| `suggestions` | `list[PermissionUpdate]` | Permission suggestions |


### 11.3 PermissionResult

#### Allow

| Field | Type (TS) | Type (Python) | Description |
|-------|-----------|---------------|-------------|
| `behavior` | `'allow'` | `Literal["allow"]` | Allow indicator |
| `updatedInput` | `ToolInput` | `dict[str, Any] \| None` | Modified input |
| `updatedPermissions` | `PermissionUpdate[]` | `list[PermissionUpdate] \| None` | Permission updates |

#### Deny

| Field | Type (TS) | Type (Python) | Description |
|-------|-----------|---------------|-------------|
| `behavior` | `'deny'` | `Literal["deny"]` | Deny indicator |
| `message` | `string` | `str` | Denial message |
| `interrupt` | `boolean` | `bool` | Interrupt execution |


### 11.4 PermissionUpdate

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'addRules' \| 'replaceRules' \| 'removeRules' \| 'setMode' \| 'addDirectories' \| 'removeDirectories'` | Update type |
| `rules` | `PermissionRuleValue[]` | Rules for add/replace/remove |
| `behavior` | `'allow' \| 'deny' \| 'ask'` | Rule behavior |
| `mode` | `PermissionMode` | For setMode |
| `directories` | `string[]` | For add/remove directories |
| `destination` | `'userSettings' \| 'projectSettings' \| 'localSettings' \| 'session'` | Target location |


### 11.5 PermissionRuleValue

| Field | Type | Description |
|-------|------|-------------|
| `toolName` | `string` | Tool name |
| `ruleContent` | `string` | Optional rule content |

---

## 12. MCP (Model Context Protocol)

### 12.1 McpServerConfig (Union)

```typescript
type McpServerConfig =
  | McpStdioServerConfig
  | McpSSEServerConfig
  | McpHttpServerConfig
  | McpSdkServerConfigWithInstance;
```


### 12.2 McpStdioServerConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `'stdio'` | No | Transport type (optional) |
| `command` | `string` | Yes | Command to run |
| `args` | `string[]` | No | Command arguments |
| `env` | `Record<string, string>` | No | Environment variables |


### 12.3 McpSSEServerConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `'sse'` | Yes | Transport type |
| `url` | `string` | Yes | Server URL |
| `headers` | `Record<string, string>` | No | HTTP headers |


### 12.4 McpHttpServerConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `'http'` | Yes | Transport type |
| `url` | `string` | Yes | Server URL |
| `headers` | `Record<string, string>` | No | HTTP headers |


### 12.5 McpSdkServerConfigWithInstance

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | `'sdk'` | Yes | Transport type |
| `name` | `string` | Yes | Server name |
| `instance` | `McpServer` | Yes | Server instance |


### 12.6 McpServerStatus

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Server name |
| `status` | `'connected' \| 'failed' \| 'needs-auth' \| 'pending' \| 'disabled'` | Connection status |
| `serverInfo` | `{name: string, version: string}` (optional) | Server info |
| `error` | `string` (optional) | Error message when status is `'failed'` |
| `config` | `McpServerStatusConfig` (optional) | Server configuration |
| `scope` | `string` (optional) | Configuration scope (`project`, `user`, `local`, `claudeai`, `managed`) |
| `tools` | `Array<McpToolInfo>` (optional) | Tools provided by this server |


### 12.7 McpToolInfo

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Tool name |
| `description` | `string` (optional) | Tool description |
| `annotations` | `object` (optional) | Tool behavior annotations |
| `annotations.readOnly` | `boolean` (optional) | Tool only reads, does not write |
| `annotations.destructive` | `boolean` (optional) | Tool may destructively modify data |
| `annotations.openWorld` | `boolean` (optional) | Tool accesses external systems |


### 12.8 McpSetServersResult

| Field | Type | Description |
|-------|------|-------------|
| `added` | `string[]` | Names of servers added |
| `removed` | `string[]` | Names of servers removed |
| `errors` | `Record<string, string>` | Per-server error messages |


### 12.9 McpServerStatusConfig (Union)

```typescript
type McpServerStatusConfig = McpServerConfigForProcessTransport | McpClaudeAIProxyServerConfig;
type McpServerConfigForProcessTransport = McpStdioServerConfig | McpSSEServerConfig | McpHttpServerConfig | McpSdkServerConfig;
```


### 12.10 McpClaudeAIProxyServerConfig

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'claudeai-proxy'` | Transport type |
| `url` | `string` | Proxy URL |
| `id` | `string` | Server identifier |


### 12.7 SdkMcpTool (Python)

| Field | Type | Description |
|-------|------|-------------|
| `name` | `str` | Tool identifier |
| `description` | `str` | Tool description |
| `input_schema` | `type[T] \| dict[str, Any]` | Input schema |
| `handler` | `Callable[[T], Awaitable[dict[str, Any]]]` | Handler function |

---

## 13. Subagent System

### 13.1 AgentDefinition

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `description` | `string` | Yes | When to use this agent |
| `prompt` | `string` | Yes | Agent's system prompt |
| `tools` | `string[]` | No | Allowed tools (inherits if omitted) |
| `disallowedTools` | `string[]` | No | Tools to block for this agent |
| `model` | `'sonnet' \| 'opus' \| 'haiku' \| 'inherit'` | No | Model override |
| `mcpServers` | `AgentMcpServerSpec[]` | No | MCP servers for this agent |
| `criticalSystemReminder_EXPERIMENTAL` | `string` | No | Additional system reminder (experimental) |
| `skills` | `string[]` | No | Skill names to load |
| `maxTurns` | `number` | No | Maximum turns for this agent |


### 13.2 Subagent Invocation

- Invoked via `Task` tool
- `Task` must be in `allowedTools`
- Messages include `parent_tool_use_id` when from subagent context
- Subagents cannot spawn their own subagents


### 13.3 Built-in Subagent Types

| Type | Description |
|------|-------------|
| `general-purpose` | Default agent for general tasks |
| `Explore` | Fast codebase exploration |
| `Plan` | Implementation planning |

---

## 14. Session Management

### 14.1 Session ID Acquisition

The session ID is returned in the first `system` message with `subtype: 'init'`.

```typescript
if (message.type === 'system' && message.subtype === 'init') {
  sessionId = message.session_id;
}
```


### 14.2 Session Resume

| Option | Type | Description |
|--------|------|-------------|
| `resume` | `string` | Session ID to resume |
| `forkSession` / `fork_session` | `boolean` | Create new session from resume point |


### 14.3 Resume vs Fork Behavior

| Behavior | `forkSession: false` | `forkSession: true` |
|----------|---------------------|---------------------|
| Session ID | Same as original | New ID generated |
| History | Appends to original | Creates branch |
| Original session | Modified | Preserved |

---

## 15. Sandbox Configuration

### 15.1 SandboxSettings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | `boolean` | `false` | Enable sandbox mode |
| `autoAllowBashIfSandboxed` | `boolean` | `false` | Auto-approve bash in sandbox |
| `excludedCommands` | `string[]` | `[]` | Commands that bypass sandbox |
| `allowUnsandboxedCommands` | `boolean` | `false` | Allow model to request unsandboxed |
| `network` | `SandboxNetworkConfig` | `undefined` | Network configuration |
| `filesystem` | `SandboxFilesystemConfig` | `undefined` | Filesystem access configuration |
| `ignoreViolations` | `SandboxIgnoreViolations` | `undefined` | Violations to ignore |
| `enableWeakerNestedSandbox` | `boolean` | `false` | Compatibility mode for nested sandboxes |


### 15.2 NetworkSandboxSettings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allowLocalBinding` | `boolean` | `false` | Allow binding to local ports |
| `allowUnixSockets` | `string[]` | `[]` | Allowed Unix socket paths |
| `allowAllUnixSockets` | `boolean` | `false` | Allow all Unix sockets |
| `httpProxyPort` | `number` | `undefined` | HTTP proxy port |
| `socksProxyPort` | `number` | `undefined` | SOCKS proxy port |


### 15.3 SandboxFilesystemConfig

| Field | Type | Description |
|-------|------|-------------|
| `allowWrite` | `string[]` (optional) | Paths allowed for writing |
| `denyWrite` | `string[]` (optional) | Paths denied for writing |
| `denyRead` | `string[]` (optional) | Paths denied for reading |


### 15.4 SandboxIgnoreViolations

| Field | Type | Description |
|-------|------|-------------|
| `file` | `string[]` | File path patterns to ignore |
| `network` | `string[]` | Network patterns to ignore |

---

## 16. Error Types

### 16.1 Python Error Classes

| Error | Parent | Description |
|-------|--------|-------------|
| `ClaudeSDKError` | `Exception` | Base SDK error |
| `CLIConnectionError` | `ClaudeSDKError` | Connection failure |
| `CLINotFoundError` | `CLIConnectionError` | CLI not found |
| `ProcessError` | `ClaudeSDKError` | Process failure |
| `CLIJSONDecodeError` | `ClaudeSDKError` | JSON parse failure |


### 16.2 TypeScript Error Classes

| Error | Description |
|-------|-------------|
| `AbortError` | Abort operation error |

---

## 17. Beta Features

### 17.1 SdkBeta Values

| Value | Description | Compatible Models |
|-------|-------------|-------------------|
| `'context-1m-2025-08-07'` | 1 million token context window | Claude Opus 4.6, Claude Sonnet 4.5, Claude Sonnet 4 |

---

## 18. Additional Types

### 18.1 ApiKeySource

```typescript
type ApiKeySource = 'user' | 'project' | 'org' | 'temporary';
```


### 18.2 SlashCommand

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Command name |
| `description` | `string` | Command description |
| `argumentHint` | `string` | Argument hint |


### 18.3 ModelInfo

| Field | Type | Description |
|-------|------|-------------|
| `value` | `string` | Model identifier |
| `displayName` | `string` | Display name |
| `description` | `string` | Model description |
| `supportsEffort` | `boolean` (optional) | Whether model supports effort levels |
| `supportedEffortLevels` | `('low' \| 'medium' \| 'high' \| 'max')[]` (optional) | Supported effort levels |
| `supportsAdaptiveThinking` | `boolean` (optional) | Whether model supports adaptive thinking |


### 18.4 AccountInfo

| Field | Type | Description |
|-------|------|-------------|
| `email` | `string` | Account email |
| `organization` | `string` | Organization |
| `subscriptionType` | `string` | Subscription type |
| `tokenSource` | `string` | Token source |
| `apiKeySource` | `string` | API key source |


### 18.5 ModelUsage

| Field | Type | Description |
|-------|------|-------------|
| `inputTokens` | `number` | Input tokens |
| `outputTokens` | `number` | Output tokens |
| `cacheReadInputTokens` | `number` | Cache read tokens |
| `cacheCreationInputTokens` | `number` | Cache creation tokens |
| `webSearchRequests` | `number` | Web search count |
| `costUSD` | `number` | Cost in USD |
| `contextWindow` | `number` | Context window size |
| `maxOutputTokens` | `number` | Maximum output tokens for this model |


### 18.6 Usage

| Field | Type | Description |
|-------|------|-------------|
| `input_tokens` | `number \| null` | Input tokens |
| `output_tokens` | `number \| null` | Output tokens |
| `cache_creation_input_tokens` | `number \| null` | Cache creation tokens |
| `cache_read_input_tokens` | `number \| null` | Cache read tokens |


### 18.7 SdkPluginConfig

| Field | Type | Description |
|-------|------|-------------|
| `type` | `'local'` | Plugin type |
| `path` | `string` | Path to plugin directory |


### 18.8 ConfigScope

```typescript
type ConfigScope = 'local' | 'user' | 'project';
```


### 18.9 NonNullableUsage

A version of `Usage` with all nullable fields made non-nullable.

```typescript
type NonNullableUsage = {
  [K in keyof Usage]: NonNullable<Usage[K]>;
}
```


### 18.10 CallToolResult

MCP tool result type (from `@modelcontextprotocol/sdk/types.js`).

| Field | Type | Description |
|-------|------|-------------|
| `content` | `Array<{type: 'text' \| 'image' \| 'resource', ...}>` | Result content blocks |
| `isError` | `boolean` | Error indicator |


### 18.11 AbortError (TypeScript only)

```typescript
class AbortError extends Error {}
```


### 18.12 AgentInfo

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | Agent type name |
| `description` | `string` | Agent description |
| `model` | `string` (optional) | Default model for this agent |


### 18.13 FastModeState

```typescript
type FastModeState = 'off' | 'cooldown' | 'on';
```


### 18.14 ThinkingConfig (Union)

```typescript
type ThinkingConfig = ThinkingAdaptive | ThinkingEnabled | ThinkingDisabled;
```

| Variant | Fields | Description |
|---------|--------|-------------|
| `ThinkingAdaptive` | `type: 'adaptive'` | Model adapts thinking dynamically |
| `ThinkingEnabled` | `type: 'enabled', budgetTokens?: number` | Enable thinking with optional token budget |
| `ThinkingDisabled` | `type: 'disabled'` | Disable thinking |


### 18.15 SDKControlInitializeResponse

Returned by `query.initializationResult()`:

| Field | Type | Description |
|-------|------|-------------|
| `commands` | `SlashCommand[]` | Available slash commands |
| `agents` | `AgentInfo[]` | Available agent types |
| `output_style` | `string` | Current output style |
| `available_output_styles` | `string[]` | All available output styles |
| `models` | `ModelInfo[]` | Available models |
| `account` | `AccountInfo` | Current account information |
| `fast_mode_state` | `FastModeState` (optional) | Current fast mode state |


### 18.16 RewindFilesResult

Returned by `query.rewindFiles()`:

| Field | Type | Description |
|-------|------|-------------|
| `canRewind` | `boolean` | Whether a rewind is possible |
| `error` | `string` (optional) | Error message if rewind is not possible |
| `filesChanged` | `string[]` (optional) | Files that would be/were changed |
| `insertions` | `number` (optional) | Lines inserted |
| `deletions` | `number` (optional) | Lines deleted |


### 18.17 SDKSessionInfo

Returned by `listSessions()`:

| Field | Type | Description |
|-------|------|-------------|
| `sessionId` | `string` | Session identifier |
| `summary` | `string` | Session summary |
| `lastModified` | `number` | Last modification timestamp (Unix ms) |
| `fileSize` | `number` | Session file size in bytes |
| `customTitle` | `string` (optional) | Custom session title |
| `firstPrompt` | `string` (optional) | First prompt in the session |
| `gitBranch` | `string` (optional) | Git branch at session start |
| `cwd` | `string` (optional) | Working directory |


### 18.18 Standalone Session Functions (New in v0.2.63)

**`getSessionMessages(sessionId, options?)`**

```typescript
function getSessionMessages(
    sessionId: string,
    options?: { dir?: string; limit?: number; offset?: number }
): Promise<SessionMessage[]>
```

**`listSessions(options?)`**

```typescript
function listSessions(
    options?: { dir?: string; limit?: number }
): Promise<SDKSessionInfo[]>
```


### 18.19 ElicitationRequest / OnElicitation

```typescript
type ElicitationRequest = {
    serverName: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitationId?: string;
    requestedSchema?: Record<string, unknown>;
};

type OnElicitation = (
    request: ElicitationRequest,
    options: { signal: AbortSignal }
) => Promise<ElicitationResult>;
```


### 18.20 SDKRateLimitInfo

| Field | Type | Description |
|-------|------|-------------|
| `status` | `'allowed' \| 'allowed_warning' \| 'rejected'` | Rate limit status |
| `resetsAt` | `number` (optional) | When limit resets (Unix ms) |
| `rateLimitType` | `'five_hour' \| 'seven_day' \| 'seven_day_opus' \| 'seven_day_sonnet' \| 'overage'` (optional) | Type of rate limit |
| `utilization` | `number` (optional) | Current utilization ratio (0-1) |
| `overageStatus` | `'allowed' \| 'allowed_warning' \| 'rejected'` (optional) | Overage status |
| `overageResetsAt` | `number` (optional) | When overage resets |
| `overageDisabledReason` | `string` (optional) | Reason overage is disabled |
| `isUsingOverage` | `boolean` (optional) | Whether currently using overage |
| `surpassedThreshold` | `number` (optional) | Threshold that was surpassed |

---

## Appendix A: Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | API key for authentication |
| `CLAUDE_CODE_USE_BEDROCK` | Set to `1` for Amazon Bedrock |
| `CLAUDE_CODE_USE_VERTEX` | Set to `1` for Google Vertex AI |
| `CLAUDE_CODE_USE_FOUNDRY` | Set to `1` for Microsoft Azure Foundry |
| `ENABLE_TOOL_SEARCH` | Control MCP tool search (`auto`, `auto:N%`, `true`, `false`) |

---

## Appendix B: Feature Parity Matrix

| Feature | TypeScript | Python |
|---------|------------|--------|
| `query()` function | ✅ | ✅ |
| `tool()` helper | ✅ | ✅ (decorator) |
| `createSdkMcpServer()` | ✅ | ✅ |
| `Query` class with methods | ✅ | ❌ |
| `ClaudeSDKClient` class | ❌ | ✅ |
| Streaming input | ✅ | ✅ |
| Session resume | ✅ | ✅ |
| Session fork | ✅ | ✅ |
| Interrupt | ✅ | ✅ (`ClaudeSDKClient` only) |
| File checkpointing / rewind | ✅ | ✅ |
| Hooks via `query()` | ✅ | ❌ (use `ClaudeSDKClient`) |
| All hook events | ✅ (20 events) | Partial (6 events, no SessionStart/End/Notification/PostToolUseFailure/SubagentStart/PermissionRequest/Setup/TeammateIdle/TaskCompleted/Elicitation/ElicitationResult/ConfigChange/WorktreeCreate/WorktreeRemove) |
| Custom permission callback | ✅ | ✅ |
| Custom MCP tools via `query()` | ✅ | ❌ (use `ClaudeSDKClient`) |
| MCP servers | ✅ | ✅ |
| Subagents | ✅ | ✅ |
| Sandbox configuration | ✅ | ✅ |
| Structured output | ✅ | ✅ |
| Plugins | ✅ | ✅ |
