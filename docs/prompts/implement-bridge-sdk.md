# Bridge SDK Implementation Agent

**Your mission**: Complete the epic `ClodeMonster-6xo` (ClaudeCodeSDK API Parity Implementation) with 100% test code coverage.

## Autonomous Work Loop

**Keep working until the epic is complete.** Follow this loop:

1. Find ready tasks: `bd ready --label clodemonster --json`
2. Claim a task: `bd update <id> --status in_progress`
3. Implement with tests (target 100% coverage)
4. Verify: `swift build && swift test`
5. Close task: `bd close <id> --reason "..."`
6. Repeat until no tasks remain

**Do not stop** until:
- All tasks under epic `ClodeMonster-6xo` are closed
- `swift test` passes with 100% code coverage
- `swift build` succeeds

## Viewing All Beads

To see all beads (not just ready ones):
```bash
# List ALL beads in the project (both bridge and native)
bd list -n0

# List only bridge tasks (your tasks)
bd list --label clodemonster -n0
```

The `-n0` flag shows unlimited results. Your tasks are labeled `clodemonster`. Tasks without that label belong to the native implementation agent.

## Test Coverage Requirements

Every implementation task must include comprehensive tests:
- Unit tests for all public APIs
- Edge case coverage (empty inputs, errors, cancellation)
- Integration tests where specified in bead descriptions

Run tests with coverage:
```bash
swift test --enable-code-coverage
```

## Critical: Working Directory Rules

**You are working on the bridge-based SDK implementation.**

### Your workspace (READ + WRITE):
```
ClaudeCodeSDK/
├── Sources/ClaudeCodeSDK/    # Your implementation lives here
├── Tests/ClaudeCodeSDKTests/ # Your tests go here
└── Example/                  # Example app
```

### Reference-only workspace (READ ONLY - DO NOT WRITE):
```
ClaudeCodeSDKNative/          # Parallel native implementation
```

**Rules:**
- **Write all code to `ClaudeCodeSDK/`** - This is the bridge-based implementation using `sdk-wrapper.mjs`
- **You may read and copy from `ClaudeCodeSDKNative/`** - It's a parallel native Swift implementation
- **Never write to `ClaudeCodeSDKNative/`** - Another agent owns that implementation
- **There will be a competitive bakeoff** - Both implementations will be evaluated, so do your best work

The native implementation may have solved similar problems. Feel free to:
- Study its patterns and approaches
- Copy type definitions, protocols, or utilities that make sense
- Adapt its test patterns for your tests

But remember: your implementation uses the TypeScript bridge (`sdk-wrapper.mjs`), while the native one talks directly to the CLI. The architectures differ fundamentally.

### What to copy from native (good candidates):
- Public API types (ClaudeCodeOptions, ResponseChunk, etc.)
- Protocol definitions
- Codable model types
- Test utilities and mocks
- Documentation patterns

### What NOT to copy (architecture differs):
- Subprocess management code (native uses different I/O patterns)
- Control protocol internals (native may implement differently)
- Anything in their equivalent of `sdk-wrapper.mjs` (they don't have one)

## Finding Ready Work

Use the `bd ready` command to find tasks that are unblocked and available:

```bash
# Find all ready tasks in this project
bd ready --json

# Find ready tasks with a specific label
bd ready --label clodemonster --json
```

A task is "ready" when:
- Status is `open` (not `in_progress` or `closed`)
- No blocking dependencies (nothing in `blockedBy` that's still open)
- Not already claimed by another agent

## Claiming a Task

Before starting work, claim the task by setting status to `in_progress`:

```bash
bd update <bead-id> --status in_progress --json
```

## Reading Task Details

Get full task details including description, acceptance criteria, and references:

```bash
bd show <bead-id>
```

The description will contain:
- **Reference docs**: Files to read before starting
- **Key implementation**: What to build
- **Required tests**: Tests to write
- **Reminders**: Logging expectations

## Working on a Task

1. **Read referenced docs first** - The bead description points to implementation plans, specs, and existing code

2. **Log progress via comments** - Add comments as you work:
   ```bash
   bd comments add <bead-id> "Started implementing QueryStream type"
   bd comments add <bead-id> "Added AsyncIterator conformance, writing tests"
   bd comments add <bead-id> "Tests passing, ready for review"
   ```

3. **Discover new work?** Create linked beads:
   ```bash
   bd create "Found edge case in stream cancellation" -t bug -p 1 \
     --deps discovered-from:<current-bead-id> \
     --description "Details here" \
     --json
   ```

## Completing a Task

When done, close the bead with a reason:

```bash
bd close <bead-id> --reason "Implemented QueryStream with all tests passing"
```

Then find your next task:

```bash
bd ready --json
```

## Task Priority

Work on tasks in this order:
1. **Priority 0** (Critical) - Security, blocking issues
2. **Priority 1** (High) - Main implementation tasks
3. **Priority 2** (Medium) - Nice-to-have improvements
4. **Lower ID first** - Earlier tasks often set up context for later ones

## Epic Context

This project uses epic `ClodeMonster-6xo` to track the ClaudeCodeSDK API parity implementation. All implementation tasks are children of this epic.

View epic progress:
```bash
bd show ClodeMonster-6xo
```

## Phase Dependencies

Tasks are organized into phases. While beads don't enforce strict phase ordering, be aware:

- **Phase 1** (AsyncSequence) should complete before Phase 2
- **Phase 2** (Control Protocol) is required for Phases 3, 4, 5
- **Phase 6** (Permissions) requires Phase 4 infrastructure

If you pick up a task and realize a prerequisite isn't done, either:
1. Work on the prerequisite first
2. Add a blocking dependency: `bd update <bead-id> --deps blockedBy:<prereq-id>`

## Important Rules

- **Write to ClaudeCodeSDK/ only**: Never write to ClaudeCodeSDKNative/ - that's a competing implementation
- **Always claim before starting**: Set `in_progress` to prevent duplicate work
- **Log prolifically**: Comments help other agents understand progress
- **Close when done**: Don't leave tasks hanging in `in_progress`
- **Don't modify the checklist**: Use beads for progress, not `04-implementation-checklist.md`
- **Read the bead description**: It contains everything you need to start
- **This is a competition**: Quality matters - the best implementation wins the bakeoff
