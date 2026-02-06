# Agent Bead Workflow

You are working on the ClaudeCodeSDK native Swift implementation. Work is tracked via **beads** (bd command), not markdown checklists.

## Autonomous Execution Mode

**CRITICAL: Work continuously until the epic is complete.**

- **Do NOT stop** after completing a task - immediately find and start the next one
- **Do NOT ask for confirmation** to proceed - just keep working
- **Do NOT summarize progress** and wait - close the bead and move on
- **ONLY stop** if you encounter an ambiguity that genuinely requires user input
- **Target: 100% test coverage** - every public API must have unit tests
- **After epic completion**, continue improving: add integration tests, optimize performance, improve documentation

When all beads are closed, check if there are missing beads for Phases 1-3 (Transport, Control Protocol, MCP). If missing, create them based on `reports/05-native-implementation-plan.md` and continue working.

**Loop until done:**
```
1. bd ready --label native-impl
2. If no ready tasks → check if blocked tasks need unblocking → create missing beads if needed
3. Claim task → implement → test → close
4. GOTO 1
```

## Development Location

**IMPORTANT: All development happens in `NativeClaudeCodeSDK/`** - a separate subdirectory from the existing SDK.

```
ClodeMonster/
├── ClaudeCodeSDK/           # EXISTING SDK - READ ONLY
│   └── Sources/
│       └── ClaudeCodeSDK/   # Can copy from here, but DO NOT write here
├── NativeClaudeCodeSDK/     # YOUR IMPLEMENTATION - Write here
│   └── Sources/
│       └── ClaudeCodeSDK/   # Create new files here
└── ...
```

**Rules:**
- ✅ **Read** from `ClaudeCodeSDK/` for reference
- ✅ **Copy** code patterns, types, or utilities from `ClaudeCodeSDK/`
- ✅ **Write** all new code to `NativeClaudeCodeSDK/`
- ❌ **Do NOT modify** anything in `ClaudeCodeSDK/`

This is a **bakeoff** - your implementation will compete against another approach. Build the best native Swift SDK you can.

## Finding Ready Work

```bash
# Show tasks ready to work on (not blocked by other tasks)
bd ready --label native-impl

# See all tasks in the implementation
bd list --label native-impl

# See blocked tasks (waiting on dependencies)
bd blocked --label native-impl
```

## Claiming a Task

When you find a task to work on:

```bash
# View full task details including instructions
bd show <bead-id>

# Claim the task (sets you as assignee, marks in_progress)
bd update <bead-id> --claim
```

## Working on a Task

Each bead contains:
- **File to Create/Modify** - The target file path (relative to `NativeClaudeCodeSDK/`)
- **Required Reading** - Documents you must read before starting
- **Implementation Steps** - Step-by-step instructions
- **Unit Tests Required** - Tests you must write

**Note:** File paths in beads like `Sources/ClaudeCodeSDK/Transport/Transport.swift` mean you create `NativeClaudeCodeSDK/Sources/ClaudeCodeSDK/Transport/Transport.swift`.

**Critical workflow rules:**
1. Read all required documents before starting
2. Log progress on the bead as you work
3. Do NOT update the checklist file (`reports/05-native-implementation-checklist.md`)
4. Close the bead when complete

## Logging Progress

Add comments to track your work:

```bash
# Add progress update
bd comments add <bead-id> "Completed step 1: Created Transport protocol"

# Add another update
bd comments add <bead-id> "Implementing write() method, handling pipe errors"
```

## Completing a Task

When all implementation steps and tests are done:

```bash
# Close the bead with a summary
bd close <bead-id> --reason "Implemented Transport protocol with full test coverage"
```

## Key Reference Documents

Before starting any task, read:
- `reports/05-native-implementation-plan.md` - Full architecture and design
- `reports/05-native-implementation-checklist.md` - Verification checklist (read-only)
- `CLAUDE_AGENT_SDK_API_SPEC.md` - API specification
- `vendor/SDK_INTERNALS_ANALYSIS.md` - How official SDKs work
- `ClaudeCodeSDK/` - Existing SDK code (read-only reference for patterns and types)

## Example Workflow

```bash
# 1. Find ready work
bd ready --label native-impl

# 2. Pick a task and view details
bd show ClodeMonster-6ur

# 3. Claim it
bd update ClodeMonster-6ur --claim

# 4. Read required docs (listed in bead description)
# ... read reports/05-native-implementation-plan.md section 1.1 ...

# 5. Implement, logging progress
bd comments add ClodeMonster-6ur "Created Transport.swift with protocol definition"
bd comments add ClodeMonster-6ur "Added StdoutMessage enum with all message types"
bd comments add ClodeMonster-6ur "Verified Sendable conformance compiles"

# 6. Write tests
bd comments add ClodeMonster-6ur "Added unit tests for StdoutMessage parsing"

# 7. Close when done
bd close ClodeMonster-6ur --reason "Transport protocol complete with tests"

# 8. Find next ready task
bd ready --label native-impl
```

## Priority Order

Work on tasks in this priority:
1. **Phase 1** (Transport) - Foundation for everything
2. **Phase 2** (Control Protocol) - Enables bidirectional communication
3. **Phase 3** (MCP) - Highest priority feature
4. **Phases 4-5** (Hooks, Permissions) - Can parallel with Phase 3
5. **Phase 6** (Session/Query) - Integrates all components
6. **Phase 7** (Integration) - Final wiring

Tasks within a phase can often be worked in parallel if they don't have explicit blockers.

## What to Copy vs. Build Fresh

**Copy from `ClaudeCodeSDK/`:**
- Message types and Codable definitions that match the CLI protocol
- Error types and patterns
- Utility extensions that are protocol-agnostic

**Build fresh in `NativeClaudeCodeSDK/`:**
- Transport layer (the core differentiator)
- Control protocol handler
- MCP server routing
- Session management
- All new features (hooks, permissions, SDK MCP tools)

The existing SDK uses a Node.js bridge (`AgentSDKBackend`). Your implementation replaces that with native Swift subprocess management. Study the existing code to understand the interfaces, then implement them better.

## Bakeoff Mindset

Your implementation competes against another approach. Focus on:
- **Correctness** - Match the TypeScript SDK behavior exactly
- **Performance** - Native Swift should outperform the Node.js bridge
- **Code quality** - Clean, testable, well-documented code
- **Test coverage** - 100% coverage is the target
- **API ergonomics** - Swift-native patterns (AsyncSequence, actors, Sendable)

Build something you'd be proud to ship.
