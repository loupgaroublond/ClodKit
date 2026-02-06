# Task: Deep Dive into Python SDK Implementation

You're analyzing the Python SDK source code to understand its implementation patterns and compare with TypeScript.

## Context

This is part of the ClodeMonster project - a Swift SDK for Claude Code. The Python SDK is MIT licensed and has full source available, making it a clean reference for implementation.

## Files

Source code at `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-python/src/claude_agent_sdk/`:
- `__init__.py` - Public exports
- `types.py` - All type definitions
- `_internal/transport/subprocess_cli.py` - CLI subprocess management
- `_internal/query.py` - Core query logic, control protocol
- `_internal/client.py` - ClaudeSDKClient class

Examples at `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-python/examples/`:
- `hooks.py` - Hook examples
- `mcp_calculator.py` - SDK MCP tool examples

Tests at `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-python/tests/`

Related reference:
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/SDK_INTERNALS_ANALYSIS.md` - existing high-level analysis

## Questions to Answer

1. **Code organization**: How is the codebase structured? What's public vs internal?

2. **Query implementation**: Trace `query()` and `ClaudeSDKClient` implementations. How do they differ?

3. **MCP tool implementation**: Full details on `@tool` decorator, `create_sdk_mcp_server()`, and how tools are invoked.

4. **Hook implementation**: How are hooks registered? How does `_handle_hook_callback` work?

5. **Control protocol details**: Document all control request/response handling in `_handle_control_request()`.

6. **Streaming modes**: How does single-shot vs streaming mode work? When is stdin kept open?

7. **Error types**: What errors can be raised? How are CLI errors surfaced?

8. **Differences from TypeScript**: What features does TypeScript have that Python doesn't? What's Python-specific?

## Output

Create `/Users/yankee/Documents/Projects/ClodeMonster/reports/03-python-sdk-report.md` with detailed findings. Include code references with file paths and line numbers.
