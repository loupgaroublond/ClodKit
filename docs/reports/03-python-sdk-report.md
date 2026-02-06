# Python SDK Deep Dive Report

This report provides a comprehensive analysis of the Python Claude Agent SDK implementation, answering all questions from the task prompt with detailed code references.

---

## 1. Code Organization: Public vs Internal

### 1.1 Package Structure

```
src/claude_agent_sdk/
├── __init__.py              # Public exports (366 lines)
├── client.py                # Public ClaudeSDKClient (404 lines)
├── query.py                 # Public query() function (127 lines)
├── types.py                 # Public type definitions (756 lines)
├── _errors.py               # Public error types (57 lines)
├── _version.py              # Version info
└── _internal/
    ├── client.py            # InternalClient (125 lines)
    ├── message_parser.py    # Message parsing (181 lines)
    ├── query.py             # Query class with control protocol (626 lines)
    └── transport/
        ├── __init__.py      # Transport protocol
        └── subprocess_cli.py # CLI subprocess (673 lines)
```

### 1.2 Public API (`__init__.py:302-365`)

The SDK exports a carefully curated public API:

**Core Functions:**
- `query()` - One-shot queries
- `ClaudeSDKClient` - Interactive sessions
- `tool()` - MCP tool decorator
- `create_sdk_mcp_server()` - SDK MCP server factory

**Types:** 59 exported types covering messages, permissions, hooks, MCP servers, and agents.

**Errors:** 5 exception classes (`ClaudeSDKError`, `CLIConnectionError`, `CLINotFoundError`, `ProcessError`, `CLIJSONDecodeError`)

### 1.3 Internal Components

The `_internal/` directory contains implementation details:

- **`_internal/client.py`** - `InternalClient` class that orchestrates `Query` and `Transport`
- **`_internal/query.py`** - `Query` class handling the bidirectional control protocol
- **`_internal/message_parser.py`** - Converts raw JSON to typed dataclasses
- **`_internal/transport/subprocess_cli.py`** - `SubprocessCLITransport` managing the CLI subprocess

---

## 2. Query Implementation: `query()` vs `ClaudeSDKClient`

### 2.1 `query()` Function (`query.py:12-127`)

The `query()` function provides one-shot or unidirectional streaming:

```python
async def query(
    *,
    prompt: str | AsyncIterable[dict[str, Any]],
    options: ClaudeAgentOptions | None = None,
    transport: Transport | None = None,
) -> AsyncIterator[Message]:
```

**Key characteristics:**
- Accepts string prompt (single-shot) or `AsyncIterable` (streaming)
- Creates `InternalClient` internally
- Sets `CLAUDE_CODE_ENTRYPOINT` to `"sdk-py"`

**Internal flow (`_internal/client.py:43-125`):**

```python
async def process_query(self, prompt, options, transport):
    # 1. Validate can_use_tool callback requirements
    if options.can_use_tool and isinstance(prompt, str):
        raise ValueError("can_use_tool requires streaming mode")

    # 2. Auto-set permission_prompt_tool_name to "stdio"
    if options.can_use_tool:
        configured_options = replace(options, permission_prompt_tool_name="stdio")

    # 3. Create transport (default: SubprocessCLITransport)
    transport = SubprocessCLITransport(prompt=prompt, options=configured_options)
    await transport.connect()

    # 4. Create Query with control protocol handlers
    query = Query(
        transport=transport,
        is_streaming_mode=not isinstance(prompt, str),
        can_use_tool=options.can_use_tool,
        hooks=self._convert_hooks_to_internal_format(options.hooks),
        sdk_mcp_servers=sdk_mcp_servers,
    )

    # 5. Start message reading and initialize
    await query.start()
    if is_streaming:
        await query.initialize()
        query._tg.start_soon(query.stream_input, prompt)

    # 6. Yield parsed messages
    async for data in query.receive_messages():
        yield parse_message(data)
```

### 2.2 `ClaudeSDKClient` Class (`client.py:14-404`)

The client provides bidirectional, interactive conversations:

```python
class ClaudeSDKClient:
    """
    - Bidirectional: Send and receive messages at any time
    - Stateful: Maintains conversation context
    - Interactive: Send follow-ups based on responses
    - Control flow: Support for interrupts and session management
    """
```

**Key methods:**

| Method | Purpose | Reference |
|--------|---------|-----------|
| `connect(prompt?)` | Start session, optionally with initial prompt | `client.py:87-168` |
| `query(prompt, session_id)` | Send message in streaming mode | `client.py:180-208` |
| `receive_messages()` | Async iterator for all messages | `client.py:170-178` |
| `receive_response()` | Iterate until `ResultMessage` | `client.py:347-386` |
| `interrupt()` | Send interrupt signal | `client.py:210-214` |
| `set_permission_mode(mode)` | Change permission mode | `client.py:216-238` |
| `set_model(model)` | Change AI model | `client.py:240-262` |
| `rewind_files(user_message_id)` | Restore files to checkpoint | `client.py:264-294` |
| `get_mcp_status()` | Query MCP server status | `client.py:296-320` |
| `get_server_info()` | Get initialization info | `client.py:322-345` |
| `disconnect()` | Close connection | `client.py:388-393` |

**Async context manager support (`client.py:395-403`):**

```python
async with ClaudeSDKClient(options) as client:
    await client.query("Hello")
    async for msg in client.receive_response():
        print(msg)
```

### 2.3 Key Differences

| Feature | `query()` | `ClaudeSDKClient` |
|---------|-----------|-------------------|
| Input mode | All upfront | Send anytime |
| Bidirectional | Limited | Full |
| Interrupts | No | Yes |
| State management | None | Session context |
| Use case | Batch processing | Chat interfaces |

---

## 3. MCP Tool Implementation

### 3.1 `@tool` Decorator (`__init__.py:75-136`)

Creates `SdkMcpTool` dataclass instances:

```python
@dataclass
class SdkMcpTool(Generic[T]):
    name: str
    description: str
    input_schema: type[T] | dict[str, Any]
    handler: Callable[[T], Awaitable[dict[str, Any]]]

def tool(name, description, input_schema):
    def decorator(handler):
        return SdkMcpTool(
            name=name,
            description=description,
            input_schema=input_schema,
            handler=handler,
        )
    return decorator
```

**Input schema formats supported:**
1. Simple dict mapping names to Python types: `{"a": float, "b": float}`
2. TypedDict classes
3. Full JSON Schema dictionaries

**Handler return format:**
```python
{
    "content": [{"type": "text", "text": "result"}],
    "is_error": True  # Optional
}
```

### 3.2 `create_sdk_mcp_server()` (`__init__.py:138-299`)

Creates an in-process MCP server:

```python
def create_sdk_mcp_server(name, version="1.0.0", tools=None):
    from mcp.server import Server
    from mcp.types import Tool

    server = Server(name, version=version)
    tool_map = {tool_def.name: tool_def for tool_def in tools}

    @server.list_tools()
    async def list_tools() -> list[Tool]:
        # Convert input_schema to JSON Schema format
        for tool_def in tools:
            if isinstance(tool_def.input_schema, dict):
                if "type" in tool_def.input_schema:
                    schema = tool_def.input_schema  # Already JSON Schema
                else:
                    # Convert {name: type} to JSON Schema
                    properties = {}
                    for param_name, param_type in tool_def.input_schema.items():
                        if param_type is str:
                            properties[param_name] = {"type": "string"}
                        elif param_type is float:
                            properties[param_name] = {"type": "number"}
                        # ... etc
                    schema = {
                        "type": "object",
                        "properties": properties,
                        "required": list(properties.keys()),
                    }
        return [Tool(name=t.name, description=t.description, inputSchema=schema) for t in tools]

    @server.call_tool()
    async def call_tool(name, arguments):
        result = await tool_map[name].handler(arguments)
        # Convert to MCP content format (TextContent, ImageContent)
        return content

    return McpSdkServerConfig(type="sdk", name=name, instance=server)
```

### 3.3 CLI Configuration (`subprocess_cli.py:246-271`)

When building CLI command, SDK servers are handled specially:

```python
for name, config in self._options.mcp_servers.items():
    if isinstance(config, dict) and config.get("type") == "sdk":
        # Strip instance field - CLI can't use it
        sdk_config = {k: v for k, v in config.items() if k != "instance"}
        servers_for_cli[name] = sdk_config
    else:
        servers_for_cli[name] = config

cmd.extend(["--mcp-config", json.dumps({"mcpServers": servers_for_cli})])
```

### 3.4 MCP Message Routing (`_internal/query.py:386-518`)

The `Query` class handles `mcp_message` control requests:

```python
async def _handle_sdk_mcp_request(self, server_name, message):
    server = self.sdk_mcp_servers[server_name]
    method = message.get("method")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": message["id"],
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": server.name, "version": server.version},
            },
        }

    elif method == "tools/list":
        handler = server.request_handlers.get(ListToolsRequest)
        result = await handler(ListToolsRequest(method=method))
        return {"jsonrpc": "2.0", "id": message["id"], "result": {"tools": [...]}}

    elif method == "tools/call":
        request = CallToolRequest(
            method=method,
            params=CallToolRequestParams(
                name=params["name"],
                arguments=params.get("arguments", {}),
            ),
        )
        handler = server.request_handlers.get(CallToolRequest)
        result = await handler(request)
        return {"jsonrpc": "2.0", "id": message["id"], "result": {"content": [...]}}

    elif method == "notifications/initialized":
        return {"jsonrpc": "2.0", "result": {}}
```

**Note:** The Python MCP SDK lacks a proper Transport abstraction, forcing manual method routing. TypeScript SDK uses `server.connect(transport)` for cleaner integration.

---

## 4. Hook Implementation

### 4.1 Hook Registration (`_internal/query.py:116-158`)

During initialization, hooks are registered with callback IDs:

```python
async def initialize(self):
    hooks_config = {}
    for event, matchers in self.hooks.items():
        hooks_config[event] = []
        for matcher in matchers:
            callback_ids = []
            for callback in matcher.get("hooks", []):
                callback_id = f"hook_{self.next_callback_id}"
                self.next_callback_id += 1
                self.hook_callbacks[callback_id] = callback  # Store reference
                callback_ids.append(callback_id)

            hooks_config[event].append({
                "matcher": matcher.get("matcher"),
                "hookCallbackIds": callback_ids,
                "timeout": matcher.get("timeout"),
            })

    # Send initialize control request
    await self._send_control_request({
        "subtype": "initialize",
        "hooks": hooks_config,
    })
```

### 4.2 Hook Callback Handling (`_internal/query.py:280-294`)

When CLI invokes a hook:

```python
elif subtype == "hook_callback":
    callback_id = request_data["callback_id"]
    callback = self.hook_callbacks.get(callback_id)
    if not callback:
        raise Exception(f"No hook callback found for ID: {callback_id}")

    hook_output = await callback(
        request_data.get("input"),      # HookInput
        request_data.get("tool_use_id"),
        {"signal": None},               # HookContext
    )

    # Convert Python field names to CLI field names
    response_data = _convert_hook_output_for_cli(hook_output)
```

### 4.3 Field Name Conversion (`_internal/query.py:34-51`)

Python uses `async_` and `continue_` to avoid keyword conflicts:

```python
def _convert_hook_output_for_cli(hook_output):
    converted = {}
    for key, value in hook_output.items():
        if key == "async_":
            converted["async"] = value
        elif key == "continue_":
            converted["continue"] = value
        else:
            converted[key] = value
    return converted
```

### 4.4 Hook Types (`types.py:160-382`)

**Supported hook events:**
```python
HookEvent = (
    Literal["PreToolUse"]
    | Literal["PostToolUse"]
    | Literal["UserPromptSubmit"]
    | Literal["Stop"]
    | Literal["SubagentStop"]
    | Literal["PreCompact"]
)
```

**Note:** Python SDK does NOT support `SessionStart`, `SessionEnd`, and `Notification` hooks due to setup limitations.

**Hook input types (discriminated union):**

| Event | Input Type | Unique Fields |
|-------|------------|---------------|
| PreToolUse | `PreToolUseHookInput` | `tool_name`, `tool_input` |
| PostToolUse | `PostToolUseHookInput` | `tool_name`, `tool_input`, `tool_response` |
| UserPromptSubmit | `UserPromptSubmitHookInput` | `prompt` |
| Stop | `StopHookInput` | `stop_hook_active` |
| SubagentStop | `SubagentStopHookInput` | `stop_hook_active` |
| PreCompact | `PreCompactHookInput` | `trigger`, `custom_instructions` |

**Hook output types:**

```python
class SyncHookJSONOutput(TypedDict):
    # Control fields
    continue_: NotRequired[bool]       # Default: True
    suppressOutput: NotRequired[bool]
    stopReason: NotRequired[str]

    # Decision fields
    decision: NotRequired[Literal["block"]]
    systemMessage: NotRequired[str]
    reason: NotRequired[str]

    # Hook-specific
    hookSpecificOutput: NotRequired[HookSpecificOutput]
```

---

## 5. Control Protocol Details

### 5.1 Message Types (`_internal/query.py:53-62`)

**Regular messages (CLI → SDK):**
- `type: "user"` - User messages
- `type: "assistant"` - Assistant responses
- `type: "system"` - System messages
- `type: "result"` - Final result
- `type: "stream_event"` - Partial message streaming

**Control messages (bidirectional):**
- `type: "control_request"` - Request something
- `type: "control_response"` - Response to request
- `type: "control_cancel_request"` - Cancel pending request

### 5.2 Control Request Handling (`_internal/query.py:228-337`)

```python
async def _handle_control_request(self, request: SDKControlRequest):
    request_id = request["request_id"]
    request_data = request["request"]
    subtype = request_data["subtype"]

    try:
        if subtype == "can_use_tool":
            # Permission check
            response = await self.can_use_tool(
                request_data["tool_name"],
                request_data["input"],
                ToolPermissionContext(
                    signal=None,
                    suggestions=request_data.get("permission_suggestions", []),
                ),
            )
            if isinstance(response, PermissionResultAllow):
                response_data = {
                    "behavior": "allow",
                    "updatedInput": response.updated_input or original_input,
                }
                if response.updated_permissions:
                    response_data["updatedPermissions"] = [
                        perm.to_dict() for perm in response.updated_permissions
                    ]
            elif isinstance(response, PermissionResultDeny):
                response_data = {
                    "behavior": "deny",
                    "message": response.message,
                }
                if response.interrupt:
                    response_data["interrupt"] = True

        elif subtype == "hook_callback":
            # Hook invocation (see section 4.2)

        elif subtype == "mcp_message":
            # SDK MCP request (see section 3.4)

        # Send success response
        await self.transport.write(json.dumps({
            "type": "control_response",
            "response": {
                "subtype": "success",
                "request_id": request_id,
                "response": response_data,
            },
        }) + "\n")

    except Exception as e:
        # Send error response
        await self.transport.write(json.dumps({
            "type": "control_response",
            "response": {
                "subtype": "error",
                "request_id": request_id,
                "error": str(e),
            },
        }) + "\n")
```

### 5.3 Control Request Types (`types.py:685-756`)

**SDK → CLI requests:**

| Subtype | Purpose | Fields |
|---------|---------|--------|
| `initialize` | Start control protocol | `hooks: dict` |
| `interrupt` | Interrupt operation | (none) |
| `set_permission_mode` | Change permissions | `mode: str` |
| `set_model` | Change AI model | `model: str` |
| `rewind_files` | Restore file state | `user_message_id: str` |
| `mcp_status` | Query MCP status | (none) |

**CLI → SDK requests:**

| Subtype | Purpose | Fields |
|---------|---------|--------|
| `can_use_tool` | Permission check | `tool_name`, `input`, `permission_suggestions`, `blocked_path` |
| `hook_callback` | Invoke hook | `callback_id`, `input`, `tool_use_id` |
| `mcp_message` | SDK MCP call | `server_name`, `message` (JSONRPC) |

### 5.4 Sending Control Requests (`_internal/query.py:339-384`)

```python
async def _send_control_request(self, request, timeout=60.0):
    # Generate unique request ID
    self._request_counter += 1
    request_id = f"req_{self._request_counter}_{os.urandom(4).hex()}"

    # Create event for response
    event = anyio.Event()
    self.pending_control_responses[request_id] = event

    # Send request
    await self.transport.write(json.dumps({
        "type": "control_request",
        "request_id": request_id,
        "request": request,
    }) + "\n")

    # Wait for response with timeout
    with anyio.fail_after(timeout):
        await event.wait()

    result = self.pending_control_results.pop(request_id)
    if isinstance(result, Exception):
        raise result
    return result.get("response", {})
```

---

## 6. Streaming Modes

### 6.1 Single-Shot Mode (`subprocess_cli.py:327-334`)

When prompt is a string:

```python
if self._is_streaming:
    cmd.extend(["--input-format", "stream-json"])
else:
    cmd.extend(["--print", "--", str(self._prompt)])
```

In single-shot mode:
- Prompt passed via CLI args
- stdin closed immediately after process starts (`subprocess_cli.py:426-429`)

### 6.2 Streaming Mode (`subprocess_cli.py:425-426`, `_internal/query.py:561-594`)

When prompt is an `AsyncIterable`:

```python
if self._is_streaming and self._process.stdin:
    self._stdin_stream = TextSendStream(self._process.stdin)
```

**Stdin management:**

```python
async def stream_input(self, stream: AsyncIterable[dict]):
    # Send all input messages
    async for message in stream:
        if self._closed:
            break
        await self.transport.write(json.dumps(message) + "\n")

    # Wait for first result if SDK MCP or hooks need bidirectional
    has_hooks = bool(self.hooks)
    if self.sdk_mcp_servers or has_hooks:
        try:
            with anyio.move_on_after(self._stream_close_timeout):
                await self._first_result_event.wait()
        except Exception:
            pass

    # Close stdin
    await self.transport.end_input()
```

### 6.3 Why Wait for Result?

The SDK waits for the first `result` message before closing stdin when:
- SDK MCP servers are configured (need to receive `mcp_message` control requests)
- Hooks are configured (need to receive `hook_callback` control requests)

This keeps the control channel open for bidirectional communication.

---

## 7. Error Types

### 7.1 Exception Hierarchy (`_errors.py:1-57`)

```
ClaudeSDKError (base)
├── CLIConnectionError
│   └── CLINotFoundError
├── ProcessError
├── CLIJSONDecodeError
└── MessageParseError
```

### 7.2 Error Details

**`CLIConnectionError`** (`_errors.py:10-11`):
- Raised when unable to connect to CLI
- Examples: working directory doesn't exist, failed to start process

**`CLINotFoundError`** (`_errors.py:14-22`):
- Raised when Claude CLI not found
- Includes helpful installation instructions

**`ProcessError`** (`_errors.py:25-39`):
- Raised when CLI process fails
- Contains `exit_code` and `stderr` attributes

**`CLIJSONDecodeError`** (`_errors.py:42-48`):
- Raised when JSON parsing fails
- Contains the problematic `line` and `original_error`
- Also raised when buffer exceeds `max_buffer_size` (`subprocess_cli.py:589-597`)

**`MessageParseError`** (`_errors.py:51-56`):
- Raised in `parse_message()` for invalid message structure
- Contains the raw `data` dict

### 7.3 Error Surfacing

**CLI exit codes (`subprocess_cli.py:616-628`):**
```python
returncode = await self._process.wait()
if returncode is not None and returncode != 0:
    self._exit_error = ProcessError(
        f"Command failed with exit code {returncode}",
        exit_code=returncode,
        stderr="Check stderr output for details",
    )
    raise self._exit_error
```

**Fatal errors in message reader (`_internal/query.py:215-226`):**
```python
except Exception as e:
    logger.error(f"Fatal error in message reader: {e}")
    # Signal all pending control requests
    for request_id, event in list(self.pending_control_responses.items()):
        if request_id not in self.pending_control_results:
            self.pending_control_results[request_id] = e
            event.set()
    # Put error in stream
    await self._message_send.send({"type": "error", "error": str(e)})
```

---

## 8. Python vs TypeScript SDK Differences

### 8.1 Features in TypeScript but NOT in Python

| Feature | TypeScript | Python |
|---------|------------|--------|
| **Hook events** | 13 events | 7 events (missing `SessionStart`, `SessionEnd`, `Notification`, `SubagentStart`, `PostToolUseFailure`, `PermissionRequest`, `Setup`) |
| **Custom process spawning** | `spawnClaudeCodeProcess` option | Not supported |
| **Dynamic MCP management** | `setMcpServers()`, `reconnectMcpServer()`, `toggleMcpServer()` | Not documented |
| **MCP Transport abstraction** | Clean `Transport` interface with `server.connect(transport)` | Manual JSONRPC method routing |
| **V2 API** | `SDKSession` interface (unstable) | Not present |
| **Control methods** | `setMaxThinkingTokens()`, `supportedCommands()`, `supportedModels()`, `accountInfo()` | Not exposed |
| **McpClaudeAIProxyServerConfig** | Supported MCP server type | Not supported |
| **Zod schema validation** | Built-in tool validation | Simple dict/type mapping |

### 8.2 Python-Specific Features

| Feature | Details |
|---------|---------|
| **anyio support** | Works with both asyncio and trio |
| **Bundled CLI detection** | Checks `_bundled/` directory for CLI (`subprocess_cli.py:103-116`) |
| **Keyword conversion** | `async_` → `async`, `continue_` → `continue` |
| **Simple tool decorator** | `@tool(name, desc, {param: type})` without Zod |

### 8.3 Implementation Differences

**Transport:**
- TypeScript: Abstract `Transport` interface, custom `SpawnedProcess` support
- Python: Concrete `SubprocessCLITransport` only

**MCP routing:**
- TypeScript: Uses MCP SDK's Transport abstraction via `K9` class
- Python: Manual routing in `_handle_sdk_mcp_request()` (limitation noted in code)

**Concurrency:**
- TypeScript: Node.js event loop, Promise-based
- Python: anyio TaskGroups, Event-based coordination

---

## Summary

The Python SDK is a subprocess wrapper around the Claude CLI with:

1. **Two entry points**: `query()` for one-shot, `ClaudeSDKClient` for interactive
2. **Control protocol**: Bidirectional JSON over stdin/stdout for hooks, permissions, SDK MCP
3. **SDK MCP tools**: In-process MCP servers with manual JSONRPC routing (not using MCP SDK Transport)
4. **Hooks**: Registered via callback IDs, invoked via control requests
5. **Streaming mode**: stdin kept open when SDK MCP or hooks need bidirectional communication

For Swift implementation priorities:
1. **SDK MCP tools** - Implement JSONRPC routing for `initialize`, `tools/list`, `tools/call`
2. **Control protocol** - Request/response correlation with unique IDs
3. **Hooks** - Callback ID registration and invocation
4. **Streaming management** - Keep stdin open when needed for bidirectional

The TypeScript SDK has more features (13 vs 7 hook events, dynamic MCP, custom process spawning) but the core architecture is identical: subprocess + JSON lines + bidirectional control protocol.
