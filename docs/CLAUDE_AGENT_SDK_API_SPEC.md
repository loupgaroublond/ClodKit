# Claude Agent SDK API Specification

This document comprehensively captures the current API for the official Claude Agent SDK (TypeScript and Python). It is organized analytically into discrete, checkable sections to enable verification of API parity in unofficial SDK implementations.

**Source**: [Anthropic Claude Agent SDK Documentation](https://platform.claude.com/docs/en/agent-sdk/overview)

**Last Updated**: 2026-01-28

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
| `rewindFiles()` | `Promise<void>` | Restores files to state at specified message UUID |
| `setPermissionMode()` | `Promise<void>` | Changes permission mode dynamically |
| `setModel()` | `Promise<void>` | Changes model dynamically |
| `setMaxThinkingTokens()` | `Promise<void>` | Changes max thinking tokens |
| `supportedCommands()` | `Promise<SlashCommand[]>` | Returns available slash commands |
| `supportedModels()` | `Promise<ModelInfo[]>` | Returns available models |
| `mcpServerStatus()` | `Promise<McpServerStatus[]>` | Returns MCP server connection status |
| `accountInfo()` | `Promise<AccountInfo>` | Returns account information |


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
| `rewind_files()` | `async (user_message_uuid: str) -> None` | Restore files to specified state |
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
| Strict MCP | `strictMcpConfig` | N/A | `boolean` | `false` | Enforce strict MCP validation |
| System prompt | `systemPrompt` | `system_prompt` | `string \| SystemPromptPreset` | `undefined` | System prompt config |
| Tools | `tools` | `tools` | `string[] \| ToolsPreset` | `undefined` | Tool configuration |
| User | N/A | `user` | `string` | `undefined` | User identifier |


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
  | SDKCompactBoundaryMessage;
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
| `modelUsage` | `{ [modelName: string]: ModelUsage }` | Per-model usage |
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
| `compact_metadata` (compact) | `{trigger, pre_tokens}` | Compaction info |


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
| `BashOutput` | Get background bash output |
| `KillBash` | Kill background bash process |
| `NotebookEdit` | Edit Jupyter notebooks |
| `ListMcpResources` | List MCP resources |
| `ReadMcpResource` | Read MCP resource |


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


### 8.4 BashOutput

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `bash_id` | `string` | Yes | Background shell ID |
| `filter` | `string` | No | Regex to filter output |


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


### 8.10 KillBash

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `shell_id` | `string` | Yes | Shell ID to kill |


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

---

## 9. Tool Output Schemas

### 9.1 Task Output

| Field | Type | Description |
|-------|------|-------------|
| `result` | `string` | Final result from subagent |
| `usage` | `object` | Token usage statistics |
| `total_cost_usd` | `number` | Total cost |
| `duration_ms` | `number` | Execution duration |


### 9.2 Bash Output

| Field | Type | Description |
|-------|------|-------------|
| `output` | `string` | Combined stdout/stderr |
| `exitCode` | `number` | Exit code |
| `killed` | `boolean` | Killed due to timeout |
| `shellId` | `string` | Background shell ID |


### 9.3 Edit Output

| Field | Type | Description |
|-------|------|-------------|
| `message` | `string` | Confirmation |
| `replacements` | `number` | Number of replacements |
| `file_path` | `string` | Edited file path |


### 9.4 Read Output (Text)

| Field | Type | Description |
|-------|------|-------------|
| `content` | `string` | File contents with line numbers |
| `total_lines` | `number` | Total lines in file |
| `lines_returned` | `number` | Lines returned |


### 9.5 Read Output (Image)

| Field | Type | Description |
|-------|------|-------------|
| `image` | `string` | Base64 encoded data |
| `mime_type` | `string` | Image MIME type |
| `file_size` | `number` | File size in bytes |


### 9.6 Write Output

| Field | Type | Description |
|-------|------|-------------|
| `message` | `string` | Success message |
| `bytes_written` | `number` | Bytes written |
| `file_path` | `string` | Written file path |


### 9.7 Glob Output

| Field | Type | Description |
|-------|------|-------------|
| `matches` | `string[]` | Matching file paths |
| `count` | `number` | Match count |
| `search_path` | `string` | Search directory |


### 9.8 Grep Output (content mode)

| Field | Type | Description |
|-------|------|-------------|
| `matches` | `Array<{file, line_number, line, context}>` | Matching lines |
| `total_matches` | `number` | Total match count |


### 9.9 Grep Output (files_with_matches mode)

| Field | Type | Description |
|-------|------|-------------|
| `files` | `string[]` | Files with matches |
| `count` | `number` | File count |


### 9.10 WebFetch Output

| Field | Type | Description |
|-------|------|-------------|
| `response` | `string` | AI analysis response |
| `url` | `string` | Fetched URL |
| `final_url` | `string` | Final URL after redirects |
| `status_code` | `number` | HTTP status |


### 9.11 WebSearch Output

| Field | Type | Description |
|-------|------|-------------|
| `results` | `Array<{title, url, snippet, metadata}>` | Search results |
| `total_results` | `number` | Total results |
| `query` | `string` | Search query |

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
| `PreToolUse` | `tool_name`, `tool_input` |
| `PostToolUse` | `tool_name`, `tool_input`, `tool_response` |
| `PostToolUseFailure` | `tool_name`, `tool_input`, `error`, `is_interrupt` |
| `UserPromptSubmit` | `prompt` |
| `Stop` | `stop_hook_active` |
| `SubagentStart` | `agent_id`, `agent_type` |
| `SubagentStop` | `stop_hook_active`, `agent_transcript_path` |
| `PreCompact` | `trigger`, `custom_instructions` |
| `PermissionRequest` | `tool_name`, `tool_input`, `permission_suggestions` |
| `SessionStart` | `source` |
| `SessionEnd` | `reason` |
| `Notification` | `message`, `notification_type`, `title` |


### 10.6 HookJSONOutput

| Field | Type | Description |
|-------|------|-------------|
| `continue` / `continue_` | `boolean` | Whether to continue (default: true) |
| `suppressOutput` | `boolean` | Hide stdout from transcript |
| `stopReason` | `string` | Message when continue is false |
| `decision` | `'approve' \| 'block'` | Decision shortcut |
| `systemMessage` | `string` | Message to inject |
| `reason` | `string` | Feedback for Claude |
| `hookSpecificOutput` | `object` | Hook-specific return data |


### 10.7 PreToolUse hookSpecificOutput

| Field | Type | Description |
|-------|------|-------------|
| `hookEventName` | `'PreToolUse'` | Event identifier |
| `permissionDecision` | `'allow' \| 'deny' \| 'ask'` | Permission decision |
| `permissionDecisionReason` | `string` | Explanation |
| `updatedInput` | `object` | Modified tool input |

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
| `status` | `'connected' \| 'failed' \| 'needs-auth' \| 'pending'` | Connection status |
| `serverInfo` | `{name, version}` | Server info (optional) |


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
| `model` | `'sonnet' \| 'opus' \| 'haiku' \| 'inherit'` | No | Model override |


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
| `network` | `NetworkSandboxSettings` | `undefined` | Network configuration |
| `ignoreViolations` | `SandboxIgnoreViolations` | `undefined` | Violations to ignore |
| `enableWeakerNestedSandbox` | `boolean` | `false` | Compatibility mode |


### 15.2 NetworkSandboxSettings

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allowLocalBinding` | `boolean` | `false` | Allow binding to local ports |
| `allowUnixSockets` | `string[]` | `[]` | Allowed Unix socket paths |
| `allowAllUnixSockets` | `boolean` | `false` | Allow all Unix sockets |
| `httpProxyPort` | `number` | `undefined` | HTTP proxy port |
| `socksProxyPort` | `number` | `undefined` | SOCKS proxy port |


### 15.3 SandboxIgnoreViolations

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
| `'context-1m-2025-08-07'` | 1 million token context window | Claude Sonnet 4, Claude Sonnet 4.5 |

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
| Interrupt | ✅ | ✅ |
| File checkpointing | ✅ | ✅ |
| All hook events | ✅ | Partial (no SessionStart/End/Notification) |
| Custom permission callback | ✅ | ✅ |
| MCP servers | ✅ | ✅ |
| Subagents | ✅ | ✅ |
| Sandbox configuration | ✅ | ✅ |
| Structured output | ✅ | ✅ |
| Plugins | ✅ | ✅ |
