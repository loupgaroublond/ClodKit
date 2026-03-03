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

## Implementation Status — SDK v0.2.63 Parity

- Core query API (single prompts, streaming responses)
- Streaming input (`AsyncSequence<SDKUserMessage>` overloads on `query()` and `Clod.query()`)
- Multi-turn conversation (`receiveResponse()`, `continueConversation`, `forkSession`)
- Query control methods (`interrupt()`, `setModel()`, `setPermissionMode()`, `setMaxThinkingTokens()`, `stopTask()`, `supportedCommands()`, `supportedModels()`, `supportedAgents()`, `mcpServerStatus()`, `accountInfo()`)
- Control protocol (bidirectional JSON-RPC, elicitation support)
- Transport layer (subprocess abstraction, shell-injection hardened)
- Session management (actor-based `ClaudeSession`)
- V2 Session API (`createSession`, `prompt`, `resumeSession` — unstable, with hooks and permission support)
- Hook system (20 event types with discriminated union inputs/outputs, including Elicitation, ConfigChange, Worktree events)
- MCP server routing with tool builder DSL (`ToolParam`, `ParamBuilder`, `SchemaValidator`), HTTP server config
- Permission callbacks (`canUseTool`, `delegate` and `dontAsk` modes, `ExitPlanModeInput`, directory add/remove)
- Agent definitions (`AgentDefinition`, `AgentModel`, with skills, maxTurns, criticalSystemReminder)
- Sandbox settings (`SandboxSettings`, `SandboxNetworkConfig`, `SandboxFilesystemConfig`, `RipgrepConfig`)
- QueryOptions: thinking config, effort, plugins, prompt suggestions, elicitation callbacks, betas
- SDKMessage: 22 variants including elicitation complete, prompt suggestion, rate limit info, task progress
- Supporting types: `AccountInfo`, `AgentInfo`, `ModelInfo`, `ModelUsage`, `FastModeState`, `ThinkingConfig`, `ApiKeySource`, `SDKSessionInfo`, `ElicitationRequest`/`ElicitationResult`
- 1,250 tests across 57 files — unit, behavioral, security, integration
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

## Critical Rules

### SwiftPM Single Instance

SwiftPM uses a shared `.build` directory and **only one `swift build` or `swift test` process can run at a time** per package. Running multiple instances causes them to block each other indefinitely. When spawning agents that build or test:

- Use `isolation: "worktree"` so each agent gets its own `.build` directory
- Never run `swift build` and `swift test` in parallel on the same working tree
- If a build/test hangs, check `ps aux | grep swift-` for competing processes

### Test Timeouts

Every XCTestCase subclass **must** include `executionTimeAllowance` in its `setUp()`:

```swift
final class MyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10  // unit/behavioral tests
    }
}
```

Timeout tiers:
- **10 seconds** — Unit tests, behavioral tests, encoding/decoding tests (default)
- **30 seconds** — Concurrency tests (race conditions, async sequences)
- **60 seconds** — Integration tests (CLI invocation, network access)

This prevents runaway tests from blocking CI, agents, or other processes. Verify coverage with: `grep -rL executionTimeAllowance Tests/`
