# Concurrency and Thread-Safety Audit Report

**SDK**: NativeClaudeCodeSDK (Swift SDK for Claude Code)
**Date**: 2026-01-31
**Auditor**: Claude Opus 4.5
**Scope**: All source files in `NativeClaudeCodeSDK/Sources/ClaudeCodeSDK/`

---

## Executive Summary

The NativeClaudeCodeSDK demonstrates **generally sound concurrency design** with appropriate use of Swift actors for most shared state. However, several issues were identified that range from potential race conditions to patterns that warrant documentation.

| Severity | Count | Description |
|----------|-------|-------------|
| **Critical** | 1 | Potential double-iteration of AsyncThrowingStream |
| **High** | 3 | Lock discipline issues in `@unchecked Sendable` types |
| **Medium** | 4 | Untracked tasks, TOCTOU patterns, resource leaks |
| **Low** | 3 | Documentation gaps, minor cleanup issues |

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Critical Issues](#critical-issues)
3. [High Severity Issues](#high-severity-issues)
4. [Medium Severity Issues](#medium-severity-issues)
5. [Low Severity Issues](#low-severity-issues)
6. [Component-by-Component Analysis](#component-by-component-analysis)
7. [Recommendations](#recommendations)

---

## Architecture Overview

The SDK uses three primary concurrency patterns:

### 1. Actor Isolation (Primary Pattern)
- `ClaudeSession` - Main session coordinator
- `ControlProtocolHandler` - Request/response correlation
- `HookRegistry` - Hook callback management
- `MCPServerRouter` - MCP message routing

### 2. Lock-Protected Classes (`@unchecked Sendable`)
- `ProcessTransport` - Subprocess communication
- `MockTransport` - Test transport
- `NativeBackend` - Query execution coordinator

### 3. Immutable Types
- `ClaudeQuery` - AsyncSequence wrapper (immutable after init)
- `SDKMCPServer` - Tool registry (immutable after init)
- All type definitions (structs, enums)

---

## Critical Issues

### CRITICAL-1: Multiple Iterator Creation from Single-Consumer AsyncThrowingStream

**Location**: `ProcessTransport.swift:94-100`, `MockTransport.swift:65-96`

**Severity**: Critical

**Pattern**:
```swift
public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
    AsyncThrowingStream { [weak self] continuation in
        self?.lock.withLock {
            self?._streamContinuation = continuation  // Replaces previous!
        }
    }
}
```

**Explanation**:
`AsyncThrowingStream` is a **single-consumer** sequence. However, `readMessages()` can be called multiple times. Each call creates a new stream and **replaces** the stored continuation. This causes:
1. The previous stream iterator to be orphaned (never finishes, never yields)
2. Potential memory leak from unclosed iterators
3. Consumer code expecting messages that will never arrive

**Example Scenario**:
```swift
let stream1 = transport.readMessages()
let stream2 = transport.readMessages()  // Orphans stream1

for try await msg in stream1 {  // Hangs forever - continuation was replaced
    // Never receives messages
}
```

**Recommendation**:
Either:
1. Make `readMessages()` return the same stream on subsequent calls
2. Throw if called multiple times
3. Document as single-call API and add runtime assertion

```swift
public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
    lock.withLock {
        precondition(_streamContinuation == nil, "readMessages() can only be called once")
        // ... create stream
    }
}
```

---

## High Severity Issues

### HIGH-1: Continuation Operations Outside Lock in ProcessTransport

**Location**: `ProcessTransport.swift:189-204`

**Severity**: High

**Pattern**:
```swift
private func handleStdoutData(_ data: Data) {
    let (messages, continuation) = lock.withLock {
        // ... modify _readBuffer, get continuation
        return (msgs, _streamContinuation)
    }

    // Yield messages outside lock - POTENTIAL RACE
    for message in messages {
        continuation?.yield(message)  // What if continuation becomes nil?
    }
}
```

**Explanation**:
While the lock correctly protects the internal state mutation, the continuation reference is used **after** the lock is released. If `handleStdoutEOF()` or `handleTermination()` executes on another thread between getting the continuation and yielding, the continuation could be set to nil and finished.

In practice, `AsyncThrowingStream.Continuation.yield()` should handle being called after `finish()`, but this creates an implicit dependency on implementation details.

**Also affected**: Lines 206-214, 217-229

**Recommendation**:
Keep critical operations atomic. If yielding must happen outside the lock (to avoid potential deadlocks), document the safety invariant:

```swift
// SAFETY: Continuation.yield() is safe to call after finish() - it no-ops.
// We intentionally yield outside the lock to avoid holding the lock during
// potentially blocking continuation operations.
```

---

### HIGH-2: Untracked Task in NativeBackend.cancel()

**Location**: `NativeBackend.swift:133-143`

**Severity**: High

**Pattern**:
```swift
public func cancel() {
    let queryToCancel = lock.withLock { activeQuery }
    if let claudeQuery = queryToCancel {
        Task {  // Unstructured, untracked task
            try? await claudeQuery.interrupt()
        }
    }
}
```

**Explanation**:
The spawned `Task` is not tracked or awaited. If the `NativeBackend` is deallocated while this task is running:
1. The task continues running with a strong reference to `claudeQuery`
2. No way to cancel or wait for this task
3. Error silently swallowed

**Example Scenario**:
```swift
let backend = NativeBackend()
let query = try await backend.runSinglePrompt(prompt: "...", options: opts)
backend.cancel()
// Backend can be deallocated while cancel task still running
// No way to know when cancel completes
```

**Recommendation**:
Track the cancellation task or make `cancel()` async:

```swift
// Option 1: Make async
public func cancel() async {
    let queryToCancel = lock.withLock { activeQuery }
    if let claudeQuery = queryToCancel {
        try? await claudeQuery.interrupt()
    }
}

// Option 2: Track the task
private var cancelTask: Task<Void, Never>?

public func cancel() {
    cancelTask?.cancel()
    cancelTask = Task { [weak self] in
        // ...
    }
}
```

---

### HIGH-3: closeInternal() Performs I/O Operations After Reading State

**Location**: `ProcessTransport.swift:232-272`

**Severity**: High

**Pattern**:
```swift
private func closeInternal() async {
    // Read state once
    let (running, stdinPipe, process) = lock.withLock { (_running, _stdinPipe, _process) }

    guard running else { return }  // TOCTOU: running could change here

    // Long-running operations WITHOUT lock:
    stdinPipe?.fileHandleForWriting.closeFile()
    // ... wait for process, potentially up to 5 seconds

    // Re-acquire lock for cleanup
    lock.withLock {
        _running = false
        // ...
    }
}
```

**Explanation**:
This is a Time-Of-Check-Time-Of-Use (TOCTOU) pattern. Between checking `running` and performing operations:
1. Another thread could call `closeInternal()`
2. Both would pass the `guard running` check
3. Both would try to close the same file handles
4. Double-close could cause issues

**Example Scenario**:
```swift
// Thread 1                          // Thread 2
closeInternal()                      closeInternal()
  running == true ✓                    running == true ✓
  closeFile() on stdinPipe             closeFile() on stdinPipe  // Double close!
```

**Recommendation**:
Use a state machine with atomic transitions:

```swift
private enum TransportState {
    case running, closing, closed
}
private var _state: TransportState = .running

private func closeInternal() async {
    let shouldClose = lock.withLock {
        guard _state == .running else { return false }
        _state = .closing  // Atomic transition
        return true
    }
    guard shouldClose else { return }

    // Now safe - only one thread reaches here
    // ... cleanup
}
```

---

## Medium Severity Issues

### MEDIUM-1: Temp File Leak in QueryAPI

**Location**: `QueryAPI.swift:456-463`

**Severity**: Medium

**Pattern**:
```swift
private func buildMCPConfigFile(...) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "mcp-config-\(UUID().uuidString).json"
    let filePath = tempDir.appendingPathComponent(fileName)
    try data.write(to: filePath)
    return filePath.path
    // File never deleted!
}
```

**Explanation**:
Temporary MCP config files are created but never cleaned up. Over time, this can accumulate disk usage.

**Recommendation**:
Register cleanup with `ClaudeQuery` or use auto-deleting temp files:

```swift
// In ClaudeQuery or ClaudeSession
deinit {
    if let configPath = mcpConfigPath {
        try? FileManager.default.removeItem(atPath: configPath)
    }
}
```

---

### MEDIUM-2: ControlProtocolHandler Continuation Registration Race

**Location**: `ControlProtocolHandler.swift:103-111`

**Severity**: Medium

**Pattern**:
```swift
group.addTask {
    try await withCheckedThrowingContinuation { continuation in
        Task {
            await self.registerPendingRequest(requestId: requestId, continuation: continuation)
        }
    }
}
```

**Explanation**:
The continuation registration happens in a detached `Task`, which could execute after the response arrives. This creates a race:
1. Request sent to CLI
2. CLI responds immediately
3. Response handler looks for continuation - not found yet!
4. Continuation finally registered - response already lost

**Example Scenario**:
With very fast CLI responses or under heavy load, the registration Task might not run before the response arrives.

**Recommendation**:
Register continuation synchronously or await the registration:

```swift
group.addTask {
    try await withCheckedThrowingContinuation { continuation in
        // Option: Register synchronously since we're already in actor context
        await self.registerPendingRequest(requestId: requestId, continuation: continuation)
    }
}
```

Note: After reviewing more carefully, this is inside `withCheckedThrowingContinuation` which is a synchronous call. The nested `Task` is unnecessary and creates the race. Just calling `await self.registerPendingRequest(...)` directly would work since we're already in an async context.

---

### MEDIUM-3: Process Termination Handler Thread Safety

**Location**: `ProcessTransport.swift:167-169`

**Severity**: Medium

**Pattern**:
```swift
process.terminationHandler = { [weak self] process in
    self?.handleTermination(exitCode: process.terminationStatus)
}
```

**Explanation**:
`terminationHandler` is called from an arbitrary thread by Foundation. `handleTermination` then acquires the lock. This is correct, but the timing of termination relative to other operations (like `closeInternal()`) creates subtle dependencies.

If termination happens while `closeInternal()` is waiting in the "give process time to exit" loop, both paths will try to finish the continuation.

**Safeguarded by**: The nil-check pattern (`let cont = _streamContinuation; _streamContinuation = nil; cont?.finish()`) prevents double-finish.

**Recommendation**:
Document the safety invariant and consider making termination state explicit:

```swift
// SAFETY: Termination handler and closeInternal() both use the atomic
// continuation extraction pattern - only the first to clear _streamContinuation
// will call finish().
```

---

### MEDIUM-4: WeakCapture in startMessageLoop Could Silently Stop

**Location**: `ClaudeSession.swift:225-235`

**Severity**: Medium

**Pattern**:
```swift
public func startMessageLoop() -> AsyncThrowingStream<StdoutMessage, Error> {
    AsyncThrowingStream { [weak self] continuation in
        guard let self else {
            continuation.finish()  // Silently finishes if session deallocated
            return
        }
        Task {
            await self.runMessageLoop(continuation: continuation)
        }
    }
}
```

**Explanation**:
If the `ClaudeSession` is deallocated between stream creation and task execution, the stream finishes silently. The consumer sees normal completion, not an error.

**Example Scenario**:
```swift
var session: ClaudeSession? = ClaudeSession(...)
let stream = await session!.startMessageLoop()
session = nil  // Deallocate session

for try await msg in stream {
    // Stream immediately finishes - no messages, no error
    // Consumer thinks query completed normally with no output
}
```

**Recommendation**:
Either throw an error when session is deallocated, or document this behavior:

```swift
guard let self else {
    continuation.finish(throwing: SessionError.sessionClosed)
    return
}
```

---

## Low Severity Issues

### LOW-1: SDKMCPServer @unchecked Sendable is Safe but Undocumented

**Location**: `SDKMCPServer.swift:17`

**Pattern**:
```swift
public final class SDKMCPServer: @unchecked Sendable {
    public let name: String
    public let version: String
    private let tools: [String: MCPTool]  // All immutable after init
```

**Explanation**:
The `@unchecked Sendable` is safe because all properties are `let` constants assigned in `init()`. However, this safety relies on the class being effectively immutable, which isn't documented.

**Recommendation**:
Add a comment explaining the safety invariant:

```swift
/// In-process MCP server for SDK tools.
///
/// Thread-safety: This class is Sendable because all properties are
/// immutable after initialization. The `@unchecked Sendable` conformance
/// is safe - there is no mutable state.
public final class SDKMCPServer: @unchecked Sendable {
```

---

### LOW-2: ClaudeQuery @unchecked Sendable Relies on Session Being Actor

**Location**: `ClaudeQuery.swift:24`

**Pattern**:
```swift
public final class ClaudeQuery: AsyncSequence, @unchecked Sendable {
    private let session: ClaudeSession  // Actor
    private let underlyingStream: AsyncThrowingStream<StdoutMessage, Error>  // Sendable
```

**Explanation**:
The `@unchecked Sendable` is safe because:
1. `session` is an actor (inherently Sendable)
2. `underlyingStream` is Sendable
3. No mutable state in `ClaudeQuery`

However, this isn't documented.

**Recommendation**:
Document the safety:

```swift
/// Thread-safety: This class is Sendable because it holds only immutable
/// references to a Sendable actor (ClaudeSession) and a Sendable stream.
public final class ClaudeQuery: AsyncSequence, @unchecked Sendable {
```

---

### LOW-3: Non-async Actor Methods Could Cause Confusion

**Location**: `ControlProtocolHandler.swift:141, 165, 231`

**Pattern**:
```swift
public actor ControlProtocolHandler {
    public func handleControlResponse(_ response: ControlResponse) {  // Not async!
        // ...accesses pendingRequests...
    }
}
```

**Explanation**:
While Swift actors correctly isolate non-async methods (callers must use `await`), the lack of `async` keyword can cause confusion. Some developers might think these methods are synchronous when they're actually isolated.

Looking at the call site in `ClaudeSession.swift:260`:
```swift
case .controlResponse(let response):
    await controlHandler.handleControlResponse(response)  // Correct!
```

The call site is correct, but the API surface is potentially confusing.

**Recommendation**:
This is a style preference. Either:
1. Keep as-is (valid Swift, compiler enforces safety)
2. Make methods async for clarity (minor performance impact from extra hop)

---

## Component-by-Component Analysis

### ClaudeSession.swift ✅ SAFE

| Aspect | Status | Notes |
|--------|--------|-------|
| Actor isolation | ✅ | All mutable state isolated |
| Weak captures | ✅ | Properly prevents retain cycles |
| Async boundaries | ✅ | All cross-actor calls awaited |

**No issues found.** Well-designed actor with proper isolation.

---

### ControlProtocolHandler.swift ⚠️ ISSUES

| Aspect | Status | Notes |
|--------|--------|-------|
| Actor isolation | ✅ | Proper isolation |
| Continuation safety | ⚠️ | Registration race (MEDIUM-2) |
| CheckedContinuation | ✅ | Correctly resumed exactly once |

---

### HookRegistry.swift ✅ SAFE

| Aspect | Status | Notes |
|--------|--------|-------|
| Actor isolation | ✅ | All state isolated |
| Type erasure | ✅ | CallbackBox properly Sendable |
| @Sendable handlers | ✅ | Correctly constrained |

**No issues found.** Clean actor-based design.

---

### MCPServerRouter.swift ✅ SAFE

| Aspect | Status | Notes |
|--------|--------|-------|
| Actor isolation | ✅ | Proper isolation |
| Async routing | ✅ | Tool calls properly awaited |

**No issues found.** Simple, correct actor.

---

### ProcessTransport.swift ⚠️ ISSUES

| Aspect | Status | Notes |
|--------|--------|-------|
| Lock discipline | ⚠️ | Operations outside lock (HIGH-1) |
| @unchecked Sendable | ⚠️ | Correct but needs documentation |
| Single-consumer stream | ❌ | Multiple readMessages() calls (CRITICAL-1) |
| Termination handling | ⚠️ | Race with closeInternal() (HIGH-3) |

---

### MockTransport.swift ⚠️ ISSUES

| Aspect | Status | Notes |
|--------|--------|-------|
| Lock discipline | ✅ | Consistent lock usage |
| Single-consumer stream | ❌ | Same issue as ProcessTransport (CRITICAL-1) |
| Test isolation | ✅ | Clean state management |

---

### NativeBackend.swift ⚠️ ISSUES

| Aspect | Status | Notes |
|--------|--------|-------|
| Lock discipline | ✅ | Consistent for activeQuery |
| Untracked task | ⚠️ | cancel() spawns untracked Task (HIGH-2) |
| @unchecked Sendable | ✅ | Correct with NSLock |

---

### QueryAPI.swift ⚠️ ISSUES

| Aspect | Status | Notes |
|--------|--------|-------|
| Sequential setup | ✅ | Correct ordering |
| Temp file cleanup | ⚠️ | Files not deleted (MEDIUM-1) |
| Async flow | ✅ | Proper await usage |

---

### ClaudeQuery.swift ✅ SAFE (with caveats)

| Aspect | Status | Notes |
|--------|--------|-------|
| Immutability | ✅ | No mutable state |
| @unchecked Sendable | ⚠️ | Safe but undocumented (LOW-2) |
| Delegation | ✅ | All ops properly delegated to actor |

---

### SDKMCPServer.swift ✅ SAFE (with caveats)

| Aspect | Status | Notes |
|--------|--------|-------|
| Immutability | ✅ | All let constants |
| @unchecked Sendable | ⚠️ | Safe but undocumented (LOW-1) |
| Async tool handlers | ✅ | Properly @Sendable constrained |

---

### Type Definition Files ✅ SAFE

- `HookTypes.swift` - All Sendable conformances correct
- `PermissionTypes.swift` - All Sendable conformances correct
- `ControlProtocolTypes.swift` - All Sendable conformances correct
- `MCPTool.swift` - @Sendable handler correctly typed
- `JSONLineParser.swift` - Stateless, Sendable
- `Transport.swift` - Protocol correctly requires Sendable

---

## Recommendations

### Priority 1: Critical Fixes

1. **Add single-call enforcement to readMessages()**
   - Add precondition or return same stream
   - Affects: ProcessTransport, MockTransport

### Priority 2: High-Impact Improvements

2. **Fix continuation registration race**
   - Remove nested Task in sendRequest()
   - Direct await the registration

3. **Track or await cancel task in NativeBackend**
   - Make cancel() async, or track the Task

4. **Add state machine to ProcessTransport.closeInternal()**
   - Prevent TOCTOU race

### Priority 3: Cleanup and Documentation

5. **Add temp file cleanup for MCP config**
   - Clean up in ClaudeQuery deinit or session close

6. **Document @unchecked Sendable safety**
   - ProcessTransport, MockTransport, ClaudeQuery, SDKMCPServer, NativeBackend

7. **Consider making weak capture failure explicit**
   - Throw SessionError.sessionClosed instead of silent finish

---

## Appendix: Files Audited

| File | Lines | Concurrency Patterns |
|------|-------|---------------------|
| ClaudeSession.swift | 379 | Actor |
| ControlProtocolHandler.swift | 347 | Actor, CheckedContinuation |
| HookRegistry.swift | 662 | Actor, @Sendable callbacks |
| MCPServerRouter.swift | 191 | Actor |
| ProcessTransport.swift | 283 | NSLock, @unchecked Sendable, AsyncThrowingStream |
| MockTransport.swift | 197 | NSLock, @unchecked Sendable, AsyncThrowingStream |
| NativeBackend.swift | 296 | NSLock, @unchecked Sendable, Task |
| QueryAPI.swift | 519 | Async functions |
| ClaudeQuery.swift | 129 | AsyncSequence, @unchecked Sendable |
| SDKMCPServer.swift | 186 | @unchecked Sendable |
| HookTypes.swift | 662 | Sendable types |
| PermissionTypes.swift | ~300 | Sendable types |
| ControlProtocolTypes.swift | ~200 | Sendable types |
| MCPTool.swift | ~150 | @Sendable handler |
| JSONLineParser.swift | ~100 | Sendable struct |
| Transport.swift | ~50 | Sendable protocol |

---

*End of Audit Report*
