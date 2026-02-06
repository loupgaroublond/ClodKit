# Claude Code CLI Internals Analysis

This document analyzes the Claude Code CLI internals based on the deminified `cli.js` file (580K lines, 11.6MB). The analysis focuses on authentication, backend API communication, control protocol, SDK MCP routing, and session management.

**Source**: `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/cli.js`

---

## Notation Legend

**Reconstructed Names**: Names marked with `*` are inferred/reconstructed from behavior analysis, similar to how Proto-Indo-European uses asterisks for reconstructed words. The actual minified names are preserved in the code.

| Minified | *Reconstructed | Confidence | Evidence |
|----------|----------------|------------|----------|
| `H8` | *getConfigDir | High | Returns `~/.claude` path |
| `Dz` | *AnthropicClient | High | Has `apiKey`, `authToken`, `baseURL`, makes `/v1/messages` calls |
| `jR4` | *exchangeCodeForTokens | High | OAuth token exchange with `grant_type: "authorization_code"` |
| `s56` | *refreshAccessToken | High | OAuth refresh with `grant_type: "refresh_token"` |
| `q0K` | *SessionWriter | High | Has `sessionFile`, `insertMessageChain`, writes JSONL |
| `KlA` | *StreamInputHandler | High | Reads stdin, parses JSON lines, correlates control_request/response |
| `yKz` | *handleInitializeRequest | High | Handles `subtype: "initialize"` control request |
| `$W7` | *isLocalMcpServer | High | Returns true for `stdio` or `sdk` type servers |
| `mj6` | *plaintextCredentialStorage | High | Has `read()`, `update()`, writes to `.credentials.json` |
| `jf` | *getCredentialStorage | High | Returns Keychain on darwin, plaintext otherwise |
| `X9A` | *getProjectsDir | High | Returns `~/.claude/projects` |
| `P_` | *getSessionFilePath | High | Returns `<project-hash>/<session-id>.jsonl` |
| `AB` | *getSubagentSessionFilePath | High | Returns `<session>/subagents/agent-<id>.jsonl` |
| `F1` | *getCurrentSessionId | Medium | Used to get session ID in path functions |
| `SJ` | *getHashedProjectDir | Medium | Takes project path, returns hashed directory |
| `Ke` | *currentProjectPath | Medium | Global variable used with `SJ` |
| `UC` | *getMcpClient | Medium | Memoized MCP client factory with `.cache` |
| `t6` | *axios | Medium | HTTP client with `.post()`, `.get()` methods |
| `C7` | *getOAuthConfig | Medium | Returns OAuth URLs (TOKEN_URL, etc.) |
| `JkA` | *getEnvVar | Medium | Reads environment variables |
| `QA` | *jsonStringify | Medium | Used for JSON serialization |
| `X6` | *jsonParse | Medium | Used for JSON parsing |
| `v7` | *zod | Medium | Schema validation with `.object()`, `.string()`, `.literal()` |
| `Iv` | *pathJoin | Medium | Used like `path.join()` |

**Confidence levels**:
- **High**: Multiple strong indicators (method names, usage patterns, string literals)
- **Medium**: Usage patterns suggest purpose, but fewer confirming indicators

---

## 1. Authentication

### 1.1 OAuth 2.0 Flow with PKCE

The CLI uses OAuth 2.0 with PKCE (Proof Key for Code Exchange) for authentication with Claude.ai accounts.

**OAuth Configuration** (lines 27570-27605):

```javascript
// Production OAuth configuration (jY8 object)
{
  BASE_API_URL: "https://api.anthropic.com",
  CONSOLE_AUTHORIZE_URL: "https://platform.claude.com/oauth/authorize",
  CLAUDE_AI_AUTHORIZE_URL: "https://claude.ai/oauth/authorize",
  TOKEN_URL: "https://platform.claude.com/v1/oauth/token",
  API_KEY_URL: "https://api.anthropic.com/api/oauth/claude_cli/create_api_key",
  ROLES_URL: "https://api.anthropic.com/api/oauth/claude_cli/roles",
  CLIENT_ID: "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
  MCP_PROXY_URL: "https://mcp-proxy.anthropic.com",
  MCP_PROXY_PATH: "/v1/mcp/{server_id}",
}
```

**OAuth Scopes** (lines 27551-27568):

```javascript
// Required scopes for OAuth
[
  "user:profile",
  "user:inference",           // For making API calls
  "user:sessions:claude_code", // For session management
  "user:mcp_servers",         // For MCP server access
  "org:create_api_key"        // For API key creation (console)
]
```

### 1.2 Token Exchange

**Token Exchange Function** (lines 192601-192622):

```javascript
// jR4 function - exchanges authorization code for tokens
async function jR4(code, state, codeVerifier, port, isManual = false, expiresIn) {
  let params = {
    grant_type: "authorization_code",
    code: code,
    redirect_uri: isManual
      ? "https://platform.claude.com/oauth/code/callback"
      : `http://localhost:${port}/callback`,
    client_id: CLIENT_ID,
    code_verifier: codeVerifier,
    state: state,
  };
  if (expiresIn !== undefined) params.expires_in = expiresIn;

  let response = await axios.post(TOKEN_URL, params, {
    headers: { "Content-Type": "application/json" },
  });
  return response.data; // { access_token, refresh_token, expires_in, scope }
}
```

**Token Refresh** (lines 192624-192665):

```javascript
// s56 function - refreshes expired access token
async function s56(refreshToken) {
  let params = {
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    client_id: CLIENT_ID,
    scope: scopes.join(" "),
  };

  let response = await axios.post(TOKEN_URL, params, {
    headers: { "Content-Type": "application/json" },
  });

  let { access_token, refresh_token = refreshToken, expires_in } = response.data;
  let expiresAt = Date.now() + expires_in * 1000;

  return {
    accessToken: access_token,
    refreshToken: refresh_token,
    expiresAt: expiresAt,
    // ... scopes, subscriptionType, rateLimitTier
  };
}
```

### 1.3 Credential Storage

**Config Directory** (line 2631-2632):

```javascript
function H8() {
  return process.env.CLAUDE_CONFIG_DIR ?? path.join(homedir(), ".claude");
}
```

**Storage Backend Selection** (lines 304288-304291):

```javascript
function jf() {
  // macOS uses Keychain, others use plaintext
  if (process.platform === "darwin") return fG7(NG7, mj6); // Keychain with fallback
  return mj6; // Plaintext storage
}
```

**macOS Keychain Storage** (lines 304200-304232):

```javascript
// Uses `security` command to store in macOS Keychain
// Service name: "claude-code-credentials" (with environment suffix)
// Account: current username
// Data: hex-encoded JSON credentials
{
  update(credentials) {
    let serviceName = getServiceName("-credentials");
    let username = getCurrentUser();
    let hexData = Buffer.from(JSON.stringify(credentials), "utf-8").toString("hex");
    let command = `add-generic-password -U -a "${username}" -s "${serviceName}" -X "${hexData}"`;
    execSync("security", ["-i"], { input: command });
  }
}
```

**Plaintext Storage** (lines 304247-304286):

```javascript
// Stores at ~/.claude/.credentials.json with chmod 600
{
  update(credentials) {
    let { storageDir, storagePath } = Bj6(); // ~/.claude, ~/.claude/.credentials.json
    if (!fs.existsSync(storageDir)) fs.mkdirSync(storageDir);
    fs.writeFileSync(storagePath, JSON.stringify(credentials), { encoding: "utf8" });
    fs.chmodSync(storagePath, 0o600); // 384 decimal = 0600 octal
    return { success: true, warning: "Warning: Storing credentials in plaintext." };
  }
}
```

### 1.4 API Key vs OAuth Token

The CLI supports two authentication methods (lines 93140-93217):

```javascript
class Dz { // Anthropic API Client
  constructor({
    baseURL = process.env.ANTHROPIC_BASE_URL,
    apiKey = process.env.ANTHROPIC_API_KEY ?? null,
    authToken = process.env.ANTHROPIC_AUTH_TOKEN ?? null,
  }) {
    this.baseURL = baseURL || "https://api.anthropic.com";
    this.apiKey = apiKey;
    this.authToken = authToken;
  }

  async authHeaders() {
    return merge([
      await this.apiKeyAuth(),   // X-Api-Key header
      await this.bearerAuth()    // Authorization: Bearer header
    ]);
  }

  async apiKeyAuth() {
    if (this.apiKey == null) return;
    return { "X-Api-Key": this.apiKey };
  }

  async bearerAuth() {
    if (this.authToken == null) return;
    return { Authorization: `Bearer ${this.authToken}` };
  }
}
```

---

## 2. Backend API

### 2.1 Endpoints

All API communication goes to `https://api.anthropic.com`:

| Purpose | Endpoint | Method |
|---------|----------|--------|
| Messages | `/v1/messages` | POST |
| Token counting | `/v1/messages/count_tokens` | POST |
| Batches | `/v1/messages/batches` | POST/GET/DELETE |
| OAuth roles | `/api/oauth/claude_cli/roles` | GET |
| API key creation | `/api/oauth/claude_cli/create_api_key` | POST |
| Metrics | `/api/claude_code/metrics` | POST |
| Organization metrics | `/api/claude_code/organizations/metrics_enabled` | GET |
| Feedback | `/api/claude_cli_feedback` | POST |
| Domain info | `/api/web/domain_info` | GET |
| Health check | `/api/hello` | HEAD/GET |

### 2.2 Message Creation

**Main API Call** (lines 93060-93071, 264759):

```javascript
// Beta messages.create call with extended thinking
await client.beta.messages.create({
  model: modelId,
  max_tokens: maxTokens,
  messages: conversationMessages,
  system: systemPrompt,
  tools: availableTools,
  // Extended thinking parameters
  thinking: { type: "enabled", budget_tokens: thinkingBudget },
});
```

**API Headers** (line 93546-93548):

```javascript
{
  "anthropic-version": "2023-06-01",
  "anthropic-dangerous-direct-browser-access": "true", // Only when allowed
}
```

**Beta Features** (lines 527697-527702):

```javascript
// anthropic_beta header management
if (body.anthropic_beta && Array.isArray(body.anthropic_beta)) {
  let existing = body.anthropic_beta;
  let betaFeatures = getBetaFeatures(); // e.g., ["extended-thinking-2025-01-24"]
  body.anthropic_beta = [...existing, ...betaFeatures];
}
```

### 2.3 Streaming

The CLI uses streaming for real-time responses:

```javascript
// Beta messages.stream for streaming responses
client.beta.messages.stream({
  model: modelId,
  max_tokens: maxTokens,
  messages: conversationMessages,
  // ... other params
});
```

---

## 3. Control Protocol

### 3.1 Overview

The control protocol enables bidirectional communication between the CLI and SDK over stdin/stdout using JSON lines.

**Message Types** (lines 557436-557443):

```javascript
const controlMessageTypes = [
  "control_request",
  "control_response",
  "control_cancel_request",
];

function isRegularMessage(msg) {
  return msg.type !== "control_request" && msg.type !== "control_response";
}
```

### 3.2 Control Request Structure

**SDK → CLI** (line 572051):

```javascript
// sendRequest function builds control requests
{
  type: "control_request",
  request_id: generateUUID(),
  request: {
    subtype: "<request_type>",
    // ... request-specific fields
  }
}
```

**CLI → SDK** (same structure, different subtypes)

### 3.3 Control Response Structure

**Success Response** (lines 573703-573710):

```javascript
{
  type: "control_response",
  response: {
    subtype: "success",
    request_id: originalRequestId,
    response: { /* result data */ }
  }
}
```

**Error Response** (lines 573712-573716):

```javascript
{
  type: "control_response",
  response: {
    subtype: "error",
    request_id: originalRequestId,
    error: "Error message"
  }
}
```

### 3.4 Control Request Types

**SDK → CLI:**

| Subtype | Purpose | Key Fields | Response |
|---------|---------|------------|----------|
| `initialize` | Start control protocol | `hooks`, `sdkMcpServers`, `agents`, `systemPrompt` | `commands`, `models`, `account` |
| `interrupt` | Abort current operation | (none) | (empty) |
| `set_permission_mode` | Change permissions | `mode` | `mode` |
| `set_model` | Change AI model | `model` | (empty) |
| `set_max_thinking_tokens` | Set thinking budget | `max_thinking_tokens` | (empty) |
| `mcp_status` | Get MCP server status | (none) | `mcpServers[]` |
| `mcp_set_servers` | Update MCP servers | `servers` | `added`, `removed`, `errors` |
| `mcp_reconnect` | Reconnect MCP server | `serverName` | (empty) |
| `mcp_toggle` | Enable/disable server | `serverName`, `enabled` | (empty) |
| `rewind_files` | Restore files | `user_message_id`, `dry_run` | `canRewind`, `filesChanged` |

**CLI → SDK:**

| Subtype | Purpose | Key Fields | Expected Response |
|---------|---------|------------|-------------------|
| `can_use_tool` | Permission check | `tool_name`, `input`, `permission_suggestions`, `tool_use_id` | `behavior`, `updatedInput`, `message` |
| `hook_callback` | Invoke hook | `callback_id`, `input`, `tool_use_id` | Hook-specific output |
| `mcp_message` | SDK MCP call | `server_name`, `message` (JSONRPC) | `mcp_response` (JSONRPC) |

### 3.5 CLI Control Protocol Handler

**Main Processing Loop** (lines 573730-573944):

```javascript
// Processes incoming messages from SDK
for await (let msg of streamInput.structuredInput) {
  if (msg.type === "control_request") {
    switch (msg.request.subtype) {
      case "interrupt":
        if (abortController) abortController.abort();
        sendSuccess(msg);
        break;

      case "initialize":
        // Register SDK MCP servers
        if (msg.request.sdkMcpServers?.length > 0) {
          for (let name of msg.request.sdkMcpServers) {
            mcpServers[name] = { type: "sdk", name: name };
          }
        }
        // Setup hooks, agents, system prompt
        await handleInitialize(msg.request, msg.request_id, ...);
        break;

      case "set_permission_mode":
        updatePermissionMode(msg.request.mode);
        sendSuccess(msg);
        break;

      case "mcp_message":
        // Route to SDK MCP server (via control protocol back to SDK)
        let server = sdkClients.find(s => s.name === msg.request.server_name);
        if (server?.client?.transport?.onmessage) {
          server.client.transport.onmessage(msg.request.message);
        }
        sendSuccess(msg);
        break;

      // ... other subtypes
    }
  }
}
```

### 3.6 Initialize Response

**Response Format** (lines 574111-574147):

```javascript
// yKz function sends initialize response
{
  type: "control_response",
  response: {
    subtype: "success",
    request_id: requestId,
    response: {
      commands: availableCommands.map(cmd => ({
        name: cmd.userFacingName(),
        description: getDescription(cmd),
        argumentHint: cmd.argumentHint || "",
      })),
      output_style: currentOutputStyle,
      available_output_styles: Object.keys(outputStyles),
      models: availableModels,
      account: {
        email: accountInfo?.email,
        organization: accountInfo?.organization,
        subscriptionType: accountInfo?.subscription,
        tokenSource: accountInfo?.tokenSource,
        apiKeySource: accountInfo?.apiKeySource,
      },
    },
  },
}
```

---

## 4. SDK MCP Routing

### 4.1 Server Type Detection

**Type Check** (line 306353):

```javascript
// SDK servers have type: "sdk"
function $W7(config) {
  return !config.type || config.type === "stdio" || config.type === "sdk";
}
```

**SDK Server Handling** (lines 306962-306963, 306370):

```javascript
// In MCP client creation function UC
if (config.type === "sdk") {
  throw Error("SDK servers should be handled in print.ts");
}

// In reconnection handling
async function hGA(client) {
  if (client.config.type === "sdk") return client; // Return as-is, no connection
  // ... connect to external server
}
```

### 4.2 SDK Server Registration

**During Initialize** (lines 573736-573738):

```javascript
// When SDK sends initialize with sdkMcpServers
if (msg.request.sdkMcpServers && msg.request.sdkMcpServers.length > 0) {
  for (let serverName of msg.request.sdkMcpServers) {
    mcpServerConfigs[serverName] = { type: "sdk", name: serverName };
  }
}
```

**Dynamic Server Updates** (lines 574361-574398):

```javascript
// xKz function handles mcp_set_servers
async function xKz(newServers, currentState, dynamicState, setAppState) {
  let sdkServers = {};
  let otherServers = {};

  // Separate SDK servers from external servers
  for (let [name, config] of Object.entries(newServers)) {
    if (config.type === "sdk") {
      sdkServers[name] = config;
    } else {
      otherServers[name] = config;
    }
  }

  // Track added/removed SDK servers
  let currentSdkNames = new Set(Object.keys(currentState.configs));
  let newSdkNames = new Set(Object.keys(sdkServers));

  let added = [];
  let removed = [];

  // Remove servers no longer in SDK
  for (let name of currentSdkNames) {
    if (!newSdkNames.has(name)) {
      removed.push(name);
      // Cleanup if connected
    }
  }

  // Add new SDK servers
  for (let [name, config] of Object.entries(sdkServers)) {
    if (!currentSdkNames.has(name)) {
      added.push(name);
      // Create pending client
    }
  }

  return {
    response: { added, removed, errors },
    sdkServersChanged: added.length > 0 || removed.length > 0,
  };
}
```

### 4.3 MCP Message Routing Flow

When Claude wants to use an SDK MCP tool:

1. **CLI detects SDK server** - Tool name has `mcp__<server>__` prefix
2. **CLI sends mcp_message to SDK** via control protocol:

```javascript
// From SDK perspective, CLI sends this control_request
{
  type: "control_request",
  request_id: "req_xyz",
  request: {
    subtype: "mcp_message",
    server_name: "my-sdk-server",
    message: {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: "my_tool", arguments: { param1: "value" } }
    }
  }
}
```

3. **SDK processes and responds**:

```javascript
// SDK sends back
{
  type: "control_response",
  response: {
    subtype: "success",
    request_id: "req_xyz",
    response: {
      mcp_response: {
        jsonrpc: "2.0",
        id: 1,
        result: { content: [{ type: "text", text: "Tool result" }] }
      }
    }
  }
}
```

4. **CLI receives message in SDK server transport** (lines 573814-573823):

```javascript
} else if (msg.request.subtype === "mcp_message") {
  let request = msg.request;
  let server = sdkClients.find(s => s.name === request.server_name);
  if (server?.type === "connected" && server.client?.transport?.onmessage) {
    // Deliver JSONRPC message to MCP server transport
    server.client.transport.onmessage(request.message);
  }
  sendSuccess(msg);
}
```

---

## 5. Session Management

### 5.1 Session File Paths

**Project Directory** (lines 468432-468433):

```javascript
function X9A() {
  return path.join(H8(), "projects"); // ~/.claude/projects
}
```

**Session File Path** (lines 468440-468442):

```javascript
function P_(sessionId) {
  let projectDir = SJ(currentProjectPath); // Hashed project path
  return path.join(projectDir, `${sessionId}.jsonl`);
}
// Result: ~/.claude/projects/<project-hash>/<session-id>.jsonl
```

**Subagent Session Path** (lines 468444-468447):

```javascript
function AB(agentId) {
  let projectDir = SJ(currentProjectPath);
  let sessionId = F1(); // Current session ID
  return path.join(projectDir, sessionId, "subagents", `agent-${agentId}.jsonl`);
}
// Result: ~/.claude/projects/<project-hash>/<session-id>/subagents/agent-<agent-id>.jsonl
```

### 5.2 Session Entry Format

**Message Entry Structure** (lines 468560-468576):

```javascript
let entry = {
  parentUuid: isFirst ? null : previousUuid,      // Links to parent message
  logicalParentUuid: isLogical ? previousUuid : undefined,
  isSidechain: isSidechain,                       // For branching conversations
  teamName: context?.teamName,
  agentName: context?.agentName,
  userType: "external",                           // or "internal"
  cwd: getCurrentWorkingDir(),
  sessionId: sessionId,
  version: sessionVersion,                        // e.g., "1.0.0"
  gitBranch: currentGitBranch,
  agentId: agentId,
  slug: projectSlug,
  ...messageData,                                 // type, message, uuid, etc.
};

await this.appendEntry(entry);
```

### 5.3 Session Writer

**SessionWriter Class** (lines 468481-468578):

```javascript
class q0K { // SessionWriter
  sessionFile = null;
  remoteIngressUrl = null;
  pendingWriteCount = 0;
  flushResolvers = [];

  async insertMessageChain(messages, isSidechain = false, agentId, previousUuid, context) {
    return this.trackWrite(async () => {
      let parentUuid = previousUuid ?? null;
      let gitBranch = await getGitBranch();
      let sessionId = F1();
      let slug = projectSlugs.get(sessionId);

      for (let message of messages) {
        let isFirst = isFirstMessage(message);
        let parent = isFirst ? null : parentUuid;

        let entry = {
          parentUuid: parent,
          isSidechain: isSidechain,
          userType: "external",
          cwd: getCurrentDir(),
          sessionId: sessionId,
          version: sessionVersion,
          gitBranch: gitBranch,
          agentId: agentId,
          slug: slug,
          ...message,
        };

        await this.appendEntry(entry);
        parentUuid = message.uuid;
      }
    });
  }

  async removeMessageByUuid(uuid) {
    // Reads file, filters out message with uuid, rewrites file
    let lines = (await fs.readFile(this.sessionFile, "utf-8"))
      .split("\n")
      .filter(line => {
        if (!line.trim()) return true;
        try {
          return JSON.parse(line).uuid !== uuid;
        } catch {
          return true;
        }
      });
    await fs.writeFile(this.sessionFile, lines.join("\n"), "utf8");
  }

  async flush() {
    // Wait for all pending writes to complete
    if (this.pendingWriteCount === 0) return;
    return new Promise(resolve => {
      this.flushResolvers.push(resolve);
    });
  }
}
```

### 5.4 History File

**Command History** (lines 185675, 185731):

```javascript
// History file location
let historyFile = path.join(H8(), "history.jsonl"); // ~/.claude/history.jsonl

// Reading history
let historyPath = path.join(H8(), "history.jsonl");
```

---

## 6. Key Implementation Insights for Swift SDK

### 6.1 Authentication Implementation

For Swift SDK, implement:

1. **OAuth PKCE Flow**:
   - Generate code_verifier (43-128 char random string)
   - Generate code_challenge = base64url(sha256(code_verifier))
   - Open browser to authorize URL with challenge
   - Start local HTTP server to catch callback
   - Exchange code for tokens at TOKEN_URL

2. **Token Storage**:
   - Use Keychain Services on macOS
   - Store refresh_token and access_token
   - Track expiry time

3. **Token Refresh**:
   - Check expiry before API calls
   - Refresh proactively when near expiry

### 6.2 Control Protocol Implementation

```swift
// Message types
enum ControlMessageType: String, Codable {
    case control_request
    case control_response
    case control_cancel_request
}

// Request structure
struct ControlRequest: Codable {
    let type = "control_request"
    let request_id: String
    let request: RequestPayload
}

// Subtypes to implement
enum RequestSubtype: String {
    // SDK → CLI
    case initialize
    case interrupt
    case set_permission_mode
    case set_model
    case mcp_status
    case rewind_files
    case mcp_set_servers
    case mcp_reconnect
    case mcp_toggle

    // CLI → SDK
    case can_use_tool
    case hook_callback
    case mcp_message
}
```

### 6.3 MCP Server Routing

The key insight for SDK MCP servers:

1. **Pass server names during initialize**:
   ```json
   { "subtype": "initialize", "sdkMcpServers": ["my-tools"] }
   ```

2. **Handle mcp_message requests**:
   - Receive JSONRPC message from CLI
   - Route to appropriate in-process MCP server
   - Return JSONRPC response

3. **Tool name format**: `mcp__<server-name>__<tool-name>`

### 6.4 Session File Format

JSONL with one JSON object per line:

```json
{"uuid":"abc123","type":"user","message":{"role":"user","content":"Hello"},"parentUuid":null,"sessionId":"sess_xyz","cwd":"/path","version":"1.0.0"}
{"uuid":"def456","type":"assistant","message":{"role":"assistant","content":[...]},"parentUuid":"abc123","sessionId":"sess_xyz"}
```

---

## 7. Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_CONFIG_DIR` | Override ~/.claude directory |
| `ANTHROPIC_BASE_URL` | Override API base URL |
| `ANTHROPIC_API_KEY` | Direct API key auth |
| `ANTHROPIC_AUTH_TOKEN` | Bearer token auth |
| `CLAUDE_CODE_OAUTH_CLIENT_ID` | Override OAuth client ID |
| `CLAUDE_CODE_ENTRYPOINT` | SDK identifier (e.g., "sdk-py") |
| `CLAUDE_AGENT_SDK_VERSION` | SDK version for telemetry |
| `CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING` | Enable file checkpointing |
| `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR` | Maintain working directory |

---

## 8. References

- **OAuth endpoints**: lines 27570-27605
- **Anthropic client**: lines 93140-93289
- **Control protocol handler**: lines 571990-572143
- **CLI control loop**: lines 573700-573944
- **Initialize handler**: lines 574062-574148
- **SDK MCP routing**: lines 574361-574482
- **Session writer**: lines 468481-468578
- **Credential storage**: lines 304200-304291
