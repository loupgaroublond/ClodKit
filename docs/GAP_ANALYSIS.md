# ClaudeCodeSDK Swift - Gap Analysis

This document identifies the differences between the official Claude Agent SDK (TypeScript/Python) and this Swift implementation, with recommendations for achieving API parity while maintaining Swift-native idioms.

---

## Executive Summary

The Swift SDK has a solid foundation with basic query functionality, MCP support, session management, and streaming. However, major features are missing:

| Category | Status | Priority |
|----------|--------|----------|
| Core Query API | Partial (~60%) | High |
| Hook System | Missing (0%) | High |
| Permission Callbacks | Missing (0%) | High |
| Content Block Types | Missing (0%) | Medium |
| Tool Definitions | Missing (0%) | Medium |
| Streaming Input | Missing (0%) | Medium |
| File Checkpointing | Missing (0%) | Low |
| Sandbox Configuration | Missing (0%) | Low |

---

## 1. Core Query API

### 1.1 Currently Implemented

```swift
// ✅ Basic query methods
func runSinglePrompt(prompt:outputFormat:options:) async throws -> ClaudeCodeResult
func continueConversation(prompt:outputFormat:options:) async throws -> ClaudeCodeResult
func resumeConversation(sessionId:prompt:outputFormat:options:) async throws -> ClaudeCodeResult
func runWithStdin(stdinContent:outputFormat:options:) async throws -> ClaudeCodeResult
func listSessions() async throws -> [SessionInfo]
func cancel()
```

### 1.2 Missing: Query Control Methods

The official SDK returns a `Query` object with dynamic control methods:

| Method | Description | Implementation Sketch |
|--------|-------------|----------------------|
| `interrupt()` | Interrupt during streaming input | Add to `ClaudeCode` protocol, forward to backend |
| `rewindFiles()` | Restore files to previous state | Requires file checkpointing; send message to CLI |
| `setPermissionMode()` | Change mode mid-execution | Send control message via stdin |
| `setModel()` | Switch model dynamically | Send control message via stdin |
| `setMaxThinkingTokens()` | Adjust thinking budget | Send control message via stdin |
| `supportedCommands()` | List slash commands | Query CLI for `system.init` message |
| `supportedModels()` | List available models | Query CLI with `--help` or dedicated endpoint |
| `mcpServerStatus()` | Check MCP connections | Parse from `system.init` message |
| `accountInfo()` | Get account details | Query CLI for account information |


### 1.3 Missing: Streaming Input

The official SDK accepts `AsyncIterable<SDKUserMessage>` for streaming prompts:

```typescript
// Official API
for await (const message of query({
  prompt: asyncUserMessageGenerator(),  // ← Streaming input
  options
})) { ... }
```

**Swift Implementation Sketch:**

```swift
// Proposed Swift API using AsyncSequence
public func query(
    messages: AsyncStream<UserMessage>,
    options: QueryOptions?
) -> AsyncThrowingStream<ResponseChunk, Error>

// Or with a more ergonomic builder pattern
let session = try await client.startSession(options: options)
for await response in session.send("Hello") {
    // Handle response
}
await session.send("Follow up")  // Multi-turn
await session.interrupt()
```


### 1.4 Missing: Custom MCP Tools

```typescript
// Official API
const myTool = tool("calculator", "Performs math", schema, handler)
const server = createSdkMcpServer({ name: "my-tools", tools: [myTool] })
```

**Swift Implementation Sketch:**

```swift
// Using result builders for Swift-native feel
@ToolBuilder
var calculatorTool: MCPTool {
    Tool("calculator", description: "Performs math") {
        Parameter("operation", type: .string, description: "The operation")
        Parameter("operands", type: .array(of: .number), description: "Numbers")
    } handler: { input in
        // Return result
    }
}

let server = MCPServer(name: "my-tools") {
    calculatorTool
    anotherTool
}
```

---

## 2. Hook System (Completely Missing)

The hook system is a major feature allowing interception of agent lifecycle events.

### 2.1 Hook Events to Implement

| Event | When Fired | Use Case |
|-------|------------|----------|
| `PreToolUse` | Before tool execution | Approve/deny/modify tool calls |
| `PostToolUse` | After tool execution | Log, validate results |
| `PostToolUseFailure` | After tool failure | Error handling |
| `UserPromptSubmit` | User sends message | Input validation |
| `Stop` | Agent stops | Cleanup |
| `SubagentStart` | Subagent spawns | Track subagents |
| `SubagentStop` | Subagent completes | Aggregate results |
| `PreCompact` | Before context compaction | Save important context |
| `PermissionRequest` | Permission needed | External notifications |
| `SessionStart` | Session begins | Setup |
| `SessionEnd` | Session ends | Teardown |
| `Notification` | Status updates | UI updates |


### 2.2 Swift Implementation Sketch

```swift
// Protocol-based hooks for type safety
public protocol ClaudeHook: Sendable {
    associatedtype Input
    associatedtype Output

    func handle(_ input: Input, toolUseID: String?) async throws -> Output
}

// Concrete hook types
public struct PreToolUseHook: ClaudeHook {
    public typealias Input = PreToolUseInput
    public typealias Output = HookDecision

    let matcher: Regex<Substring>?
    let handler: @Sendable (Input, String?) async throws -> Output
}

// Registration with Swift-native pattern matching
var options = QueryOptions()
options.hooks.onPreToolUse(matching: /Bash|Write/) { input, toolUseID in
    // Approve, deny, or modify
    return .allow(modifiedInput: input)
}

// Or with result builders
options.hooks {
    OnPreToolUse(matching: "Bash") { input in
        guard input.command.hasPrefix("safe-") else {
            return .deny(reason: "Only safe- commands allowed")
        }
        return .allow()
    }

    OnPostToolUse { input, result in
        logger.info("Tool \(input.toolName) completed")
        return .continue
    }
}
```


### 2.3 Hook Input/Output Types

```swift
public struct PreToolUseInput: Sendable {
    public let sessionID: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode
    public let toolName: String
    public let toolInput: [String: Any]
}

public enum HookDecision: Sendable {
    case `continue`
    case stop(reason: String)
    case allow(modifiedInput: [String: Any]? = nil)
    case deny(reason: String)
    case ask  // Defer to user
}

public struct HookOutput: Sendable {
    public var shouldContinue: Bool = true
    public var suppressOutput: Bool = false
    public var stopReason: String?
    public var systemMessage: String?
    public var permissionDecision: PermissionDecision?
    public var updatedInput: [String: Any]?
}
```

---

## 3. Permission System (Missing)

### 3.1 canUseTool Callback

The official SDK supports a callback for permission decisions:

```typescript
options: {
  canUseTool: async (toolName, input) => {
    if (toolName === "Bash") {
      return { behavior: "deny", message: "Bash not allowed" }
    }
    return { behavior: "allow", updatedInput: input }
  }
}
```

**Swift Implementation Sketch:**

```swift
// Closure-based (simple)
options.canUseTool = { toolName, input, context in
    switch toolName {
    case "Bash":
        return .deny(message: "Bash not allowed")
    case "Write" where input.filePath?.hasPrefix("/etc") == true:
        return .deny(message: "Cannot write to /etc")
    default:
        return .allow()
    }
}

// Or protocol-based (more structured)
public protocol ToolPermissionHandler: Sendable {
    func canUseTool(
        _ toolName: String,
        input: ToolInput,
        context: ToolPermissionContext
    ) async throws -> PermissionResult
}

public enum PermissionResult: Sendable {
    case allow(updatedInput: ToolInput? = nil, permissionUpdates: [PermissionUpdate]? = nil)
    case deny(message: String, interrupt: Bool = false)
}
```


### 3.2 AskUserQuestion Support

When Claude uses the `AskUserQuestion` tool, the SDK should surface this to the app:

```swift
// The canUseTool callback receives AskUserQuestion calls
options.canUseTool = { toolName, input, context in
    if toolName == "AskUserQuestion" {
        let questions = input.questions  // Parsed question data

        // Present to user via your UI
        let answers = await presentQuestionsToUser(questions)

        return .allow(updatedInput: ToolInput(
            questions: questions,
            answers: answers
        ))
    }
    return .allow()
}
```

---

## 4. Message & Content Types (Partial)

### 4.1 Currently Implemented

```swift
// ✅ Basic message types
ResponseChunk.initSystem(InitSystemMessage)
ResponseChunk.user(UserMessage)
ResponseChunk.assistant(AssistantMessage)
ResponseChunk.result(ResultMessage)
```

### 4.2 Missing Message Types

| Type | Purpose |
|------|---------|
| `StreamEvent` | Partial streaming events (when `includePartialMessages: true`) |
| `CompactBoundaryMessage` | Context compaction markers |


### 4.3 Missing Content Block Types

The official SDK has typed content blocks:

```swift
// Proposed Swift implementation
public enum ContentBlock: Sendable, Codable {
    case text(TextBlock)
    case thinking(ThinkingBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
}

public struct TextBlock: Sendable, Codable {
    public let type = "text"
    public let text: String
}

public struct ThinkingBlock: Sendable, Codable {
    public let type = "thinking"
    public let thinking: String
    public let signature: String
}

public struct ToolUseBlock: Sendable, Codable {
    public let type = "tool_use"
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]
}

public struct ToolResultBlock: Sendable, Codable {
    public let type = "tool_result"
    public let toolUseID: String
    public let content: ToolResultContent?
    public let isError: Bool?
}
```


### 4.4 Missing InitSystemMessage Fields

Current implementation is incomplete:

```swift
// Current
public struct InitSystemMessage: Codable {
    public let type: String
    public let subtype: String
    public let sessionId: String
    public let tools: [String]
    public let mcpServers: [MCPServer]
}

// Should include
public struct InitSystemMessage: Codable {
    // ... existing ...
    public let uuid: String
    public let apiKeySource: ApiKeySource
    public let cwd: String
    public let model: String
    public let permissionMode: PermissionMode
    public let slashCommands: [String]
    public let outputStyle: String?
}
```

---

## 5. Configuration Options (Gaps)

### 5.1 Missing Options

| Option | Official Name | Purpose |
|--------|---------------|---------|
| File checkpointing | `enableFileCheckpointing` | Track file changes for rewind |
| Plugins | `plugins` | Load SDK plugins |
| Structured output | `outputFormat` | JSON schema validation |
| Sandbox | `sandbox` | Sandbox configuration |
| Environment | `env` | Environment variables (separate from config) |
| Budget limit | `maxBudgetUsd` | Cost cap |
| Resume at | `resumeSessionAt` | Resume at specific message |


### 5.2 Sandbox Configuration

```swift
public struct SandboxSettings: Sendable, Codable {
    public var enabled: Bool = false
    public var autoAllowBashIfSandboxed: Bool = false
    public var excludedCommands: [String] = []
    public var allowUnsandboxedCommands: Bool = false
    public var network: NetworkSandboxSettings?
    public var ignoreViolations: SandboxIgnoreViolations?
    public var enableWeakerNestedSandbox: Bool = false
}

public struct NetworkSandboxSettings: Sendable, Codable {
    public var allowLocalBinding: Bool = false
    public var allowUnixSockets: [String] = []
    public var allowAllUnixSockets: Bool = false
    public var httpProxyPort: Int?
    public var socksProxyPort: Int?
}
```


### 5.3 Structured Output

```swift
// JSON Schema for validated output
public struct OutputFormat: Sendable, Codable {
    public let type: String = "json_schema"
    public let schema: JSONSchema
}

// Usage
options.outputFormat = OutputFormat(schema: MyResponseSchema.self)
```

---

## 6. Tool Input/Output Schemas (Missing)

The SDK should provide typed interfaces for built-in tools.

### 6.1 Tool Input Types

```swift
public enum ToolInput: Sendable {
    case bash(BashInput)
    case edit(EditInput)
    case write(WriteInput)
    case read(ReadInput)
    case glob(GlobInput)
    case grep(GrepInput)
    case task(TaskInput)
    case askUserQuestion(AskUserQuestionInput)
    case webSearch(WebSearchInput)
    case webFetch(WebFetchInput)
    // ... others
}

public struct BashInput: Sendable, Codable {
    public let command: String
    public let timeout: Int?
    public let description: String?
    public let runInBackground: Bool?
}

public struct TaskInput: Sendable, Codable {
    public let description: String
    public let prompt: String
    public let subagentType: String
}

public struct AskUserQuestionInput: Sendable, Codable {
    public let questions: [Question]
    public let answers: [String: String]?

    public struct Question: Sendable, Codable {
        public let question: String
        public let header: String
        public let options: [Option]
        public let multiSelect: Bool

        public struct Option: Sendable, Codable {
            public let label: String
            public let description: String
        }
    }
}
```


### 6.2 Tool Output Types

```swift
public enum ToolOutput: Sendable {
    case bash(BashOutput)
    case edit(EditOutput)
    case read(ReadOutput)
    // ... etc
}

public struct BashOutput: Sendable, Codable {
    public let output: String
    public let exitCode: Int
    public let killed: Bool?
    public let shellID: String?
}
```

---

## 7. Error Handling (Gaps)

### 7.1 Missing Result Subtypes

```swift
// Current ResultMessage.subtype is String
// Should be typed enum:
public enum ResultSubtype: String, Codable, Sendable {
    case success
    case errorMaxTurns = "error_max_turns"
    case errorDuringExecution = "error_during_execution"
    case errorMaxBudgetUsd = "error_max_budget_usd"
    case errorMaxStructuredOutputRetries = "error_max_structured_output_retries"
}
```


### 7.2 Missing Error Details

```swift
// Add to ResultMessage for error cases
public struct ResultMessage: Codable {
    // ... existing ...
    public let errors: [String]?  // Present on error subtypes
    public let permissionDenials: [PermissionDenial]?
    public let structuredOutput: AnyCodable?
}

public struct PermissionDenial: Codable, Sendable {
    public let toolName: String
    public let toolUseID: String
    public let toolInput: [String: AnyCodable]
}
```

---

## 8. Swift-Native Design Recommendations

### 8.1 Use AsyncSequence Instead of Combine

The current implementation uses Combine publishers. Modern Swift prefers `AsyncSequence`:

```swift
// Current (Combine-based)
case stream(AnyPublisher<ResponseChunk, Error>)

// Proposed (AsyncSequence-based)
public func query(prompt: String, options: QueryOptions?) -> AsyncThrowingStream<ResponseChunk, Error>

// Usage becomes more idiomatic
for try await chunk in client.query(prompt: "Hello") {
    switch chunk {
    case .assistant(let msg):
        print(msg.content)
    case .result(let result):
        print("Done: \(result.result)")
    }
}
```


### 8.2 Use Result Builders for Complex Configurations

```swift
// Instead of dictionary-based MCP config
@MCPConfigBuilder
var mcpServers: [String: MCPServerConfiguration] {
    MCPServer("github") {
        Command("npx")
        Args("-y", "@modelcontextprotocol/server-github")
        Environment {
            "GITHUB_TOKEN": ProcessInfo.processInfo.environment["GITHUB_TOKEN"]!
        }
    }

    MCPServer("filesystem") {
        Command("npx")
        Args("-y", "@modelcontextprotocol/server-filesystem", "/Users/me/projects")
    }
}
```


### 8.3 Use Property Wrappers for Validation

```swift
public struct QueryOptions {
    @Clamped(0...100) public var maxTurns: Int = 10
    @ValidUUID public var sessionID: String?
    @NonEmpty public var allowedTools: [String]?
}
```


### 8.4 Protocol-Oriented Message Handling

```swift
// Instead of switch statements, use protocol conformance
public protocol MessageHandler {
    func handle(_ message: InitSystemMessage) async
    func handle(_ message: AssistantMessage) async
    func handle(_ message: UserMessage) async
    func handle(_ message: ResultMessage) async
}

// Default implementations via extension
extension MessageHandler {
    func handle(_ message: InitSystemMessage) async { }
    func handle(_ message: UserMessage) async { }
}

// Usage
class MyHandler: MessageHandler {
    func handle(_ message: AssistantMessage) async {
        for block in message.content {
            switch block {
            case .text(let text):
                await updateUI(with: text.text)
            case .toolUse(let tool):
                await showToolUsage(tool)
            }
        }
    }

    func handle(_ message: ResultMessage) async {
        await showCompletion(message)
    }
}
```


### 8.5 Actor-Based Session Management

```swift
public actor ClaudeSession {
    private let client: ClaudeCodeClient
    private var sessionID: String?
    private var messageHistory: [ResponseChunk] = []

    public init(options: QueryOptions? = nil) async throws {
        self.client = try ClaudeCodeClient()
    }

    public func send(_ message: String) -> AsyncThrowingStream<ResponseChunk, Error> {
        // Manages session state automatically
    }

    public func interrupt() async {
        // Safe concurrent access
    }

    public var history: [ResponseChunk] {
        messageHistory
    }
}
```

---

## 9. Implementation Priorities

### Phase 1: Core Parity (High Priority)

1. **Hook System** - Most impactful missing feature
2. **Permission Callbacks** - Required for production use
3. **Content Block Types** - Better developer experience
4. **AsyncSequence Migration** - Modern Swift idiom


### Phase 2: Complete API (Medium Priority)

5. **Streaming Input** - Multi-turn conversations
6. **Query Control Methods** - `interrupt()`, `rewindFiles()`, etc.
7. **Tool Input/Output Types** - Type safety
8. **Full InitSystemMessage** - Complete initialization data


### Phase 3: Advanced Features (Lower Priority)

9. **Custom MCP Tools** - `tool()` and `createSdkMcpServer()`
10. **Sandbox Configuration** - Security features
11. **File Checkpointing** - File state management
12. **Structured Output** - JSON schema validation

---

## 10. Questions for Clarification

1. **Backend Strategy**: The SDK currently supports both "headless" (CLI `-p` flag) and "Agent SDK" (Node.js wrapper) backends. Should the Swift-native implementation:
   - Continue wrapping the Node.js SDK?
   - Implement direct API communication?
   - Support both via the existing backend abstraction?

2. **Streaming Architecture**: The current implementation uses Combine. Should we:
   - Migrate fully to `AsyncSequence`?
   - Support both for backward compatibility?
   - Provide adapters between the two?

3. **Hook Execution Context**: Hooks in the official SDK run in the Node.js process. For Swift:
   - Should hooks run in-process (more natural for Swift)?
   - Or communicate via IPC with the CLI (matches official behavior)?
   - What's the timeout expectation (official is 60 seconds)?

4. **MCP Tool Definitions**: The official SDK's `tool()` function uses Zod for schema definition. Should Swift:
   - Use Codable + Mirror for reflection?
   - Require explicit JSON Schema definitions?
   - Use a custom DSL with result builders?

5. **Error Handling Strategy**: Should errors be:
   - Thrown exceptions (current approach)?
   - Returned as `Result<T, Error>` types?
   - A hybrid based on error recoverability?

6. **SwiftUI Integration**: Is first-class SwiftUI support desired?
   - `@Observable` session state?
   - View modifiers for common patterns?
   - Preview support?

---

## 11. Rough Effort Estimates

| Feature | Complexity | Dependencies |
|---------|------------|--------------|
| Hook System | High | Message parsing, IPC |
| Permission Callbacks | Medium | Hook system |
| Content Block Types | Low | None |
| AsyncSequence Migration | Medium | Streaming refactor |
| Streaming Input | Medium | Session management |
| Query Control Methods | Medium | CLI communication |
| Tool Types | Low | Content blocks |
| Custom MCP Tools | High | MCP protocol impl |
| Sandbox Config | Low | CLI flags |
| Structured Output | Low | JSON Schema |

---

## Appendix: File Mapping

| Official Module | Swift File(s) |
|-----------------|---------------|
| `query()` | `ClaudeCode.swift`, `ClaudeCodeClient.swift` |
| Options | `ClaudeCodeOptions.swift` |
| Messages | `ResponseChunk.swift`, `AssistantMessage.swift`, etc. |
| MCP | `McpServerConfig.swift` |
| Subagents | `SubagentDefinition.swift` |
| Sessions | `SessionInfo.swift`, `ClaudeNativeSessionStorage.swift` |
| Permissions | `PermissionMode.swift` (enum only) |
| Hooks | **Not implemented** |
| Tool types | **Not implemented** |

---

# Part 2: Detailed Implementation Analysis

This section provides in-depth implementation thoughts for each gap identified above, with concrete approaches, tradeoffs, and code patterns.

---

## Implementation Analysis 1: Core Query API Completion

### 1.1 Query Object Architecture

**The Problem:**
The current Swift SDK returns `ClaudeCodeResult` which is either a final value or a Combine publisher. The official SDK returns a `Query` object that is both an async iterator AND has control methods like `interrupt()`, `setModel()`, etc.

**Deep Analysis:**

The fundamental architectural question is: how do we return something that is both a stream AND has methods? In TypeScript this is natural because `Query extends AsyncGenerator`. In Swift, we need to think differently.

**Option A: Separate Session Object**
```swift
// The query returns a stream, but you get control via the session
let session = try await client.createSession(options: options)
let stream = session.query(prompt: "Hello")

// Control methods on session
await session.interrupt()
await session.setModel("opus")

// Stream consumption
for try await chunk in stream { ... }
```

This separates concerns but requires two objects.

**Option B: Custom AsyncSequence with Methods**
```swift
// QueryStream is both AsyncSequence AND has control methods
public final class QueryStream: AsyncSequence, @unchecked Sendable {
    public typealias Element = ResponseChunk

    private let backend: ClaudeCodeBackend
    private let controlChannel: AsyncChannel<ControlMessage>
    private var iterator: AsyncThrowingStream<ResponseChunk, Error>.Iterator?

    public func interrupt() async {
        await controlChannel.send(.interrupt)
    }

    public func setModel(_ model: String) async {
        await controlChannel.send(.setModel(model))
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: underlyingStream, control: controlChannel)
    }
}
```

This is more faithful to the official API but requires careful concurrency design.

**Option C: Actor-based Unified Interface**
```swift
public actor ClaudeQuery {
    private var underlyingStream: AsyncThrowingStream<ResponseChunk, Error>
    private var continuation: AsyncThrowingStream<ResponseChunk, Error>.Continuation?

    // Expose stream as property
    public var responses: AsyncThrowingStream<ResponseChunk, Error> {
        underlyingStream
    }

    // Control methods
    public func interrupt() { ... }
    public func setModel(_ model: String) { ... }
}
```

**Recommendation:** Option B with careful design. It matches the official API most closely and Swift's `AsyncSequence` protocol is flexible enough to support this. The key insight is that the control methods don't return values from the stream—they send commands to the CLI process.

**Implementation Mechanics:**

1. The `QueryStream` holds a reference to the running `Process`
2. Control methods send signals/messages to stdin of the process
3. The official SDK uses a specific JSON protocol for control messages
4. We need to discover what that protocol looks like (likely `{"type": "control", "action": "interrupt"}` or similar)

**Investigation Needed:**
- What's the actual wire protocol for control messages?
- Does the CLI accept stdin messages mid-execution?
- Or do control methods work via signals (SIGINT, etc.)?


### 1.2 The `interrupt()` Method

**What it does:** Stops the current operation mid-stream, allowing you to send a new message.

**How the official SDK implements it:**
Looking at the docs, `interrupt()` is only available in "streaming input" mode where you pass an `AsyncIterable` for the prompt. It essentially cancels the current response generation.

**Swift Implementation:**

```swift
extension QueryStream {
    public func interrupt() async throws {
        // Option 1: Send SIGINT to the process
        process.interrupt()  // Process.interrupt() sends SIGINT

        // Option 2: Send a control message via stdin
        let controlMessage = #"{"type":"interrupt"}"# + "\n"
        if let data = controlMessage.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }

        // Option 3: Close stdin to signal end of input
        stdinPipe.fileHandleForWriting.closeFile()
    }
}
```

**Key Question:** Which approach does the CLI expect? This requires testing against the actual CLI.


### 1.3 The `rewindFiles()` Method

**What it does:** Restores files to the state they were in at a specific message UUID.

**Prerequisites:**
- `enableFileCheckpointing: true` must be set in options
- The CLI tracks file changes per message
- We need the UUID of the message to rewind to

**Implementation Approach:**

```swift
extension QueryStream {
    public func rewindFiles(to messageUUID: String) async throws {
        // This likely sends a control message to the CLI
        let message: [String: Any] = [
            "type": "control",
            "action": "rewind_files",
            "message_uuid": messageUUID
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: message)
        stdinPipe.fileHandleForWriting.write(jsonData)
        stdinPipe.fileHandleForWriting.write("\n".data(using: .utf8)!)

        // Wait for acknowledgment?
        // The response stream should contain a confirmation message
    }
}
```

**File Checkpointing Integration:**

For this to work, we need to:
1. Add `enableFileCheckpointing` to `ClaudeCodeOptions`
2. Store message UUIDs as they come in
3. Provide access to the message history (for the user to pick which UUID)

```swift
public struct ClaudeCodeOptions {
    // ... existing ...

    /// Enable file checkpointing for rewind support
    /// When enabled, file changes are tracked per message, allowing
    /// restoration to previous states via rewindFiles()
    public var enableFileCheckpointing: Bool = false
}
```


### 1.4 Dynamic Setters: `setModel()`, `setPermissionMode()`, `setMaxThinkingTokens()`

**Pattern Analysis:**

These all follow the same pattern: send a control message to modify runtime behavior.

```swift
extension QueryStream {
    public func setModel(_ model: String) async throws {
        try await sendControl(["action": "set_model", "model": model])
    }

    public func setPermissionMode(_ mode: PermissionMode) async throws {
        try await sendControl(["action": "set_permission_mode", "mode": mode.rawValue])
    }

    public func setMaxThinkingTokens(_ tokens: Int) async throws {
        try await sendControl(["action": "set_max_thinking_tokens", "value": tokens])
    }

    private func sendControl(_ payload: [String: Any]) async throws {
        var message = payload
        message["type"] = "control"

        let jsonData = try JSONSerialization.data(withJSONObject: message)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ClaudeCodeError.invalidConfiguration("Failed to encode control message")
        }

        stdinPipe.fileHandleForWriting.write((jsonString + "\n").data(using: .utf8)!)
    }
}
```


### 1.5 Query Methods: `supportedCommands()`, `supportedModels()`, `mcpServerStatus()`, `accountInfo()`

**Key Insight:** These don't send control messages—they query state that's already available from the `init` system message or from one-off CLI calls.

**Implementation Strategy:**

```swift
public final class QueryStream: AsyncSequence {
    // Cache data from init message
    private var initData: InitSystemMessage?

    /// Available slash commands (from init message)
    public var supportedCommands: [SlashCommand] {
        get async throws {
            if let cached = initData?.slashCommands {
                return cached
            }
            // Wait for init message if not yet received
            // This requires tracking state across the stream
            throw ClaudeCodeError.notInitialized
        }
    }

    /// MCP server connection status
    public var mcpServerStatus: [MCPServerStatus] {
        get async {
            initData?.mcpServers.map { MCPServerStatus(name: $0.name, status: $0.status) } ?? []
        }
    }
}
```

**For `supportedModels()` and `accountInfo()`:**

These might require separate CLI calls:
```swift
public func supportedModels() async throws -> [ModelInfo] {
    // Option 1: Parse from init message if available
    // Option 2: Run `claude --list-models` or similar
    // Option 3: Query a specific endpoint

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "claude --list-models --output-format json"]

    // ... execute and parse
}
```


### 1.6 Streaming Input (Bidirectional Communication)

**The Big Picture:**

The official SDK allows passing an `AsyncIterable<SDKUserMessage>` as the prompt. This enables:
- Multi-turn conversations within a single query
- Interruption and continuation
- Dynamic message injection

**Swift Architecture:**

```swift
// The prompt can be a string OR an async stream of messages
public enum QueryPrompt {
    case single(String)
    case stream(AsyncStream<UserMessage>)
}

public func query(
    prompt: QueryPrompt,
    options: QueryOptions?
) -> QueryStream {
    switch prompt {
    case .single(let text):
        // Send once, then close stdin
        return executeWithSinglePrompt(text, options: options)

    case .stream(let messageStream):
        // Keep stdin open, forward messages as they arrive
        return executeWithStreamingPrompt(messageStream, options: options)
    }
}

private func executeWithStreamingPrompt(
    _ messages: AsyncStream<UserMessage>,
    options: QueryOptions?
) -> QueryStream {
    let process = Process()
    // ... setup ...

    // Create bidirectional pipes
    let stdinPipe = Pipe()
    let stdoutPipe = Pipe()

    process.standardInput = stdinPipe
    process.standardOutput = stdoutPipe

    // Forward incoming messages to stdin
    Task {
        for await message in messages {
            let json = try JSONEncoder().encode(message)
            stdinPipe.fileHandleForWriting.write(json)
            stdinPipe.fileHandleForWriting.write("\n".data(using: .utf8)!)
        }
        // When stream ends, close stdin
        stdinPipe.fileHandleForWriting.closeFile()
    }

    // Return stream that reads from stdout
    return QueryStream(process: process, outputPipe: stdoutPipe)
}
```

**Ergonomic API with Continuation:**

```swift
// More Swift-native API using continuations
public func startSession(options: QueryOptions? = nil) async throws -> ClaudeSession {
    let session = ClaudeSession()
    await session.start(options: options)
    return session
}

public actor ClaudeSession {
    private var inputContinuation: AsyncStream<UserMessage>.Continuation?
    private var queryStream: QueryStream?

    public func send(_ message: String) -> AsyncThrowingStream<ResponseChunk, Error> {
        inputContinuation?.yield(UserMessage(content: message))
        // Return filtered stream of responses to this message
        return filterResponses(for: message)
    }

    public func interrupt() {
        queryStream?.interrupt()
    }
}
```

---

## Implementation Analysis 2: Hook System

### 2.1 Understanding the Hook Architecture

**How hooks work in the official SDK:**

1. You register hook callbacks in options
2. When the CLI encounters a hookable event, it pauses execution
3. It sends a JSON message describing the event to your callback
4. Your callback runs and returns a decision
5. The CLI resumes based on your decision

**The Critical Question:** How does the CLI communicate with hook callbacks?

**Option A: In-Process (Node.js SDK approach)**
The Node.js SDK runs hooks in the same process. The SDK intercepts messages from the CLI and invokes callbacks directly.

**Option B: External Process (CLI hooks approach)**
The CLI's hook system (`~/.claude/settings.json` hooks) runs external commands and reads their stdout.

**Option C: IPC Protocol**
The CLI sends hook events via a channel and waits for responses.

**For Swift, Option A is most natural** because:
- Hooks run in Swift, not as external processes
- We're already parsing the stream in Swift
- We can intercept before forwarding to the user

**Implementation Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│                     Swift SDK Process                        │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────┐ │
│  │   Backend   │───▶│ Hook Router  │───▶│  User Handler  │ │
│  │  (Process)  │    │              │    │                │ │
│  │             │◀───│  (intercept  │◀───│  (returns      │ │
│  │             │    │   & resume)  │    │   decision)    │ │
│  └─────────────┘    └──────────────┘    └────────────────┘ │
│         │                  │                     │          │
│         ▼                  ▼                     ▼          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              User's AsyncSequence consumption        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```


### 2.2 Hook Event Detection

**Key Insight:** We need to detect hook-triggering events in the message stream before forwarding them to the user.

```swift
internal actor HookRouter {
    private let hooks: HookConfiguration
    private var pendingToolUses: [String: ToolUseBlock] = [:]

    func process(_ chunk: ResponseChunk) async throws -> HookRouterResult {
        switch chunk {
        case .assistant(let msg):
            // Check for tool_use blocks that need PreToolUse hooks
            for block in msg.content {
                if case .toolUse(let toolUse) = block {
                    if let preHook = hooks.preToolUse(matching: toolUse.name) {
                        // Invoke hook and get decision
                        let decision = try await invokePreToolUse(
                            hook: preHook,
                            toolUse: toolUse,
                            sessionID: msg.sessionId
                        )

                        switch decision {
                        case .allow(let modifiedInput):
                            // Continue with possibly modified input
                            return .continue(modifyingToolInput: modifiedInput)
                        case .deny(let reason):
                            // Block this tool use
                            return .blockTool(toolUse.id, reason: reason)
                        case .ask:
                            // Defer to permission system
                            return .deferToPermission(toolUse)
                        }
                    }
                }
            }
            return .passthrough(chunk)

        case .result(let result):
            // Fire Stop hook
            if let stopHook = hooks.stop {
                try await invokeStopHook(stopHook, result: result)
            }
            return .passthrough(chunk)

        // ... other cases
        }
    }
}
```


### 2.3 Hook Types and Their Signatures

Let's define each hook type precisely:

```swift
// MARK: - Hook Event Types

/// Input provided to PreToolUse hooks
public struct PreToolUseInput: Sendable {
    public let sessionID: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode
    public let toolName: String
    public let toolInput: ToolInputData

    /// Typed access to tool input based on tool name
    public var typedInput: TypedToolInput? {
        TypedToolInput.from(name: toolName, data: toolInput)
    }
}

/// Input provided to PostToolUse hooks
public struct PostToolUseInput: Sendable {
    public let sessionID: String
    public let transcriptPath: String
    public let cwd: String
    public let permissionMode: PermissionMode
    public let toolName: String
    public let toolInput: ToolInputData
    public let toolResponse: ToolOutputData
}

/// Input for PostToolUseFailure (TypeScript-only in official SDK)
public struct PostToolUseFailureInput: Sendable {
    public let sessionID: String
    public let toolName: String
    public let toolInput: ToolInputData
    public let error: String
    public let isInterrupt: Bool
}

/// Input for UserPromptSubmit
public struct UserPromptSubmitInput: Sendable {
    public let sessionID: String
    public let prompt: String
}

/// Input for SubagentStop
public struct SubagentStopInput: Sendable {
    public let sessionID: String
    public let agentID: String
    public let stopHookActive: Bool
    public let agentTranscriptPath: String
}

/// Input for PreCompact
public struct PreCompactInput: Sendable {
    public let sessionID: String
    public let trigger: String
    public let customInstructions: String?
}

/// Input for PermissionRequest
public struct PermissionRequestInput: Sendable {
    public let sessionID: String
    public let toolName: String
    public let toolInput: ToolInputData
    public let permissionSuggestions: [PermissionSuggestion]
}

/// Input for Notification
public struct NotificationInput: Sendable {
    public let sessionID: String
    public let message: String
    public let notificationType: NotificationType
    public let title: String?
}
```


### 2.4 Hook Registration API

**Closure-Based (Simple):**

```swift
public struct HookConfiguration {
    public var preToolUse: [HookMatcher<PreToolUseInput, PreToolUseDecision>] = []
    public var postToolUse: [HookMatcher<PostToolUseInput, PostToolUseDecision>] = []
    public var stop: ((_ input: StopInput) async throws -> StopDecision)?
    // ... etc

    public mutating func onPreToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60,
        handler: @escaping @Sendable (PreToolUseInput) async throws -> PreToolUseDecision
    ) {
        preToolUse.append(HookMatcher(
            pattern: pattern.map { try! Regex($0) },
            timeout: timeout,
            handler: handler
        ))
    }
}

public struct HookMatcher<Input, Output>: Sendable {
    let pattern: Regex<Substring>?
    let timeout: TimeInterval
    let handler: @Sendable (Input) async throws -> Output

    func matches(toolName: String) -> Bool {
        guard let pattern else { return true }  // nil = match all
        return toolName.contains(pattern)
    }
}
```

**Result Builder (Expressive):**

```swift
@resultBuilder
public struct HookBuilder {
    public static func buildBlock(_ components: AnyHook...) -> [AnyHook] {
        components
    }
}

public struct OnPreToolUse: AnyHook {
    let matcher: HookMatcher<PreToolUseInput, PreToolUseDecision>

    public init(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60,
        handler: @escaping @Sendable (PreToolUseInput) async throws -> PreToolUseDecision
    ) {
        self.matcher = HookMatcher(
            pattern: pattern.map { try! Regex($0) },
            timeout: timeout,
            handler: handler
        )
    }
}

// Usage
let options = QueryOptions {
    OnPreToolUse(matching: "Bash") { input in
        guard !input.typedInput?.bash?.command.contains("rm -rf") else {
            return .deny(reason: "Dangerous command blocked")
        }
        return .allow()
    }

    OnPostToolUse { input, output in
        logger.info("Tool \(input.toolName) completed")
        return .continue
    }

    OnNotification { notification in
        await notificationCenter.post(notification)
        return .continue
    }
}
```


### 2.5 Hook Decision Types

```swift
/// Decision returned from PreToolUse hooks
public enum PreToolUseDecision: Sendable {
    /// Allow the tool to execute
    case allow

    /// Allow with modified input
    case allow(modifiedInput: ToolInputData)

    /// Deny the tool execution
    case deny(reason: String)

    /// Defer to the permission system (triggers canUseTool callback)
    case ask

    /// Stop the entire query
    case stop(reason: String)
}

/// Decision returned from PostToolUse hooks
public enum PostToolUseDecision: Sendable {
    /// Continue normal execution
    case `continue`

    /// Inject a system message
    case `continue`(systemMessage: String)

    /// Stop the query
    case stop(reason: String)
}

/// Generic hook output matching official SDK structure
public struct HookOutput: Sendable, Codable {
    public var shouldContinue: Bool = true
    public var suppressOutput: Bool = false
    public var stopReason: String?
    public var systemMessage: String?
    public var reason: String?  // Feedback for Claude

    // PreToolUse specific
    public var permissionDecision: PermissionDecision?
    public var updatedInput: [String: AnyCodable]?
}

public enum PermissionDecision: String, Sendable, Codable {
    case allow
    case deny
    case ask
}
```


### 2.6 Timeout Handling

**Critical:** Hooks have a 60-second timeout in the official SDK.

```swift
internal func invokeHook<Input, Output>(
    _ hook: HookMatcher<Input, Output>,
    input: Input
) async throws -> Output {
    try await withThrowingTaskGroup(of: Output.self) { group in
        // The actual hook
        group.addTask {
            try await hook.handler(input)
        }

        // Timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(hook.timeout))
            throw HookError.timeout(after: hook.timeout)
        }

        // Return first to complete (hook result or timeout)
        guard let result = try await group.next() else {
            throw HookError.unexpectedState
        }

        // Cancel the other task
        group.cancelAll()

        return result
    }
}
```


### 2.7 Communicating Hook Decisions Back to CLI

**The Challenge:** When we make a hook decision in Swift, how does the CLI know about it?

**Approach 1: Stream Interception Only**

For `PostToolUse` and `Notification` hooks, we might not need to communicate back—we're just observing.

**Approach 2: Stdin Response Protocol**

For `PreToolUse`, we need to tell the CLI our decision:

```swift
func sendHookDecision(_ decision: PreToolUseDecision, for toolUseID: String) throws {
    let response: [String: Any]

    switch decision {
    case .allow:
        response = [
            "type": "hook_response",
            "tool_use_id": toolUseID,
            "decision": "allow"
        ]
    case .allow(let modifiedInput):
        response = [
            "type": "hook_response",
            "tool_use_id": toolUseID,
            "decision": "allow",
            "updated_input": modifiedInput
        ]
    case .deny(let reason):
        response = [
            "type": "hook_response",
            "tool_use_id": toolUseID,
            "decision": "deny",
            "reason": reason
        ]
    // ... etc
    }

    let json = try JSONSerialization.data(withJSONObject: response)
    stdinPipe.fileHandleForWriting.write(json)
    stdinPipe.fileHandleForWriting.write("\n".data(using: .utf8)!)
}
```

**Investigation Required:** What's the actual protocol? The official SDK likely has this implemented in the Node.js wrapper. We'd need to:
1. Read the official SDK source
2. Or trace the wire protocol
3. Or test empirically

---

## Implementation Analysis 3: Permission System

### 3.1 Understanding `canUseTool`

**What it does:** Provides a callback that's invoked when Claude wants to use a tool that isn't auto-approved.

**When it's called:**
- When a tool isn't in `allowedTools`
- When `permissionMode` isn't `bypassPermissions`
- When the `PreToolUse` hook returns `.ask`

**Relationship to Hooks:**
`canUseTool` is like a specialized hook for permission decisions. It's separate from the hook system but serves a similar interception purpose.


### 3.2 Implementation Approach

```swift
/// Protocol for handling tool permission requests
public protocol ToolPermissionHandler: Sendable {
    func canUseTool(
        _ toolName: String,
        input: ToolInputData,
        context: ToolPermissionContext
    ) async throws -> PermissionResult
}

/// Context provided to permission handlers
public struct ToolPermissionContext: Sendable {
    public let sessionID: String
    public let suggestions: [PermissionUpdate]

    // Access to cancel the request
    public let signal: CancellationSignal
}

/// Result of a permission check
public enum PermissionResult: Sendable {
    case allow(updatedInput: ToolInputData? = nil, permissionUpdates: [PermissionUpdate]? = nil)
    case deny(message: String, interrupt: Bool = false)
}

/// Updates to permission rules
public struct PermissionUpdate: Sendable {
    public enum UpdateType {
        case addRules([PermissionRule])
        case replaceRules([PermissionRule])
        case removeRules([PermissionRule])
        case setMode(PermissionMode)
        case addDirectories([String])
        case removeDirectories([String])
    }

    public let type: UpdateType
    public let destination: SettingDestination
}

public enum SettingDestination: String, Sendable {
    case userSettings
    case projectSettings
    case localSettings
    case session
}
```


### 3.3 Closure-Based API (Simple)

```swift
public struct QueryOptions {
    /// Callback for tool permission checks
    public var canUseTool: (@Sendable (
        _ toolName: String,
        _ input: ToolInputData,
        _ context: ToolPermissionContext
    ) async throws -> PermissionResult)?
}

// Usage
options.canUseTool = { toolName, input, context in
    switch toolName {
    case "Bash":
        // Check the command
        if let command = input["command"] as? String,
           command.hasPrefix("rm ") {
            return .deny(message: "Delete commands require explicit approval")
        }
        return .allow()

    case "Write":
        // Check the path
        if let path = input["file_path"] as? String,
           path.hasPrefix("/etc/") {
            return .deny(message: "Cannot write to system directories")
        }
        return .allow()

    case "AskUserQuestion":
        // This is Claude asking a clarifying question
        // Present to user and return their answer
        let questions = try parseQuestions(from: input)
        let answers = await presentQuestionsToUser(questions)
        return .allow(updatedInput: input.merging(["answers": answers]))

    default:
        return .allow()
    }
}
```


### 3.4 AskUserQuestion Special Handling

**The Pattern:** When `canUseTool` receives `"AskUserQuestion"`, Claude is asking the user for clarification. Your app should:

1. Parse the questions from input
2. Present them to the user (via UI)
3. Collect answers
4. Return the answers in `updatedInput`

```swift
/// Helper for handling AskUserQuestion
public struct AskUserQuestionHelper {
    public static func parseQuestions(from input: ToolInputData) throws -> [Question] {
        guard let questionsData = input["questions"] as? [[String: Any]] else {
            throw ClaudeCodeError.invalidToolInput("Missing questions array")
        }

        return try questionsData.map { q in
            Question(
                text: q["question"] as? String ?? "",
                header: q["header"] as? String ?? "",
                options: (q["options"] as? [[String: Any]] ?? []).map { opt in
                    Question.Option(
                        label: opt["label"] as? String ?? "",
                        description: opt["description"] as? String ?? ""
                    )
                },
                multiSelect: q["multiSelect"] as? Bool ?? false
            )
        }
    }

    public static func formatAnswers(
        _ answers: [String: String],
        for questions: [Question]
    ) -> ToolInputData {
        [
            "questions": questions.map { $0.toDictionary() },
            "answers": answers
        ]
    }
}

public struct Question: Sendable {
    public let text: String
    public let header: String
    public let options: [Option]
    public let multiSelect: Bool

    public struct Option: Sendable {
        public let label: String
        public let description: String
    }
}
```


### 3.5 SwiftUI Integration for Permissions

```swift
/// SwiftUI view modifier for permission handling
public struct PermissionHandlerModifier: ViewModifier {
    @Binding var pendingPermission: PendingPermission?
    let handler: (PermissionResult) -> Void

    public func body(content: Content) -> some View {
        content
            .sheet(item: $pendingPermission) { permission in
                PermissionRequestView(
                    permission: permission,
                    onDecision: { result in
                        handler(result)
                        pendingPermission = nil
                    }
                )
            }
    }
}

public struct PermissionRequestView: View {
    let permission: PendingPermission
    let onDecision: (PermissionResult) -> Void

    public var body: some View {
        VStack {
            Text("Claude wants to use: \(permission.toolName)")
                .font(.headline)

            // Show tool-specific details
            switch permission.toolName {
            case "Bash":
                BashPermissionDetail(input: permission.input)
            case "Write":
                WritePermissionDetail(input: permission.input)
            case "AskUserQuestion":
                QuestionAnswerView(input: permission.input, onAnswer: { answers in
                    onDecision(.allow(updatedInput: permission.input.merging(["answers": answers])))
                })
            default:
                GenericPermissionDetail(input: permission.input)
            }

            HStack {
                Button("Deny") {
                    onDecision(.deny(message: "User denied"))
                }
                Button("Allow") {
                    onDecision(.allow())
                }
            }
        }
    }
}
```

---

## Implementation Analysis 4: Message & Content Types

### 4.1 Content Block Architecture

**The Problem:** The current SDK uses SwiftAnthropic's `MessageResponse` type, but we need our own typed content blocks for SDK-specific features.

**Design Decision:** Create SDK-specific types that can wrap or convert from SwiftAnthropic types.

```swift
/// Content block types matching the official SDK
public enum ContentBlock: Sendable, Codable, Equatable {
    case text(TextBlock)
    case thinking(ThinkingBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case image(ImageBlock)  // For multimodal

    // Custom decoding based on "type" field
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "thinking":
            self = .thinking(try ThinkingBlock(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "tool_result":
            self = .toolResult(try ToolResultBlock(from: decoder))
        case "image":
            self = .image(try ImageBlock(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }
}
```


### 4.2 Individual Block Types

```swift
public struct TextBlock: Sendable, Codable, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct ThinkingBlock: Sendable, Codable, Equatable {
    public let thinking: String
    public let signature: String

    public init(thinking: String, signature: String) {
        self.thinking = thinking
        self.signature = signature
    }
}

public struct ToolUseBlock: Sendable, Codable, Equatable {
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]

    /// Typed access to input based on tool name
    public func typedInput<T: ToolInputType>() throws -> T where T.ToolName == Self {
        try T.decode(from: input)
    }

    public init(id: String, name: String, input: [String: AnyCodable]) {
        self.id = id
        self.name = name
        self.input = input
    }
}

public struct ToolResultBlock: Sendable, Codable, Equatable {
    public let toolUseId: String
    public let content: ToolResultContent?
    public let isError: Bool?

    public init(toolUseId: String, content: ToolResultContent?, isError: Bool? = nil) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Tool result can be text, images, or mixed
public enum ToolResultContent: Sendable, Codable, Equatable {
    case text(String)
    case blocks([ContentBlock])
}

public struct ImageBlock: Sendable, Codable, Equatable {
    public let source: ImageSource

    public enum ImageSource: Sendable, Codable, Equatable {
        case base64(mediaType: String, data: String)
        case url(String)
    }
}
```


### 4.3 AnyCodable Implementation

**The Challenge:** Tool inputs can have arbitrary JSON structure. Swift's strong typing needs a flexible container.

```swift
/// Type-erased Codable value for arbitrary JSON
public struct AnyCodable: Sendable, Codable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: [], debugDescription: "Cannot encode \(type(of: value))")
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Deep equality comparison
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case (let l as Bool, let r as Bool):
            return l == r
        case (let l as Int, let r as Int):
            return l == r
        case (let l as Double, let r as Double):
            return l == r
        case (let l as String, let r as String):
            return l == r
        case (let l as [Any], let r as [Any]):
            return l.count == r.count && zip(l, r).allSatisfy {
                AnyCodable($0) == AnyCodable($1)
            }
        case (let l as [String: Any], let r as [String: Any]):
            guard l.count == r.count else { return false }
            for (key, lValue) in l {
                guard let rValue = r[key], AnyCodable(lValue) == AnyCodable(rValue) else {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
}
```


### 4.4 StreamEvent for Partial Messages

```swift
/// Partial streaming event (when includePartialMessages is true)
public struct StreamEvent: Sendable, Codable {
    public let type: String  // "stream_event"
    public let event: RawStreamEvent
    public let parentToolUseId: String?
    public let uuid: String
    public let sessionId: String
}

/// Raw stream event from the API
public enum RawStreamEvent: Sendable, Codable {
    case messageStart(MessageStartEvent)
    case contentBlockStart(ContentBlockStartEvent)
    case contentBlockDelta(ContentBlockDeltaEvent)
    case contentBlockStop(ContentBlockStopEvent)
    case messageEnd(MessageEndEvent)

    public struct MessageStartEvent: Sendable, Codable {
        public let message: PartialMessage
    }

    public struct ContentBlockStartEvent: Sendable, Codable {
        public let index: Int
        public let contentBlock: ContentBlock
    }

    public struct ContentBlockDeltaEvent: Sendable, Codable {
        public let index: Int
        public let delta: ContentDelta
    }

    public struct ContentBlockStopEvent: Sendable, Codable {
        public let index: Int
    }

    public struct MessageEndEvent: Sendable, Codable {
        // Empty in most cases
    }
}

/// Delta for streaming content
public enum ContentDelta: Sendable, Codable {
    case textDelta(text: String)
    case thinkingDelta(thinking: String)
    case inputJsonDelta(partialJson: String)
}
```


### 4.5 CompactBoundaryMessage

```swift
/// Marks context compaction events
public struct CompactBoundaryMessage: Sendable, Codable {
    public let type: String  // "system"
    public let subtype: String  // "compact_boundary"
    public let uuid: String
    public let sessionId: String
    public let compactMetadata: CompactMetadata

    public struct CompactMetadata: Sendable, Codable {
        public let trigger: String
        public let preTokens: Int
    }
}
```


### 4.6 Updated ResponseChunk

```swift
/// All possible message types in the response stream
public enum ResponseChunk: Sendable {
    case system(SystemMessage)
    case user(UserMessage)
    case assistant(AssistantMessage)
    case result(ResultMessage)
    case streamEvent(StreamEvent)  // New: partial streaming
    case compactBoundary(CompactBoundaryMessage)  // New: compaction

    public var sessionId: String {
        switch self {
        case .system(let msg): return msg.sessionId
        case .user(let msg): return msg.sessionId
        case .assistant(let msg): return msg.sessionId
        case .result(let msg): return msg.sessionId
        case .streamEvent(let event): return event.sessionId
        case .compactBoundary(let msg): return msg.sessionId
        }
    }

    public var uuid: String? {
        switch self {
        case .system(let msg): return msg.uuid
        case .user(let msg): return msg.uuid
        case .assistant(let msg): return msg.uuid
        case .result(let msg): return msg.uuid
        case .streamEvent(let event): return event.uuid
        case .compactBoundary(let msg): return msg.uuid
        }
    }
}

/// Unified system message type
public enum SystemMessage: Sendable, Codable {
    case `init`(InitSystemMessage)
    case compactBoundary(CompactBoundaryMessage)

    public var sessionId: String {
        switch self {
        case .`init`(let msg): return msg.sessionId
        case .compactBoundary(let msg): return msg.sessionId
        }
    }

    public var uuid: String {
        switch self {
        case .`init`(let msg): return msg.uuid
        case .compactBoundary(let msg): return msg.uuid
        }
    }
}
```


### 4.7 Complete InitSystemMessage

```swift
/// Full init message with all fields from official SDK
public struct InitSystemMessage: Sendable, Codable {
    public let type: String  // "system"
    public let subtype: String  // "init"
    public let uuid: String
    public let sessionId: String

    // Environment
    public let cwd: String
    public let apiKeySource: ApiKeySource

    // Capabilities
    public let tools: [String]
    public let mcpServers: [MCPServerInfo]
    public let slashCommands: [String]

    // Configuration
    public let model: String
    public let permissionMode: PermissionMode
    public let outputStyle: String?

    public struct MCPServerInfo: Sendable, Codable {
        public let name: String
        public let status: MCPServerStatus
        public let serverInfo: ServerInfo?

        public struct ServerInfo: Sendable, Codable {
            public let name: String
            public let version: String
        }
    }
}

public enum MCPServerStatus: String, Sendable, Codable {
    case connected
    case failed
    case needsAuth = "needs-auth"
    case pending
}
```

---

## Implementation Analysis 5: Configuration Options

### 5.1 Missing Options Implementation

```swift
extension ClaudeCodeOptions {
    // MARK: - File Management

    /// Enable file checkpointing for rewind support
    /// CLI flag: --enable-file-checkpointing
    public var enableFileCheckpointing: Bool = false

    // MARK: - Cost Control

    /// Maximum budget in USD for this query
    /// CLI flag: --max-budget-usd
    public var maxBudgetUsd: Double?

    // MARK: - Session Management

    /// Resume at a specific message UUID (not just session)
    /// CLI flag: --resume-session-at
    public var resumeSessionAt: String?

    // MARK: - Plugins

    /// Plugin configurations to load
    public var plugins: [PluginConfig]?

    // MARK: - Structured Output

    /// JSON schema for validated output
    public var outputFormat: OutputFormat?

    // MARK: - Sandbox

    /// Sandbox configuration
    public var sandbox: SandboxSettings?

    // MARK: - Environment (per-query override)

    /// Environment variables specific to this query
    /// Merged with configuration.environment
    public var env: [String: String]?
}

public struct PluginConfig: Sendable, Codable {
    public let type: PluginType
    public let path: String

    public enum PluginType: String, Sendable, Codable {
        case local
    }

    public init(localPath: String) {
        self.type = .local
        self.path = localPath
    }
}
```


### 5.2 Sandbox Settings

```swift
public struct SandboxSettings: Sendable, Codable {
    /// Enable sandbox mode
    public var enabled: Bool = false

    /// Auto-approve bash commands when sandboxed
    public var autoAllowBashIfSandboxed: Bool = false

    /// Commands that bypass the sandbox
    public var excludedCommands: [String] = []

    /// Allow model to request unsandboxed execution
    public var allowUnsandboxedCommands: Bool = false

    /// Network sandbox configuration
    public var network: NetworkSandboxSettings?

    /// Violations to ignore
    public var ignoreViolations: SandboxIgnoreViolations?

    /// Compatibility mode for nested sandboxing
    public var enableWeakerNestedSandbox: Bool = false

    public init() {}
}

public struct NetworkSandboxSettings: Sendable, Codable {
    /// Allow binding to local ports
    public var allowLocalBinding: Bool = false

    /// Specific Unix sockets to allow
    public var allowUnixSockets: [String] = []

    /// Allow all Unix sockets
    public var allowAllUnixSockets: Bool = false

    /// HTTP proxy port (for outbound HTTP)
    public var httpProxyPort: Int?

    /// SOCKS proxy port
    public var socksProxyPort: Int?

    public init() {}
}

public struct SandboxIgnoreViolations: Sendable, Codable {
    /// File path patterns to ignore
    public var file: [String]?

    /// Network patterns to ignore
    public var network: [String]?

    public init() {}
}
```


### 5.3 Structured Output

```swift
/// Output format configuration for structured responses
public struct OutputFormat: Sendable, Codable {
    public let type: String = "json_schema"
    public let schema: JSONSchema

    public init(schema: JSONSchema) {
        self.schema = schema
    }

    /// Create from a Codable type using reflection
    public static func from<T: Codable>(_ type: T.Type) -> OutputFormat {
        // Generate JSON Schema from type
        let schema = JSONSchema.generate(from: type)
        return OutputFormat(schema: schema)
    }
}

/// JSON Schema representation
public struct JSONSchema: Sendable, Codable {
    public let type: String
    public let properties: [String: PropertySchema]?
    public let required: [String]?
    public let items: PropertySchema?  // For arrays
    public let additionalProperties: Bool?

    public struct PropertySchema: Sendable, Codable {
        public let type: String
        public let description: String?
        public let `enum`: [String]?
        public let properties: [String: PropertySchema]?
        public let items: PropertySchema?
    }

    /// Generate schema from Codable type (simplified)
    public static func generate<T: Codable>(from type: T.Type) -> JSONSchema {
        // Use Mirror or macros for reflection
        // This is a simplified placeholder
        return JSONSchema(
            type: "object",
            properties: nil,
            required: nil,
            items: nil,
            additionalProperties: nil
        )
    }
}
```


### 5.4 Command Argument Generation

Update `toCommandArgs()` to include new options:

```swift
extension ClaudeCodeOptions {
    internal func toCommandArgs() -> [String] {
        var args: [String] = []

        // ... existing args ...

        // File checkpointing
        if enableFileCheckpointing {
            args.append("--enable-file-checkpointing")
        }

        // Budget limit
        if let maxBudgetUsd = maxBudgetUsd {
            args.append("--max-budget-usd")
            args.append(String(maxBudgetUsd))
        }

        // Resume at specific message
        if let resumeSessionAt = resumeSessionAt {
            args.append("--resume-session-at")
            args.append(resumeSessionAt)
        }

        // Plugins
        if let plugins = plugins {
            for plugin in plugins {
                args.append("--plugin")
                args.append(plugin.path)
            }
        }

        // Structured output
        if let outputFormat = outputFormat {
            args.append("--output-format")
            args.append("json_schema")
            args.append("--json-schema")
            if let schemaJson = try? JSONEncoder().encode(outputFormat.schema),
               let schemaString = String(data: schemaJson, encoding: .utf8) {
                args.append(shellEscape(schemaString))
            }
        }

        // Sandbox
        if let sandbox = sandbox, sandbox.enabled {
            args.append("--sandbox")

            if sandbox.autoAllowBashIfSandboxed {
                args.append("--auto-allow-bash-if-sandboxed")
            }

            for cmd in sandbox.excludedCommands {
                args.append("--sandbox-exclude")
                args.append(cmd)
            }

            if sandbox.allowUnsandboxedCommands {
                args.append("--allow-unsandboxed-commands")
            }

            // Network settings
            if let network = sandbox.network {
                if network.allowLocalBinding {
                    args.append("--sandbox-allow-local-binding")
                }
                for socket in network.allowUnixSockets {
                    args.append("--sandbox-allow-unix-socket")
                    args.append(socket)
                }
                if let httpPort = network.httpProxyPort {
                    args.append("--sandbox-http-proxy-port")
                    args.append(String(httpPort))
                }
            }
        }

        return args
    }
}
```

---

## Implementation Analysis 6: Tool Input/Output Types

### 6.1 Design Philosophy

**Goal:** Provide type-safe access to tool inputs/outputs while maintaining flexibility for unknown tools.

**Approach:**
1. Enum for known tools with associated typed structs
2. Fallback to raw dictionary for unknown tools
3. Convenience accessors on ToolUseBlock


### 6.2 Complete Tool Input Types

```swift
/// Type-safe tool input access
public enum TypedToolInput: Sendable {
    case bash(BashInput)
    case read(ReadInput)
    case write(WriteInput)
    case edit(EditInput)
    case glob(GlobInput)
    case grep(GrepInput)
    case webSearch(WebSearchInput)
    case webFetch(WebFetchInput)
    case task(TaskInput)
    case askUserQuestion(AskUserQuestionInput)
    case todoWrite(TodoWriteInput)
    case exitPlanMode(ExitPlanModeInput)
    case notebookEdit(NotebookEditInput)
    case bashOutput(BashOutputInput)
    case killBash(KillBashInput)
    case unknown(name: String, input: [String: AnyCodable])

    public static func from(name: String, data: [String: AnyCodable]) -> TypedToolInput {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: data.mapValues { $0.value }
        ) else {
            return .unknown(name: name, input: data)
        }

        switch name {
        case "Bash":
            if let input = try? decoder.decode(BashInput.self, from: jsonData) {
                return .bash(input)
            }
        case "Read":
            if let input = try? decoder.decode(ReadInput.self, from: jsonData) {
                return .read(input)
            }
        case "Write":
            if let input = try? decoder.decode(WriteInput.self, from: jsonData) {
                return .write(input)
            }
        case "Edit":
            if let input = try? decoder.decode(EditInput.self, from: jsonData) {
                return .edit(input)
            }
        case "Glob":
            if let input = try? decoder.decode(GlobInput.self, from: jsonData) {
                return .glob(input)
            }
        case "Grep":
            if let input = try? decoder.decode(GrepInput.self, from: jsonData) {
                return .grep(input)
            }
        case "WebSearch":
            if let input = try? decoder.decode(WebSearchInput.self, from: jsonData) {
                return .webSearch(input)
            }
        case "WebFetch":
            if let input = try? decoder.decode(WebFetchInput.self, from: jsonData) {
                return .webFetch(input)
            }
        case "Task":
            if let input = try? decoder.decode(TaskInput.self, from: jsonData) {
                return .task(input)
            }
        case "AskUserQuestion":
            if let input = try? decoder.decode(AskUserQuestionInput.self, from: jsonData) {
                return .askUserQuestion(input)
            }
        // ... other cases
        default:
            break
        }

        return .unknown(name: name, input: data)
    }
}

// MARK: - Individual Input Types

public struct BashInput: Sendable, Codable {
    public let command: String
    public let timeout: Int?
    public let description: String?
    public let runInBackground: Bool?
    public let dangerouslyDisableSandbox: Bool?
}

public struct ReadInput: Sendable, Codable {
    public let filePath: String
    public let offset: Int?
    public let limit: Int?
}

public struct WriteInput: Sendable, Codable {
    public let filePath: String
    public let content: String
}

public struct EditInput: Sendable, Codable {
    public let filePath: String
    public let oldString: String
    public let newString: String
    public let replaceAll: Bool?
}

public struct GlobInput: Sendable, Codable {
    public let pattern: String
    public let path: String?
}

public struct GrepInput: Sendable, Codable {
    public let pattern: String
    public let path: String?
    public let glob: String?
    public let type: String?
    public let outputMode: GrepOutputMode?
    public let caseInsensitive: Bool?
    public let showLineNumbers: Bool?
    public let contextBefore: Int?
    public let contextAfter: Int?
    public let context: Int?
    public let headLimit: Int?
    public let offset: Int?
    public let multiline: Bool?

    public enum GrepOutputMode: String, Sendable, Codable {
        case content
        case filesWithMatches = "files_with_matches"
        case count
    }

    private enum CodingKeys: String, CodingKey {
        case pattern, path, glob, type, outputMode = "output_mode"
        case caseInsensitive = "-i"
        case showLineNumbers = "-n"
        case contextBefore = "-B"
        case contextAfter = "-A"
        case context = "-C"
        case headLimit = "head_limit"
        case offset, multiline
    }
}

public struct WebSearchInput: Sendable, Codable {
    public let query: String
    public let allowedDomains: [String]?
    public let blockedDomains: [String]?
}

public struct WebFetchInput: Sendable, Codable {
    public let url: String
    public let prompt: String
}

public struct TaskInput: Sendable, Codable {
    public let description: String
    public let prompt: String
    public let subagentType: String
    public let model: String?
    public let maxTurns: Int?
    public let runInBackground: Bool?
    public let resume: String?
}

public struct AskUserQuestionInput: Sendable, Codable {
    public let questions: [Question]
    public let answers: [String: String]?
    public let metadata: QuestionMetadata?

    public struct Question: Sendable, Codable {
        public let question: String
        public let header: String
        public let options: [Option]
        public let multiSelect: Bool

        public struct Option: Sendable, Codable {
            public let label: String
            public let description: String
        }
    }

    public struct QuestionMetadata: Sendable, Codable {
        public let source: String?
    }
}

public struct TodoWriteInput: Sendable, Codable {
    public let todos: [Todo]

    public struct Todo: Sendable, Codable {
        public let content: String
        public let status: TodoStatus
        public let activeForm: String

        public enum TodoStatus: String, Sendable, Codable {
            case pending
            case inProgress = "in_progress"
            case completed
        }
    }
}

public struct ExitPlanModeInput: Sendable, Codable {
    public let allowedPrompts: [AllowedPrompt]?
    public let pushToRemote: Bool?
    public let remoteSessionId: String?
    public let remoteSessionTitle: String?
    public let remoteSessionUrl: String?

    public struct AllowedPrompt: Sendable, Codable {
        public let tool: String
        public let prompt: String
    }
}

public struct NotebookEditInput: Sendable, Codable {
    public let notebookPath: String
    public let cellId: String?
    public let newSource: String
    public let cellType: CellType?
    public let editMode: EditMode?

    public enum CellType: String, Sendable, Codable {
        case code
        case markdown
    }

    public enum EditMode: String, Sendable, Codable {
        case replace
        case insert
        case delete
    }
}

public struct BashOutputInput: Sendable, Codable {
    public let bashId: String
    public let filter: String?
}

public struct KillBashInput: Sendable, Codable {
    public let shellId: String
}
```


### 6.3 Tool Output Types

```swift
public enum TypedToolOutput: Sendable {
    case bash(BashOutput)
    case read(ReadOutput)
    case write(WriteOutput)
    case edit(EditOutput)
    case glob(GlobOutput)
    case grep(GrepOutput)
    case webSearch(WebSearchOutput)
    case webFetch(WebFetchOutput)
    case task(TaskOutput)
    case unknown(name: String, output: [String: AnyCodable])
}

public struct BashOutput: Sendable, Codable {
    public let output: String
    public let exitCode: Int
    public let killed: Bool?
    public let shellId: String?
}

public struct ReadOutput: Sendable, Codable {
    // For text files
    public let content: String?
    public let totalLines: Int?
    public let linesReturned: Int?

    // For images
    public let image: String?  // Base64
    public let mimeType: String?
    public let fileSize: Int?
}

public struct WriteOutput: Sendable, Codable {
    public let message: String
    public let bytesWritten: Int
    public let filePath: String
}

public struct EditOutput: Sendable, Codable {
    public let message: String
    public let replacements: Int
    public let filePath: String
}

public struct GlobOutput: Sendable, Codable {
    public let matches: [String]
    public let count: Int
    public let searchPath: String
}

public struct GrepOutput: Sendable, Codable {
    // Content mode
    public let matches: [GrepMatch]?
    public let totalMatches: Int?

    // Files with matches mode
    public let files: [String]?
    public let count: Int?

    public struct GrepMatch: Sendable, Codable {
        public let file: String
        public let lineNumber: Int
        public let line: String
        public let context: [String]?
    }
}

public struct WebSearchOutput: Sendable, Codable {
    public let results: [SearchResult]
    public let totalResults: Int
    public let query: String

    public struct SearchResult: Sendable, Codable {
        public let title: String
        public let url: String
        public let snippet: String
        public let metadata: [String: AnyCodable]?
    }
}

public struct WebFetchOutput: Sendable, Codable {
    public let response: String
    public let url: String
    public let finalUrl: String?
    public let statusCode: Int
}

public struct TaskOutput: Sendable, Codable {
    public let result: String
    public let usage: [String: AnyCodable]?
    public let totalCostUsd: Double?
    public let durationMs: Int?
}
```


### 6.4 Convenience Extensions

```swift
extension ToolUseBlock {
    /// Get typed input for this tool use
    public var typedInput: TypedToolInput {
        TypedToolInput.from(name: name, data: input)
    }

    /// Convenience accessors for common tools
    public var bashInput: BashInput? {
        if case .bash(let input) = typedInput { return input }
        return nil
    }

    public var readInput: ReadInput? {
        if case .read(let input) = typedInput { return input }
        return nil
    }

    public var writeInput: WriteInput? {
        if case .write(let input) = typedInput { return input }
        return nil
    }

    public var editInput: EditInput? {
        if case .edit(let input) = typedInput { return input }
        return nil
    }

    public var taskInput: TaskInput? {
        if case .task(let input) = typedInput { return input }
        return nil
    }

    public var askUserQuestionInput: AskUserQuestionInput? {
        if case .askUserQuestion(let input) = typedInput { return input }
        return nil
    }
}
```

---

## Implementation Analysis 7: Error Handling

### 7.1 ResultSubtype Enum

```swift
/// All possible result subtypes from the official SDK
public enum ResultSubtype: String, Sendable, Codable {
    case success
    case errorMaxTurns = "error_max_turns"
    case errorDuringExecution = "error_during_execution"
    case errorMaxBudgetUsd = "error_max_budget_usd"
    case errorMaxStructuredOutputRetries = "error_max_structured_output_retries"

    public var isError: Bool {
        self != .success
    }

    public var localizedDescription: String {
        switch self {
        case .success:
            return "Query completed successfully"
        case .errorMaxTurns:
            return "Maximum turn limit reached"
        case .errorDuringExecution:
            return "Error occurred during execution"
        case .errorMaxBudgetUsd:
            return "Budget limit exceeded"
        case .errorMaxStructuredOutputRetries:
            return "Failed to produce valid structured output after maximum retries"
        }
    }
}
```


### 7.2 Enhanced ResultMessage

```swift
public struct ResultMessage: Sendable, Codable {
    public let type: String
    public let subtype: ResultSubtype
    public let uuid: String
    public let sessionId: String

    // Metrics
    public let totalCostUsd: Double
    public let durationMs: Int
    public let durationApiMs: Int
    public let numTurns: Int

    // Status
    public let isError: Bool

    // Success case
    public let result: String?

    // Error cases
    public let errors: [String]?

    // Permission tracking
    public let permissionDenials: [PermissionDenial]?

    // Usage breakdown
    public let usage: Usage?
    public let modelUsage: [String: ModelUsage]?

    // Structured output (if configured)
    public let structuredOutput: AnyCodable?

    // Convenience computed properties
    public var succeeded: Bool {
        subtype == .success && !isError
    }

    public var errorMessages: [String] {
        errors ?? []
    }
}

public struct PermissionDenial: Sendable, Codable {
    public let toolName: String
    public let toolUseId: String
    public let toolInput: [String: AnyCodable]
}

public struct Usage: Sendable, Codable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
}

public struct ModelUsage: Sendable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadInputTokens: Int?
    public let cacheCreationInputTokens: Int?
    public let webSearchRequests: Int?
    public let costUsd: Double
    public let contextWindow: Int?
}
```


### 7.3 Error Classification Enhancement

```swift
extension ClaudeCodeError {
    /// Classify result message errors into ClaudeCodeError types
    public static func from(resultMessage: ResultMessage) -> ClaudeCodeError? {
        guard resultMessage.isError else { return nil }

        switch resultMessage.subtype {
        case .success:
            return nil

        case .errorMaxTurns:
            return .maxTurnsExceeded(
                limit: resultMessage.numTurns,
                message: resultMessage.errors?.first ?? "Maximum turns reached"
            )

        case .errorDuringExecution:
            return .executionFailed(
                resultMessage.errors?.joined(separator: "\n") ?? "Unknown execution error"
            )

        case .errorMaxBudgetUsd:
            return .budgetExceeded(
                limit: nil,  // We don't know the limit from result
                spent: resultMessage.totalCostUsd
            )

        case .errorMaxStructuredOutputRetries:
            return .structuredOutputFailed(
                message: resultMessage.errors?.first ?? "Failed to produce valid structured output"
            )
        }
    }
}

// New error cases
extension ClaudeCodeError {
    public static func maxTurnsExceeded(limit: Int, message: String) -> ClaudeCodeError {
        .executionFailed("Max turns (\(limit)) exceeded: \(message)")
    }

    public static func budgetExceeded(limit: Double?, spent: Double) -> ClaudeCodeError {
        if let limit = limit {
            return .executionFailed("Budget exceeded: spent $\(spent) of $\(limit) limit")
        }
        return .executionFailed("Budget exceeded: spent $\(spent)")
    }

    public static func structuredOutputFailed(message: String) -> ClaudeCodeError {
        .executionFailed("Structured output validation failed: \(message)")
    }
}
```

---

## Implementation Analysis 8: AsyncSequence Migration

### 8.1 Core Stream Type

```swift
/// Modern AsyncSequence-based response stream
public struct ClaudeResponseStream: AsyncSequence, Sendable {
    public typealias Element = ResponseChunk

    private let makeStream: @Sendable () -> AsyncThrowingStream<ResponseChunk, Error>

    internal init(_ makeStream: @escaping @Sendable () -> AsyncThrowingStream<ResponseChunk, Error>) {
        self.makeStream = makeStream
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: makeStream())
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var iterator: AsyncThrowingStream<ResponseChunk, Error>.Iterator

        init(stream: AsyncThrowingStream<ResponseChunk, Error>) {
            self.iterator = stream.makeAsyncIterator()
        }

        public mutating func next() async throws -> ResponseChunk? {
            try await iterator.next()
        }
    }
}
```


### 8.2 Query Return Type Migration

```swift
// Old API (Combine-based)
public func runSinglePrompt(...) async throws -> ClaudeCodeResult

public enum ClaudeCodeResult {
    case text(String)
    case json(Data)
    case stream(AnyPublisher<ResponseChunk, Error>)
}

// New API (AsyncSequence-based)
public func query(prompt: String, options: QueryOptions? = nil) -> ClaudeResponseStream

// The stream IS the result - no enum wrapping needed
// Text/JSON extraction becomes:
let stream = client.query(prompt: "Hello")
var finalResult: String?

for try await chunk in stream {
    if case .result(let result) = chunk {
        finalResult = result.result
    }
}
```


### 8.3 Backward Compatibility Layer

```swift
extension ClaudeCodeClient {
    /// Legacy API for backward compatibility
    @available(*, deprecated, message: "Use query() instead")
    public func runSinglePrompt(
        prompt: String,
        outputFormat: ClaudeCodeOutputFormat,
        options: ClaudeCodeOptions?
    ) async throws -> ClaudeCodeResult {
        switch outputFormat {
        case .text:
            // Collect stream into final text result
            var text = ""
            for try await chunk in query(prompt: prompt, options: options?.toQueryOptions()) {
                if case .result(let result) = chunk {
                    text = result.result ?? ""
                }
            }
            return .text(text)

        case .json:
            // Collect and return as JSON
            var chunks: [ResponseChunk] = []
            for try await chunk in query(prompt: prompt, options: options?.toQueryOptions()) {
                chunks.append(chunk)
            }
            let data = try JSONEncoder().encode(chunks)
            return .json(data)

        case .streamJson:
            // Convert to Combine publisher for legacy code
            let stream = query(prompt: prompt, options: options?.toQueryOptions())
            let publisher = stream.publisher()
            return .stream(publisher)
        }
    }
}

// AsyncSequence to Combine bridge
extension ClaudeResponseStream {
    public func publisher() -> AnyPublisher<ResponseChunk, Error> {
        let subject = PassthroughSubject<ResponseChunk, Error>()

        Task {
            do {
                for try await chunk in self {
                    subject.send(chunk)
                }
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }
}
```


### 8.4 Convenience Methods on Stream

```swift
extension ClaudeResponseStream {
    /// Collect all chunks into an array
    public func collect() async throws -> [ResponseChunk] {
        var chunks: [ResponseChunk] = []
        for try await chunk in self {
            chunks.append(chunk)
        }
        return chunks
    }

    /// Get just the final result
    public func result() async throws -> ResultMessage {
        for try await chunk in self {
            if case .result(let result) = chunk {
                return result
            }
        }
        throw ClaudeCodeError.unexpectedEndOfStream
    }

    /// Get the final text output
    public func text() async throws -> String {
        let result = try await result()
        return result.result ?? ""
    }

    /// Filter to only assistant messages
    public func assistantMessages() -> AsyncFilterSequence<Self> {
        filter { chunk in
            if case .assistant = chunk { return true }
            return false
        }
    }

    /// Extract all text content
    public func textContent() -> AsyncCompactMapSequence<Self, String> {
        compactMap { chunk -> String? in
            guard case .assistant(let msg) = chunk else { return nil }
            return msg.content.compactMap { block -> String? in
                if case .text(let text) = block { return text.text }
                return nil
            }.joined()
        }
    }

    /// Get the init message (first system.init)
    public func initMessage() async throws -> InitSystemMessage {
        for try await chunk in self {
            if case .system(.`init`(let initMsg)) = chunk {
                return initMsg
            }
        }
        throw ClaudeCodeError.unexpectedEndOfStream
    }
}
```

---

## Implementation Analysis 9: Custom MCP Tools

### 9.1 Tool Definition Architecture

**The Challenge:** The official SDK uses Zod schemas (TypeScript) or Pydantic (Python) for tool input validation. Swift needs an equivalent.

**Option A: Codable + JSONSchema Generation**
```swift
// Define tool input as Codable struct
struct CalculatorInput: Codable, ToolInputSchema {
    let operation: Operation
    let operands: [Double]

    enum Operation: String, Codable {
        case add, subtract, multiply, divide
    }

    static var jsonSchema: JSONSchema {
        // Auto-generated or manually specified
    }
}
```

**Option B: Result Builder DSL**
```swift
let calculatorTool = Tool("calculator") {
    Description("Performs basic math operations")

    Input {
        Property("operation", type: .string) {
            Description("The math operation")
            Enum("add", "subtract", "multiply", "divide")
        }
        Property("operands", type: .array(of: .number)) {
            Description("Numbers to operate on")
            MinItems(2)
        }
    }

    Handler { input in
        // Process and return
    }
}
```

**Option C: Macro-Based (Swift 5.9+)**
```swift
@MCPTool(name: "calculator", description: "Performs basic math")
struct Calculator {
    @ToolParameter(description: "The math operation")
    var operation: Operation

    @ToolParameter(description: "Numbers to operate on")
    var operands: [Double]

    func execute() async throws -> ToolResult {
        // Implementation
    }
}
```

**Recommendation:** Option A with Option B as a convenience layer. Macros are nice but add complexity.


### 9.2 Tool Protocol Definition

```swift
/// Protocol for SDK MCP tools
public protocol MCPToolDefinition: Sendable {
    /// Unique tool name
    var name: String { get }

    /// Human-readable description
    var description: String { get }

    /// JSON Schema for input validation
    var inputSchema: JSONSchema { get }

    /// Handler function
    func handle(_ input: [String: AnyCodable]) async throws -> ToolResult
}

/// Result from tool execution
public struct ToolResult: Sendable {
    public let content: [ToolResultContent]
    public let isError: Bool

    public enum ToolResultContent: Sendable {
        case text(String)
        case image(data: Data, mimeType: String)
        case resource(uri: String, mimeType: String?, text: String?)
    }

    public static func text(_ text: String) -> ToolResult {
        ToolResult(content: [.text(text)], isError: false)
    }

    public static func error(_ message: String) -> ToolResult {
        ToolResult(content: [.text(message)], isError: true)
    }
}
```


### 9.3 Typed Tool Implementation

```swift
/// Type-safe tool with Codable input
public struct TypedMCPTool<Input: Codable & Sendable>: MCPToolDefinition {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    private let handler: @Sendable (Input) async throws -> ToolResult

    public init(
        name: String,
        description: String,
        inputType: Input.Type = Input.self,
        handler: @escaping @Sendable (Input) async throws -> ToolResult
    ) {
        self.name = name
        self.description = description
        self.inputSchema = JSONSchema.from(Input.self)
        self.handler = handler
    }

    public func handle(_ input: [String: AnyCodable]) async throws -> ToolResult {
        // Decode input to typed struct
        let jsonData = try JSONSerialization.data(
            withJSONObject: input.mapValues { $0.value }
        )
        let typedInput = try JSONDecoder().decode(Input.self, from: jsonData)
        return try await handler(typedInput)
    }
}

// Convenience function matching official SDK
public func tool<Input: Codable & Sendable>(
    _ name: String,
    description: String,
    input: Input.Type,
    handler: @escaping @Sendable (Input) async throws -> ToolResult
) -> TypedMCPTool<Input> {
    TypedMCPTool(name: name, description: description, inputType: input, handler: handler)
}
```


### 9.4 MCP Server Creation

```swift
/// In-process MCP server for custom tools
public final class SDKMCPServer: Sendable {
    public let name: String
    public let version: String
    private let tools: [any MCPToolDefinition]

    public init(
        name: String,
        version: String = "1.0.0",
        tools: [any MCPToolDefinition]
    ) {
        self.name = name
        self.version = version
        self.tools = tools
    }

    /// Get tool definitions for the init message
    public var toolDefinitions: [[String: Any]] {
        tools.map { tool in
            [
                "name": tool.name,
                "description": tool.description,
                "inputSchema": tool.inputSchema.toDictionary()
            ]
        }
    }

    /// Handle a tool call
    public func handleToolCall(
        name: String,
        input: [String: AnyCodable]
    ) async throws -> ToolResult {
        guard let tool = tools.first(where: { $0.name == name }) else {
            throw MCPError.unknownTool(name)
        }
        return try await tool.handle(input)
    }
}

/// Convenience function matching official SDK
public func createSdkMcpServer(
    name: String,
    version: String = "1.0.0",
    @ToolArrayBuilder tools: () -> [any MCPToolDefinition]
) -> SDKMCPServer {
    SDKMCPServer(name: name, version: version, tools: tools())
}

// Result builder for tool arrays
@resultBuilder
public struct ToolArrayBuilder {
    public static func buildBlock(_ tools: any MCPToolDefinition...) -> [any MCPToolDefinition] {
        tools
    }
}
```


### 9.5 Integration with Query Options

```swift
extension QueryOptions {
    /// Custom MCP servers with in-process tools
    public var sdkMcpServers: [String: SDKMCPServer]?
}

// During query execution, SDK MCP servers are handled specially:
// - Tool definitions are injected into the tools list
// - Tool calls are intercepted and handled in-process
// - Results are injected back into the stream
```


### 9.6 Example Usage

```swift
// Define input types
struct CalculatorInput: Codable, Sendable {
    let operation: String
    let operands: [Double]
}

struct WeatherInput: Codable, Sendable {
    let city: String
    let units: String?
}

// Create tools
let calculatorTool = tool("calculator", description: "Performs math", input: CalculatorInput.self) { input in
    let result: Double
    switch input.operation {
    case "add": result = input.operands.reduce(0, +)
    case "multiply": result = input.operands.reduce(1, *)
    default: return .error("Unknown operation")
    }
    return .text("Result: \(result)")
}

let weatherTool = tool("weather", description: "Gets weather", input: WeatherInput.self) { input in
    // Call weather API
    let weather = try await fetchWeather(city: input.city)
    return .text("Weather in \(input.city): \(weather.description)")
}

// Create server
let myServer = createSdkMcpServer(name: "my-tools") {
    calculatorTool
    weatherTool
}

// Use in query
var options = QueryOptions()
options.sdkMcpServers = ["my-tools": myServer]
options.allowedTools = ["mcp__my-tools__*"]

let stream = client.query(prompt: "What's 5 + 3?", options: options)
```

---

## Implementation Analysis 10: SwiftUI Integration

### 10.1 Observable Session State

```swift
import SwiftUI

/// Observable Claude session for SwiftUI
@Observable
public final class ClaudeSessionState {
    // State
    public private(set) var isConnected = false
    public private(set) var isProcessing = false
    public private(set) var messages: [ResponseChunk] = []
    public private(set) var error: ClaudeCodeError?
    public private(set) var sessionId: String?

    // Metrics
    public private(set) var totalCost: Double = 0
    public private(set) var totalTurns: Int = 0

    // Pending permission request
    public var pendingPermission: PendingPermission?

    private var client: ClaudeCodeClient?
    private var currentTask: Task<Void, Never>?

    public init() {}

    @MainActor
    public func connect(options: QueryOptions? = nil) async throws {
        client = try ClaudeCodeClient()
        isConnected = true
    }

    @MainActor
    public func send(_ message: String, options: QueryOptions? = nil) {
        guard let client = client else { return }

        isProcessing = true
        error = nil

        currentTask = Task {
            do {
                for try await chunk in client.query(prompt: message, options: options) {
                    await MainActor.run {
                        messages.append(chunk)

                        if case .system(.`init`(let initMsg)) = chunk {
                            sessionId = initMsg.sessionId
                        }

                        if case .result(let result) = chunk {
                            totalCost += result.totalCostUsd
                            totalTurns += result.numTurns
                            isProcessing = false
                        }
                    }
                }
            } catch let err as ClaudeCodeError {
                await MainActor.run {
                    error = err
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.error = .executionFailed(error.localizedDescription)
                    isProcessing = false
                }
            }
        }
    }

    @MainActor
    public func cancel() {
        currentTask?.cancel()
        isProcessing = false
    }

    @MainActor
    public func clear() {
        messages = []
        totalCost = 0
        totalTurns = 0
    }
}
```


### 10.2 View Components

```swift
/// Chat message view
public struct ClaudeMessageView: View {
    let chunk: ResponseChunk

    public var body: some View {
        switch chunk {
        case .assistant(let msg):
            AssistantMessageView(message: msg)
        case .user(let msg):
            UserMessageView(message: msg)
        case .result(let result):
            ResultView(result: result)
        case .system:
            EmptyView()  // Usually hidden
        default:
            EmptyView()
        }
    }
}

struct AssistantMessageView: View {
    let message: AssistantMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(message.content.enumerated()), id: \.offset) { _, block in
                ContentBlockView(block: block)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ContentBlockView: View {
    let block: ContentBlock

    var body: some View {
        switch block {
        case .text(let text):
            Text(text.text)
        case .thinking(let thinking):
            DisclosureGroup("Thinking...") {
                Text(thinking.thinking)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .toolUse(let tool):
            ToolUseView(tool: tool)
        case .toolResult(let result):
            ToolResultView(result: result)
        default:
            EmptyView()
        }
    }
}

struct ToolUseView: View {
    let tool: ToolUseBlock
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(formatInput(tool.input))
                .font(.system(.caption, design: .monospaced))
        } label: {
            Label(tool.name, systemImage: "wrench")
        }
    }

    private func formatInput(_ input: [String: AnyCodable]) -> String {
        // Format as JSON
        guard let data = try? JSONSerialization.data(
            withJSONObject: input.mapValues { $0.value },
            options: .prettyPrinted
        ) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
```


### 10.3 View Modifiers

```swift
/// Modifier for handling Claude responses
public struct ClaudeResponseModifier: ViewModifier {
    @Binding var state: ClaudeSessionState
    let onMessage: (ResponseChunk) -> Void
    let onError: (ClaudeCodeError) -> Void

    public func body(content: Content) -> some View {
        content
            .onChange(of: state.messages.count) { _, _ in
                if let lastMessage = state.messages.last {
                    onMessage(lastMessage)
                }
            }
            .onChange(of: state.error) { _, error in
                if let error = error {
                    onError(error)
                }
            }
    }
}

extension View {
    public func onClaudeResponse(
        _ state: Binding<ClaudeSessionState>,
        onMessage: @escaping (ResponseChunk) -> Void = { _ in },
        onError: @escaping (ClaudeCodeError) -> Void = { _ in }
    ) -> some View {
        modifier(ClaudeResponseModifier(
            state: state,
            onMessage: onMessage,
            onError: onError
        ))
    }
}
```


### 10.4 Permission Sheet

```swift
/// Sheet for handling permission requests
public struct PermissionRequestSheet: View {
    let permission: PendingPermission
    let onDecision: (PermissionResult) -> Void

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                Image(systemName: iconForTool(permission.toolName))
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                Text("Permission Request")
                    .font(.headline)

                Text("Claude wants to use: **\(permission.toolName)**")

                // Tool-specific content
                Group {
                    switch permission.toolName {
                    case "Bash":
                        BashPermissionContent(input: permission.input)
                    case "Write":
                        WritePermissionContent(input: permission.input)
                    case "Edit":
                        EditPermissionContent(input: permission.input)
                    case "AskUserQuestion":
                        QuestionContent(input: permission.input) { answers in
                            onDecision(.allow(updatedInput: mergeAnswers(permission.input, answers)))
                        }
                    default:
                        GenericPermissionContent(input: permission.input)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                Spacer()

                // Action buttons (not shown for AskUserQuestion)
                if permission.toolName != "AskUserQuestion" {
                    HStack(spacing: 20) {
                        Button("Deny", role: .destructive) {
                            onDecision(.deny(message: "User denied"))
                        }
                        .buttonStyle(.bordered)

                        Button("Allow") {
                            onDecision(.allow())
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Claude Request")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func iconForTool(_ name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil"
        case "Read": return "doc.text"
        case "AskUserQuestion": return "questionmark.bubble"
        default: return "gearshape"
        }
    }
}

struct BashPermissionContent: View {
    let input: ToolInputData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Command:")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(input["command"] as? String ?? "")
                .font(.system(.body, design: .monospaced))

            if let description = input["description"] as? String {
                Text("Description:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(description)
            }
        }
    }
}
```


### 10.5 Complete Chat View Example

```swift
struct ClaudeChatView: View {
    @State private var session = ClaudeSessionState()
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(session.messages.enumerated()), id: \.offset) { index, chunk in
                            ClaudeMessageView(chunk: chunk)
                                .id(index)
                        }
                    }
                    .padding()
                }
                .onChange(of: session.messages.count) { _, count in
                    withAnimation {
                        proxy.scrollTo(count - 1, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            HStack {
                TextField("Message", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(session.isProcessing)

                if session.isProcessing {
                    Button("Stop") {
                        session.cancel()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Send") {
                        let message = inputText
                        inputText = ""
                        session.send(message)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding()
        }
        .sheet(item: $session.pendingPermission) { permission in
            PermissionRequestSheet(permission: permission) { decision in
                // Handle decision
                session.pendingPermission = nil
            }
        }
        .alert("Error", isPresented: .init(
            get: { session.error != nil },
            set: { if !$0 { session.error = nil } }
        )) {
            Button("OK") { session.error = nil }
        } message: {
            Text(session.error?.localizedDescription ?? "")
        }
        .task {
            try? await session.connect()
        }
    }
}
```

---

## Summary: Implementation Roadmap

Based on this deep analysis, here's a recommended implementation order:

### Week 1-2: Foundation
1. **Content Block Types** - Low effort, enables everything else
2. **Enhanced Message Types** - Complete InitSystemMessage, add StreamEvent
3. **Tool Input/Output Types** - Type safety for hooks and permissions

### Week 3-4: Core Features
4. **AsyncSequence Migration** - Modern streaming foundation
5. **Hook System** - PreToolUse, PostToolUse, Stop
6. **Permission Callbacks** - canUseTool with AskUserQuestion support

### Week 5-6: Query Control
7. **QueryStream Class** - Control methods (interrupt, setModel, etc.)
8. **Streaming Input** - Bidirectional communication
9. **Session Management** - Actor-based session state

### Week 7-8: Polish
10. **Custom MCP Tools** - tool() and createSdkMcpServer()
11. **SwiftUI Integration** - Observable state, view components
12. **Configuration Options** - Sandbox, structured output, remaining flags

### Ongoing
- Testing against real CLI behavior
- Documentation
- Example applications
