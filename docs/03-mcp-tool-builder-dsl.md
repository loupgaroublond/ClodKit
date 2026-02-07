# Enhanced MCP Tool Builder DSL

## Context

ClodKit already has a working MCP tool system: `MCPTool`, `MCPToolBuilder` (result builder), `SDKMCPServer`, `MCPServerRouter`, `JSONSchema`, and `PropertySchema`. Tools can be defined, registered, and invoked via the control protocol. The integration tests prove the full roundtrip works.

The gap remediation (v0.2.34) adds **tool annotations** (`ToolAnnotations` with `readOnly`, `destructive`, `openWorld` flags) to `MCPTool` and the `tool()` helper. That's a small structural addition handled as gap work.

Everything else in this document is about **ergonomics** — the gap between ClodKit's current tool definition experience and what's possible in Swift. Today, defining a tool looks like this:

```swift
MCPTool(
    name: "add",
    description: "Adds two numbers",
    inputSchema: JSONSchema(
        properties: [
            "a": .number("First number"),
            "b": .number("Second number")
        ],
        required: ["a", "b"]
    ),
    handler: { args in
        let a = args["a"] as? Double ?? 0  // Manual casting, no compile-time safety
        let b = args["b"] as? Double ?? 0
        return .text("\(a + b)")
    }
)
```

The handler receives `[String: Any]` — a bag of untyped values. The caller manually casts each argument, handles missing keys with fallbacks, and hopes the schema matches what they wrote. There's no validation that the handler's expectations match the declared schema. TypeScript solves this with Zod schemas that auto-infer handler argument types; Python uses Pydantic models or typed dicts.

Swift can't do exactly what Zod does (no runtime type inference from schemas), but it can provide type-safe argument extraction, schema-from-type generation, and validation — through a combination of protocols, generics, and result builders.


## What the Improved API Should Look Like

### Goal State: Simple Tools

```swift
let server = createSDKMCPServer(name: "math") {
    Tool("add", description: "Adds two numbers") {
        Param("a", .number, "First number", required: true)
        Param("b", .number, "Second number", required: true)
    } handler: { args in
        let a: Double = try args.require("a")
        let b: Double = try args.require("b")
        return .text("\(a + b)")
    }

    Tool("greet", description: "Greets a person") {
        Param("name", .string, "Person's name", required: true)
        Param("enthusiastic", .boolean, "Add exclamation mark")
    } handler: { args in
        let name: String = try args.require("name")
        let enthusiastic: Bool = args.get("enthusiastic") ?? false
        return .text(enthusiastic ? "Hello, \(name)!" : "Hello, \(name).")
    }
}
```

### Goal State: Codable Input Types

For tools with complex inputs, derive the schema from a Swift type:

```swift
struct AddInput: ToolInput {
    @Property("First number")
    var a: Double

    @Property("Second number")
    var b: Double
}

let addTool = Tool("add", description: "Adds two numbers", input: AddInput.self) { input in
    return .text("\(input.a + input.b)")
}
```

The `ToolInput` protocol and `@Property` wrapper generate the `JSONSchema` at compile time and provide a decoded, typed `input` to the handler instead of a raw dictionary.


## Implementation

### 1. ToolArgs: Type-Safe Argument Extraction

Create `Sources/ClodKit/MCP/ToolArgs.swift`.

`ToolArgs` wraps `[String: Any]` and provides typed extraction methods:

```swift
public struct ToolArgs: Sendable {
    private let raw: [String: Any]

    public func require<T>(_ key: String) throws -> T
    public func get<T>(_ key: String) -> T?
    public func get<T>(_ key: String, default: T) -> T
    public var rawDictionary: [String: Any]
}
```

`require()` throws `ToolArgError.missingRequired(key)` or `.typeMismatch(key, expected, actual)` with clear error messages. These errors become `MCPToolResult.error(...)` responses back to Claude, so the messages should be informative.

Supported types for `T`: `String`, `Int`, `Double`, `Bool`, `[String]`, `[Any]`, `[String: Any]`. The extraction handles JSON number coercion (JSON numbers may arrive as `NSNumber`, `Int`, or `Double` depending on the value).

This alone is a significant improvement — callers go from `args["a"] as? Double ?? 0` to `try args.require("a")` with proper error messages instead of silent fallbacks.


### 2. Tool Convenience Initializer with Param Builder

Create `Sources/ClodKit/MCP/ToolParam.swift`.

`Param` is a lightweight descriptor used in a result builder to declare tool parameters:

```swift
public struct Param: Sendable {
    public let name: String
    public let type: ParamType
    public let description: String?
    public let required: Bool
    public let enumValues: [String]?
    public let itemType: ParamType?

    public init(_ name: String, _ type: ParamType, _ description: String? = nil, required: Bool = false)
    public static func `enum`(_ name: String, values: [String], _ description: String? = nil, required: Bool = false) -> Param
    public static func array(_ name: String, of itemType: ParamType, _ description: String? = nil, required: Bool = false) -> Param
}

public enum ParamType: Sendable {
    case string, number, integer, boolean, object, array
}
```

A `@ParamBuilder` result builder collects `Param` values and generates the `JSONSchema`:

```swift
@resultBuilder
public struct ParamBuilder {
    public static func buildBlock(_ params: Param...) -> [Param]
    // ... standard result builder methods
}
```

And a `Tool` convenience function that combines the param builder with a handler:

```swift
public func Tool(
    _ name: String,
    description: String,
    @ParamBuilder params: () -> [Param],
    handler: @escaping @Sendable (ToolArgs) async throws -> MCPToolResult
) -> MCPTool
```

This constructs the `JSONSchema` from the params, wraps the handler to convert `[String: Any]` → `ToolArgs`, and returns a standard `MCPTool`. No changes to `MCPTool` itself are needed — `Tool()` is a builder function that produces `MCPTool` values.


### 3. ToolInput Protocol (Codable-Based Schema Generation)

Create `Sources/ClodKit/MCP/ToolInput.swift`.

This is the more ambitious feature: derive JSON Schema from Swift types.

```swift
public protocol ToolInput: Sendable {
    static var schema: JSONSchema { get }
    init(from args: ToolArgs) throws
}
```

Conforming types declare their properties with a `@Property` wrapper:

```swift
@propertyWrapper
public struct Property<Value>: Sendable {
    public var wrappedValue: Value
    public let description: String?
    public let required: Bool
}
```

The challenge is that Swift property wrappers don't have the reflection capabilities needed to auto-generate schemas at compile time without macros. Two realistic approaches:

**Approach A — Manual schema declaration (simpler, no macros):**

```swift
struct AddInput: ToolInput {
    var a: Double
    var b: Double

    static var schema: JSONSchema {
        JSONSchema(
            properties: ["a": .number("First number"), "b": .number("Second number")],
            required: ["a", "b"]
        )
    }

    init(from args: ToolArgs) throws {
        a = try args.require("a")
        b = try args.require("b")
    }
}
```

The protocol still provides value: typed handler, centralized input definition, reusable across tools. The schema and init are boilerplate, but they're co-located with the type.

**Approach B — Macro-based (better DX, higher complexity):**

A Swift macro like `@ToolSchema` could generate both `schema` and `init(from:)`:

```swift
@ToolSchema
struct AddInput: ToolInput {
    /// First number
    var a: Double

    /// Second number
    var b: Double
}
```

This is the ideal end state but requires a separate macro target in the package. Recommend starting with Approach A and adding the macro later as a follow-up.

Either way, the `Tool` function gets an overload:

```swift
public func Tool<Input: ToolInput>(
    _ name: String,
    description: String,
    input: Input.Type,
    handler: @escaping @Sendable (Input) async throws -> MCPToolResult
) -> MCPTool
```


### 4. Schema Validation (Pre-Handler)

Create `Sources/ClodKit/MCP/SchemaValidator.swift`.

Before calling the handler, validate that the incoming arguments match the declared schema. This catches malformed input early and returns clear error messages to Claude instead of letting the handler crash or silently produce wrong results.

Validation checks:

- Required fields are present
- Field types match (string is string, number is number, etc.)
- Enum values are within the allowed set
- Array items match the declared item type
- Nested objects are recursively validated

The validator takes a `JSONSchema` and a `[String: Any]` dictionary, returns either success or a `[String]` list of violation messages.

Integrate validation into the `SDKMCPServer.callTool()` method (currently at `Sources/ClodKit/MCP/SDKMCPServer.swift`). Before calling `tool.handler(arguments)`, run `SchemaValidator.validate(arguments, against: tool.inputSchema)`. On failure, return `MCPToolResult.error(...)` with the violation messages. This protects ALL tools, not just ones using the new DSL.


### 5. PropertySchema Additions

The existing `PropertySchema` (in `Sources/ClodKit/MCP/JSONSchema.swift`) supports `string`, `number`, `integer`, `boolean`, `array`, `object`, and `enum`. Consider adding:

- `nullable` support — wraps any type to allow null values
- `default` values — informational in the schema (JSON Schema `default` keyword)
- `oneOf` — for union types (less common but useful)

These are additive. Only add them if concrete use cases arise during implementation. The existing set covers the vast majority of tool definitions.


### 6. MCPToolBuilder Compatibility

The existing `MCPToolBuilder` result builder already works with `MCPTool` values. Since `Tool()` returns `MCPTool`, it integrates naturally:

```swift
let server = createSDKMCPServer(name: "tools") {
    // New DSL-style tool
    Tool("add", description: "Adds numbers") { ... } handler: { ... }

    // Classic MCPTool still works
    MCPTool(name: "old", description: "...", inputSchema: ..., handler: { ... })
}
```

No changes to `MCPToolBuilder` itself are needed.


### 7. Tests

**ToolArgs tests:**

- `require()` returns correct typed value for String, Int, Double, Bool
- `require()` throws `.missingRequired` for absent key
- `require()` throws `.typeMismatch` for wrong type
- `get()` returns nil for absent key
- `get(default:)` returns default for absent key
- Number coercion: Int value extracted as Double, Double value extracted as Int (when lossless)

**Param builder tests:**

- `Tool()` with params generates correct JSONSchema
- Required params appear in `required` array
- Optional params are absent from `required`
- Enum params generate `enum` field
- Array params generate `items` field

**Schema validation tests:**

- Valid input passes validation
- Missing required field fails with clear message
- Wrong type fails with clear message
- Enum value outside allowed set fails
- Nested object validation works
- Array item type validation works

**ToolInput protocol tests:**

- Conforming type generates correct schema
- `init(from:)` correctly decodes valid args
- `init(from:)` throws for invalid args
- `Tool()` with ToolInput type produces working MCPTool

**Integration tests:**

- Tool defined with new DSL is invocable by Claude
- Schema validation rejects bad input before handler runs
- Error messages from validation are useful to Claude


## Prerequisites (from gap remediation)

- Tool annotations (`ToolAnnotations`) added to `MCPTool` — the DSL's `Tool()` function should support passing annotations through


## Files to Create

| File | Purpose |
|------|---------|
| `Sources/ClodKit/MCP/ToolArgs.swift` | Type-safe argument extraction |
| `Sources/ClodKit/MCP/ToolParam.swift` | `Param`, `ParamBuilder`, `Tool()` convenience |
| `Sources/ClodKit/MCP/ToolInput.swift` | `ToolInput` protocol for Codable-style tools |
| `Sources/ClodKit/MCP/SchemaValidator.swift` | Pre-handler input validation |
| `Tests/ClodKitTests/ToolArgsTests.swift` | Argument extraction tests |
| `Tests/ClodKitTests/ToolParamTests.swift` | Param builder and Tool() tests |
| `Tests/ClodKitTests/ToolInputTests.swift` | ToolInput protocol tests |
| `Tests/ClodKitTests/SchemaValidatorTests.swift` | Validation tests |


## Files to Modify

| File | Change |
|------|--------|
| `Sources/ClodKit/MCP/SDKMCPServer.swift` | Add schema validation before handler invocation in `callTool()` |
| `Sources/ClodKit/MCP/JSONSchema.swift` | Add `nullable`, `default` to PropertySchema (if needed) |


## Verification

1. `swift build` compiles cleanly
2. `swift test` — all existing tests pass (backward compatibility — `MCPTool` unchanged)
3. New unit tests pass for ToolArgs, Param builder, SchemaValidator, ToolInput
4. Integration test: tool defined with `Tool()` DSL is callable by Claude via MCP
5. Integration test: malformed input is rejected before reaching handler
