//
//  PermissionCallback Example
//  ClodKit
//
//  Demonstrates the permission callback system:
//  - Setting canUseTool on QueryOptions to handle permission requests
//  - Using PermissionResult.allowTool() and .denyTool() convenience methods
//  - Inspecting ToolPermissionContext for suggestions and metadata
//  - Using permission mode .delegate to route all decisions to the callback
//
//  Note: Requires the `claude` CLI to be installed and authenticated.
//

import ClodKit
import Foundation

@main
struct PermissionCallbackExample {
    static func main() async throws {
        var options = QueryOptions()
        options.maxTurns = 3

        // Use delegate mode so all permission decisions come through our callback
        options.permissionMode = .delegate

        // Set the permission callback
        options.canUseTool = { toolName, input, context in
            print("[Permission] Tool: \(toolName)")
            print("[Permission] Tool use ID: \(context.toolUseID)")

            if let path = context.blockedPath {
                print("[Permission] Blocked path: \(path)")
            }
            if let reason = context.decisionReason {
                print("[Permission] Reason: \(reason)")
            }
            if !context.suggestions.isEmpty {
                print("[Permission] Suggestions: \(context.suggestions.count) available")
            }

            // Allow read-only tools
            let readOnlyTools = ["Read", "Glob", "Grep", "WebSearch"]
            if readOnlyTools.contains(toolName) {
                print("[Permission] ALLOWED: \(toolName) is read-only")
                return .allowTool(toolUseID: context.toolUseID)
            }

            // Allow Bash but only for non-destructive commands
            if toolName == "Bash" {
                let command = input["command"]?.stringValue ?? ""
                if command.contains("rm ") || command.contains("sudo ") {
                    print("[Permission] DENIED: destructive Bash command")
                    return .denyTool(
                        "Destructive commands require manual approval",
                        toolUseID: context.toolUseID
                    )
                }
                print("[Permission] ALLOWED: non-destructive Bash command")
                return .allowTool(toolUseID: context.toolUseID)
            }

            // Deny write operations with interrupt
            if toolName == "Write" || toolName == "Edit" {
                print("[Permission] DENIED: write operations blocked")
                return .denyToolAndInterrupt(
                    "Write operations are disabled in this session",
                    toolUseID: context.toolUseID
                )
            }

            // Allow everything else
            return .allowTool(toolUseID: context.toolUseID)
        }

        // Send a query
        print("Sending query with permission callback...")
        let query = try await Clod.query(
            prompt: "List the files in the current directory",
            options: options
        )

        for try await message in query {
            if case .regular(let sdkMessage) = message {
                switch sdkMessage.type {
                case "assistant":
                    if let content = sdkMessage.content?.stringValue {
                        print("Claude: \(content)")
                    }
                case "result":
                    if let result = sdkMessage.content?.stringValue {
                        print("Result: \(result)")
                    }
                default:
                    break
                }
            }
        }

        print("Query complete.")
    }
}
