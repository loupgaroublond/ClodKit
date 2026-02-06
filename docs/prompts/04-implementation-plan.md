# Task: Implementation Plan for ClaudeCodeSDK API Parity (Bridge Approach)

Create an implementation plan to bring the Swift ClaudeCodeSDK to complete feature parity with the TypeScript SDK, using the existing TypeScript bridge approach.

## Context

ClodeMonster/ClaudeCodeSDK is a Swift SDK for Claude Code. It currently has:
- `HeadlessBackend` - Direct CLI subprocess (limited features)
- `AgentSDKBackend` - Uses a Node.js wrapper (`sdk-wrapper.mjs`) that calls the TypeScript SDK

The TypeScript bridge approach works and gives us access to TypeScript SDK features.

**Goal**: Achieve complete feature parity with the TypeScript SDK. Every capability exposed by the TypeScript SDK should have a corresponding Swift API. The TypeScript SDK is the reference implementation - match its features exactly.

## Files to Review

Swift SDK:
- `/Users/yankee/Documents/Projects/ClodeMonster/ClaudeCodeSDK/Sources/ClaudeCodeSDK/` - Current implementation
- `/Users/yankee/Documents/Projects/ClodeMonster/ClaudeCodeSDK/Sources/ClaudeCodeSDK/Resources/sdk-wrapper.mjs` - Node.js bridge

Reference docs:
- `/Users/yankee/Documents/Projects/ClodeMonster/CLAUDE_AGENT_SDK_API_SPEC.md` - Full API spec
- `/Users/yankee/Documents/Projects/ClodeMonster/GAP_ANALYSIS.md` - Identified gaps
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/SDK_INTERNALS_ANALYSIS.md` - How SDKs work
- `/Users/yankee/Documents/Projects/ClodeMonster/CLAUDE.md` - Project requirements

TypeScript SDK types:
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/sdk.d.ts`

## Requirements

- Use AsyncSequence (not Combine) for streaming
- macOS only, cutting edge Swift
- Keep using TypeScript bridge via `sdk-wrapper.mjs`
- Focus on API parity, not native Swift control protocol (yet)

## Plan Should Cover

1. **SDK MCP Tools** (highest priority)
   - Swift API for defining tools (Codable + macros preferred)
   - How tool definitions pass through to sdk-wrapper.mjs
   - How tool invocations come back and get routed

2. **Hooks**
   - Swift API for registering hooks
   - How hook callbacks pass through the bridge
   - All hook event types

3. **Query Control Methods**
   - interrupt(), setModel(), setPermissionMode(), etc.
   - How these map to sdk-wrapper.mjs

4. **Dynamic MCP Management**
   - setMcpServers(), reconnectMcpServer(), toggleMcpServer()

5. **Session API**
   - V2 session interface if applicable

6. **Message Type Parity**
   - Ensure all TypeScript message types have Swift equivalents

7. **Migration Path**
   - How to migrate current Combine-based code to AsyncSequence

## Testing & Code Quality Requirements

The plan MUST include comprehensive testing architecture. Work is not complete until tests achieve 100% code coverage.

### Testability Architecture

Every component must be designed for testability from the start:
- **Protocol-based dependencies** - All external dependencies (subprocess, file system, network) abstracted behind protocols
- **Dependency injection** - No hardcoded dependencies; all injected via initializers
- **Actor isolation boundaries** - Clear boundaries that can be mocked independently
- **Deterministic behavior** - No hidden state or side effects that prevent reproducible tests

### Unit Testing (Mocked)

Full unit test coverage with mocked dependencies:
- **Protocol mocks** - Mock implementations for all protocol dependencies
- **Isolated component testing** - Each type tested in isolation
- **Edge cases** - Error paths, timeouts, malformed input, concurrent access
- **State machine coverage** - All state transitions tested

### Integration Testing (Mocked)

End-to-end flows with mocked subprocess/bridge:
- **Mock subprocess** - Simulated CLI responses for deterministic testing
- **Full message flow** - Query → streaming → completion with mocked data
- **Control protocol sequences** - Tool calls, hooks, permissions with mock responses
- **Error scenarios** - Subprocess crashes, malformed JSON, connection drops

### Integration Testing (Live)

Real integration with actual Claude CLI:
- **Smoke tests** - Basic query/response with real CLI
- **Feature verification** - Each feature validated against real CLI behavior
- **Regression suite** - Catch breaking changes from CLI updates
- **Skip markers** - Tests marked to skip in CI when API key unavailable

### Code Coverage Requirement

**100% code coverage is required for completion.** This means:
- Every line of production code exercised by tests
- Every branch taken (both true and false paths)
- Every error handling path tested
- Coverage measured and enforced in CI

### Test Organization

```
Tests/
├── ClaudeCodeSDKTests/
│   ├── Unit/           # Isolated component tests with mocks
│   ├── Integration/    # End-to-end with mock subprocess
│   └── Live/           # Real CLI tests (requires API key)
└── Mocks/              # Shared mock implementations
```

## Output

Create `/Users/yankee/Documents/Projects/ClodeMonster/reports/04-implementation-plan.md` with:
- Prioritized list of work items
- For each item: Swift API design, changes to sdk-wrapper.mjs, testing approach
- **Testing section for each item**: specific unit tests, integration tests, mocks needed
- Dependencies between items
- Estimated complexity (S/M/L) for each item
- **Testability architecture**: how dependencies are abstracted for testing
