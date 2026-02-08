//
//  StreamingOutput Example
//  ClodKit
//
//  Demonstrates streaming message iteration with type-specific handling:
//  - Processing each StdoutMessage variant (regular, control, keepAlive)
//  - Handling different SDKMessage types (assistant, result, user, system)
//  - Extracting session ID and stop reason from result messages
//  - Error detection on assistant messages
//
//  Note: Requires the `claude` CLI to be installed and authenticated.
//

import ClodKit
import Foundation

@main
struct StreamingOutputExample {
    static func main() async throws {
        var options = QueryOptions()
        options.maxTurns = 3
        options.model = "claude-sonnet-4-5-20250929"

        print("Sending query and streaming output...")
        let query = try await Clod.query(
            prompt: "Write a haiku about Swift programming",
            options: options
        )

        var messageCount = 0

        for try await message in query {
            messageCount += 1

            switch message {
            case .regular(let sdkMessage):
                handleSDKMessage(sdkMessage, index: messageCount)

            case .controlRequest(let request):
                print("[\(messageCount)] Control request: type=\(request.type) id=\(request.requestId)")

            case .controlResponse(let response):
                print("[\(messageCount)] Control response: type=\(response.type)")

            case .controlCancelRequest(let cancel):
                print("[\(messageCount)] Cancel request for: \(cancel.requestId)")

            case .keepAlive:
                print("[\(messageCount)] Keep-alive")
            }
        }

        // Access session ID after iteration
        if let sessionId = await query.sessionId {
            print("\nSession ID: \(sessionId)")
        }

        print("Total messages received: \(messageCount)")
    }

    static func handleSDKMessage(_ message: SDKMessage, index: Int) {
        switch message.type {
        case "assistant":
            // Check for errors on assistant messages
            if let error = message.error {
                print("[\(index)] Assistant ERROR: \(error)")
                return
            }
            if let content = message.content?.stringValue {
                print("[\(index)] Assistant: \(content)")
            }

        case "result":
            if let result = message.content?.stringValue {
                print("[\(index)] Result: \(result)")
            }
            if let stopReason = message.stopReason {
                print("[\(index)] Stop reason: \(stopReason)")
            }
            if let sessionId = message.sessionId {
                print("[\(index)] Session: \(sessionId)")
            }

        case "user":
            if let isSynthetic = message.isSynthetic, isSynthetic {
                print("[\(index)] Synthetic user message (tool result)")
            } else {
                print("[\(index)] User message")
            }

        case "system":
            print("[\(index)] System message")

        default:
            print("[\(index)] Unknown message type: \(message.type)")
        }
    }
}
