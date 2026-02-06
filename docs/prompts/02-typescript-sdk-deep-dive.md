# Task: Deep Dive into TypeScript SDK Implementation

You're analyzing the TypeScript SDK to understand all its features and how it interfaces with the Claude Code CLI.

## Context

This is part of the ClodeMonster project - a Swift SDK for Claude Code. The TypeScript SDK is the most feature-complete official SDK. We need to understand everything it supports.

## Files

- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/sdk.mjs` (deminified, 19115 lines)
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/sdk.d.ts` (type definitions, 1753 lines)
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/sdk-tools.d.ts` (tool type definitions)

Related reference:
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/SDK_INTERNALS_ANALYSIS.md` - existing high-level analysis

## Questions to Answer

1. **Query lifecycle**: Trace the full lifecycle of a query from `query()` call to completion. What happens at each step?

2. **All control request types**: Document every control request type the SDK can send TO the CLI, and every type it can receive FROM the CLI.

3. **Dynamic MCP management**: How do `setMcpServers()`, `reconnectMcpServer()`, `toggleMcpServer()` work? What control requests do they use?

4. **V2 Session API**: How does `unstable_v2_createSession()` differ from `query()`? What's the internal implementation?

5. **Transport abstraction**: How is the `Transport` interface used? Could a WebSocket transport be plugged in?

6. **Hook registration and invocation**: Full details on how hooks are registered during `initialize` and invoked via `hook_callback`.

7. **Error handling**: How does the SDK handle CLI errors, process crashes, timeouts?

8. **All Options**: Catalog every option in the `Options` type and how each maps to CLI behavior.

## Output

**1. Annotate the code directly:**

As you analyze `sdk.mjs`, add comments liberally throughout the file explaining what obfuscated functions, classes, and variables actually do in human terms. For example:

```javascript
// MCP Transport for SDK servers - routes messages through control protocol
// K9 in original minified code
class K9 {
  sendMcpMessage;  // Callback to send JSONRPC to CLI via control_request
  isClosed = false;

  constructor(sendCallback) {
    this.sendMcpMessage = sendCallback;  // sendCallback = function to write to stdin
  }

  // Called by MCP server when it wants to send a message
  async send(message) {
    // message = JSONRPC request/response
    if (this.isClosed) throw Error("Transport is closed");
    this.sendMcpMessage(message);
  }
}
```

The goal is to make the deminified code readable for future analysis. Be liberal with comments - explain:
- What each major class/function does (and its original likely name if guessable)
- What obfuscated parameter names actually represent
- The purpose of important code blocks
- Control protocol message handling
- How the SDK interfaces with the CLI subprocess

**2. Create analysis document:**

Create `/Users/yankee/Documents/Projects/ClodeMonster/reports/02-typescript-sdk-report.md` with detailed findings. Include code references with line numbers.
