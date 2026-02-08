//
//  HookDemo Example
//  ClodKit
//
//  Demonstrates the hook system for intercepting tool execution:
//  - PreToolUse hooks: inspect/modify/block tool calls before execution
//  - PostToolUse hooks: inspect results after tool execution
//  - Hook output: allow, deny, or modify tool inputs
//  - Pattern matching: filter hooks to specific tool names
//
//  Note: Requires the `claude` CLI to be installed and authenticated.
//

import ClodKit
import Foundation

@main
struct HookDemoExample {
    static func main() async throws {
        var options = QueryOptions()
        options.maxTurns = 5

        // PreToolUse hook: log and optionally block dangerous tools
        options.preToolUseHooks = [
            PreToolUseHookConfig(
                pattern: ".*",  // Match all tools
                timeout: 30.0
            ) { input in
                print("[PreToolUse] Tool: \(input.toolName)")
                print("[PreToolUse] Session: \(input.base.sessionId)")

                // Block any tool that tries to delete files
                if input.toolName == "Bash" {
                    let command = input.toolInput["command"]?.stringValue ?? ""
                    if command.contains("rm ") {
                        print("[PreToolUse] DENIED: destructive command blocked")
                        return .deny(reason: "Destructive commands are not allowed")
                    }
                }

                // Allow all other tools with additional context
                return .allow(additionalContext: "Tool approved by hook")
            }
        ]

        // PostToolUse hook: log successful tool results
        options.postToolUseHooks = [
            PostToolUseHookConfig(
                pattern: "Read|Write",  // Only match file operations
                timeout: 30.0
            ) { input in
                print("[PostToolUse] Tool: \(input.toolName) completed")
                print("[PostToolUse] Tool use ID: \(input.toolUseId)")
                return .continue()
            }
        ]

        // PostToolUseFailure hook: log failures
        options.postToolUseFailureHooks = [
            PostToolUseFailureHookConfig(
                pattern: ".*"
            ) { input in
                print("[PostToolUseFailure] Tool \(input.toolName) failed: \(input.error)")
                if input.isInterrupt {
                    print("[PostToolUseFailure] Failure was caused by an interrupt")
                }
                return .continue()
            }
        ]

        // Send a query
        print("Sending query with hooks enabled...")
        let query = try await Clod.query(
            prompt: "Read the current directory listing",
            options: options
        )

        for try await message in query {
            if case .regular(let sdkMessage) = message,
               sdkMessage.type == "result",
               let result = sdkMessage.content?.stringValue {
                print("Result: \(result)")
            }
        }

        print("Query complete.")
    }
}
