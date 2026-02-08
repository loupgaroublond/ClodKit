# ClodKit

*"It's just a turf!"*

Pure Swift SDK for Claude Code, targeting API parity with official TypeScript and Python SDKs.

## Technical Stack

- **Swift 6.0** / macOS 13+
- **Zero dependencies** - Pure Swift, no external packages
- **AsyncSequence** - `AsyncStream`, `AsyncThrowingStream` for streaming responses
- **Actors** - Thread-safe state management throughout

## Architecture

```
Sources/ClodKit/
├── Query/           ← Public API: query(), ClaudeQuery, QueryOptions
├── Session/         ← ClaudeSession actor - orchestrates everything
├── Backend/         ← NativeBackend - subprocess management
├── Transport/       ← ProcessTransport - CLI communication
├── ControlProtocol/ ← Bidirectional JSON-RPC with CLI
├── MCP/             ← SDK MCP server routing
├── Hooks/           ← Pre/post tool execution hooks
└── Permissions/     ← Tool authorization callbacks
```

### Control Protocol

Bidirectional JSON-lines over stdin/stdout with `--input-format stream-json`:
- `control_request` / `control_response` messages
- Enables hooks, SDK MCP tools, permission callbacks

## Implementation Status — SDK v0.2.34 Parity

- Core query API (single prompts, streaming responses)
- Streaming input (`AsyncSequence<SDKUserMessage>` overloads on `query()` and `Clod.query()`)
- Multi-turn conversation (`receiveResponse()`, `continueConversation`, `forkSession`)
- Query control methods (`interrupt()`, `setModel()`, `setPermissionMode()`, `setMaxThinkingTokens()`)
- Control protocol (bidirectional JSON-RPC)
- Transport layer (subprocess abstraction, shell-injection hardened)
- Session management (actor-based `ClaudeSession`)
- V2 Session API (`createSession`, `prompt`, `resumeSession` — unstable)
- Hook system (15 event types with discriminated union inputs/outputs)
- MCP server routing with tool builder DSL (`ToolParam`, `ParamBuilder`, `SchemaValidator`)
- Permission callbacks (`canUseTool`, `delegate` and `dontAsk` modes, `ExitPlanModeInput`)
- Agent definitions (`AgentDefinition`, `AgentModel`)
- Sandbox settings (`SandboxSettings`, `SandboxNetworkConfig`, `RipgrepConfig`)
- 652 tests across 57 files (~20,600 lines) — unit, behavioral, security, integration
- 5 example applications

## Examples

Five self-contained example applications in `Examples/`:

- **SimpleQuery** - Basic query API usage, iterating response messages
- **ToolServer** - SDK MCP server with custom tool definitions
- **HookDemo** - Pre/post tool use hooks with allow/deny/modify
- **PermissionCallback** - canUseTool callback with delegate permission mode
- **StreamingOutput** - Streaming message iteration with type-specific handling

## Reference Documents

- `docs/CLAUDE_AGENT_SDK_API_SPEC.md` - Official SDK API reference

## Workflow

```bash
# Build
swift build

# Test
swift test
```
