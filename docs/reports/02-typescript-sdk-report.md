# TypeScript SDK Deep Dive Report

This document provides detailed analysis of the TypeScript SDK implementation, answering the questions from the prompt with code references and line numbers.

**Sources analyzed:**

- `vendor/claude-agent-sdk-typescript-pkg/sdk.mjs` (19115 lines, deminified)
- `vendor/claude-agent-sdk-typescript-pkg/sdk.d.ts` (1753 lines, type definitions)
- `vendor/claude-agent-sdk-typescript-pkg/sdk-tools.d.ts` (tool type definitions)

**Naming Convention:**

Names prefixed with `_x_` are **reconstructed** based on code behavior analysis. The original names were lost during minification. Names without the prefix are **verified** from exports or type definitions.

| Verified | Reconstructed |
|----------|---------------|
| `query()` | `_x_ProcessTransport` |
| `Query` (interface) | `_x_AsyncIterableQueue` |
| `SDKSession` (interface) | `_x_SdkMcpTransport` |
| `Transport` (interface) | |
| `tool()` | |
| `createSdkMcpServer()` | |

---

## 1. Query Lifecycle

The query lifecycle traces from `query()` call to completion through several components.

### 1.1 Entry Point: `query()` function (lines 18961-19082)

```
query({ prompt, options }) → Query
```

**Step-by-step execution:**

1. **Parse options** (lines 18962-19017):
   - Extract `systemPrompt`, `settingSources`, `sandbox`
   - Resolve `pathToClaudeCodeExecutable` (defaults to `cli.js` in same directory)
   - Set environment variables (`CLAUDE_CODE_ENTRYPOINT: "sdk-ts"`)
   - Separate SDK MCP servers from external servers

2. **Create ProcessTransport** (lines 19026-19064, class `XX` at 7196-7515):
   - Build CLI arguments (flags like `--output-format stream-json`, `--input-format stream-json`, `--verbose`)
   - Spawn `claude` CLI subprocess using `child_process.spawn`
   - Set up stdin/stdout pipes

3. **Create Query handler** (lines 19065-19068, class `$X` at 7591-8021):
   - Initialize control protocol state (pending requests, MCP transports, hook callbacks)
   - Connect SDK MCP servers
   - Start reading messages in background

4. **Send initial message** (lines 19070-19081):
   - If prompt is a string: write single user message to stdin
   - If prompt is AsyncIterable: call `streamInput()` to stream messages

5. **Return Query** (line 19082):
   - Query is an AsyncGenerator yielding `SDKMessage` objects

### 1.2 Message Reading Loop (lines 7671-7703)

```javascript
async readMessages() {
  for await (let message of this.transport.readMessages()) {
    // Route by message type
    if (message.type === "control_response") {
      // Resolve pending SDK→CLI request
      let resolver = this.pendingControlResponses.get(message.response.request_id);
      if (resolver) resolver(message.response);
      continue;
    } else if (message.type === "control_request") {
      // Handle CLI→SDK request (permissions, hooks, MCP)
      this.handleControlRequest(message);
      continue;
    } else if (message.type === "control_cancel_request") {
      this.handleControlCancelRequest(message);
      continue;
    } else if (message.type === "keep_alive") {
      continue;  // Ignore heartbeats
    }

    // Regular messages go to output stream
    if (message.type === "result") {
      this.firstResultReceived = true;
      if (this.isSingleUserTurn) this.transport.endInput();
    }
    this.inputStream.enqueue(message);
  }
}
```

### 1.3 Query Completion

Query completes when:

1. **Result message received** (line 8105-8106): For streaming mode, `result` message signals completion
2. **Transport closes** (line 7698-7699): When CLI process exits, `inputStream.done()` is called
3. **Error occurs** (line 7700-7702): Errors propagate via `inputStream.error()`

---

## 2. Control Request Types

The bidirectional control protocol uses JSON lines over stdin/stdout.

### 2.1 Control Request Structure

```json
{
  "type": "control_request",
  "request_id": "<unique-id>",
  "request": {
    "subtype": "<request-type>",
    ...fields specific to request type
  }
}
```

### 2.2 SDK → CLI Request Types

| Subtype | Purpose | Source |
|---------|---------|--------|
| `initialize` | Register hooks, MCP servers, system prompt | lines 7788-7820 |
| `interrupt` | Stop current execution | line 7822-7824 |
| `set_permission_mode` | Change permission mode | lines 7825-7827 |
| `set_model` | Change AI model | lines 7828-7830 |
| `set_max_thinking_tokens` | Set thinking token limit | lines 7831-7836 |
| `rewind_files` | Restore files to previous state | lines 7837-7845 |
| `mcp_status` | Get MCP server status | lines 7881-7883 |
| `mcp_reconnect` | Reconnect an MCP server | lines 7875-7877 |
| `mcp_toggle` | Enable/disable MCP server | lines 7878-7880 |
| `mcp_set_servers` | Dynamically update MCP servers | lines 7884-7903 |
| `mcp_message` | Send MCP message from SDK server | lines 7986-7995 |

### 2.3 CLI → SDK Request Types

| Subtype | Purpose | Handler |
|---------|---------|---------|
| `can_use_tool` | Permission check before tool use | lines 7750-7762 |
| `hook_callback` | Invoke registered hook | lines 7763-7769 |
| `mcp_message` | Route MCP call to SDK server | lines 7770-7782 |

### 2.4 Control Response Structure

**Success:**
```json
{
  "type": "control_response",
  "response": {
    "subtype": "success",
    "request_id": "<matching-request-id>",
    "response": { ...result data }
  }
}
```

**Error:**
```json
{
  "type": "control_response",
  "response": {
    "subtype": "error",
    "request_id": "<matching-request-id>",
    "error": "<error message>",
    "pending_permission_requests": [...]  // Optional
  }
}
```

---

## 3. Dynamic MCP Management

### 3.1 setMcpServers() (lines 7884-7903)

Replaces the set of dynamically-added MCP servers.

```javascript
async setMcpServers(servers) {
  // 1. Separate SDK servers (in-process) from external servers
  let sdkServers = {};    // { name: McpServer instance }
  let cliServers = {};    // { name: config for CLI }

  for (let [name, config] of Object.entries(servers)) {
    if (config.type === "sdk" && "instance" in config) {
      sdkServers[name] = config.instance;
    } else {
      cliServers[name] = config;
    }
  }

  // 2. Disconnect removed SDK servers
  let currentSDK = new Set(this.sdkMcpServerInstances.keys());
  let newSDK = new Set(Object.keys(sdkServers));
  for (let name of currentSDK) {
    if (!newSDK.has(name)) await this.disconnectSdkMcpServer(name);
  }

  // 3. Connect new SDK servers
  for (let [name, instance] of Object.entries(sdkServers)) {
    if (!currentSDK.has(name)) this.connectSdkMcpServer(name, instance);
  }

  // 4. Send mcp_set_servers control request to CLI
  let cliConfig = {};
  for (let name of Object.keys(sdkServers)) {
    cliConfig[name] = { type: "sdk", name };  // Reference only, no instance
  }

  return await this.request({
    subtype: "mcp_set_servers",
    servers: { ...cliServers, ...cliConfig }
  });
}
```

### 3.2 reconnectMcpServer() (lines 7875-7877)

```javascript
async reconnectMcpServer(serverName) {
  await this.request({ subtype: "mcp_reconnect", serverName });
}
```

### 3.3 toggleMcpServer() (lines 7878-7880)

```javascript
async toggleMcpServer(serverName, enabled) {
  await this.request({ subtype: "mcp_toggle", serverName, enabled });
}
```

### 3.4 SDK MCP Server Connection (lines 7966-7976)

```javascript
connectSdkMcpServer(serverName, mcpServer) {
  // Create transport that routes through control protocol
  let transport = new K9((message) => this.sendMcpServerMessageToCli(serverName, message));

  this.sdkMcpTransports.set(serverName, transport);
  this.sdkMcpServerInstances.set(serverName, mcpServer);

  // MCP SDK pattern: connect server to transport
  mcpServer.connect(transport);
}
```

---

## 4. V2 Session API

The unstable V2 API provides a simpler interface for multi-turn conversations.

### 4.1 SDKSession class (lines 8024-8116, class `U9`)

```javascript
class U9 {
  closed = false;
  inputStream;      // Queue for outgoing messages
  query;            // Internal Query instance
  queryIterator;
  abortController;
  _sessionId = null;

  constructor(options) {
    // Resume existing session or start new
    if (options.resume) this._sessionId = options.resume;

    // Create message queue
    this.inputStream = new QX();  // AsyncIterableQueue

    // Create ProcessTransport with session options
    let transport = new XX({
      ...options,
      resume: options.resume
    });

    // Create Query handler (not single-turn)
    this.query = new $X(transport, false /*isSingleUserTurn*/, ...);

    // Start streaming from input queue
    this.query.streamInput(this.inputStream);
  }

  async send(message) {
    // Convert string to SDKUserMessage if needed
    let userMessage = typeof message === "string"
      ? { type: "user", session_id: "", message: { role: "user", content: [...] }, ... }
      : message;
    this.inputStream.enqueue(userMessage);
  }

  async *stream() {
    if (!this.queryIterator) {
      this.queryIterator = this.query[Symbol.asyncIterator]();
    }
    while (true) {
      let { value, done } = await this.queryIterator.next();
      if (done) return;

      // Capture session ID from init message
      if (value.type === "system" && value.subtype === "init") {
        this._sessionId = value.session_id;
      }

      yield value;
      if (value.type === "result") return;
    }
  }

  close() {
    this.closed = true;
    this.inputStream.done();
    this.abortController.abort();
  }
}
```

### 4.2 V2 API Functions (lines 19084-19104)

```javascript
// Create new session
function unstable_v2_createSession(options) {
  return new U9(options);
}

// Resume existing session
function unstable_v2_resumeSession(sessionId, options) {
  return new U9({ ...options, resume: sessionId });
}

// One-shot prompt (convenience)
async function unstable_v2_prompt(message, options) {
  await using session = unstable_v2_createSession(options);
  await session.send(message);
  for await (let msg of session.stream()) {
    if (msg.type === "result") return msg;
  }
  throw Error("Session ended without result message");
}
```

### 4.3 Key Differences from query()

| Feature | `query()` | `unstable_v2_createSession()` |
|---------|-----------|------------------------------|
| Input | String or AsyncIterable | Via `send()` method |
| Multi-turn | Manual via AsyncIterable | Built-in via `send()`/`stream()` |
| Session ID | Available in messages | Available as property |
| Cleanup | Manual abort | `Symbol.asyncDispose` support |
| Complexity | Lower-level | Higher-level convenience |

---

## 5. Transport Abstraction

### 5.1 Transport Interface (sdk.d.ts lines 1689-1713)

```typescript
interface Transport {
  // Write JSON line to CLI stdin
  write(data: string): void | Promise<void>;

  // Close connection and cleanup
  close(): void;

  // Check if ready
  isReady(): boolean;

  // Async generator of messages from CLI stdout
  readMessages(): AsyncGenerator<StdoutMessage, void, unknown>;

  // Signal end of input stream
  endInput(): void;
}
```

### 5.2 ProcessTransport Implementation (class `XX`, lines 7196-7515)

```javascript
class XX {
  options;
  process;           // ChildProcess
  processStdin;      // Writable stream
  processStdout;     // Readable stream
  abortController;
  ready = false;
  exitError;
  exitListeners = [];

  constructor(options) {
    this.options = options;
    this.abortController = options.abortController || new AbortController();
    this.initialize();
  }

  initialize() {
    // Build CLI arguments
    let args = [
      "--output-format", "stream-json",
      "--verbose",
      "--input-format", "stream-json"
    ];
    // ... add all options as args

    // Spawn process (or use custom spawner)
    if (this.options.spawnClaudeCodeProcess) {
      this.process = this.options.spawnClaudeCodeProcess(spawnOptions);
    } else {
      this.process = this.spawnLocalProcess(spawnOptions);
    }

    this.processStdin = this.process.stdin;
    this.processStdout = this.process.stdout;
  }

  write(data) {
    if (!this.ready) throw Error("Not ready");
    this.processStdin.write(data);
  }

  async *readMessages() {
    // Use readline to parse JSON lines from stdout
    let lines = readline.createInterface({ input: this.processStdout });
    for await (let line of lines) {
      if (line.trim()) {
        yield JSON.parse(line);
      }
    }
    await this.waitForExit();
  }

  endInput() {
    this.processStdin.end();
  }

  close() {
    this.processStdin?.end();
    if (this.process && !this.process.killed) {
      this.process.kill("SIGTERM");
      setTimeout(() => {
        if (!this.process.killed) this.process.kill("SIGKILL");
      }, 5000);
    }
  }
}
```

### 5.3 Custom Process Spawning

The SDK supports custom process spawning via `spawnClaudeCodeProcess` option:

```typescript
interface SpawnOptions {
  command: string;
  args: string[];
  cwd?: string;
  env: { [envVar: string]: string | undefined };
  signal: AbortSignal;
}

interface SpawnedProcess {
  stdin: Writable;
  stdout: Readable;
  readonly killed: boolean;
  readonly exitCode: number | null;
  kill(signal: NodeJS.Signals): boolean;
  on(event: 'exit' | 'error', listener: Function): void;
  once(event: 'exit' | 'error', listener: Function): void;
  off(event: 'exit' | 'error', listener: Function): void;
}
```

This allows running Claude in VMs, containers, or remote environments via SSH.

### 5.4 WebSocket Transport Feasibility

Yes, a WebSocket transport could be plugged in. Requirements:

1. Implement the `Transport` interface
2. Handle JSON line framing over WebSocket messages
3. Map `readMessages()` to receive WebSocket messages
4. Handle connection lifecycle (reconnect, heartbeat)

---

## 6. Hook Registration and Invocation

### 6.1 Hook Registration During Initialize (lines 7788-7820)

```javascript
async initialize() {
  let hookConfig;
  if (this.hooks) {
    hookConfig = {};
    for (let [eventName, matchers] of Object.entries(this.hooks)) {
      if (matchers.length > 0) {
        hookConfig[eventName] = matchers.map(matcher => {
          // Assign unique callback IDs to each hook function
          let callbackIds = [];
          for (let hookFn of matcher.hooks) {
            let callbackId = `hook_${this.nextCallbackId++}`;
            this.hookCallbacks.set(callbackId, hookFn);  // Store for later
            callbackIds.push(callbackId);
          }
          return {
            matcher: matcher.matcher,       // Optional tool name pattern
            hookCallbackIds: callbackIds,
            timeout: matcher.timeout
          };
        });
      }
    }
  }

  // Send to CLI
  let request = {
    subtype: "initialize",
    hooks: hookConfig,
    sdkMcpServers: Array.from(this.sdkMcpTransports.keys()),
    jsonSchema: this.jsonSchema,
    systemPrompt: this.initConfig?.systemPrompt,
    appendSystemPrompt: this.initConfig?.appendSystemPrompt,
    agents: this.initConfig?.agents
  };

  return (await this.request(request)).response;
}
```

### 6.2 Hook Invocation via Control Request (lines 7961-7965)

When CLI needs to invoke a hook:

```javascript
// CLI sends:
{
  "type": "control_request",
  "request_id": "req_42",
  "request": {
    "subtype": "hook_callback",
    "callback_id": "hook_0",
    "input": {
      "session_id": "...",
      "hook_event_name": "PreToolUse",
      "tool_name": "Bash",
      "tool_input": { "command": "ls -la" },
      ...
    },
    "tool_use_id": "toolu_123"
  }
}

// SDK handler:
handleHookCallbacks(callbackId, input, toolUseId, signal) {
  let hookFn = this.hookCallbacks.get(callbackId);
  if (!hookFn) throw Error(`No hook callback found for ID: ${callbackId}`);
  return hookFn(input, toolUseId, { signal });
}
```

### 6.3 Hook Events (sdk.d.ts lines 250-251)

```typescript
const HOOK_EVENTS = [
  "PreToolUse",           // Before tool execution
  "PostToolUse",          // After successful tool execution
  "PostToolUseFailure",   // After failed tool execution
  "Notification",         // User notification
  "UserPromptSubmit",     // User submits prompt
  "SessionStart",         // Session begins
  "SessionEnd",           // Session ends
  "Stop",                 // Agent stop
  "SubagentStart",        // Subagent spawned
  "SubagentStop",         // Subagent finished
  "PreCompact",           // Before context compaction
  "PermissionRequest",    // Permission prompt
  "Setup"                 // Initial setup
] as const;
```

### 6.4 Hook Output Structure

```typescript
type SyncHookJSONOutput = {
  continue?: boolean;           // Whether to proceed (default: true)
  suppressOutput?: boolean;     // Hide from transcript
  stopReason?: string;          // Message when continue=false
  decision?: 'approve' | 'block';
  systemMessage?: string;       // Warning for user
  reason?: string;              // Feedback for Claude
  hookSpecificOutput?: PreToolUseHookSpecificOutput | ...;
};

type PreToolUseHookSpecificOutput = {
  hookEventName: 'PreToolUse';
  permissionDecision?: 'allow' | 'deny' | 'ask';
  permissionDecisionReason?: string;
  updatedInput?: Record<string, unknown>;  // Modified tool input
  additionalContext?: string;
};
```

---

## 7. Error Handling

### 7.1 Process Spawn Errors (lines 7369-7376)

```javascript
this.process.on("error", (error) => {
  this.ready = false;
  if (this.abortController.signal.aborted) {
    this.exitError = new AbortError("Claude Code process aborted by user");
  } else {
    this.exitError = Error(`Failed to spawn Claude Code process: ${error.message}`);
  }
});
```

### 7.2 Process Exit Errors (lines 7378-7384)

```javascript
this.process.on("exit", (code, signal) => {
  this.ready = false;
  if (this.abortController.signal.aborted) {
    this.exitError = new AbortError("Claude Code process aborted by user");
  } else {
    let error = this.getProcessExitError(code, signal);
    if (error) this.exitError = error;
  }
});

getProcessExitError(code, signal) {
  if (code !== 0 && code !== null) {
    return Error(`Claude Code process exited with code ${code}`);
  } else if (signal) {
    return Error(`Claude Code process terminated by signal ${signal}`);
  }
  return undefined;
}
```

### 7.3 Control Request Timeouts

Control requests use Promise-based correlation but don't have explicit timeouts. The abort signal can cancel pending requests:

```javascript
async processControlRequest(request, signal) {
  // signal is passed to callbacks for cancellation
  if (request.request.subtype === "can_use_tool") {
    return await this.canUseTool(toolName, input, { signal, ... });
  }
}
```

### 7.4 Stream Error Propagation (lines 7700-7702)

```javascript
} catch (error) {
  this.inputStream.error(error);  // Propagate to consumer
  this.cleanup(error);
}
```

### 7.5 Cleanup on Error (lines 7639-7654)

```javascript
cleanup(error) {
  if (this.cleanupPerformed) return;
  this.cleanupPerformed = true;

  this.transport.close();
  this.pendingControlResponses.clear();
  this.pendingMcpResponses.clear();
  this.cancelControllers.clear();
  this.hookCallbacks.clear();

  // Close all SDK MCP transports
  for (let transport of this.sdkMcpTransports.values()) {
    transport.close();
  }
  this.sdkMcpTransports.clear();

  if (error) {
    this.inputStream.error(error);
  } else {
    this.inputStream.done();
  }
}
```

---

## 8. All Options

Complete catalog of the `Options` type with CLI mappings.

### 8.1 Core Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `abortController` | AbortController | - | Cancel query |
| `cwd` | string | - | Working directory (env CWD) |
| `env` | Record<string, string> | - | Environment variables |
| `pathToClaudeCodeExecutable` | string | - | Path to `claude` binary |
| `executable` | 'node'\|'bun'\|'deno' | - | JS runtime |
| `executableArgs` | string[] | - | Runtime arguments |
| `extraArgs` | Record<string, string\|null> | `--{key} {value}` | Additional CLI args |

### 8.2 Model Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `model` | string | `--model` | Primary AI model |
| `fallbackModel` | string | `--fallback-model` | Fallback if primary fails |
| `maxThinkingTokens` | number | `--max-thinking-tokens` | Thinking token limit |

### 8.3 Session Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `continue` | boolean | `--continue` | Continue most recent session |
| `resume` | string | `--resume` | Resume specific session ID |
| `resumeSessionAt` | string | `--resume-session-at` | Resume to specific message |
| `forkSession` | boolean | `--fork-session` | Fork resumed session |
| `persistSession` | boolean | `--no-session-persistence` | Disable session persistence |

### 8.4 Tool Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `tools` | string[]\|{preset} | `--tools` | Specify available tools |
| `allowedTools` | string[] | `--allowedTools` | Auto-allow these tools |
| `disallowedTools` | string[] | `--disallowedTools` | Block these tools |

### 8.5 Permission Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `permissionMode` | PermissionMode | `--permission-mode` | Permission behavior |
| `allowDangerouslySkipPermissions` | boolean | `--allow-dangerously-skip-permissions` | Enable bypass mode |
| `permissionPromptToolName` | string | `--permission-prompt-tool` | MCP tool for prompts |
| `canUseTool` | CanUseTool | `--permission-prompt-tool stdio` | Custom handler |

### 8.6 MCP Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `mcpServers` | Record<string, McpServerConfig> | `--mcp-config` | MCP server configs |
| `strictMcpConfig` | boolean | `--strict-mcp-config` | Enforce valid configs |

### 8.7 Hooks & Callbacks

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `hooks` | Record<HookEvent, HookCallbackMatcher[]> | - | In-process hooks |
| `stderr` | (data: string) => void | - | Stderr callback |

### 8.8 Output Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `outputFormat` | { type: 'json_schema', schema } | `--json-schema` | Structured output |
| `includePartialMessages` | boolean | `--include-partial-messages` | Stream partial messages |

### 8.9 Execution Control

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `maxTurns` | number | `--max-turns` | Max conversation turns |
| `maxBudgetUsd` | number | `--max-budget-usd` | Max cost in USD |
| `enableFileCheckpointing` | boolean | env var | Enable file rewind |

### 8.10 Advanced Options

| Option | Type | CLI Flag | Purpose |
|--------|------|----------|---------|
| `systemPrompt` | string\|{preset} | - | Custom system prompt |
| `agents` | Record<string, AgentDefinition> | - | Custom subagents |
| `agent` | string | `--agent` | Main thread agent |
| `betas` | SdkBeta[] | `--betas` | Beta features |
| `additionalDirectories` | string[] | `--add-dir` | Additional directories |
| `plugins` | SdkPluginConfig[] | `--plugin-dir` | Load plugins |
| `sandbox` | SandboxSettings | - | Sandbox configuration |
| `settingSources` | SettingSource[] | `--setting-sources` | Settings to load |

---

## Key Classes Reference

| Minified | Name | Purpose | Lines |
|----------|------|---------|-------|
| `XX` | _x_ProcessTransport | Subprocess management, implements `Transport` | 7196-7515 |
| `QX` | _x_AsyncIterableQueue | Message streaming buffer | 7520-7570 |
| `K9` | _x_SdkMcpTransport | Routes MCP through control protocol | 7571-7589 |
| `$X` | Query (impl) | Main query handler, implements `Query` interface | 7591-8021 |
| `U9` | SDKSession (impl) | V2 session API, implements `SDKSession` interface | 8024-8116 |
| `J7` | _x_McpServer | MCP server wrapper (bundled from MCP SDK) | ~18000+ |

Names prefixed with `_x_` are reconstructed based on behavior analysis.

---

## Summary

The TypeScript SDK is a well-architected wrapper around the Claude CLI that:

1. **Spawns CLI as subprocess** with JSON line protocol
2. **Uses bidirectional control protocol** for hooks, permissions, and SDK MCP
3. **Routes SDK MCP calls** through control requests to in-process servers
4. **Supports Transport abstraction** for future WebSocket/remote use
5. **Provides V2 Session API** for simpler multi-turn conversations

The key insight for Swift implementation: focus on the control protocol and MCP routing. The Process/Transport abstraction makes the core logic transport-agnostic.
