# Testing Where Types Can't Reach

A strategy for systematically verifying invariants that Swift's type system cannot express.


## 1. The Problem Class: Boundary Crossing

A **boundary crossing** occurs when data moves between interpretation contexts. The sending context treats the data as opaque bytes; the receiving context assigns it meaning — and potentially executes it.

Every injection vulnerability in software is an instance of this pattern:

| Boundary | Source context | Target context | Classic exploit |
|----------|---------------|----------------|-----------------|
| SQL | Application string | SQL parser | `'; DROP TABLE users--` |
| HTML | User input | Browser DOM | `<script>alert(1)</script>` |
| Shell | Program argument | Shell interpreter | `$(rm -rf /)` |
| JSON | Struct field | JSON parser | Unescaped quotes break structure |
| Filesystem | User string | Path resolver | `../../etc/passwd` |

The pattern is always the same: a value that is *data* in one context becomes *code* in another.


### The ClodKit Instance

ClodKit constructs CLI commands from user-supplied `QueryOptions` fields. The data flow:

```
QueryOptions.systemPrompt: String     ← Swift string (data)
       │
       ▼
buildCLIArguments() → ["--system-prompt", systemPrompt]
       │
       ▼
.joined(separator: " ") → "claude --system-prompt Don't stop"
       │
       ▼
ProcessTransport.start()
  process.executableURL = /bin/zsh
  process.arguments = ["-l", "-c", command]     ← shell string (code)
       │
       ▼
zsh interprets: claude --system-prompt Don't stop
                                       ^^^
                               unmatched quote — shell hangs
```

Three files participate in this chain:

- **`QueryAPI.swift:53`** — joins arguments with spaces: `([cliPath] + arguments).joined(separator: " ")`
- **`ProcessTransport.swift:170-171`** — passes joined string to zsh: `process.arguments = ["-l", "-c", command]`
- **`NativeBackend.swift:121-122`** — interpolates cliPath into shell command: `"which \(cli)"`

The apostrophe bug ([docs/handoff-apostrophe-bug.md](handoff-apostrophe-bug.md)) was the first symptom. But apostrophes are one character in a universe of shell metacharacters: `` ` ``, `$`, `(`, `)`, `;`, `|`, `&`, `\`, `"`, `'`, `{`, `}`, `<`, `>`, `!`, `~`, `#`, newlines, null bytes. A system prompt containing `$(rm -rf /)` would execute that command.


## 2. Types as Proof, Tests as Substitute

In a language with dependent or refinement types, the compiler enforces constraints on values:

```
-- Pseudocode: a type that can only hold shell-safe strings
type ShellSafe = { s : String | ∀ c ∈ s, c ∉ shellMetachars }

-- This won't compile — the compiler proves the constraint
let prompt : ShellSafe = "Don't stop"  -- TYPE ERROR: ' is a shell metachar

-- This compiles — the compiler can prove it's safe
let prompt : ShellSafe = "Do not stop"  -- OK
```

Other useful refinement types that don't exist in Swift:

- `NonEmptyString` — a `String` with `count > 0`
- `PositiveInt` — an `Int` with `value > 0`
- `ValidPath` — a `String` that is a legal filesystem path
- `JSONSafeString` — a `String` whose content won't break JSON structure

Swift's type system can't express any of these. A `String` is a `String` whether it contains `"hello"` or `"; rm -rf /"`. An `Int` is an `Int` whether it's `5` or `-1`.

**Tests fill this gap.** Not as ad-hoc spot checks, but as systematic substitutes for the proofs a richer type system would provide:

1. Identify what the ideal refinement type would guarantee
2. Enumerate the full range of values the actual Swift type permits
3. Test that the invariant holds across that range — including the values the refinement type would have rejected

This is the same work a dependent type checker does, moved from compile time to test time. The coverage is weaker (tests check samples, types prove universals) but the method is principled: we know exactly what we're testing and why.


## 3. The Method

Three steps, applied systematically to every public API surface.


### Step 1: Inventory the Type Gaps

For every value in the public API, identify constraints that matter but aren't type-enforced.

| Field | Swift type | Actual constraint | Gap |
|-------|-----------|-------------------|-----|
| `systemPrompt` | `String?` | Must survive shell + JSON boundaries without reinterpretation | Any `String` value accepted |
| `appendSystemPrompt` | `String?` | Same as systemPrompt | Same |
| `model` | `String?` | Must be a valid model identifier, shell-safe | Any `String` value accepted |
| `maxTurns` | `Int?` | Must be positive (or nil) | Any `Int` value accepted, including 0, -1 |
| `maxThinkingTokens` | `Int?` | Must be positive (or nil) | Same |
| `cliPath` | `String?` | Must be a valid executable path, not a shell command | Any `String` value accepted |
| `allowedTools` | `[String]?` | Each element must not contain commas (joined with `,`) | Any `[String]` accepted |
| `blockedTools` | `[String]?` | Each element must be a valid tool name | Any `[String]` accepted |
| `additionalDirectories` | `[String]` | Each must be a valid directory path, shell-safe | Any `[String]` accepted |
| `resume` | `String?` | Must be a valid session ID, shell-safe | Any `String` accepted |
| `environment` | `[String: String]` | Keys/values must not corrupt the process environment | Any dict accepted |
| `prompt` (query param) | `String` | Must survive JSON serialization intact | Any `String` accepted |


### Step 2: Inventory the Crossing Points

For every boundary, enumerate ALL the places where values cross it.

**Shell boundary** (9 crossing points in `QueryAPI.buildCLIArguments` + command construction):

| Crossing point | Source field | CLI flag | Location |
|---------------|-------------|----------|----------|
| 1 | `cliPath` | (executable name) | `QueryAPI.swift:52` |
| 2 | `model` | `--model` | `QueryAPI.swift:145-146` |
| 3 | `maxTurns` | `--max-turns` | `QueryAPI.swift:148-149` |
| 4 | `maxThinkingTokens` | `--max-thinking-tokens` | `QueryAPI.swift:151-152` |
| 5 | `permissionMode` | `--permission-mode` | `QueryAPI.swift:154-155` |
| 6 | `systemPrompt` | `--system-prompt` | `QueryAPI.swift:162-163` |
| 7 | `appendSystemPrompt` | `--append-system-prompt` | `QueryAPI.swift:165-166` |
| 8 | `allowedTools` | `--allowed-tools` | `QueryAPI.swift:168-169` |
| 9 | `blockedTools` | `--disallowed-tools` | `QueryAPI.swift:171-174` |
| 10 | `additionalDirectories` | `--add-dir` | `QueryAPI.swift:176-178` |
| 11 | `resume` | `--resume` | `QueryAPI.swift:179-180` |

**Shell boundary** (NativeBackend — 1 crossing point):

| Crossing point | Source field | Pattern | Location |
|---------------|-------------|---------|----------|
| 12 | `cliPath` | `"which \(cli)"` interpolation | `NativeBackend.swift:122` |

**JSON boundary** (values serialized to JSON for stdin):

| Crossing point | Source field | Serialization | Location |
|---------------|-------------|---------------|----------|
| 13 | `prompt` | `JSONSerialization` in promptPayload | `QueryAPI.swift:115-122` |
| 14 | MCP config | `JSONSerialization` for server configs | `QueryAPI.swift:208` |
| 15 | Control messages | `JSONEncoder` for SDKMessage fields | `ControlProtocolHandler` |

**Filesystem boundary**:

| Crossing point | Source field | Operation | Location |
|---------------|-------------|-----------|----------|
| 16 | MCP config | Temp file write | `QueryAPI.swift:211-217` |
| 17 | `workingDirectory` | `process.currentDirectoryURL` | `ProcessTransport.swift:174-176` |

**Environment boundary**:

| Crossing point | Source field | Operation | Location |
|---------------|-------------|-----------|----------|
| 18 | `environment` dict | `process.environment` merge | `ProcessTransport.swift:179-183` |


### Step 3: Test the Full Range of the Type

For each (value × crossing point), generate inputs that cover the entire range the Swift type permits — including values the target context would misinterpret — and verify the invariant holds.

For shell boundary crossing points, "the full range" means:

- Empty string
- Strings with every shell metacharacter: `'`, `"`, `` ` ``, `$`, `(`, `)`, `;`, `|`, `&`, `\`, `{`, `}`, `<`, `>`, `!`, `~`, `#`, space, tab, newline, null byte
- Strings with shell expansion patterns: `$(command)`, `` `command` ``, `${var}`, `$((expr))`
- Strings with glob patterns: `*`, `?`, `[`, `]`
- Strings that are valid shell commands: `; echo pwned`, `| cat /etc/passwd`
- Very long strings (buffer overflow territory)
- Unicode strings (multi-byte characters, zero-width joiners, RTL marks)
- Strings that look like flags: `--help`, `-rf`

For JSON boundary crossing points:

- Strings with JSON structural characters: `"`, `\`, `/`
- Strings with control characters: `\n`, `\t`, `\r`, `\0`
- Strings that would break JSON structure if unescaped: `","evil":"injected`
- Unicode escapes: `\u0000`, `\uFFFF`

For filesystem boundary crossing points:

- Path traversal: `../../etc/passwd`
- Null bytes: `file\0.txt`
- Very long paths (PATH_MAX)
- Special filenames: `.`, `..`, `-`, names starting with `-`


## 4. Testing Toolkit

Four concrete approaches, each serving a distinct purpose.


### 4.1 Adversarial String Sets

Curated lists of metacharacters per target context. These are the "what would a dependent type reject?" lists.

```swift
enum AdversarialStrings {
    /// Characters that have special meaning in shell contexts
    static let shellMetachars: [String] = [
        "'", "\"", "`", "$", "(", ")", ";", "|", "&", "\\",
        "{", "}", "<", ">", "!", "~", "#", " ", "\t", "\n", "\0",
    ]

    /// Strings that attempt shell command injection
    static let shellInjection: [String] = [
        "$(echo pwned)",
        "`echo pwned`",
        "; echo pwned",
        "| cat /etc/passwd",
        "& echo background",
        "Don't stop",
        "say \"hello\"",
        "test\necho pwned",
        "${PATH}",
        "$((1+1))",
        "$(rm -rf /)",
        "test`id`test",
    ]

    /// Characters that have special meaning in JSON contexts
    static let jsonMetachars: [String] = [
        "\"", "\\", "/", "\n", "\r", "\t", "\0",
    ]

    /// Strings that attempt JSON structure injection
    static let jsonInjection: [String] = [
        "\",\"evil\":\"injected",
        "\\\"},{\"hacked\":true,\"x\":\"",
        "\\\\\\\"/",
    ]
}
```

Each curated string set encodes domain expertise about a specific interpretation context. They're the testing equivalent of a refinement type's constraint predicate.


### 4.2 Seeded Property Testing

Generate random inputs from the full type range. Reproducible failures via seed. Pure Swift, zero dependencies.

```swift
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

struct PropertyTest {
    static func forAll<T>(
        iterations: Int = 1000,
        seed: UInt64 = 42,
        generator: (inout SeededRNG) -> T,
        property: (T) throws -> Void
    ) rethrows {
        var rng = SeededRNG(seed: seed)
        for _ in 0..<iterations {
            let value = generator(&rng)
            try property(value)
        }
    }
}
```

Generators produce values from the full range of the Swift type — including the adversarial region. When a property test fails, the seed makes it reproducible.


### 4.3 Roundtrip Identity Protocol

A reusable pattern where `recover(transform(input)) == input` is the property under test. Each boundary implements its own `transform`/`recover` pair.

```swift
protocol BoundaryCrossingTest {
    associatedtype Input: Equatable
    associatedtype Intermediate

    /// Transform input for the target context (e.g., build a shell command)
    func transform(_ input: Input) throws -> Intermediate

    /// Recover the original input from the target context's representation
    func recover(_ intermediate: Intermediate) throws -> Input

    /// The invariant: data survives the boundary crossing intact
    func testRoundtrip(_ input: Input) throws {
        let intermediate = try transform(input)
        let recovered = try recover(intermediate)
        assert(recovered == input, "Roundtrip failed: '\(input)' → '\(recovered)'")
    }
}
```

Concrete implementations:

- **Shell roundtrip**: Transform = build command string, Recover = parse argument from `ps` output or echo test
- **JSON roundtrip**: Transform = `JSONEncoder.encode`, Recover = `JSONDecoder.decode`
- **Codable roundtrip**: Transform = encode to wire format, Recover = decode from wire format
- **Environment roundtrip**: Transform = set env var, Recover = read env var in subprocess


### 4.4 Structural Invariant Tests

Tests that assert architectural properties, making entire classes of bugs structurally impossible.

```swift
/// This test makes shell injection structurally impossible by verifying
/// the process never uses a shell executable.
func testProcessNeverUsesShell() throws {
    let config = try buildProcessConfiguration(options: options)

    // The executable must be the CLI binary directly, not a shell
    XCTAssertNotEqual(config.executablePath, "/bin/zsh")
    XCTAssertNotEqual(config.executablePath, "/bin/bash")
    XCTAssertNotEqual(config.executablePath, "/bin/sh")

    // Arguments must be an array, not a joined string
    XCTAssertTrue(config.arguments.count > 1,
        "Arguments should be individual array elements, not a single joined string")
}
```

These are the closest thing to a type-level guarantee. A structural invariant test doesn't verify individual values — it verifies that the architecture makes the entire vulnerability class impossible.


## 5. Boundary Inventory for ClodKit

Complete reference table. Every boundary, every crossing point, the adversarial character set, the invariant.

### Shell Boundary

| # | Field | CLI flag | Adversarial set | Invariant |
|---|-------|----------|----------------|-----------|
| 1 | `cliPath` | (executable) | Shell metacharacters, path traversal, spaces | Resolved to executable path, never shell-interpreted |
| 2 | `model` | `--model` | Shell metacharacters | Passed as discrete argument, not shell-interpreted |
| 3 | `maxTurns` | `--max-turns` | Negative, zero, MAX_INT | Converted to string safely, positive only |
| 4 | `maxThinkingTokens` | `--max-thinking-tokens` | Negative, zero, MAX_INT | Same as maxTurns |
| 5 | `permissionMode` | `--permission-mode` | N/A (enum with rawValue) | Enum constrains values — low risk |
| 6 | `systemPrompt` | `--system-prompt` | **Full shell + JSON metachar set** | Passed as discrete argument, content preserved verbatim |
| 7 | `appendSystemPrompt` | `--append-system-prompt` | **Full shell + JSON metachar set** | Same as systemPrompt |
| 8 | `allowedTools` | `--allowed-tools` | Commas, shell metachars | Each tool name passed without comma injection |
| 9 | `blockedTools` | `--disallowed-tools` | Shell metachars | Each tool name passed as discrete argument |
| 10 | `additionalDirectories` | `--add-dir` | Path traversal, shell metachars, spaces | Each path passed as discrete argument |
| 11 | `resume` | `--resume` | Shell metachars | Session ID passed as discrete argument |
| 12 | `cliPath` (validateSetup) | `which \(cli)` | Shell metachars, semicolons | Must not allow command injection in which lookup |

### JSON Boundary

| # | Field | Serialization | Adversarial set | Invariant |
|---|-------|--------------|----------------|-----------|
| 13 | `prompt` | `JSONSerialization` | JSON metachars, Unicode, control chars | Content preserved verbatim through JSON encode/decode |
| 14 | MCP server configs | `JSONSerialization` | JSON metachars in server names/paths | Config structure preserved, no injection |
| 15 | Control protocol messages | `JSONEncoder`/`Codable` | JSON metachars in all string fields | Roundtrip identity holds for all Codable types |

### Filesystem Boundary

| # | Field | Operation | Adversarial set | Invariant |
|---|-------|-----------|----------------|-----------|
| 16 | MCP config path | Temp file creation | Path traversal, special chars | Written to temp dir only, path not user-controlled |
| 17 | `workingDirectory` | `currentDirectoryURL` | Nonexistent paths, symlinks | URL type provides some safety; existence validated |

### Environment Boundary

| # | Field | Operation | Adversarial set | Invariant |
|---|-------|-----------|----------------|-----------|
| 18 | `environment` dict | Process env merge | `=` in keys, null bytes, PATH override | Keys/values set verbatim; no special interpretation |


## 6. Test Organization

```
Tests/ClodKitTests/
└── Security/
    ├── ArgumentSafetyTests.swift          ← Curated metachar tests, all 12 shell crossing points
    ├── ArgumentSafetyPropertyTests.swift   ← Random input tests for shell boundary
    ├── BoundaryCrossingRoundtripTests.swift ← JSON, Codable, env roundtrip tests
    ├── ShellInjectionRegressionTests.swift  ← Permanent regression tests (DO NOT DELETE)
    └── Helpers/
        ├── PropertyTesting.swift            ← SeededRNG, generators, PropertyTest runner
        ├── BoundaryCrossingTest.swift       ← Protocol + concrete implementations
        └── AdversarialStrings.swift         ← Curated metachar sets per context
```

### What goes where

**`ArgumentSafetyTests`** — Deterministic tests with curated adversarial inputs. One test per (field × metacharacter class). These tests say: "for every shell metacharacter we know about, this field handles it correctly." Fast, readable, and they document exactly which characters have been considered.

**`ArgumentSafetyPropertyTests`** — Random input tests that explore the space beyond curated lists. These tests say: "for 1000 random strings from the full Unicode range, this field handles them correctly." They catch the metacharacters we didn't think of. Seeded for reproducibility.

**`BoundaryCrossingRoundtripTests`** — Tests that verify data survives boundary crossings intact. JSON encode/decode roundtrip. Codable roundtrip. Environment variable roundtrip. These tests say: "whatever goes in comes back out unchanged."

**`ShellInjectionRegressionTests`** — The permanent record. Each test reproduces a specific vulnerability that was found and fixed. Marked with `// DO NOT DELETE — regression test for [issue]`. These tests say: "this specific exploit was possible before, and it must never be possible again."

**`Helpers/`** — Reusable infrastructure. The property testing framework, the boundary crossing protocol, and the adversarial string collections. These are tools, not tests — they're imported by the test files above.


### Guidance

- A curated test (`ArgumentSafetyTests`) is the right choice when you know the exact adversarial input and want to document it.
- A property test (`ArgumentSafetyPropertyTests`) is the right choice when you want to explore the space beyond what you've thought of.
- A roundtrip test (`BoundaryCrossingRoundtripTests`) is the right choice when the invariant is "data in == data out."
- A regression test (`ShellInjectionRegressionTests`) is the right choice when a specific vulnerability was found in production or during testing.

Every new boundary crossing point discovered in the codebase should get at least one curated test and one property test. Every vulnerability found should get a permanent regression test.
