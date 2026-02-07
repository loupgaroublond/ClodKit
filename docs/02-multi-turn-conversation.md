# Multi-Turn Conversation API

## Context

ClodKit currently supports single-shot queries: one prompt in, one response stream out, session over. The gap analysis (v0.2.34) reveals that the TypeScript SDK now ships an entirely new **V2 Session API** that handles multi-turn conversations natively. This replaces the earlier Python-only `ClaudeSDKClient` approach.

The V2 Session API is delivered as part of gap remediation:

- **`unstable_v2_createSession()`** — creates a persistent session
- **`unstable_v2_resumeSession()`** — resumes an existing session by ID
- **`unstable_v2_prompt()`** — one-shot convenience for single prompts
- **`SDKSession`** interface — `send()`, `stream()`, `close()`, `sessionId`, async disposal
- **`SDKSessionOptions`** — subset of Options with `model` required

That covers the core multi-turn infrastructure: persistent subprocess, message sending, streaming responses, session lifecycle. All of that is gap work.

What remains here are two things: **QueryOptions additions** from the original spec that aren't in the gap, and **convenience wrappers** that improve the V2 API's usability in Swift.


## What the Gap Delivers

After gap remediation, multi-turn looks like this:

```swift
let session = Clod.createSession(options: sessionOptions)
try await session.send("What files are in this directory?")
for try await message in session.stream() {
    // Handle messages until result
}

try await session.send("Now explain the main one")
for try await message in session.stream() {
    // Handle messages until result
}

session.close()
```

`SDKSession.stream()` yields all messages from the subprocess indefinitely. The caller must detect result messages to know when a turn ends.


## What This Adds

### 1. receiveResponse() Convenience

The V2 API's `stream()` yields messages indefinitely across all turns. For the common case — send a prompt, get one complete response — callers must manually detect the `result` message and stop iterating.

Add a convenience method that wraps `stream()` and auto-terminates after the first result:

```swift
extension SDKSession {
    public func receiveResponse() -> AsyncThrowingStream<StdoutMessage, Error>
}
```

Returns a stream that yields messages until (and including) the next `result` message, then finishes. This is the per-turn method.

Usage becomes:

```swift
try await session.send("Hello")
for try await message in session.receiveResponse() {
    // Yields assistant messages, then result, then finishes
}

try await session.send("Follow up")
for try await message in session.receiveResponse() {
    // Next turn
}
```

This matches the Python SDK's `receive_response()` method.


### 2. QueryOptions: continueConversation and forkSession

The original API spec (Section 4.1) defines two options that aren't in the gap analysis (they were already in the spec, predating v0.2.34):

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `continueConversation` | `Bool?` | `nil` | Continue most recent conversation (spec Section 4.1) |
| `forkSession` | `Bool?` | `nil` | Fork instead of continuing when resuming (spec Section 14.3) |

These map to CLI flags: `continueConversation` adds `--continue`, `forkSession` adds `--fork-session`.

Add these to `QueryOptions` and wire them through `buildCLIArguments()`.

Fork behavior (from spec Section 14.3):

| Behavior | `forkSession: false` | `forkSession: true` |
|----------|---------------------|---------------------|
| Session ID | Same as original | New ID generated |
| History | Appends to original | Creates branch |
| Original session | Modified | Preserved |


### 3. Tests

**Unit tests** (MockTransport):

- `receiveResponse()` yields messages and finishes at result message
- `receiveResponse()` can be called multiple times for multiple turns
- `continueConversation` option adds `--continue` to CLI arguments
- `forkSession` option adds `--fork-session` to CLI arguments

**Integration tests** (real CLI):

- Two-turn conversation using V2 session + `receiveResponse()`: ask a question, get answer, ask follow-up referencing previous answer
- Resume: start session, capture ID, resume with new session, verify context preserved


## Prerequisites (from gap remediation)

These must exist before this work begins:

- V2 Session API: `createSession()`, `SDKSession` with `send()`/`stream()`/`close()`/`sessionId`
- `SDKSessionOptions` type
- `resumeSession()` function
- `closeStdinOnResult` parameter on `startMessageLoop()`


## Files to Modify

| File | Change |
|------|--------|
| `Sources/ClodKit/Session/SDKSession.swift` (or wherever V2 lands) | Add `receiveResponse()` convenience |
| `Sources/ClodKit/Query/QueryOptions.swift` | Add `continueConversation`, `forkSession` properties |
| `Sources/ClodKit/Query/QueryAPI.swift` | Wire new options through `buildCLIArguments()` |
| `Tests/ClodKitTests/ReceiveResponseTests.swift` | Per-turn convenience tests |
| `Tests/ClodKitTests/Integration/ConversationIntegrationTests.swift` | End-to-end tests |


## Verification

1. `swift build` compiles cleanly
2. `swift test` — all existing tests pass
3. `receiveResponse()` yields messages for one turn, then finishes
4. Two-turn conversation where second turn references first turn's answer
5. `continueConversation` and `forkSession` options produce correct CLI arguments
