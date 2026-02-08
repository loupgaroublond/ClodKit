//
//  SimpleQuery Example
//  ClodKit
//
//  Demonstrates basic usage of the ClodKit SDK:
//  - Creating QueryOptions with model and system prompt
//  - Sending a query via Clod.query()
//  - Iterating over response messages
//  - Extracting text content from assistant messages
//
//  Note: Requires the `claude` CLI to be installed and authenticated.
//

import ClodKit
import Foundation

@main
struct SimpleQueryExample {
    static func main() async throws {
        // Configure query options
        var options = QueryOptions()
        options.model = "claude-sonnet-4-5-20250929"
        options.systemPrompt = "You are a helpful coding assistant. Be concise."
        options.maxTurns = 1
        options.permissionMode = .default

        // Send a query to Claude
        print("Sending query to Claude...")
        let query = try await Clod.query(
            prompt: "What is the Swift keyword for defining an asynchronous function?",
            options: options
        )

        // Iterate over response messages
        for try await message in query {
            switch message {
            case .regular(let sdkMessage):
                switch sdkMessage.type {
                case "assistant":
                    if let content = sdkMessage.content?.stringValue {
                        print("Claude: \(content)")
                    }
                case "result":
                    if let result = sdkMessage.content?.stringValue {
                        print("Result: \(result)")
                    }
                    if let sessionId = sdkMessage.sessionId {
                        print("Session ID: \(sessionId)")
                    }
                default:
                    break
                }

            case .controlRequest, .controlResponse, .controlCancelRequest, .keepAlive:
                // Internal protocol messages - not relevant for simple queries
                break
            }
        }

        print("Query complete.")
    }
}
