//
//  ToolServer Example
//  ClodKit
//
//  Demonstrates creating an SDK MCP server with custom tools:
//  - Defining MCPTool instances with JSON Schema input
//  - Creating an SDKMCPServer with multiple tools
//  - Registering the server via QueryOptions.sdkMcpServers
//  - Tools run in-process, routed through the control protocol
//
//  Note: Requires the `claude` CLI to be installed and authenticated.
//

import ClodKit
import Foundation

@main
struct ToolServerExample {
    static func main() async throws {
        // Define a "get_weather" tool
        let weatherTool = MCPTool(
            name: "get_weather",
            description: "Get the current weather for a city",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "city": .string("The city name"),
                    "units": .enum(["celsius", "fahrenheit"], description: "Temperature units")
                ],
                required: ["city"]
            ),
            annotations: MCPToolAnnotations(
                title: "Weather Lookup",
                readOnlyHint: true,
                openWorldHint: true
            )
        ) { args in
            let city = args["city"] as? String ?? "unknown"
            let units = args["units"] as? String ?? "celsius"
            return .text("Weather in \(city): 22\u{00B0} \(units), partly cloudy")
        }

        // Define a "calculate" tool
        let calcTool = MCPTool(
            name: "calculate",
            description: "Perform a mathematical calculation",
            inputSchema: JSONSchema(
                type: "object",
                properties: [
                    "expression": .string("Mathematical expression to evaluate")
                ],
                required: ["expression"]
            ),
            annotations: MCPToolAnnotations(
                readOnlyHint: true,
                idempotentHint: true
            )
        ) { args in
            let expression = args["expression"] as? String ?? ""
            return .text("Result of '\(expression)': 42")
        }

        // Create the SDK MCP server
        let server = SDKMCPServer(
            name: "demo-tools",
            version: "1.0.0",
            tools: [weatherTool, calcTool]
        )

        // Configure query options with the SDK server
        var options = QueryOptions()
        options.sdkMcpServers = ["demo-tools": server]
        options.systemPrompt = "You have access to weather and calculator tools. Use them when asked."
        options.maxTurns = 3

        // Send a query that should trigger tool use
        print("Sending query with custom tools...")
        let query = try await Clod.query(
            prompt: "What's the weather in Tokyo?",
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
