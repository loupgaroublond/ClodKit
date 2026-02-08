# ClodKit

*"It's just a turf!"*

Pure Swift SDK for Claude Code, targeting API parity with official TypeScript and Python SDKs.

> **Renamed from ClodeMonster/ClaudeCodeSDK** - Same great SDK, fresh new name.

## Overview

ClodKit is a complete rewrite of the Swift SDK for Claude Code, implementing the control protocol for bidirectional communication with the Claude CLI. Unlike wrapper-based approaches, this SDK uses native Swift concurrency (actors, AsyncSequence) for thread-safe, streaming interactions.

## Features

- **Pure Swift** - Zero external dependencies, Swift 6.0+
- **SDK v0.2.34 Parity** - Full API coverage matching official TypeScript/Python SDKs
- **Control Protocol** - Bidirectional JSON-RPC communication with Claude CLI
- **Streaming** - AsyncSequence-based streaming responses and streaming input
- **Multi-Turn** - `receiveResponse()`, `continueConversation`, `forkSession`
- **Query Control** - `interrupt()`, `setModel()`, `setPermissionMode()` mid-query
- **Hook System** - 15 event types with pre/post tool execution callbacks
- **MCP Integration** - Server routing with type-safe tool builder DSL
- **Permission Callbacks** - Dynamic tool authorization with delegate/dontAsk modes
- **V2 Session API** - `createSession`, `prompt`, `resumeSession` (unstable)
- **Actor-Based** - Thread-safe state management throughout

## Requirements

- **Platform:** macOS 13+
- **Swift:** 6.0+
- **Claude CLI:** Installed and authenticated (`npm install -g @anthropic-ai/claude-code`)

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/loupgaroublond/ClodKit", from: "3.0.0")
]
```

Then import:

```swift
import ClodKit
```

## Quick Start

```swift
import ClodKit

// Simple query
var options = QueryOptions()
options.maxTurns = 5
options.permissionMode = .bypassPermissions

let claudeQuery = try await query(
    prompt: "Write a function to calculate Fibonacci numbers",
    options: options
)

for try await message in claudeQuery {
    switch message {
    case .regular(let msg) where msg.type == "assistant":
        if let content = msg.content { print(content) }
    case .regular(let msg) where msg.type == "result":
        print("Done: stop reason = \(msg.stopReason ?? "unknown")")
    default:
        break
    }
}
```

### Streaming Input (Multi-Turn)

```swift
let messages = AsyncStream<SDKUserMessage> { continuation in
    continuation.yield(SDKUserMessage(content: .text("Hello!")))
    continuation.yield(SDKUserMessage(content: .text("Now count to 5.")))
    continuation.finish()
}

let claudeQuery = try await query(messages: messages, options: options)
for try await message in claudeQuery { /* ... */ }
```

### Convenience via `Clod` Namespace

```swift
// Static shorthand
let claudeQuery = try await Clod.query("Explain async/await in Swift")

// With options
let claudeQuery = try await Clod.query("Hello", options: options)

// With closure
let claudeQuery = try await Clod.query("Hello") { opts in
    opts.maxTurns = 3
    opts.permissionMode = .bypassPermissions
}
```

### With SDK MCP Server

```swift
let server = createSDKMCPServer(name: "my-tools") {
    MCPTool(
        name: "add",
        description: "Add two numbers",
        inputSchema: JSONSchema(
            type: "object",
            properties: [
                "a": .number("First number"),
                "b": .number("Second number")
            ],
            required: ["a", "b"]
        ),
        handler: { args in
            let a = args["a"] as? Double ?? 0
            let b = args["b"] as? Double ?? 0
            return .text("Result: \(a + b)")
        }
    )
}

var options = QueryOptions()
options.mcpServers = [server]
```

### With Permission Callbacks

```swift
var options = QueryOptions()
options.permissionMode = .delegate
options.canUseTool = { context in
    if context.toolName == "Bash" {
        return .deny(reason: "Bash not allowed")
    }
    return .allow
}
```

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

The SDK communicates with Claude CLI via bidirectional JSON-lines over stdin/stdout using `--input-format stream-json`:
- Sends user messages and control requests
- Receives assistant messages and control requests from CLI
- Enables hooks, SDK MCP tools, and permission callbacks

## Examples

Five self-contained example applications in `Examples/`:

- **SimpleQuery** - Basic query API usage, iterating response messages
- **ToolServer** - SDK MCP server with custom tool definitions
- **HookDemo** - Pre/post tool use hooks with allow/deny/modify
- **PermissionCallback** - canUseTool callback with delegate permission mode
- **StreamingOutput** - Streaming message iteration with type-specific handling

Run an example:

```bash
swift run SimpleQuery
```

## Implementation Status — SDK v0.2.34 Parity

All major SDK features are implemented:

- Core query API with streaming responses
- Streaming input (`AsyncSequence<SDKUserMessage>`)
- Multi-turn conversation (`receiveResponse()`, `continueConversation`, `forkSession`)
- Query control methods (`interrupt()`, `setModel()`, `setPermissionMode()`)
- Control protocol (bidirectional JSON-RPC)
- Hook system (15 event types with discriminated union inputs/outputs)
- MCP server routing with tool builder DSL
- Permission callbacks with delegate/dontAsk modes
- V2 Session API (unstable)
- Agent definitions, sandbox settings
- 652 tests across 57 files (~20,600 lines)

## Documentation

- [API Specification](docs/CLAUDE_AGENT_SDK_API_SPEC.md) - Official SDK API reference
- [Reading Guide](docs/READING_GUIDE.md) - How to navigate the codebase

## Development

```bash
# Build
swift build

# Run tests
swift test

# Run specific test
swift test --filter ControlProtocolTests
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Fork of [jamesrochabrun/ClaudeCodeSDK](https://github.com/jamesrochabrun/ClaudeCodeSDK), completely rewritten for native Swift implementation with control protocol support.

---

*ClodKit - It's just a turf!*
