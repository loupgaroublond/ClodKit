# Task: Analyze Claude Code CLI Internals

You're researching how the Claude Code CLI works internally to inform building SDK clients.

## Context

This is part of the ClodeMonster project - a Swift SDK for Claude Code. We need to understand:
1. How the CLI authenticates and talks to Anthropic's backend
2. How it expects to communicate with SDK clients (the control protocol from CLI's perspective)
3. What endpoints/APIs it uses

## Files

The deminified CLI is at:
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/claude-agent-sdk-typescript-pkg/cli.js` (11.6MB, deminified with prettier)

Related reference:
- `/Users/yankee/Documents/Projects/ClodeMonster/vendor/SDK_INTERNALS_ANALYSIS.md` - existing analysis of SDK side

## Questions to Answer

1. **Authentication**: How does the CLI authenticate? OAuth flow? API keys? Session tokens? Where are credentials stored?

2. **Backend API**: What endpoints does it call? Is it api.anthropic.com or something else for Claude.ai accounts? What's the request/response format?

3. **Control Protocol (CLI side)**: How does the CLI handle:
   - Sending `control_request` to SDK (mcp_message, hook_callback, can_use_tool)
   - Receiving `control_response` from SDK
   - The `initialize` handshake

4. **SDK MCP routing**: How does the CLI decide to route an MCP call to the SDK vs handle it internally?

5. **Session management**: How are sessions persisted? What's the format in ~/.claude/projects/?

## Output

**1. Annotate the code directly:**

As you analyze `cli.js`, add comments liberally throughout the file explaining what obfuscated functions, classes, and variables actually do in human terms. For example:

```javascript
// Authentication handler - manages OAuth flow with Claude.ai
class K7 {
  // Stores session token after successful auth
  constructor(X) {
    this.token = X;  // X = session token from OAuth callback
  }

  // Refreshes expired token using refresh_token
  async refreshToken() {
    // ...
  }
}
```

The goal is to make the deminified code readable for future analysis. Be liberal with comments - explain:
- What each major class/function does
- What obfuscated parameter names actually represent
- The purpose of important code blocks
- API endpoints and their purposes

**2. Create analysis document:**

Create `/Users/yankee/Documents/Projects/ClodeMonster/reports/01-cli-internals-report.md` with findings organized by topic. Include relevant code snippets (with line numbers) where helpful.

Note: The code is deminified but variable names are still obfuscated. Use grep/search to find relevant patterns like "api.anthropic", "control_request", "mcp_message", "authenticate", etc.
