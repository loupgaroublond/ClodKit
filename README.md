# ClodKit

*"It's just a turf!"*

Pure Swift SDK for Claude Code, targeting API parity with official TypeScript and Python SDKs.

> **Renamed from ClodeMonster/ClaudeCodeSDK** - Same great SDK, fresh new name.

## Overview

ClodKit is a complete rewrite of the Swift SDK for Claude Code, implementing the control protocol for bidirectional communication with the Claude CLI. Unlike wrapper-based approaches, this SDK uses native Swift concurrency (actors, AsyncSequence) for thread-safe, streaming interactions.

## Features

- **Pure Swift** - Zero external dependencies, Swift 6.0+
- **Control Protocol** - Bidirectional JSON-RPC communication with Claude CLI
- **Streaming Responses** - AsyncSequence-based streaming via `AsyncThrowingStream`
- **Hook System** - Pre/post tool execution callbacks
- **MCP Integration** - SDK-provided MCP server routing
- **Permission Callbacks** - Dynamic tool authorization
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
let result = try await query(
    prompt: "Write a function to calculate Fibonacci numbers",
    options: QueryOptions(maxTurns: 5)
)

print(result.response)
```

### Streaming Responses

```swift
let queryHandle = try await query(
    prompt: "Explain async/await in Swift",
    options: QueryOptions()
)

// Stream messages as they arrive
for try await message in queryHandle.messages {
    switch message {
    case .text(let content):
        print(content, terminator: "")
    case .toolUse(let tool, let input):
        print("Using tool: \(tool)")
    case .result(let result):
        print("Final result: \(result)")
    }
}
```

### With Hooks

```swift
let options = QueryOptions(
    hooks: HookConfigs(
        preToolUse: { context in
            print("About to use tool: \(context.toolName)")
            return .proceed  // or .block(reason:) or .modify(input:)
        },
        postToolUse: { context in
            print("Tool \(context.toolName) completed")
        }
    )
)

let result = try await query(prompt: "Create a new file", options: options)
```

### With Permission Callbacks

```swift
let options = QueryOptions(
    permissionCallback: { request in
        // Dynamically approve/deny tool usage
        if request.toolName == "Bash" && request.input.contains("rm") {
            return .deny(reason: "Destructive commands not allowed")
        }
        return .allow
    }
)
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

## Implementation Status

**Working:**
- Core query API (single prompts, streaming responses)
- Control protocol (bidirectional JSON-RPC)
- Transport layer (subprocess abstraction)
- Session management (actor-based)
- Hook system (pre/post tool use)
- MCP server routing
- Permission callbacks
- Comprehensive test suite (28 files, 8700+ lines)

**Not yet implemented:**
- MCP tool builder DSL
- Query control methods (interrupt, rewind, setModel)
- Streaming input (AsyncSequence of user messages)
- Multi-turn conversation API
- Example applications

## Documentation

- [API Specification](docs/CLAUDE_AGENT_SDK_API_SPEC.md) - Official SDK API reference
- [Gap Analysis](docs/GAP_ANALYSIS.md) - Feature comparison with official SDKs
- [Reading Guide](docs/READING_GUIDE.md) - How to navigate the codebase
- [Implementation Reports](docs/reports/) - Development history and decisions

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
