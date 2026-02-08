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

## Implementation Status

**Working:**
- Core query API (single prompts, streaming responses)
- Control protocol (bidirectional JSON-RPC)
- Transport layer (subprocess abstraction)
- Session management (actor-based)
- Hook system (pre/post tool use)
- MCP server routing
- MCP tool builder DSL (createSDKMCPServer result builder)
- Permission callbacks
- Comprehensive test suite (28 files, 8700+ lines)
- Example applications (5 self-contained demos)

**Not yet implemented:**
- Query control methods (interrupt, rewind, setModel)
- Streaming input (AsyncSequence of user messages)
- Multi-turn conversation API

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
