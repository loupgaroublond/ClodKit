# Streaming Input

## Context

ClodKit's `query()` function currently accepts only a `String` prompt. The official TypeScript and Python SDKs accept `string | AsyncIterable<SDKUserMessage>`, allowing callers to feed a stream of user messages into a running session at query creation time.

Most of the infrastructure for streaming input is delivered by gap remediation work (v0.2.34 parity):

- **SDKUserMessage type** and **ContentBlock enum** — created as part of message type updates
- **`streamInput()` method on ClaudeQuery** — new Query method that feeds an AsyncSequence into a running query
- **`close()` method on ClaudeQuery** — explicit resource cleanup
- **Stdin lifecycle changes** (`closeStdinOnResult` on `startMessageLoop()`) — prerequisite for `streamInput()` to keep stdin open

What remains here is the **`query()` overload** that accepts an `AsyncSequence<SDKUserMessage>` as the prompt parameter, matching the original spec signature (Section 2.1). This is a convenience layer over `streamInput()`.


## What This Adds

Instead of creating a query and then calling `streamInput()` separately:

```swift
let query = try await Clod.query("", options: options)
try await query.streamInput(messages)
```

The caller can pass the stream directly as the prompt:

```swift
let query = try await Clod.query(prompt: messages, options: options)
```

This matches the TypeScript/Python `query()` signature where `prompt` is `string | AsyncIterable<SDKUserMessage>`.


## Implementation

### 1. Add query() Overload Accepting AsyncSequence

In `Sources/ClodKit/Query/QueryAPI.swift`, add a second `query()` overload:

```swift
public func query<S: AsyncSequence>(
    prompt: S,
    options: QueryOptions = QueryOptions()
) async throws -> ClaudeQuery where S.Element == SDKUserMessage, S: Sendable
```

This overload follows the same setup path as `query(prompt: String)` — build CLI arguments, create transport, create session, register hooks/servers, start transport, start message loop, initialize control protocol. The difference is in the prompt-sending phase.

Instead of serializing a single string, it calls `streamInput()` on the returned `ClaudeQuery`, passing through the caller's `AsyncSequence`. Internally this is thin: create the query (with an empty or no-op initial prompt), then delegate to `streamInput()`.


### 2. Update the Clod Namespace

Add matching overloads on the `Clod` enum:

```swift
public static func query<S: AsyncSequence>(
    prompt: S,
    options: QueryOptions = QueryOptions()
) async throws -> ClaudeQuery where S.Element == SDKUserMessage, S: Sendable
```


### 3. Convenience: Prompt from Closure

For simpler use cases, provide a convenience that creates an `AsyncStream` from a closure:

```swift
public static func query(
    options: QueryOptions = QueryOptions(),
    promptStream: @Sendable @escaping (AsyncStream<SDKUserMessage>.Continuation) -> Void
) async throws -> ClaudeQuery
```

This lets callers write:

```swift
let query = try await Clod.query(options: opts) { continuation in
    continuation.yield(.text("Hello"))
    continuation.yield(.text("Follow up"))
    continuation.finish()
}
```


### 4. Tests

**Unit tests** (using MockTransport):

- Streaming query overload sends each message as a separate write via `streamInput()`
- Convenience closure API creates the stream and delegates correctly
- Cancellation of the query cancels the underlying stream

**Integration tests** (using real CLI):

- Send a single message via streaming (equivalent to string prompt)
- Send two messages, verify Claude processes both


## Files to Modify

| File | Change |
|------|--------|
| `Sources/ClodKit/Query/QueryAPI.swift` | Add streaming `query()` overload + closure convenience |
| `Tests/ClodKitTests/StreamingInputTests.swift` | Overload and closure convenience tests |
| `Tests/ClodKitTests/Integration/StreamingIntegrationTests.swift` | End-to-end tests |


## Prerequisites (from gap remediation)

These must exist before this work begins:

- `SDKUserMessage` type with `toJSONData()` serialization
- `ContentBlock` enum (text, tool_result, image)
- `ClaudeQuery.streamInput()` method
- `ClaudeSession.startMessageLoop(closeStdinOnResult:)` parameter


## Verification

1. `swift build` compiles cleanly
2. `swift test` — all existing tests pass (backward compatibility)
3. Streaming query overload produces same result as string query for single message
4. Multi-message streaming query processes all messages
