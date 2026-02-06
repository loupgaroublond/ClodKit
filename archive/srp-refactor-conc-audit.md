# ClaudeCodeSDK Concurrency Audit Report (Post-SRP Refactor) - STRICT

**Date:** 2026-01-31
**Codebase:** NativeClaudeCodeSDK
**Swift Version:** 6.0+
**Files Audited:** 39 Swift source files
**Audit Mode:** STRICT (bulletproof standard)

---

## Executive Summary

This is a **strict re-audit** applying bulletproof standards. The refactoring improved code organization but did not fix most concurrency issues from the original audit.

**Issue Severity Distribution:**
- Critical: 2
- High: 3
- Medium: 3
- Low: 2

**Verdict: 4/10** (needs work before production use)

---

## Critical Issues

### CRITICAL-1: Request/Response Registration Race Condition

**Location:** `ControlProtocolHandler.swift:105-110`
**Severity:** Critical
**Status:** UNFIXED from original audit (was MEDIUM-2, promoted to Critical)

**Code:**
```swift
group.addTask {
    try await withCheckedThrowingContinuation { continuation in
        Task {
            await self.registerPendingRequest(requestId: requestId, continuation: continuation)
        }
    }
}
```

**Problem:**
The continuation registration is deferred to an unstructured `Task`. This creates a race:
1. Request sent to CLI (line 98)
2. TaskGroup entered, response task spawned
3. Inside `withCheckedThrowingContinuation`, a nested Task is spawned (non-blocking)
4. CLI responds immediately
5. Message loop calls `handleControlResponse` → looks for continuation → NOT FOUND
6. Response dropped
7. Continuation never resumes → hangs until timeout

**Impact:** Requests can hang for 60 seconds (default timeout) before failing, even though the CLI responded successfully.

**Fix Required:**
```swift
public func sendRequest(_ payload: ControlRequestPayload, timeout: TimeInterval? = nil) async throws -> FullControlResponsePayload {
    let requestId = generateRequestId()
    let request = FullControlRequest(requestId: requestId, request: payload)
    let data = try encoder.encode(request)
    let effectiveTimeout = timeout ?? defaultTimeout

    return try await withCheckedThrowingContinuation { continuation in
        // Register FIRST, while we're on the actor
        pendingRequests[requestId] = continuation

        Task {
            do {
                try await transport.write(data)
            } catch {
                if self.pendingRequests.removeValue(forKey: requestId) != nil {
                    continuation.resume(throwing: error)
                }
                return
            }

            // Timeout
            Task {
                try? await Task.sleep(nanoseconds: UInt64(effectiveTimeout * 1_000_000_000))
                if let cont = self.pendingRequests.removeValue(forKey: requestId) {
                    cont.resume(throwing: ControlProtocolError.timeout(requestId: requestId))
                }
            }
        }
    }
}
```

---

### CRITICAL-2: Multiple readMessages() Calls Replace Continuation

**Location:** `ProcessTransport.swift:94-100`
**Severity:** Critical
**Status:** UNFIXED from original audit (was CRITICAL-1)

**Code:**
```swift
public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
    AsyncThrowingStream { [weak self] continuation in
        self?.lock.withLock {
            self?._streamContinuation = continuation  // REPLACES previous!
        }
    }
}
```

**Problem:**
Calling `readMessages()` multiple times replaces the stored continuation, orphaning all previous streams.

**Scenario:**
```swift
let stream1 = transport.readMessages()
let stream2 = transport.readMessages()  // Orphans stream1!

for try await msg in stream1 {
    // HANGS FOREVER - continuation was replaced, stream1 never receives messages or finishes
}
```

**Impact:** Any code that accidentally calls `readMessages()` twice causes the first consumer to hang indefinitely.

**Fix Required:**
```swift
public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
    lock.withLock {
        precondition(_streamContinuation == nil,
            "readMessages() can only be called once per transport instance")
    }
    return AsyncThrowingStream { [weak self] continuation in
        self?.lock.withLock {
            self?._streamContinuation = continuation
        }
    }
}
```

---

## High Severity Issues

### HIGH-1: Untracked Task in cancel()

**Location:** `NativeBackend.swift:98-108`
**Severity:** High
**Status:** UNFIXED from original audit (was HIGH-2)

**Code:**
```swift
public func cancel() {
    let queryToCancel = lock.withLock { activeQuery }

    if let claudeQuery = queryToCancel {
        Task {
            try? await claudeQuery.interrupt()
        }
    }
}
```

**Problems:**
1. Task is fire-and-forget - no way to await completion
2. Error silently swallowed (`try?`)
3. Multiple rapid `cancel()` calls spawn multiple concurrent Tasks
4. No way to know if cancellation actually succeeded
5. Starting a new query immediately after cancel() may race with ongoing cancellation

**Impact:** Code like this is broken:
```swift
backend.cancel()
// User expects previous query is cancelled, starts new one
let newQuery = try await backend.runSinglePrompt(...)  // May race with cancel!
```

**Fix Required:**
```swift
private var cancelTask: Task<Void, Never>?

public func cancel() async {
    // Cancel any previous cancellation
    cancelTask?.cancel()

    let queryToCancel = lock.withLock { activeQuery }

    if let claudeQuery = queryToCancel {
        cancelTask = Task {
            try? await claudeQuery.interrupt()
        }
        await cancelTask?.value  // Wait for completion
    }
}
```

---

### HIGH-2: TOCTOU Race in closeInternal()

**Location:** `ProcessTransport.swift:232-272`
**Severity:** High
**Status:** UNFIXED from original audit (was HIGH-3)

**Code:**
```swift
private func closeInternal() async {
    let (running, stdinPipe, process) = lock.withLock { (_running, _stdinPipe, _process) }

    guard running else { return }  // TOCTOU: both threads pass this

    // ... long-running operations without lock
    stdinPipe?.fileHandleForWriting.closeFile()  // Double-close possible
    process.terminate()  // Called twice
    // ...

    lock.withLock {
        _running = false  // First one sets false, second one already passed guard
        // ...
    }
}
```

**Problem:**
Two concurrent `close()` calls both read `running=true`, both pass the guard, both execute close logic. Results in:
- Double `closeFile()` on same file handles
- Double `terminate()` on same process
- Potential crashes or undefined behavior

**Scenario:**
```swift
// Thread A                         // Thread B
closeInternal()                     closeInternal()
  running == true ✓                   running == true ✓
  closeFile(stdinPipe)                closeFile(stdinPipe)  // DOUBLE CLOSE!
  process.terminate()                 process.terminate()   // DOUBLE TERMINATE!
```

**Fix Required:**
```swift
private var _closeStarted = false

private func closeInternal() async {
    let shouldClose = lock.withLock { () -> Bool in
        guard !_closeStarted && _running else { return false }
        _closeStarted = true
        return true
    }
    guard shouldClose else { return }

    // Now safe - only one thread reaches here
    // ... rest of close logic
}
```

---

### HIGH-3: Silent Stream Finish Masks Errors

**Location:** `ClaudeSession.swift:224-234`
**Severity:** High
**Status:** UNFIXED from original audit (was MEDIUM-4)

**Code:**
```swift
public func startMessageLoop() -> AsyncThrowingStream<StdoutMessage, Error> {
    AsyncThrowingStream { [weak self] continuation in
        guard let self else {
            continuation.finish()  // Silent finish - looks like success!
            return
        }

        Task {
            await self.runMessageLoop(continuation: continuation)
        }
    }
}
```

**Problem:**
If session is deallocated between stream creation and Task execution, the stream finishes **successfully** with no messages. Consumer code cannot distinguish between:
- Query completed normally with no output
- Session died unexpectedly

**Impact:**
```swift
var session: ClaudeSession? = ClaudeSession(...)
let stream = await session!.startMessageLoop()
session = nil  // Oops, deallocated

for try await msg in stream {
    // Loop exits immediately, no error thrown
    // Consumer thinks query completed successfully!
}
print("Query done!")  // Wrong - session crashed
```

**Fix Required:**
```swift
guard let self else {
    continuation.finish(throwing: SessionError.sessionClosed)
    return
}
```

---

## Medium Severity Issues

### MEDIUM-1: Temp File Leak

**Location:** `QueryAPI.swift:180-213`
**Severity:** Medium
**Status:** UNFIXED from original audit (was MEDIUM-1)

**Code:**
```swift
private func buildMCPConfigFile(...) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "mcp-config-\(UUID().uuidString).json"
    let filePath = tempDir.appendingPathComponent(fileName)

    try data.write(to: filePath)

    return filePath.path  // Never deleted!
}
```

**Impact:** Each query with MCP servers creates a temp file that is never cleaned up. Long-running apps accumulate files.

**Fix Required:** Track config path and delete in ClaudeSession.close() or ClaudeQuery deinit.

---

### MEDIUM-2: Multiple Iteration of ClaudeQuery

**Location:** `ClaudeQuery.swift:44-46`
**Severity:** Medium

**Code:**
```swift
public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(stream: underlyingStream)
}
```

**Problem:**
`AsyncThrowingStream` is single-consumer. Multiple calls to `makeAsyncIterator()` create multiple iterators over the same stream, causing undefined behavior (messages randomly distributed, some lost).

**Impact:**
```swift
let query = try await ClaudeCode.query("test")

Task { for try await msg in query { print("A: \(msg)") } }
Task { for try await msg in query { print("B: \(msg)") } }
// Messages randomly split between A and B, some may be lost
```

**Fix Required:** Add runtime check or clearly document single-iteration contract.

---

### MEDIUM-3: Blocking Call in Async Context

**Location:** `NativeBackend.swift:126`
**Severity:** Medium

**Code:**
```swift
public func validateSetup() async throws -> Bool {
    try process.run()
    process.waitUntilExit()  // BLOCKS entire thread
    // ...
}
```

**Impact:** Blocks a thread from Swift's cooperative thread pool. Under load, this can cause thread starvation.

**Fix Required:** Use termination handler with continuation.

---

## Low Severity Issues

### LOW-1: Continuation Operations Inside Lock

**Location:** `ProcessTransport.swift:267-270`
**Severity:** Low

**Code:**
```swift
lock.withLock {
    // ...
    let cont = _streamContinuation
    _streamContinuation = nil
    cont?.finish()  // Inside lock
}
```

**Assessment:** Safe in this case (finish() is synchronous, doesn't acquire locks), but unusual pattern. Add comment explaining safety.

---

### LOW-2: @unchecked Sendable Missing Safety Documentation

**Location:** ProcessTransport, MockTransport, NativeBackend, ClaudeQuery, SDKMCPServer
**Severity:** Low

All `@unchecked Sendable` types lack comments explaining WHY they are safe. Future maintainers may not understand the safety invariants.

**Fix Required:** Add safety documentation to each type.

---

## Issue Comparison: Before vs After Refactoring

| Issue | Original Severity | New Severity | Status |
|-------|-------------------|--------------|--------|
| Multiple readMessages() replacing continuation | CRITICAL-1 | CRITICAL-2 | **UNFIXED** |
| Request/response registration race | MEDIUM-2 | CRITICAL-1 | **UNFIXED** (promoted) |
| Untracked Task in cancel() | HIGH-2 | HIGH-1 | **UNFIXED** |
| TOCTOU in closeInternal() | HIGH-3 | HIGH-2 | **UNFIXED** |
| Silent stream finish on dealloc | MEDIUM-4 | HIGH-3 | **UNFIXED** (promoted) |
| Temp file leak | MEDIUM-1 | MEDIUM-1 | **UNFIXED** |
| Continuation ops outside lock | HIGH-1 | Safe | Confirmed safe |
| Process termination handler race | MEDIUM-3 | Safe | Confirmed safe |

**Summary:** The SRP refactoring improved code organization but did not fix any of the actual concurrency bugs.

---

## Priority Fix List

| Priority | Issue | Effort |
|----------|-------|--------|
| **P0** | CRITICAL-1: Registration race | Medium - restructure sendRequest() |
| **P0** | CRITICAL-2: readMessages() replacement | Low - add precondition |
| **P1** | HIGH-1: Untracked cancel Task | Low - make async or track |
| **P1** | HIGH-2: TOCTOU in closeInternal() | Low - add close flag |
| **P1** | HIGH-3: Silent stream finish | Low - throw error instead |
| **P2** | MEDIUM-1: Temp file leak | Low - add cleanup |
| **P2** | MEDIUM-2: Multiple iteration | Low - add check or document |
| **P2** | MEDIUM-3: Blocking waitUntilExit | Medium - use continuation |
| **P3** | LOW-1, LOW-2 | Low - add comments |

---

## Revised Score

**Strict Score: 4/10**

Breakdown:
- 2 Critical bugs that can cause hangs or undefined behavior
- 3 High issues that can cause races or mask errors
- 3 Medium issues affecting reliability
- Good architectural foundation (actors, Sendable, locks) - just needs bug fixes

**Verdict:** The bones are solid, but **do not ship to production** until P0 and P1 issues are fixed.
