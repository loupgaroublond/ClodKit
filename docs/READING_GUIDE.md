# ClodKit Reading Guide

## Prerequisites

- Swift 6.0 async/await patterns (AsyncSequence, AsyncThrowingStream)
- Swift actors for concurrency
- JSON-RPC basics (for MCP protocol understanding)


## Core Concept

The SDK wraps the `claude` CLI process, communicating via JSON-lines over stdin/stdout. A bidirectional "control protocol" enables hooks, permissions, and in-process MCP tools.


## Reading Order

### Phase 1: Public API (how users interact)

1. `Sources/ClodKit/Query/QueryAPI.swift` — Entry point. See `ClaudeCode.query()` function and `QueryError` enum.

2. `Sources/ClodKit/Query/QueryOptions.swift` — Configuration options for queries.

3. `Sources/ClodKit/Query/ClaudeQuery.swift` — AsyncSequence wrapper users iterate over.


### Phase 2: Orchestration layer

4. `Sources/ClodKit/Session/ClaudeSession.swift` — The actor that ties everything together. Manages transport, control protocol, hooks, and MCP routing.


### Phase 3: Transport (CLI communication)

5. `Sources/ClodKit/Transport/Transport.swift` — Protocol defining transport interface.

6. `Sources/ClodKit/Transport/StdoutMessage.swift` — Discriminated union of message types from CLI (regular, controlRequest, controlResponse, etc.).

7. `Sources/ClodKit/Transport/SDKMessage.swift` — Low-level message structures (SDKMessage, ControlRequest, ControlResponse, ControlCancelRequest).

8. `Sources/ClodKit/Transport/ProcessTransport.swift` — Real subprocess implementation.

9. `Sources/ClodKit/Transport/MockTransport.swift` — Test double for unit testing.

10. `Sources/ClodKit/Transport/JSONLineParser.swift` — Parses newline-delimited JSON from CLI stdout.


### Phase 4: Control Protocol (bidirectional SDK ↔ CLI messaging)

11. `Sources/ClodKit/ControlProtocol/ControlRequests.swift` — Request types and `ControlRequestPayload` discriminated union (initialize, MCP messages, hook callbacks, etc.).

12. `Sources/ClodKit/ControlProtocol/ControlResponses.swift` — Response types and `ControlResponsePayload` discriminated union.

13. `Sources/ClodKit/ControlProtocol/JSONRPCTypes.swift` — JSON-RPC message types for MCP communication.

14. `Sources/ClodKit/ControlProtocol/ControlProtocolError.swift` — Error types for control protocol failures.

15. `Sources/ClodKit/ControlProtocol/ControlProtocolHandler.swift` — Actor handling request/response correlation.


### Phase 5: Hooks (event callbacks)

16. `Sources/ClodKit/Hooks/HookEvent.swift` — Event types (PreToolUse, PostToolUse, Stop, etc.).

17. `Sources/ClodKit/Hooks/HookMatcherConfig.swift` — Configuration for matching which hooks fire.

18. `Sources/ClodKit/Hooks/HookInputTypes.swift` — Input structures for each hook type.

19. `Sources/ClodKit/Hooks/HookOutputTypes.swift` — Output structures for each hook type.

20. `Sources/ClodKit/Hooks/HookCallbacks.swift` — Type aliases for hook callback signatures.

21. `Sources/ClodKit/Hooks/JSONValue.swift` — Dynamic JSON type for flexible payloads.

22. `Sources/ClodKit/Hooks/HookRegistry.swift` — Actor for registration and invocation.

23. `Sources/ClodKit/Query/HookConfigs.swift` — Configuration structs for registering hooks in QueryOptions.


### Phase 6: MCP (custom tools)

24. `Sources/ClodKit/MCP/MCPTool.swift` — Tool definition struct.

25. `Sources/ClodKit/MCP/JSONSchema.swift` — JSON schema builders for tool input validation.

26. `Sources/ClodKit/MCP/MCPToolBuilder.swift` — Result builder for declarative tool arrays.

27. `Sources/ClodKit/MCP/MCPToolResult.swift` — Tool execution result types.

28. `Sources/ClodKit/MCP/SDKMCPServer.swift` — In-process server hosting tools.

29. `Sources/ClodKit/MCP/MCPServerRouter.swift` — Actor routing JSON-RPC to servers.

30. `Sources/ClodKit/Query/MCPServerConfig.swift` — Configuration for external MCP servers.


### Phase 7: Permissions

31. `Sources/ClodKit/Permissions/PermissionMode.swift` — Permission mode enum (default, acceptEdits, bypassPermissions, plan).

32. `Sources/ClodKit/Permissions/ToolPermissionContext.swift` — Context passed to permission callbacks.

33. `Sources/ClodKit/Permissions/PermissionResult.swift` — Result enum from permission callbacks.

34. `Sources/ClodKit/Permissions/PermissionUpdate.swift` — Permission update suggestions from CLI.

35. `Sources/ClodKit/Permissions/PermissionRule.swift` — Rule struct for permission matching.


### Phase 8: Backend abstraction

36. `Sources/ClodKit/Backend/NativeBackend.swift` — Protocol for swappable backends.

37. `Sources/ClodKit/Backend/BackendType.swift` — Enum of available backend types.

38. `Sources/ClodKit/Backend/NativeBackendFactory.swift` — Factory function to create backends.

39. `Sources/ClodKit/Backend/NativeClaudeCodeBackend.swift` — Concrete backend implementation.


## Key Patterns

| Pattern | Where | Why |
|---------|-------|-----|
| Actor isolation | `ClaudeSession`, `ControlProtocolHandler`, `HookRegistry`, `MCPServerRouter` | Thread-safe state without locks |
| AsyncThrowingStream | Transport message delivery | Modern async iteration |
| Protocol abstraction | `Transport` | Enables `MockTransport` for tests |
| Request correlation | `ControlProtocolHandler` | Match responses to pending requests via ID |
| Type-erased callbacks | `HookRegistry.CallbackBox` | Store heterogeneous hook callbacks |
| Discriminated unions | `ControlRequestPayload`, `ControlResponsePayload`, `StdoutMessage` | Type-safe message routing |
| Result builders | `MCPToolBuilder` | Declarative tool definition syntax |
| Single-type-per-file | Most files | Easier navigation, reduced merge conflicts |


## Data Flow

```
User → ClaudeCode.query() → ProcessTransport (spawn CLI)
                                    ↓
                           JSON-lines over stdin/stdout
                                    ↓
                    ClaudeSession dispatches incoming messages:
                      • .regular → yield to user stream
                      • .controlRequest → route to handler (hooks, MCP, permissions)
                      • .controlResponse → match to pending request
```


## Ownership and Lifecycles

### Ownership Graph

Each `ClaudeCode.query()` call creates a completely isolated object graph:

```
ClaudeCode.query()
    │
    ├── ProcessTransport          (class, thread-safe via NSLock)
    │       └── owns: Process, stdin/stdout/stderr Pipes
    │
    └── ClaudeSession             (actor)
            ├── owns: ControlProtocolHandler  (actor)
            │             └── owns: pendingRequests map
            │
            ├── owns: HookRegistry            (actor)
            │             └── owns: callbacks map, hookConfig map
            │
            └── owns: MCPServerRouter         (actor)
                          └── owns: servers map (references to SDKMCPServer)
```

**Key insight**: There is NO shared state between concurrent sessions. Each query gets its own:
- CLI subprocess
- Transport with independent stdin/stdout
- Control protocol handler with its own pending request tracking
- Hook registry with its own callbacks
- MCP router with its own server registrations


### Per-Session vs Shared Resources

| Resource | Per-Session? | Notes |
|----------|--------------|-------|
| ProcessTransport | Yes | Each session spawns its own `claude` CLI process |
| ClaudeSession | Yes | Actor created fresh for each query |
| ControlProtocolHandler | Yes | Created by ClaudeSession, manages request/response correlation |
| HookRegistry | Yes | Created by ClaudeSession, stores callback references |
| MCPServerRouter | Yes | Created by ClaudeSession, routes JSON-RPC to servers |
| SDKMCPServer | **Shareable** | User-provided. Same instance CAN be passed to multiple queries |
| Hook callbacks | **Shareable** | User-provided closures. Same closure CAN be used across queries |


### SDKMCPServer Sharing Scenario

```swift
// User creates ONE server instance
let myServer = SDKMCPServer(name: "tools", tools: [myTool])

// Both queries reference the SAME SDKMCPServer
var opts1 = QueryOptions()
opts1.sdkMcpServers["tools"] = myServer

var opts2 = QueryOptions()
opts2.sdkMcpServers["tools"] = myServer

// Launch concurrently
async let query1 = ClaudeCode.query("prompt1", options: opts1)
async let query2 = ClaudeCode.query("prompt2", options: opts2)
```

In this scenario:
- Two separate MCPServerRouters each hold a reference to the SAME `myServer`
- Tool handlers may be invoked concurrently from both sessions
- Tool handlers MUST be `@Sendable` and thread-safe


### Lifecycle Phases

#### 1. Creation Phase (`query()` entry)

```
query(prompt, options)
    │
    ├── Build CLI arguments from options
    ├── Create MCP config file (if needed)
    │
    ├── ProcessTransport(command, workingDirectory, env)  ← created, not started
    │
    ├── ClaudeSession(transport)
    │       ├── creates ControlProtocolHandler(transport)
    │       ├── creates HookRegistry()
    │       └── creates MCPServerRouter()
    │
    ├── Register SDK MCP servers  (session → router)
    ├── Register hooks            (session → registry)
    └── Set permission callback   (session stores reference)
```

#### 2. Start Phase (`query()` continues)

```
    │
    ├── transport.start()               ← spawns CLI subprocess
    │       └── Process.run() with stdin/stdout/stderr pipes
    │
    ├── session.startMessageLoop()      ← begins async reading
    │       └── Task reads transport.readMessages() stream
    │
    ├── session.initialize()            ← control protocol handshake (if needed)
    │       └── Sends initialize request with hooks config + MCP server names
    │
    ├── transport.write(prompt)         ← sends user prompt to CLI stdin
    │
    └── return ClaudeQuery(session, stream)
```

#### 3. Running Phase (user iterates ClaudeQuery)

```
User: for try await message in query { ... }
                    │
                    ▼
        ClaudeQuery.makeAsyncIterator()
                    │
                    ▼
        Underlying stream yields messages from session.startMessageLoop()

Message flow:
    CLI stdout → ProcessTransport.handleStdoutData()
                       │
                       ├── JSONLineParser extracts messages
                       │
                       └── continuation.yield(message)
                                │
                                ▼
                    ClaudeSession.runMessageLoop()
                                │
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
      .regular             .controlRequest    .controlResponse
      (yield to user)      (dispatch)         (match pending)
                                │
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
      canUseTool          hookCallback         mcpMessage
      (permission cb)     (HookRegistry)       (MCPServerRouter)
```

#### 4. Cleanup Phase

```
Normal termination:
    CLI process exits → stdout EOF
        │
        ├── ProcessTransport.handleStdoutEOF()
        │       └── continuation.finish()
        │
        └── ProcessTransport.handleTermination()
                └── continuation.finish() or finish(throwing:)

Forced termination (session.close() or query scope exit):
    │
    ├── transport.close()
    │       ├── stdinPipe.closeFile()     ← signals EOF to CLI
    │       ├── process.terminate()        ← SIGTERM
    │       ├── wait up to 5 seconds
    │       └── SIGKILL if still running
    │
    └── stream.finish()
```


### Concurrent Sessions Diagram

```
┌─────────────────────────────────────┐  ┌─────────────────────────────────────┐
│           Session A                 │  │           Session B                 │
│                                     │  │                                     │
│  ┌─────────────────────────────┐    │  │    ┌─────────────────────────────┐  │
│  │      ProcessTransport       │    │  │    │      ProcessTransport       │  │
│  │  ┌───────────────────────┐  │    │  │    │  ┌───────────────────────┐  │  │
│  │  │   claude process A    │  │    │  │    │  │   claude process B    │  │  │
│  │  └───────────────────────┘  │    │  │    │  └───────────────────────┘  │  │
│  └─────────────────────────────┘    │  │    └─────────────────────────────┘  │
│                                     │  │                                     │
│  ┌─────────────────────────────┐    │  │    ┌─────────────────────────────┐  │
│  │       ClaudeSession         │    │  │    │       ClaudeSession         │  │
│  │  ┌───────────────────────┐  │    │  │    │  ┌───────────────────────┐  │  │
│  │  │ ControlProtocolHandler│  │    │  │    │  │ ControlProtocolHandler│  │  │
│  │  └───────────────────────┘  │    │  │    │  └───────────────────────┘  │  │
│  │  ┌───────────────────────┐  │    │  │    │  ┌───────────────────────┐  │  │
│  │  │     HookRegistry      │  │    │  │    │  │     HookRegistry      │  │  │
│  │  └───────────────────────┘  │    │  │    │  └───────────────────────┘  │  │
│  │  ┌───────────────────────┐  │    │  │    │  ┌───────────────────────┐  │  │
│  │  │   MCPServerRouter     │──┼────┼──┼────┼──│   MCPServerRouter     │  │  │
│  │  └───────────────────────┘  │    │  │    │  └───────────────────────┘  │  │
│  └─────────────────────────────┘    │  │    └─────────────────────────────┘  │
│                                     │  │                                     │
└─────────────────────────────────────┘  └─────────────────────────────────────┘
                │                                          │
                └──────────────┬───────────────────────────┘
                               ▼
                    ┌─────────────────────┐
                    │   SDKMCPServer      │  ← SHARED if user reuses
                    │   (user-provided)   │
                    │  ┌───────────────┐  │
                    │  │  MCPTool      │  │  ← handlers may run concurrently
                    │  │  handlers     │  │
                    │  └───────────────┘  │
                    └─────────────────────┘
```


### Thread Safety Summary

| Component | Isolation Mechanism | Safe for Concurrent Access? |
|-----------|--------------------|-----------------------------|
| ProcessTransport | NSLock | Yes (internal locking) |
| ClaudeSession | Actor | Yes (actor isolation) |
| ControlProtocolHandler | Actor | Yes (actor isolation) |
| HookRegistry | Actor | Yes (actor isolation) |
| MCPServerRouter | Actor | Yes (actor isolation) |
| SDKMCPServer | Immutable after init | Yes (tools dict is `let`) |
| MCPTool.handler | Must be `@Sendable` | Depends on implementation |
| Hook callbacks | Must be `@Sendable` | Depends on implementation |


### Memory Management

- **Strong references**: ClaudeSession holds strong refs to transport, controlHandler, hookRegistry, mcpRouter
- **Weak self in closures**: Control handlers use `[weak self]` to avoid retain cycles
- **No reference cycles**: Object graph is tree-shaped, no circular references
- **Cleanup**: When ClaudeQuery goes out of scope, the session and all children become eligible for deallocation (after any pending async work completes)


## Reference Docs

- `../CLAUDE_AGENT_SDK_API_SPEC.md` — Official SDK API spec
