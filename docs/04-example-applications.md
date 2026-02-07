# Example Applications

## Context

ClodKit has a fully functional SDK with no example code showing how to use it. The public API — `Clod.query()`, `QueryOptions`, `ClaudeQuery`, hooks, permissions, MCP tools — is well-tested internally, but a new user has to read test files to understand usage patterns. Example applications serve as both documentation and validation that the API is pleasant to use in real scenarios.

The gap analysis (v0.2.34) does not cover examples — this is entirely additive work. After gap remediation adds the V2 Session API and new message types, examples should demonstrate both the one-shot `query()` API and the multi-turn session API.

The examples should be executable Swift targets that run against a real Claude Code CLI installation. They should be self-contained, minimal, and each demonstrate a specific SDK capability. They live in an `Examples/` directory and are registered as `.executableTarget` entries in `Package.swift`.


## Example Applications to Build

### 1. SimpleQuery — Basic Prompt and Response

**Purpose:** The "hello world" of ClodKit. Send a single prompt, iterate the response stream, print the result.

**Demonstrates:**

- `Clod.query()` entry point
- `QueryOptions` with minimal configuration
- Iterating `ClaudeQuery` as an `AsyncSequence`
- Extracting text from `SDKMessage`
- Extracting the final result from the `result` message

**What it does:** Takes a prompt from command-line arguments (or uses a default), sends it to Claude, and prints the assistant's response text. Also prints the result summary (cost, tokens, duration).

**Key code patterns:**

```swift
@main struct SimpleQuery {
    static func main() async throws {
        let prompt = CommandLine.arguments.dropFirst().joined(separator: " ")
        var options = QueryOptions()
        options.permissionMode = .bypassPermissions
        options.maxTurns = 1

        let query = try await Clod.query(prompt, options: options)
        for try await message in query {
            switch message {
            case .regular(let msg) where msg.type == "assistant":
                // Print assistant text
            case .regular(let msg) where msg.type == "result":
                // Print summary
            default:
                break
            }
        }
    }
}
```

**File:** `Examples/SimpleQuery/main.swift`


### 2. ToolServer — SDK MCP Tool Registration

**Purpose:** Show how to register in-process MCP tools that Claude can call during execution.

**Demonstrates:**

- `SDKMCPServer` and `MCPTool` creation
- `JSONSchema` and `PropertySchema` for defining tool inputs
- Tool handler implementation
- Registering servers via `QueryOptions.sdkMcpServers`
- Observing tool use in the message stream

**What it does:** Registers two tools — a "weather" tool that returns fake weather data and a "calculator" tool that evaluates basic math. Sends a prompt asking Claude to use both tools, and prints the full interaction including tool calls and results.

**Key code patterns:**

```swift
let weatherTool = MCPTool(
    name: "get_weather",
    description: "Get current weather for a city",
    inputSchema: JSONSchema(
        properties: ["city": .string("City name")],
        required: ["city"]
    ),
    handler: { args in
        let city = args["city"] as? String ?? "Unknown"
        return .text("Weather in \(city): 72F, sunny")
    }
)

let server = SDKMCPServer(name: "demo_tools", tools: [weatherTool, calculatorTool])
var options = QueryOptions()
options.sdkMcpServers = ["demo_tools": server]
```

**File:** `Examples/ToolServer/main.swift`


### 3. HookDemo — Pre/Post Tool Use Hooks

**Purpose:** Show how to observe and control Claude's tool usage with hooks.

**Demonstrates:**

- `PreToolUseHookConfig` — inspect and optionally block tool calls before execution
- `PostToolUseHookConfig` — observe tool results after execution
- `StopHookConfig` — run logic when Claude finishes
- Pattern matching (hook only fires for specific tools)
- Hook output: approve, deny, modify input

**What it does:** Registers hooks that log every tool call Claude makes. The pre-tool-use hook blocks any `Bash` commands containing `rm` (safety guardrail). The post-tool-use hook prints a summary of each tool invocation. Sends a prompt that triggers multiple tool uses and shows the hooks firing.

**Key code patterns:**

```swift
options.preToolUseHooks = [
    PreToolUseHookConfig(pattern: "Bash", timeout: 10) { input in
        let command = input.toolInput["command"] as? String ?? ""
        if command.contains("rm ") {
            return HookOutput(decision: .block, reason: "Destructive commands blocked")
        }
        print("[Hook] Allowing Bash: \(command.prefix(60))")
        return HookOutput(decision: .approve)
    }
]
```

**File:** `Examples/HookDemo/main.swift`


### 4. PermissionCallback — Custom Permission Logic

**Purpose:** Show how to implement custom permission decisions programmatically.

**Demonstrates:**

- `CanUseToolCallback` — the permission callback
- `PermissionResult` — allow with modifications, deny with message
- `ToolPermissionContext` — suggestions from the CLI
- Dynamic permission rules based on tool name and input
- Using `--permission-prompt-tool stdio` (automatic when `canUseTool` is set)

**What it does:** Implements a permission callback that auto-approves Read and Glob, prompts the user (via stdin) for Write and Edit, and denies Bash commands that touch sensitive paths. Sends a prompt that triggers various tool uses and shows the permission decisions.

**Key code patterns:**

```swift
options.canUseTool = { toolName, input, context in
    switch toolName {
    case "Read", "Glob", "Grep":
        return .allowTool()
    case "Write", "Edit":
        print("Allow \(toolName) to \(input["file_path"] ?? "?")?  [y/n]")
        let answer = readLine()
        if answer == "y" { return .allowTool() }
        return .denyTool("User declined")
    default:
        return .denyTool("Tool not in allowlist")
    }
}
```

**File:** `Examples/PermissionCallback/main.swift`


### 5. StreamingOutput — Real-Time Response Display

**Purpose:** Show how to process the message stream in real-time, including partial messages and different message types.

**Demonstrates:**

- Processing every `StdoutMessage` variant
- Handling `system` (init) messages to capture session ID and model info
- Handling `assistant` messages to display text and tool use blocks
- Handling `result` messages to display cost and token usage
- Message type discrimination via `SDKMessage.type` and `SDKMessage.subtype`

**What it does:** Sends a prompt that produces a multi-step response (e.g., "Research and summarize the contents of this directory"). Prints each message type with colored prefixes, showing the full lifecycle of a query: init → assistant messages (with thinking, text, and tool use blocks) → result.

**Key code patterns:**

```swift
for try await message in query {
    switch message {
    case .regular(let msg):
        switch msg.type {
        case "system":
            print("[SYSTEM] Session: \(msg.data?...)")
        case "assistant":
            // Extract content blocks, print text and tool uses
        case "result":
            // Print cost, duration, turn count
        default:
            break
        }
    case .controlRequest, .controlResponse, .controlCancelRequest:
        // Not visible in normal flow
        break
    case .keepAlive:
        break
    }
}
```

**File:** `Examples/StreamingOutput/main.swift`


## Package.swift Changes

Add executable targets for each example:

```swift
targets: [
    .target(name: "ClodKit", dependencies: []),
    .testTarget(name: "ClodKitTests", dependencies: ["ClodKit"]),

    // Examples
    .executableTarget(name: "SimpleQuery", dependencies: ["ClodKit"], path: "Examples/SimpleQuery"),
    .executableTarget(name: "ToolServer", dependencies: ["ClodKit"], path: "Examples/ToolServer"),
    .executableTarget(name: "HookDemo", dependencies: ["ClodKit"], path: "Examples/HookDemo"),
    .executableTarget(name: "PermissionCallback", dependencies: ["ClodKit"], path: "Examples/PermissionCallback"),
    .executableTarget(name: "StreamingOutput", dependencies: ["ClodKit"], path: "Examples/StreamingOutput"),
]
```

Do NOT add the examples to `products` — they're development/documentation artifacts, not distributed libraries. Users building ClodKit as a dependency won't compile the examples.


## Implementation Guidelines

### Keep Examples Minimal

Each example should be a single `main.swift` file, under 150 lines. No helper utilities, no shared code between examples. If an example needs a helper, inline it. The goal is that someone can read one file and understand one feature.

### Error Handling

Examples should handle errors gracefully with clear messages:

```swift
do {
    let query = try await Clod.query(prompt, options: options)
    // ...
} catch {
    print("Error: \(error.localizedDescription)")
    // Suggest common fixes (CLI not installed, API key missing, etc.)
}
```

### CLI Availability Check

Each example should check that `claude` is available before trying to use it. A simple `Process` check or `which claude` via the shell works. Print a helpful message if the CLI isn't found:

```
Error: Claude CLI not found. Install it with: npm install -g @anthropic-ai/claude-code
```

### Command-Line Arguments

Where it makes sense, accept the prompt or configuration from command-line arguments. Use `CommandLine.arguments` directly — no argument-parsing libraries (zero dependencies).


### Output Formatting

Use plain text with clear section markers. No ANSI color codes (they don't render in all terminals). Use indentation and blank lines for structure:

```
--- Session Started ---
  Model: claude-sonnet-4-5-20250929
  Session ID: abc123

--- Assistant ---
  Hello! I'll help you with that.

--- Tool Use: Read ---
  file_path: ./Package.swift

--- Result ---
  Duration: 4.2s
  Cost: $0.012
  Turns: 2
```


## Files to Create

| File | Purpose |
|------|---------|
| `Examples/SimpleQuery/main.swift` | Basic prompt/response |
| `Examples/ToolServer/main.swift` | SDK MCP tool registration |
| `Examples/HookDemo/main.swift` | Pre/post tool use hooks |
| `Examples/PermissionCallback/main.swift` | Custom permission logic |
| `Examples/StreamingOutput/main.swift` | Real-time message processing |


## Files to Modify

| File | Change |
|------|--------|
| `Package.swift` | Add `.executableTarget` entries for each example |


## Verification

1. `swift build` — all targets compile (library + tests + examples)
2. `swift run SimpleQuery "What is 2+2?"` — runs and prints response
3. `swift run ToolServer` — runs, Claude calls the registered tools, output shows tool interactions
4. `swift run HookDemo` — runs, hooks fire and log, blocked commands show denial
5. `swift run PermissionCallback` — runs, permission callback is invoked for each tool
6. `swift run StreamingOutput` — runs, shows all message types in real-time
7. Each example runs in under 60 seconds with a simple prompt
8. Each example produces clear, readable output
9. Each example handles missing CLI gracefully
