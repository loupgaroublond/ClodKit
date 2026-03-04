---
description: Update ClodKit to match the latest Claude Agent SDK TypeScript release
argument-hint: [version or "latest"]
---

# SDK Parity Update

You are updating ClodKit (a pure Swift SDK) to match the latest release of `@anthropic-ai/claude-agent-sdk` from npm. This is a soup-to-nuts workflow: download the TypeScript SDK, produce a gap analysis, decompose into tracked work items (beads), then execute via agent teams.

## Arguments

The user specified: $ARGUMENTS

If the argument is empty, blank, or "latest", use the latest published version. Otherwise, treat it as a specific semver (e.g., "0.2.63").

---

## Phase 1: Download and Extract TypeScript SDK

1. Get the target version:

```bash
npm view @anthropic-ai/claude-agent-sdk version
```

2. Download and extract into the project's `.claude/` directory (gitignored working area):

```bash
mkdir -p .claude/sdk-update && cd .claude/sdk-update && rm -rf * && npm pack @anthropic-ai/claude-agent-sdk@<version> && tar xzf *.tgz && echo "Extracted successfully"
```

3. Read the key type definition files:
   - `.claude/sdk-update/package/sdk.d.ts` — Primary type declarations (the source of truth)
   - `.claude/sdk-update/package/sdk-tools.d.ts` — Tool input JSON schemas
   - `.claude/sdk-update/package/package.json` — Package metadata and version confirmation

4. Verify extraction succeeded — both `.d.ts` files must exist with non-trivial content.

---

## Phase 2: Gap Analysis

Compare the downloaded TypeScript definitions against the existing spec AND the current Swift implementation.

### 2a: Read Current State

1. Read `docs/CLAUDE_AGENT_SDK_API_SPEC.md` (the current spec)
2. Read all Swift source files under `Sources/ClodKit/` to understand current implementation
3. Read `docs/GAP_ANALYSIS_v0.2.34.md` as a format reference for how the previous gap analysis was structured

### 2b: Systematic Comparison

Compare across ALL of these dimensions (matching the spec's table of contents):

1. Core functions (`query()`, `tool()`, session functions)
2. Client classes
3. Configuration options (every field in `Options`/`ClaudeAgentOptions`)
4. Message types (every variant in the `SDKMessage` union)
5. Content block types
6. Tool definitions and schemas
7. Hook system (all event types, input types, output types)
8. Permission system (modes, callbacks, types)
9. MCP (server configs, tool types, status types)
10. Subagent system
11. Session management (V1 and V2 APIs)
12. Sandbox configuration
13. Error types
14. Tool input schemas (renames, new tools, field changes)
15. Minor type changes (enums, supporting types)
16. Any entirely new sections not in the current spec

For each area, identify:
- **New** types/fields/methods present in the new SDK but absent from ClodKit
- **Changed** types/fields where signatures or shapes differ
- **Removed** types/fields present in ClodKit but removed from the SDK
- **Unchanged** areas (note briefly to confirm review)

### 2c: Write Gap Analysis Report

Write to `docs/GAP_ANALYSIS_v<version>.md` following the established format:

```markdown
# Gap Analysis: Claude Agent SDK v<version>

Comparison of the current API spec against the actual TypeScript type definitions
shipped in `@anthropic-ai/claude-agent-sdk@<version>`.

**Source files analyzed:**
- `sdk.d.ts` — Primary type declarations (<N> lines)
- `sdk-tools.d.ts` — Tool input JSON schemas (<N> lines)
- `package.json` — Package metadata

**Analysis date:** <today>
```

Include: numbered sections per gap area, full TypeScript signatures, Swift file paths affected, and a ClodKit Impact Assessment section organized by priority (high/medium/low).

### 2d: Early Exit Check

If the gap analysis reveals zero gaps (ClodKit is already at full parity):
1. Update the "Last Updated" date in `docs/CLAUDE_AGENT_SDK_API_SPEC.md`
2. Report "No changes needed — ClodKit already at parity with v<version>" and STOP here.

---

## Phase 3: Update the API Spec

Update `docs/CLAUDE_AGENT_SDK_API_SPEC.md` to reflect the new TypeScript definitions:

1. Update the version and date references
2. Add/modify/remove sections to match the new type definitions exactly
3. Maintain the existing document structure and formatting conventions

---

## Phase 4: Create Beads

This is the critical planning step. Decompose the gap analysis into fine-grained, self-contained work items using `bd`. These beads survive context compaction and enable delegation to Sonnet agents.

### 4a: Epic Bead

```bash
bd create "Update ClodKit to SDK v<version> Parity" -t epic -p 1 \
  --description "Bring ClodKit to full API parity with @anthropic-ai/claude-agent-sdk@<version>" \
  --design "Track 1: Implementation beads (organized by code area). Track 2: Behavioral test beads (organized by observable requirements). Capstone: depends on all, iterates to 100%/100%/0/0." \
  --acceptance "100% test coverage, 100% passing tests, 0 warnings, 0 errors" \
  --labels "clodkit,sdk-parity" \
  --json
```

### 4b: Track 1 — Implementation Beads

Create one bead per unit of code change. Organize by what needs to change in the code, not by gap analysis section. Each bead MUST be self-contained with:

- **Exact file paths** to modify or create (e.g., `Sources/ClodKit/Hooks/HookEvent.swift`)
- **TypeScript signatures** from the SDK to match (copy the exact types from `sdk.d.ts`)
- **Swift patterns** to follow (reference the nearest existing file as a template)
- **Gap analysis section** reference (e.g., "See GAP_ANALYSIS section 6.2")
- **Acceptance criteria** (what "done" looks like for this specific bead)

The beads must be fine-grained enough for a Sonnet agent to execute without ambiguity. One bead = one logical change (add a type, add fields to a struct, add a method, etc.).

Use `bd create` with `--deps parent-child:<epic-id>` for each bead. Batch-create efficiently.

### 4c: Track 2 — Behavioral Test Beads

Create test beads organized by **observable behaviors and requirements** — NOT 1:1 mirrors of implementation beads. These attack quality from the requirements perspective. Examples:

- "Permission mode semantics" — tests that `delegate` and `dontAsk` modes produce expected behavior
- "Hook lifecycle" — tests that all 15+ hook events fire with correct input/output types
- "SDKMessage parsing" — tests that all message types round-trip through JSON correctly
- "Query control methods" — tests that new methods (close, streamInput, etc.) have correct signatures and behavior

Each test bead should reference:
- The behaviors being tested (from the gap analysis and TypeScript SDK observations)
- Existing test files to use as pattern references (e.g., `Tests/ClodKitTests/Behavioral/SandboxConfigTests.swift`)
- Specific test patterns: enum case count assertions, round-trip encoding, optional field validation
- **Every test class MUST include a `setUp()` with `executionTimeAllowance`** — 10s for unit/behavioral, 30s for concurrency, 60s for integration. This prevents runaway tests from blocking CI or other agents

Use `bd create` with `--deps parent-child:<epic-id>` for each bead.

### 4d: Capstone Bead

Create a single capstone bead that depends on ALL Track 1 and Track 2 beads:

```bash
bd create "Iterate to SDK v<version> complete parity" -t task -p 1 \
  --description "Capstone: Verify all implementation and test beads complete, iterate to green." \
  --acceptance "swift build: 0 warnings 0 errors. swift test: 100% pass. Coverage >=95%." \
  --labels "clodkit,sdk-parity" \
  --json
```

Wire all beads as blockers: `bd dep add <capstone-id> <bead-id>` for every Track 1 and Track 2 bead.

### 4e: Audit

This step is mandatory. The v0.2.34 update skipped it initially and had to go back — it caught 4 missing beads (`reconnectMcpServer`, `toggleMcpServer`, `tool_use_id` on hook inputs, updated hook-specific outputs).

**Methodology:**

1. List every bead you created: `bd list -n 0 --label sdk-parity --json`

2. Read the description of every bead (use `bd show <id> --json`) to understand exactly what each one covers.

3. Walk through the gap analysis report section by section. For each section and sub-section:
   - Identify every discrete type, field, method, enum case, or signature change mentioned
   - Confirm at least one bead explicitly covers it (by bead ID)
   - If a gap analysis item has no corresponding bead, create one immediately

4. Walk through `sdk.d.ts` and `sdk-tools.d.ts` one more time and check for anything the gap analysis itself missed. If you find new gaps, add them to the gap analysis report AND create beads.

5. Verify the dependency graph: every Track 1 and Track 2 bead must be a blocker for the capstone bead. Run `bd show <capstone-id> --json` and confirm the `blockedBy` count matches the total bead count.

6. Report the audit results: total beads by track, any gaps found and filled, confirmation that the capstone dependency chain is complete.

---

## Phase 5: Execute via Agent Teams

Now that beads exist as durable, self-contained work items, spawn agent teams to execute them in parallel using **worktree isolation** to prevent conflicts.

### Team Setup

Create a team and spawn teammates on Sonnet. **Each agent MUST use `isolation: "worktree"`** so it works on an independent copy of the repo:

```
Agent tool parameters:
  subagent_type: "general-purpose"
  model: "sonnet"
  mode: "bypassPermissions"
  isolation: "worktree"        ← REQUIRED — prevents concurrent edit conflicts
  team_name: "<team-name>"
  run_in_background: true
```

- **Track 1 agents** — Pick up implementation beads from `bd ready`, implement Swift changes, run `swift build` to verify, close beads when done. Each agent works in its own worktree.
- **Track 2 agents** — Pick up behavioral test beads, write tests following existing patterns, close beads when done. Each agent works in its own worktree.

Agents coordinate through the bead database (shared across worktrees):
- Claim work: `bd update <id> --status in_progress`
- Report progress: `bd comments add <id> "progress note"`
- Complete: `bd close <id> --reason "Done"`

The bead descriptions contain everything an agent needs — file paths, type signatures, patterns to follow. This is what makes Sonnet delegation viable.

### Worktree Merge Strategy

When worktree agents complete, their changes are on isolated branches. Merge them back to main:

1. For each completed worktree branch, cherry-pick or merge into the main working tree
2. Resolve any merge conflicts (rare since beads target different files)
3. Run `swift build` after each merge to catch integration issues early

### Monitoring

As team lead, monitor progress via:
- `bd epic status --json` — Completion tracking
- `bd ready -n 0 --json` — Remaining unblocked work
- `bd blocked -n 0 --json` — Stuck items needing attention

### Capstone Execution

Once all Track 1 and Track 2 beads are closed and worktree branches merged:

1. **Verify test timeouts**: Every test class must have `executionTimeAllowance = 10` in its `setUp()`. Run `grep -rL executionTimeAllowance Tests/` to find any missing ones.
2. Run `swift build` — must produce 0 warnings, 0 errors
3. Run `swift test` — must have all tests passing (skip integration tests requiring the CLI)
4. If failures: read error output, fix issues, re-run. Iterate until clean.
4. Update documentation:
   - `CLAUDE.md` — Bump version references, test counts, implementation status
   - `README.md` — Update feature references and version numbers if applicable
   - `docs/READING_GUIDE.md` — Add new doc files if created
5. Commit everything with conventional commit format:

```
feat: Update ClodKit to SDK v<version> parity

Gap analysis: docs/GAP_ANALYSIS_v<version>.md
<brief summary of major additions/changes>
Tests: <N> new tests added (<total> total)
```

---

## Error Recovery

- **npm pack fails**: Verify npm is available. Try `npm view @anthropic-ai/claude-agent-sdk versions --json` to confirm the version exists.
- **swift build fails after changes**: The error is in newly added code. Read the compiler error, fix it, rebuild.
- **swift test fails**: Distinguish pre-existing failures (`git stash && swift test && git stash pop`) from new ones.
- **SDK structure changed dramatically**: Inspect tarball with `ls -la package/` and adapt.
- **Context compaction**: The beads survive. Run `bd ready -n 0 --json` to see remaining work and continue where you left off.

## Cleanup

After committing, remove the working directory:

```bash
rm -rf .claude/sdk-update
```
