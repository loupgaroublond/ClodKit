# Test Categories: NativeClaudeCodeSDK

This document tracks the different types of testing available for the SDK.

## Quick Reference

| Category | Command | When to Run |
|----------|---------|-------------|
| All Tests | `swift test` | CI/CD, pre-release |
| Unit Tests | `swift test --filter '!Integration'` | Dev loop, quick validation |
| Integration Tests | `swift test --filter Integration` | Feature complete, pre-merge |
| Coverage Tests | `swift test --filter Coverage` | Coverage reports |

## Test Categories

### 1. Unit Tests (Fast, No CLI Required)

**Purpose**: Test individual components in isolation with mocks.

**Characteristics**:
- No network access required
- No Claude CLI required
- Fast execution (< 1 second per test)
- Deterministic results
- Use MockTransport for transport layer

**Files**:
- `MockTransportTests.swift` - Transport mock behavior
- `JSONLineParserTests.swift` - JSON-line parsing
- `ControlProtocolHandlerTests.swift` - Control protocol logic
- `ControlProtocolTypesTests.swift` - Control message types
- `HookRegistryTests.swift` - Hook registration/invocation
- `HookTypesTests.swift` - Hook input/output types
- `MCPServerRouterTests.swift` - MCP routing logic
- `MCPToolTests.swift` - Tool schema/execution
- `SDKMCPServerTests.swift` - Server functionality
- `ClaudeSessionTests.swift` - Session management
- `ClaudeQueryTests.swift` - Query iteration
- `QueryAPITests.swift` - Query options/config
- `NativeBackendTests.swift` - Backend configuration
- `PermissionTypesTests.swift` - Permission types

**Run**: `swift test --filter '!Integration' --filter '!Coverage'`

### 2. Integration Tests (Slow, Requires CLI)

**Purpose**: Test end-to-end functionality with real Claude CLI.

**Characteristics**:
- Requires Claude CLI installed
- Requires valid API key
- Network access required
- Slower execution (5-60 seconds per test)
- May have variable results due to LLM responses
- Consumes API tokens (cost)

**Files** (in `Integration/` subdirectory):
- `IntegrationTestHelpers.swift` - Shared utilities
- `MCPIntegrationTests.swift` - SDK MCP tool invocation
- `HooksIntegrationTests.swift` - Hook system with real CLI
- `PermissionCallbackIntegrationTests.swift` - Permission callbacks
- `ControlProtocolIntegrationTests.swift` - Control protocol operations
- `ErrorIntegrationTests.swift` - Error scenarios

**Legacy file** (in root):
- `IntegrationTests.swift` - Basic transport/query tests

**Run**: `swift test --filter Integration`

**Prerequisites**:
```bash
# Verify Claude CLI is available
which claude

# Verify API key is set
echo $ANTHROPIC_API_KEY
```

### 3. Coverage Tests (Comprehensive, Mock-based)

**Purpose**: Fill gaps in unit test coverage for edge cases.

**Characteristics**:
- No CLI required
- Comprehensive edge case coverage
- May be slower than unit tests due to volume
- Focus on code path coverage

**Files**:
- `FullCoverageTests.swift` (~57KB) - Extensive coverage
- `AdditionalCoverageTests.swift` (~28KB) - Additional edge cases
- `FinalCoverageTests.swift` (~39KB) - Final coverage push

**Run**: `swift test --filter Coverage`

### 4. Performance Tests (Future)

**Purpose**: Measure performance characteristics.

**Planned Characteristics**:
- Measure latency, throughput
- Memory usage profiling
- Concurrency stress tests
- No CLI required (mock-based)

**Status**: Not yet implemented

### 5. Concurrency Tests (Future)

**Purpose**: Verify thread safety and race condition handling.

**Planned Characteristics**:
- Multi-threaded stress tests
- Actor isolation verification
- Race condition detection
- Deadlock detection

**Status**: Not yet implemented

## Running Tests

### All Tests
```bash
cd NativeClaudeCodeSDK
swift test
```

### Specific Category
```bash
# Unit tests only (fast)
swift test --filter '!Integration' --filter '!Coverage'

# Integration tests only (requires CLI)
swift test --filter Integration

# Coverage tests only
swift test --filter Coverage

# Specific test file
swift test --filter MCPIntegrationTests

# Specific test method
swift test --filter testSDKMCPToolInvocation
```

### Verbose Output
```bash
swift test -v --filter Integration
```

### Parallel Execution
```bash
# Swift test runs in parallel by default
# Limit parallelism for integration tests (API rate limits)
swift test --parallel --filter Integration
```

## Test Infrastructure

### Shared Helpers

**TestCapture<T>** - Thread-safe value capture
```swift
let captured = TestCapture<String>()
captured.value = "test"
XCTAssertEqual(captured.value, "test")
```

**TestFlag** - Thread-safe invocation flag
```swift
let flag = TestFlag()
flag.set()
XCTAssertTrue(flag.value)
```

**TestArrayCapture<T>** - Thread-safe array accumulator
```swift
let captured = TestArrayCapture<Int>()
captured.append(1)
captured.append(2)
XCTAssertEqual(captured.values, [1, 2])
```

### Integration Test Helpers

**skipIfCLIUnavailable()** - Skip test if CLI not available
```swift
func testSomething() async throws {
    try skipIfCLIUnavailable()
    // Test code...
}
```

**withTestDirectory()** - Isolated temp directory
```swift
try await withTestDirectory { tempDir in
    // tempDir is cleaned up after
}
```

**TestTools** - Standard test tools
```swift
TestTools.echoTool()     // Returns input as output
TestTools.failingTool()  // Always throws
TestTools.addTool()      // Adds two numbers
TestTools.slowTool()     // Delays response
```

## CI/CD Considerations

### GitHub Actions Example
```yaml
jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: swift test --filter '!Integration'

  integration-tests:
    runs-on: macos-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - name: Install Claude CLI
        run: npm install -g @anthropic-ai/claude-code
      - name: Run Integration Tests
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: swift test --filter Integration
```

### Cost Management

Integration tests consume API tokens. Estimated costs:
- Per test: ~100-1000 tokens
- Full integration suite: ~10,000 tokens
- Consider running integration tests only on PR merge, not every push

## Coverage Tracking

### Generate Coverage Report
```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/ClaudeCodeSDKPackageTests.xctest/Contents/MacOS/ClaudeCodeSDKPackageTests \
    -instr-profile=.build/debug/codecov/default.profdata
```

### Coverage Goals
- Unit tests: 80%+ line coverage
- Integration tests: All public APIs exercised
- Overall: 70%+ line coverage

## Adding New Tests

### Unit Test Template
```swift
import XCTest
@testable import ClaudeCodeSDK

final class MyComponentTests: XCTestCase {
    func testSomething() async throws {
        // Arrange
        let component = MyComponent()

        // Act
        let result = try await component.doSomething()

        // Assert
        XCTAssertEqual(result, expected)
    }
}
```

### Integration Test Template
```swift
import XCTest
@testable import ClaudeCodeSDK

final class MyIntegrationTests: XCTestCase {
    func testWithRealCLI() async throws {
        try skipIfCLIUnavailable()

        var options = defaultIntegrationOptions()
        // Configure options...

        let query = try await query(prompt: "...", options: options)

        for try await message in query {
            // Process messages...
        }

        // Assert results
    }
}
```
