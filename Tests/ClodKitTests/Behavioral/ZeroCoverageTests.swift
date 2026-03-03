//
//  ZeroCoverageTests.swift
//  ClodKitTests
//
//  JSON round-trip encoding tests for types that previously had 0% code coverage:
//  MCP server configs, Agent I/O, AskUserQuestion, BashOutput, Config I/O,
//  EnterWorktree, ExitPlanMode, FileEdit/Read/Write outputs, GitDiff,
//  SubscribePolling, TaskOutputInput, TaskStopInput, TaskStopOutput.
//

import XCTest
@testable import ClodKit

final class ZeroCoverageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - McpHttpServerConfig

    func testMcpHttpServerConfigInit() {
        let config = McpHttpServerConfig(url: "https://example.com/mcp", headers: ["Auth": "Bearer tok"])
        XCTAssertEqual(config.type, "http")
        XCTAssertEqual(config.url, "https://example.com/mcp")
        XCTAssertEqual(config.headers, ["Auth": "Bearer tok"])
    }

    func testMcpHttpServerConfigInitDefaultHeaders() {
        let config = McpHttpServerConfig(url: "https://example.com")
        XCTAssertNil(config.headers)
    }

    func testMcpHttpServerConfigRoundTrip() throws {
        let config = McpHttpServerConfig(url: "https://example.com/mcp", headers: ["X-Key": "val"])
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpHttpServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpHttpServerConfigDecodeFromJSON() throws {
        let json = """
        {"type":"http","url":"https://a.com","headers":{"H":"V"}}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpHttpServerConfig.self, from: json)
        XCTAssertEqual(config.type, "http")
        XCTAssertEqual(config.url, "https://a.com")
        XCTAssertEqual(config.headers, ["H": "V"])
    }

    func testMcpHttpServerConfigDecodeNilHeaders() throws {
        let json = """
        {"type":"http","url":"https://a.com"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpHttpServerConfig.self, from: json)
        XCTAssertNil(config.headers)
    }

    // MARK: - McpStdioServerConfig

    func testMcpStdioServerConfigInit() {
        let config = McpStdioServerConfig(command: "node", args: ["server.js"], env: ["PORT": "3000"])
        XCTAssertEqual(config.type, "stdio")
        XCTAssertEqual(config.command, "node")
        XCTAssertEqual(config.args, ["server.js"])
        XCTAssertEqual(config.env, ["PORT": "3000"])
    }

    func testMcpStdioServerConfigInitDefaults() {
        let config = McpStdioServerConfig(command: "python")
        XCTAssertNil(config.args)
        XCTAssertNil(config.env)
    }

    func testMcpStdioServerConfigRoundTrip() throws {
        let config = McpStdioServerConfig(command: "node", args: ["s.js"], env: ["K": "V"])
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpStdioServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpStdioServerConfigDecodeFromJSON() throws {
        let json = """
        {"type":"stdio","command":"python","args":["run.py"],"env":{"A":"B"}}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpStdioServerConfig.self, from: json)
        XCTAssertEqual(config.command, "python")
        XCTAssertEqual(config.args, ["run.py"])
        XCTAssertEqual(config.env, ["A": "B"])
    }

    // MARK: - McpSdkServerConfig

    func testMcpSdkServerConfigInit() {
        let config = McpSdkServerConfig(name: "my-server")
        XCTAssertEqual(config.type, "sdk")
        XCTAssertEqual(config.name, "my-server")
    }

    func testMcpSdkServerConfigRoundTrip() throws {
        let config = McpSdkServerConfig(name: "test")
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpSdkServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpSdkServerConfigDecodeFromJSON() throws {
        let json = """
        {"type":"sdk","name":"tools"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpSdkServerConfig.self, from: json)
        XCTAssertEqual(config.type, "sdk")
        XCTAssertEqual(config.name, "tools")
    }

    // MARK: - McpSSEServerConfig

    func testMcpSSEServerConfigInit() {
        let config = McpSSEServerConfig(url: "https://sse.example.com", headers: ["Token": "abc"])
        XCTAssertEqual(config.type, "sse")
        XCTAssertEqual(config.url, "https://sse.example.com")
        XCTAssertEqual(config.headers, ["Token": "abc"])
    }

    func testMcpSSEServerConfigInitDefaultHeaders() {
        let config = McpSSEServerConfig(url: "https://sse.example.com")
        XCTAssertNil(config.headers)
    }

    func testMcpSSEServerConfigRoundTrip() throws {
        let config = McpSSEServerConfig(url: "https://sse.example.com", headers: ["K": "V"])
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpSSEServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpSSEServerConfigDecodeFromJSON() throws {
        let json = """
        {"type":"sse","url":"https://sse.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpSSEServerConfig.self, from: json)
        XCTAssertEqual(config.type, "sse")
        XCTAssertEqual(config.url, "https://sse.test")
        XCTAssertNil(config.headers)
    }

    // MARK: - McpServerConfig (Union)

    func testMcpServerConfigDecodeStdio() throws {
        let json = """
        {"type":"stdio","command":"node","args":["s.js"]}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfig.self, from: json)
        if case .stdio(let c) = config {
            XCTAssertEqual(c.command, "node")
        } else {
            XCTFail("Expected .stdio")
        }
    }

    func testMcpServerConfigDecodeSse() throws {
        let json = """
        {"type":"sse","url":"https://sse.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfig.self, from: json)
        if case .sse(let c) = config {
            XCTAssertEqual(c.url, "https://sse.test")
        } else {
            XCTFail("Expected .sse")
        }
    }

    func testMcpServerConfigDecodeHttp() throws {
        let json = """
        {"type":"http","url":"https://http.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfig.self, from: json)
        if case .http(let c) = config {
            XCTAssertEqual(c.url, "https://http.test")
        } else {
            XCTFail("Expected .http")
        }
    }

    func testMcpServerConfigDecodeSdk() throws {
        let json = """
        {"type":"sdk","name":"tools"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfig.self, from: json)
        if case .sdk(let c) = config {
            XCTAssertEqual(c.name, "tools")
        } else {
            XCTFail("Expected .sdk")
        }
    }

    func testMcpServerConfigDecodeDefaultFallsBackToStdio() throws {
        let json = """
        {"type":"unknown","command":"fallback"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfig.self, from: json)
        if case .stdio(let c) = config {
            XCTAssertEqual(c.command, "fallback")
        } else {
            XCTFail("Expected .stdio fallback")
        }
    }

    func testMcpServerConfigEncodeStdio() throws {
        let config = McpServerConfig.stdio(McpStdioServerConfig(command: "node"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpServerConfigEncodeSse() throws {
        let config = McpServerConfig.sse(McpSSEServerConfig(url: "https://sse.test"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpServerConfigEncodeHttp() throws {
        let config = McpServerConfig.http(McpHttpServerConfig(url: "https://http.test"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testMcpServerConfigEncodeSdk() throws {
        let config = McpServerConfig.sdk(McpSdkServerConfig(name: "sdk-server"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - McpServerConfigForProcessTransport (Union)

    func testProcessTransportDecodeStdio() throws {
        let json = """
        {"type":"stdio","command":"node"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfigForProcessTransport.self, from: json)
        if case .stdio(let c) = config {
            XCTAssertEqual(c.command, "node")
        } else {
            XCTFail("Expected .stdio")
        }
    }

    func testProcessTransportDecodeSse() throws {
        let json = """
        {"type":"sse","url":"https://sse.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfigForProcessTransport.self, from: json)
        if case .sse(let c) = config {
            XCTAssertEqual(c.url, "https://sse.test")
        } else {
            XCTFail("Expected .sse")
        }
    }

    func testProcessTransportDecodeHttp() throws {
        let json = """
        {"type":"http","url":"https://http.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfigForProcessTransport.self, from: json)
        if case .http(let c) = config {
            XCTAssertEqual(c.url, "https://http.test")
        } else {
            XCTFail("Expected .http")
        }
    }

    func testProcessTransportDecodeSdk() throws {
        let json = """
        {"type":"sdk","name":"tools"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfigForProcessTransport.self, from: json)
        if case .sdk(let c) = config {
            XCTAssertEqual(c.name, "tools")
        } else {
            XCTFail("Expected .sdk")
        }
    }

    func testProcessTransportDecodeUnknownFallsBackToStdio() throws {
        let json = """
        {"type":"unknown","command":"fallback"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerConfigForProcessTransport.self, from: json)
        if case .stdio(let c) = config {
            XCTAssertEqual(c.command, "fallback")
        } else {
            XCTFail("Expected .stdio fallback")
        }
    }

    func testProcessTransportEncodeStdio() throws {
        let config = McpServerConfigForProcessTransport.stdio(McpStdioServerConfig(command: "n"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfigForProcessTransport.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testProcessTransportEncodeSse() throws {
        let config = McpServerConfigForProcessTransport.sse(McpSSEServerConfig(url: "https://s"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfigForProcessTransport.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testProcessTransportEncodeHttp() throws {
        let config = McpServerConfigForProcessTransport.http(McpHttpServerConfig(url: "https://h"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfigForProcessTransport.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testProcessTransportEncodeSdk() throws {
        let config = McpServerConfigForProcessTransport.sdk(McpSdkServerConfig(name: "s"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerConfigForProcessTransport.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - McpServerStatusConfig (Union)

    func testStatusConfigDecodeStdio() throws {
        let json = """
        {"type":"stdio","command":"node"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerStatusConfig.self, from: json)
        if case .stdio(let c) = config {
            XCTAssertEqual(c.command, "node")
        } else {
            XCTFail("Expected .stdio")
        }
    }

    func testStatusConfigDecodeSse() throws {
        let json = """
        {"type":"sse","url":"https://sse.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerStatusConfig.self, from: json)
        if case .sse(let c) = config {
            XCTAssertEqual(c.url, "https://sse.test")
        } else {
            XCTFail("Expected .sse")
        }
    }

    func testStatusConfigDecodeHttp() throws {
        let json = """
        {"type":"http","url":"https://http.test"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerStatusConfig.self, from: json)
        if case .http(let c) = config {
            XCTAssertEqual(c.url, "https://http.test")
        } else {
            XCTFail("Expected .http")
        }
    }

    func testStatusConfigDecodeSdk() throws {
        let json = """
        {"type":"sdk","name":"tools"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerStatusConfig.self, from: json)
        if case .sdk(let c) = config {
            XCTAssertEqual(c.name, "tools")
        } else {
            XCTFail("Expected .sdk")
        }
    }

    func testStatusConfigDecodeClaudeAIProxy() throws {
        let json = """
        {"type":"claudeai-proxy","url":"https://proxy.test","id":"abc123"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerStatusConfig.self, from: json)
        if case .claudeAIProxy(let c) = config {
            XCTAssertEqual(c.url, "https://proxy.test")
            XCTAssertEqual(c.id, "abc123")
        } else {
            XCTFail("Expected .claudeAIProxy")
        }
    }

    func testStatusConfigDecodeUnknownFallsBackToStdio() throws {
        let json = """
        {"type":"unknown","command":"fallback"}
        """.data(using: .utf8)!
        let config = try decoder.decode(McpServerStatusConfig.self, from: json)
        if case .stdio(let c) = config {
            XCTAssertEqual(c.command, "fallback")
        } else {
            XCTFail("Expected .stdio fallback")
        }
    }

    func testStatusConfigEncodeStdio() throws {
        let config = McpServerStatusConfig.stdio(McpStdioServerConfig(command: "n"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerStatusConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testStatusConfigEncodeSse() throws {
        let config = McpServerStatusConfig.sse(McpSSEServerConfig(url: "https://s"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerStatusConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testStatusConfigEncodeHttp() throws {
        let config = McpServerStatusConfig.http(McpHttpServerConfig(url: "https://h"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerStatusConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testStatusConfigEncodeSdk() throws {
        let config = McpServerStatusConfig.sdk(McpSdkServerConfig(name: "s"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerStatusConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testStatusConfigEncodeClaudeAIProxy() throws {
        let config = McpServerStatusConfig.claudeAIProxy(McpClaudeAIProxyServerConfig(url: "https://p", id: "id1"))
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(McpServerStatusConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    // MARK: - AgentInput

    func testAgentInputInitAllFields() {
        let input = AgentInput(
            description: "desc", prompt: "do stuff", subagentType: "Explore",
            model: "opus", resume: "sess-1", runInBackground: true, maxTurns: 5,
            name: "worker", teamName: "team-a", mode: "auto", isolation: "worktree"
        )
        XCTAssertEqual(input.description, "desc")
        XCTAssertEqual(input.prompt, "do stuff")
        XCTAssertEqual(input.subagentType, "Explore")
        XCTAssertEqual(input.model, "opus")
        XCTAssertEqual(input.resume, "sess-1")
        XCTAssertEqual(input.runInBackground, true)
        XCTAssertEqual(input.maxTurns, 5)
        XCTAssertEqual(input.name, "worker")
        XCTAssertEqual(input.teamName, "team-a")
        XCTAssertEqual(input.mode, "auto")
        XCTAssertEqual(input.isolation, "worktree")
    }

    func testAgentInputInitDefaults() {
        let input = AgentInput(description: "d", prompt: "p", subagentType: "Code")
        XCTAssertNil(input.model)
        XCTAssertNil(input.resume)
        XCTAssertNil(input.runInBackground)
        XCTAssertNil(input.maxTurns)
        XCTAssertNil(input.name)
        XCTAssertNil(input.teamName)
        XCTAssertNil(input.mode)
        XCTAssertNil(input.isolation)
    }

    func testAgentInputRoundTrip() throws {
        let input = AgentInput(
            description: "desc", prompt: "go", subagentType: "Explore",
            model: "opus", resume: "s1", runInBackground: true, maxTurns: 10,
            name: "w", teamName: "t", mode: "auto", isolation: "worktree"
        )
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(AgentInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    func testAgentInputDecodeFromSnakeCaseJSON() throws {
        let json = """
        {
            "description": "test",
            "prompt": "hello",
            "subagent_type": "Code",
            "run_in_background": false,
            "max_turns": 3,
            "team_name": "alpha"
        }
        """.data(using: .utf8)!
        let input = try decoder.decode(AgentInput.self, from: json)
        XCTAssertEqual(input.subagentType, "Code")
        XCTAssertEqual(input.runInBackground, false)
        XCTAssertEqual(input.maxTurns, 3)
        XCTAssertEqual(input.teamName, "alpha")
    }

    // MARK: - AgentOutput

    func testAgentOutputDecodeCompleted() throws {
        let json = """
        {
            "status": "completed",
            "agentId": "a1",
            "content": [{"type": "text", "text": "done"}],
            "totalToolUseCount": 5,
            "totalDurationMs": 1000,
            "totalTokens": 500,
            "usage": {"input_tokens": 200, "output_tokens": 300},
            "prompt": "do it"
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(AgentOutput.self, from: json)
        if case .completed(let c) = output {
            XCTAssertEqual(c.agentId, "a1")
            XCTAssertEqual(c.content.count, 1)
            XCTAssertEqual(c.content[0].text, "done")
            XCTAssertEqual(c.totalToolUseCount, 5)
            XCTAssertEqual(c.totalDurationMs, 1000)
            XCTAssertEqual(c.totalTokens, 500)
            XCTAssertEqual(c.usage.inputTokens, 200)
            XCTAssertEqual(c.usage.outputTokens, 300)
            XCTAssertEqual(c.status, "completed")
            XCTAssertEqual(c.prompt, "do it")
        } else {
            XCTFail("Expected .completed")
        }
    }

    func testAgentOutputDecodeAsyncLaunched() throws {
        let json = """
        {
            "status": "async_launched",
            "agentId": "a2",
            "description": "background task",
            "prompt": "run",
            "outputFile": "/tmp/out.txt",
            "canReadOutputFile": true
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(AgentOutput.self, from: json)
        if case .asyncLaunched(let a) = output {
            XCTAssertEqual(a.status, "async_launched")
            XCTAssertEqual(a.agentId, "a2")
            XCTAssertEqual(a.description, "background task")
            XCTAssertEqual(a.prompt, "run")
            XCTAssertEqual(a.outputFile, "/tmp/out.txt")
            XCTAssertEqual(a.canReadOutputFile, true)
        } else {
            XCTFail("Expected .asyncLaunched")
        }
    }

    func testAgentOutputDecodeSubAgentEntered() throws {
        let json = """
        {
            "status": "sub_agent_entered",
            "description": "entering sub",
            "message": "transferred"
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(AgentOutput.self, from: json)
        if case .subAgentEntered(let s) = output {
            XCTAssertEqual(s.status, "sub_agent_entered")
            XCTAssertEqual(s.description, "entering sub")
            XCTAssertEqual(s.message, "transferred")
        } else {
            XCTFail("Expected .subAgentEntered")
        }
    }

    func testAgentOutputDecodeUnknownFallsBackToCompleted() throws {
        let json = """
        {
            "status": "unknown_status",
            "agentId": "a3",
            "content": [],
            "totalToolUseCount": 0,
            "totalDurationMs": 0,
            "totalTokens": 0,
            "usage": {"input_tokens": 0, "output_tokens": 0},
            "prompt": "x"
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(AgentOutput.self, from: json)
        if case .completed = output {
            // OK - default fallback
        } else {
            XCTFail("Expected .completed fallback for unknown status")
        }
    }

    func testAgentOutputEncodeCompleted() throws {
        let output = AgentOutput.completed(AgentCompletedOutput(
            agentId: "a1",
            content: [AgentTextContent(text: "hi")],
            totalToolUseCount: 1,
            totalDurationMs: 100,
            totalTokens: 50,
            usage: AgentUsage(inputTokens: 20, outputTokens: 30),
            prompt: "go"
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(AgentOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testAgentOutputEncodeAsyncLaunched() throws {
        let output = AgentOutput.asyncLaunched(AgentAsyncLaunchedOutput(
            agentId: "a2", description: "bg", prompt: "run", outputFile: "/out"
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(AgentOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testAgentOutputEncodeSubAgentEntered() throws {
        let output = AgentOutput.subAgentEntered(AgentSubAgentEnteredOutput(
            description: "sub", message: "msg"
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(AgentOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - AgentCompletedOutput

    func testAgentCompletedOutputInit() {
        let output = AgentCompletedOutput(
            agentId: "a1", content: [AgentTextContent(text: "x")],
            totalToolUseCount: 2, totalDurationMs: 500, totalTokens: 100,
            usage: AgentUsage(inputTokens: 40, outputTokens: 60), prompt: "go"
        )
        XCTAssertEqual(output.status, "completed")
        XCTAssertEqual(output.agentId, "a1")
    }

    // MARK: - AgentTextContent

    func testAgentTextContentInitDefault() {
        let c = AgentTextContent(text: "hello")
        XCTAssertEqual(c.type, "text")
        XCTAssertEqual(c.text, "hello")
    }

    func testAgentTextContentInitCustomType() {
        let c = AgentTextContent(type: "code", text: "print()")
        XCTAssertEqual(c.type, "code")
    }

    func testAgentTextContentRoundTrip() throws {
        let c = AgentTextContent(text: "hi")
        let data = try encoder.encode(c)
        let decoded = try decoder.decode(AgentTextContent.self, from: data)
        XCTAssertEqual(decoded, c)
    }

    // MARK: - AgentUsage

    func testAgentUsageInitAllFields() {
        let usage = AgentUsage(
            inputTokens: 100, outputTokens: 200,
            cacheCreationInputTokens: 50, cacheReadInputTokens: 30,
            serverToolUse: AgentServerToolUse(webSearchRequests: 1, webFetchRequests: 2),
            serviceTier: "standard",
            cacheCreation: AgentCacheCreation(ephemeral1hInputTokens: 10, ephemeral5mInputTokens: 5)
        )
        XCTAssertEqual(usage.inputTokens, 100)
        XCTAssertEqual(usage.outputTokens, 200)
        XCTAssertEqual(usage.cacheCreationInputTokens, 50)
        XCTAssertEqual(usage.cacheReadInputTokens, 30)
        XCTAssertEqual(usage.serverToolUse?.webSearchRequests, 1)
        XCTAssertEqual(usage.serviceTier, "standard")
        XCTAssertEqual(usage.cacheCreation?.ephemeral1hInputTokens, 10)
    }

    func testAgentUsageInitDefaults() {
        let usage = AgentUsage(inputTokens: 10, outputTokens: 20)
        XCTAssertNil(usage.cacheCreationInputTokens)
        XCTAssertNil(usage.cacheReadInputTokens)
        XCTAssertNil(usage.serverToolUse)
        XCTAssertNil(usage.serviceTier)
        XCTAssertNil(usage.cacheCreation)
    }

    func testAgentUsageRoundTrip() throws {
        let usage = AgentUsage(
            inputTokens: 100, outputTokens: 200,
            cacheCreationInputTokens: 50, cacheReadInputTokens: 30,
            serverToolUse: AgentServerToolUse(webSearchRequests: 1, webFetchRequests: 2),
            serviceTier: "premium",
            cacheCreation: AgentCacheCreation(ephemeral1hInputTokens: 10, ephemeral5mInputTokens: 5)
        )
        let data = try encoder.encode(usage)
        let decoded = try decoder.decode(AgentUsage.self, from: data)
        XCTAssertEqual(decoded, usage)
    }

    func testAgentUsageDecodeFromSnakeCaseJSON() throws {
        let json = """
        {
            "input_tokens": 100,
            "output_tokens": 200,
            "cache_creation_input_tokens": 50,
            "cache_read_input_tokens": 30,
            "server_tool_use": {"web_search_requests": 1, "web_fetch_requests": 2},
            "service_tier": "standard",
            "cache_creation": {"ephemeral_1h_input_tokens": 10, "ephemeral_5m_input_tokens": 5}
        }
        """.data(using: .utf8)!
        let usage = try decoder.decode(AgentUsage.self, from: json)
        XCTAssertEqual(usage.inputTokens, 100)
        XCTAssertEqual(usage.outputTokens, 200)
        XCTAssertEqual(usage.cacheCreationInputTokens, 50)
        XCTAssertEqual(usage.cacheReadInputTokens, 30)
        XCTAssertEqual(usage.serverToolUse?.webSearchRequests, 1)
        XCTAssertEqual(usage.serverToolUse?.webFetchRequests, 2)
        XCTAssertEqual(usage.serviceTier, "standard")
        XCTAssertEqual(usage.cacheCreation?.ephemeral1hInputTokens, 10)
        XCTAssertEqual(usage.cacheCreation?.ephemeral5mInputTokens, 5)
    }

    // MARK: - AgentServerToolUse

    func testAgentServerToolUseRoundTrip() throws {
        let stu = AgentServerToolUse(webSearchRequests: 3, webFetchRequests: 7)
        let data = try encoder.encode(stu)
        let decoded = try decoder.decode(AgentServerToolUse.self, from: data)
        XCTAssertEqual(decoded, stu)
    }

    func testAgentServerToolUseDecodeSnakeCase() throws {
        let json = """
        {"web_search_requests": 5, "web_fetch_requests": 10}
        """.data(using: .utf8)!
        let stu = try decoder.decode(AgentServerToolUse.self, from: json)
        XCTAssertEqual(stu.webSearchRequests, 5)
        XCTAssertEqual(stu.webFetchRequests, 10)
    }

    // MARK: - AgentCacheCreation

    func testAgentCacheCreationRoundTrip() throws {
        let cc = AgentCacheCreation(ephemeral1hInputTokens: 100, ephemeral5mInputTokens: 50)
        let data = try encoder.encode(cc)
        let decoded = try decoder.decode(AgentCacheCreation.self, from: data)
        XCTAssertEqual(decoded, cc)
    }

    func testAgentCacheCreationDecodeSnakeCase() throws {
        let json = """
        {"ephemeral_1h_input_tokens": 99, "ephemeral_5m_input_tokens": 33}
        """.data(using: .utf8)!
        let cc = try decoder.decode(AgentCacheCreation.self, from: json)
        XCTAssertEqual(cc.ephemeral1hInputTokens, 99)
        XCTAssertEqual(cc.ephemeral5mInputTokens, 33)
    }

    // MARK: - AgentAsyncLaunchedOutput

    func testAgentAsyncLaunchedOutputInit() {
        let output = AgentAsyncLaunchedOutput(
            agentId: "a1", description: "desc", prompt: "go", outputFile: "/out", canReadOutputFile: true
        )
        XCTAssertEqual(output.status, "async_launched")
        XCTAssertEqual(output.agentId, "a1")
        XCTAssertEqual(output.canReadOutputFile, true)
    }

    func testAgentAsyncLaunchedOutputInitDefaultCanRead() {
        let output = AgentAsyncLaunchedOutput(
            agentId: "a1", description: "d", prompt: "p", outputFile: "/f"
        )
        XCTAssertNil(output.canReadOutputFile)
    }

    func testAgentAsyncLaunchedOutputRoundTrip() throws {
        let output = AgentAsyncLaunchedOutput(
            agentId: "a1", description: "d", prompt: "p", outputFile: "/f", canReadOutputFile: true
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(AgentAsyncLaunchedOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - AgentSubAgentEnteredOutput

    func testAgentSubAgentEnteredOutputInit() {
        let output = AgentSubAgentEnteredOutput(description: "sub", message: "entered")
        XCTAssertEqual(output.status, "sub_agent_entered")
        XCTAssertEqual(output.description, "sub")
        XCTAssertEqual(output.message, "entered")
    }

    func testAgentSubAgentEnteredOutputRoundTrip() throws {
        let output = AgentSubAgentEnteredOutput(description: "sub", message: "msg")
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(AgentSubAgentEnteredOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - AskUserQuestionOption

    func testAskUserQuestionOptionRoundTrip() throws {
        let option = AskUserQuestionOption(label: "Yes", description: "Confirm")
        let data = try encoder.encode(option)
        let decoded = try decoder.decode(AskUserQuestionOption.self, from: data)
        XCTAssertEqual(decoded, option)
    }

    // MARK: - AskUserQuestionItem

    func testAskUserQuestionItemRoundTrip() throws {
        let item = AskUserQuestionItem(
            question: "Continue?",
            header: "Confirm",
            options: [AskUserQuestionOption(label: "Yes", description: "Do it")],
            multiSelect: false
        )
        let data = try encoder.encode(item)
        let decoded = try decoder.decode(AskUserQuestionItem.self, from: data)
        XCTAssertEqual(decoded, item)
    }

    // MARK: - AskUserQuestionInput

    func testAskUserQuestionInputRoundTrip() throws {
        let input = AskUserQuestionInput(questions: [
            AskUserQuestionItem(
                question: "Pick one",
                header: "Choice",
                options: [
                    AskUserQuestionOption(label: "A", description: "Option A"),
                    AskUserQuestionOption(label: "B", description: "Option B"),
                ],
                multiSelect: true
            )
        ])
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(AskUserQuestionInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    // MARK: - AskUserQuestionOutput

    func testAskUserQuestionOutputRoundTrip() throws {
        let output = AskUserQuestionOutput(
            questions: [
                AskUserQuestionItem(
                    question: "Q?", header: "H",
                    options: [AskUserQuestionOption(label: "Y", description: "yes")],
                    multiSelect: false
                )
            ],
            answers: ["Q?": "Y"]
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(AskUserQuestionOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - BashOutput

    func testBashOutputInitAllFields() {
        let output = BashOutput(
            stdout: "hello", stderr: "warn", interrupted: false,
            rawOutputPath: "/raw", isImage: true, backgroundTaskId: "t1",
            backgroundedByUser: true, dangerouslyDisableSandbox: false,
            returnCodeInterpretation: "diff", noOutputExpected: true,
            structuredContent: [.string("block")],
            persistedOutputPath: "/persisted", persistedOutputSize: 1024
        )
        XCTAssertEqual(output.stdout, "hello")
        XCTAssertEqual(output.stderr, "warn")
        XCTAssertEqual(output.interrupted, false)
        XCTAssertEqual(output.rawOutputPath, "/raw")
        XCTAssertEqual(output.isImage, true)
        XCTAssertEqual(output.backgroundTaskId, "t1")
        XCTAssertEqual(output.backgroundedByUser, true)
        XCTAssertEqual(output.dangerouslyDisableSandbox, false)
        XCTAssertEqual(output.returnCodeInterpretation, "diff")
        XCTAssertEqual(output.noOutputExpected, true)
        XCTAssertEqual(output.structuredContent, [.string("block")])
        XCTAssertEqual(output.persistedOutputPath, "/persisted")
        XCTAssertEqual(output.persistedOutputSize, 1024)
    }

    func testBashOutputInitDefaults() {
        let output = BashOutput(stdout: "out", stderr: "", interrupted: true)
        XCTAssertNil(output.rawOutputPath)
        XCTAssertNil(output.isImage)
        XCTAssertNil(output.backgroundTaskId)
        XCTAssertNil(output.backgroundedByUser)
        XCTAssertNil(output.dangerouslyDisableSandbox)
        XCTAssertNil(output.returnCodeInterpretation)
        XCTAssertNil(output.noOutputExpected)
        XCTAssertNil(output.structuredContent)
        XCTAssertNil(output.persistedOutputPath)
        XCTAssertNil(output.persistedOutputSize)
    }

    func testBashOutputRoundTrip() throws {
        let output = BashOutput(
            stdout: "ok", stderr: "err", interrupted: false,
            rawOutputPath: "/raw", isImage: false, backgroundTaskId: "bg1",
            backgroundedByUser: false, dangerouslyDisableSandbox: true,
            returnCodeInterpretation: "special", noOutputExpected: false,
            structuredContent: [.int(42)],
            persistedOutputPath: "/p", persistedOutputSize: 256
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(BashOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testBashOutputDecodeMinimal() throws {
        let json = """
        {"stdout":"hi","stderr":"","interrupted":true}
        """.data(using: .utf8)!
        let output = try decoder.decode(BashOutput.self, from: json)
        XCTAssertEqual(output.stdout, "hi")
        XCTAssertEqual(output.stderr, "")
        XCTAssertEqual(output.interrupted, true)
        XCTAssertNil(output.rawOutputPath)
    }

    // MARK: - ConfigInput

    func testConfigInputInitWithValue() {
        let input = ConfigInput(setting: "theme", value: .string("dark"))
        XCTAssertEqual(input.setting, "theme")
        XCTAssertEqual(input.value, .string("dark"))
    }

    func testConfigInputInitWithoutValue() {
        let input = ConfigInput(setting: "theme")
        XCTAssertNil(input.value)
    }

    func testConfigInputRoundTrip() throws {
        let input = ConfigInput(setting: "timeout", value: .int(30))
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(ConfigInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    func testConfigInputRoundTripNilValue() throws {
        let input = ConfigInput(setting: "theme")
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(ConfigInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    // MARK: - ConfigOutput

    func testConfigOutputInitAllFields() {
        let output = ConfigOutput(
            success: true, operation: "set", setting: "theme",
            value: .string("dark"), previousValue: .string("light"),
            newValue: .string("dark"), error: nil
        )
        XCTAssertTrue(output.success)
        XCTAssertEqual(output.operation, "set")
        XCTAssertEqual(output.setting, "theme")
        XCTAssertEqual(output.value, .string("dark"))
        XCTAssertEqual(output.previousValue, .string("light"))
        XCTAssertEqual(output.newValue, .string("dark"))
        XCTAssertNil(output.error)
    }

    func testConfigOutputInitDefaults() {
        let output = ConfigOutput(success: false, error: "not found")
        XCTAssertFalse(output.success)
        XCTAssertNil(output.operation)
        XCTAssertNil(output.setting)
        XCTAssertNil(output.value)
        XCTAssertNil(output.previousValue)
        XCTAssertNil(output.newValue)
        XCTAssertEqual(output.error, "not found")
    }

    func testConfigOutputRoundTrip() throws {
        let output = ConfigOutput(
            success: true, operation: "get", setting: "model",
            value: .string("opus"), previousValue: nil, newValue: nil
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(ConfigOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - EnterWorktreeInput

    func testEnterWorktreeInputWithName() {
        let input = EnterWorktreeInput(name: "feature-x")
        XCTAssertEqual(input.name, "feature-x")
    }

    func testEnterWorktreeInputWithoutName() {
        let input = EnterWorktreeInput()
        XCTAssertNil(input.name)
    }

    func testEnterWorktreeInputRoundTrip() throws {
        let input = EnterWorktreeInput(name: "wt-1")
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(EnterWorktreeInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    func testEnterWorktreeInputRoundTripNil() throws {
        let input = EnterWorktreeInput()
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(EnterWorktreeInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    // MARK: - EnterWorktreeOutput

    func testEnterWorktreeOutputInit() {
        let output = EnterWorktreeOutput(
            worktreePath: "/tmp/wt", worktreeBranch: "feat", message: "created"
        )
        XCTAssertEqual(output.worktreePath, "/tmp/wt")
        XCTAssertEqual(output.worktreeBranch, "feat")
        XCTAssertEqual(output.message, "created")
    }

    func testEnterWorktreeOutputInitNilBranch() {
        let output = EnterWorktreeOutput(worktreePath: "/tmp/wt", message: "ok")
        XCTAssertNil(output.worktreeBranch)
    }

    func testEnterWorktreeOutputRoundTrip() throws {
        let output = EnterWorktreeOutput(
            worktreePath: "/tmp/wt", worktreeBranch: "main", message: "done"
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(EnterWorktreeOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - ExitPlanModeOutput

    func testExitPlanModeOutputInitAllFields() {
        let output = ExitPlanModeOutput(
            plan: "step 1", isAgent: true, filePath: "/plan.md",
            hasTaskTool: true, awaitingLeaderApproval: true, requestId: "req-1"
        )
        XCTAssertEqual(output.plan, "step 1")
        XCTAssertTrue(output.isAgent)
        XCTAssertEqual(output.filePath, "/plan.md")
        XCTAssertEqual(output.hasTaskTool, true)
        XCTAssertEqual(output.awaitingLeaderApproval, true)
        XCTAssertEqual(output.requestId, "req-1")
    }

    func testExitPlanModeOutputInitDefaults() {
        let output = ExitPlanModeOutput(plan: nil, isAgent: false)
        XCTAssertNil(output.plan)
        XCTAssertFalse(output.isAgent)
        XCTAssertNil(output.filePath)
        XCTAssertNil(output.hasTaskTool)
        XCTAssertNil(output.awaitingLeaderApproval)
        XCTAssertNil(output.requestId)
    }

    func testExitPlanModeOutputRoundTrip() throws {
        let output = ExitPlanModeOutput(
            plan: "plan", isAgent: true, filePath: "/p", hasTaskTool: false,
            awaitingLeaderApproval: false, requestId: "r1"
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(ExitPlanModeOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - FileEditOutput

    func testFileEditOutputInit() {
        let hunk = StructuredPatchHunk(oldStart: 1, oldLines: 1, newStart: 1, newLines: 1, lines: ["-old", "+new"])
        let diff = GitDiff(filename: "f.swift", status: "modified", additions: 1, deletions: 1, changes: 2, patch: "@@ -1 +1 @@")
        let output = FileEditOutput(
            filePath: "/f.swift", oldString: "old", newString: "new",
            originalFile: "old\n", structuredPatch: [hunk],
            userModified: false, replaceAll: true, gitDiff: diff
        )
        XCTAssertEqual(output.filePath, "/f.swift")
        XCTAssertEqual(output.oldString, "old")
        XCTAssertEqual(output.newString, "new")
        XCTAssertEqual(output.originalFile, "old\n")
        XCTAssertEqual(output.structuredPatch.count, 1)
        XCTAssertFalse(output.userModified)
        XCTAssertTrue(output.replaceAll)
        XCTAssertNotNil(output.gitDiff)
    }

    func testFileEditOutputInitNilGitDiff() {
        let output = FileEditOutput(
            filePath: "/f", oldString: "a", newString: "b",
            originalFile: "a\n", structuredPatch: [],
            userModified: false, replaceAll: false
        )
        XCTAssertNil(output.gitDiff)
    }

    func testFileEditOutputRoundTrip() throws {
        let hunk = StructuredPatchHunk(oldStart: 1, oldLines: 2, newStart: 1, newLines: 3, lines: [" ctx", "-old", "+new", "+extra"])
        let output = FileEditOutput(
            filePath: "/f.swift", oldString: "old", newString: "new\nextra",
            originalFile: "ctx\nold\n", structuredPatch: [hunk],
            userModified: true, replaceAll: false,
            gitDiff: GitDiff(filename: "f.swift", status: "modified", additions: 2, deletions: 1, changes: 3, patch: "@@")
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileEditOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - StructuredPatchHunk

    func testStructuredPatchHunkRoundTrip() throws {
        let hunk = StructuredPatchHunk(oldStart: 5, oldLines: 3, newStart: 5, newLines: 4, lines: [" a", "-b", "+c", "+d"])
        let data = try encoder.encode(hunk)
        let decoded = try decoder.decode(StructuredPatchHunk.self, from: data)
        XCTAssertEqual(decoded, hunk)
    }

    // MARK: - FileReadOutput

    func testFileReadOutputDecodeText() throws {
        let json = """
        {
            "type": "text",
            "file": {
                "filePath": "/f.txt",
                "content": "hello",
                "numLines": 1,
                "startLine": 1,
                "totalLines": 1
            }
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(FileReadOutput.self, from: json)
        if case .text(let t) = output {
            XCTAssertEqual(t.type, "text")
            XCTAssertEqual(t.file.filePath, "/f.txt")
            XCTAssertEqual(t.file.content, "hello")
            XCTAssertEqual(t.file.numLines, 1)
            XCTAssertEqual(t.file.startLine, 1)
            XCTAssertEqual(t.file.totalLines, 1)
        } else {
            XCTFail("Expected .text")
        }
    }

    func testFileReadOutputDecodeImage() throws {
        let json = """
        {
            "type": "image",
            "file": {
                "base64": "abc123",
                "type": "image/png",
                "originalSize": 1024,
                "dimensions": {
                    "originalWidth": 100,
                    "originalHeight": 200,
                    "displayWidth": 50,
                    "displayHeight": 100
                }
            }
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(FileReadOutput.self, from: json)
        if case .image(let i) = output {
            XCTAssertEqual(i.type, "image")
            XCTAssertEqual(i.file.base64, "abc123")
            XCTAssertEqual(i.file.type, "image/png")
            XCTAssertEqual(i.file.originalSize, 1024)
            XCTAssertEqual(i.file.dimensions?.originalWidth, 100)
            XCTAssertEqual(i.file.dimensions?.originalHeight, 200)
            XCTAssertEqual(i.file.dimensions?.displayWidth, 50)
            XCTAssertEqual(i.file.dimensions?.displayHeight, 100)
        } else {
            XCTFail("Expected .image")
        }
    }

    func testFileReadOutputDecodeNotebook() throws {
        let json = """
        {
            "type": "notebook",
            "file": {
                "filePath": "/nb.ipynb",
                "cells": [{"type": "code"}]
            }
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(FileReadOutput.self, from: json)
        if case .notebook(let n) = output {
            XCTAssertEqual(n.type, "notebook")
            XCTAssertEqual(n.file.filePath, "/nb.ipynb")
            XCTAssertEqual(n.file.cells.count, 1)
        } else {
            XCTFail("Expected .notebook")
        }
    }

    func testFileReadOutputDecodePdf() throws {
        let json = """
        {
            "type": "pdf",
            "file": {
                "filePath": "/doc.pdf",
                "base64": "pdfdata",
                "originalSize": 2048
            }
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(FileReadOutput.self, from: json)
        if case .pdf(let p) = output {
            XCTAssertEqual(p.type, "pdf")
            XCTAssertEqual(p.file.filePath, "/doc.pdf")
            XCTAssertEqual(p.file.base64, "pdfdata")
            XCTAssertEqual(p.file.originalSize, 2048)
        } else {
            XCTFail("Expected .pdf")
        }
    }

    func testFileReadOutputDecodeParts() throws {
        let json = """
        {
            "type": "parts",
            "file": {
                "filePath": "/big.pdf",
                "originalSize": 50000,
                "count": 10,
                "outputDir": "/tmp/parts"
            }
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(FileReadOutput.self, from: json)
        if case .parts(let p) = output {
            XCTAssertEqual(p.type, "parts")
            XCTAssertEqual(p.file.filePath, "/big.pdf")
            XCTAssertEqual(p.file.originalSize, 50000)
            XCTAssertEqual(p.file.count, 10)
            XCTAssertEqual(p.file.outputDir, "/tmp/parts")
        } else {
            XCTFail("Expected .parts")
        }
    }

    func testFileReadOutputDecodeUnknownFallsBackToText() throws {
        let json = """
        {
            "type": "unknown_type",
            "file": {
                "filePath": "/f.txt",
                "content": "fallback",
                "numLines": 1,
                "startLine": 1,
                "totalLines": 1
            }
        }
        """.data(using: .utf8)!
        let output = try decoder.decode(FileReadOutput.self, from: json)
        if case .text = output {
            // OK - default fallback
        } else {
            XCTFail("Expected .text fallback for unknown type")
        }
    }

    func testFileReadOutputEncodeText() throws {
        let output = FileReadOutput.text(FileReadTextOutput(
            file: FileReadTextFile(filePath: "/f", content: "hi", numLines: 1, startLine: 1, totalLines: 1)
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileReadOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testFileReadOutputEncodeImage() throws {
        let output = FileReadOutput.image(FileReadImageOutput(
            file: FileReadImageFile(base64: "abc", type: "image/png", originalSize: 100)
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileReadOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testFileReadOutputEncodeNotebook() throws {
        let output = FileReadOutput.notebook(FileReadNotebookOutput(
            file: FileReadNotebookFile(filePath: "/nb.ipynb", cells: [.string("cell1")])
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileReadOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testFileReadOutputEncodePdf() throws {
        let output = FileReadOutput.pdf(FileReadPdfOutput(
            file: FileReadPdfFile(filePath: "/doc.pdf", base64: "data", originalSize: 500)
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileReadOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testFileReadOutputEncodeParts() throws {
        let output = FileReadOutput.parts(FileReadPartsOutput(
            file: FileReadPartsFile(filePath: "/f.pdf", originalSize: 1000, count: 5, outputDir: "/out")
        ))
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileReadOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - FileReadTextOutput / FileReadTextFile

    func testFileReadTextOutputInit() {
        let file = FileReadTextFile(filePath: "/f.txt", content: "hello", numLines: 1, startLine: 1, totalLines: 10)
        let output = FileReadTextOutput(file: file)
        XCTAssertEqual(output.type, "text")
        XCTAssertEqual(output.file.filePath, "/f.txt")
    }

    // MARK: - FileReadImageOutput / FileReadImageFile / FileReadImageDimensions

    func testFileReadImageOutputInit() {
        let file = FileReadImageFile(base64: "abc", type: "image/jpeg", originalSize: 2048)
        let output = FileReadImageOutput(file: file)
        XCTAssertEqual(output.type, "image")
        XCTAssertNil(output.file.dimensions)
    }

    func testFileReadImageFileWithDimensions() {
        let dims = FileReadImageDimensions(originalWidth: 800, originalHeight: 600, displayWidth: 400, displayHeight: 300)
        let file = FileReadImageFile(base64: "abc", type: "image/png", originalSize: 1024, dimensions: dims)
        XCTAssertEqual(file.dimensions?.originalWidth, 800)
        XCTAssertEqual(file.dimensions?.originalHeight, 600)
        XCTAssertEqual(file.dimensions?.displayWidth, 400)
        XCTAssertEqual(file.dimensions?.displayHeight, 300)
    }

    func testFileReadImageDimensionsAllNil() {
        let dims = FileReadImageDimensions()
        XCTAssertNil(dims.originalWidth)
        XCTAssertNil(dims.originalHeight)
        XCTAssertNil(dims.displayWidth)
        XCTAssertNil(dims.displayHeight)
    }

    func testFileReadImageDimensionsRoundTrip() throws {
        let dims = FileReadImageDimensions(originalWidth: 100, originalHeight: 200, displayWidth: 50, displayHeight: 100)
        let data = try encoder.encode(dims)
        let decoded = try decoder.decode(FileReadImageDimensions.self, from: data)
        XCTAssertEqual(decoded, dims)
    }

    // MARK: - FileReadNotebookOutput / FileReadNotebookFile

    func testFileReadNotebookOutputInit() {
        let file = FileReadNotebookFile(filePath: "/nb.ipynb", cells: [.null])
        let output = FileReadNotebookOutput(file: file)
        XCTAssertEqual(output.type, "notebook")
        XCTAssertEqual(output.file.filePath, "/nb.ipynb")
    }

    // MARK: - FileReadPdfOutput / FileReadPdfFile

    func testFileReadPdfOutputInit() {
        let file = FileReadPdfFile(filePath: "/doc.pdf", base64: "data", originalSize: 4096)
        let output = FileReadPdfOutput(file: file)
        XCTAssertEqual(output.type, "pdf")
        XCTAssertEqual(output.file.originalSize, 4096)
    }

    // MARK: - FileReadPartsOutput / FileReadPartsFile

    func testFileReadPartsOutputInit() {
        let file = FileReadPartsFile(filePath: "/big.pdf", originalSize: 10000, count: 20, outputDir: "/tmp/out")
        let output = FileReadPartsOutput(file: file)
        XCTAssertEqual(output.type, "parts")
        XCTAssertEqual(output.file.count, 20)
    }

    // MARK: - FileWriteOutput

    func testFileWriteOutputInit() {
        let output = FileWriteOutput(
            type: "create", filePath: "/new.swift", content: "import Foundation",
            structuredPatch: [], originalFile: nil
        )
        XCTAssertEqual(output.type, "create")
        XCTAssertEqual(output.filePath, "/new.swift")
        XCTAssertEqual(output.content, "import Foundation")
        XCTAssertTrue(output.structuredPatch.isEmpty)
        XCTAssertNil(output.originalFile)
        XCTAssertNil(output.gitDiff)
    }

    func testFileWriteOutputInitWithGitDiff() {
        let diff = GitDiff(filename: "f.swift", status: "added", additions: 5, deletions: 0, changes: 5, patch: "@@")
        let output = FileWriteOutput(
            type: "create", filePath: "/f.swift", content: "code",
            structuredPatch: [], originalFile: nil, gitDiff: diff
        )
        XCTAssertNotNil(output.gitDiff)
    }

    func testFileWriteOutputRoundTrip() throws {
        let hunk = StructuredPatchHunk(oldStart: 0, oldLines: 0, newStart: 1, newLines: 1, lines: ["+line1"])
        let output = FileWriteOutput(
            type: "create", filePath: "/f.swift", content: "line1",
            structuredPatch: [hunk], originalFile: nil,
            gitDiff: GitDiff(filename: "f.swift", status: "added", additions: 1, deletions: 0, changes: 1, patch: "@@")
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileWriteOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testFileWriteOutputRoundTripUpdate() throws {
        let output = FileWriteOutput(
            type: "update", filePath: "/f.swift", content: "new content",
            structuredPatch: [], originalFile: "old content"
        )
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(FileWriteOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - GitDiff

    func testGitDiffInit() {
        let diff = GitDiff(
            filename: "test.swift", status: "modified",
            additions: 3, deletions: 1, changes: 4, patch: "@@ -1,3 +1,5 @@"
        )
        XCTAssertEqual(diff.filename, "test.swift")
        XCTAssertEqual(diff.status, "modified")
        XCTAssertEqual(diff.additions, 3)
        XCTAssertEqual(diff.deletions, 1)
        XCTAssertEqual(diff.changes, 4)
        XCTAssertEqual(diff.patch, "@@ -1,3 +1,5 @@")
    }

    func testGitDiffRoundTrip() throws {
        let diff = GitDiff(
            filename: "f.swift", status: "added",
            additions: 10, deletions: 0, changes: 10, patch: "@@"
        )
        let data = try encoder.encode(diff)
        let decoded = try decoder.decode(GitDiff.self, from: data)
        XCTAssertEqual(decoded, diff)
    }

    // MARK: - SubscribePollingInput

    func testSubscribePollingInputInitAllFields() {
        let input = SubscribePollingInput(
            type: "tool", server: "my-server", toolName: "check_status",
            arguments: ["key": .string("val")], uri: nil, intervalMs: 5000, reason: "monitoring"
        )
        XCTAssertEqual(input.type, "tool")
        XCTAssertEqual(input.server, "my-server")
        XCTAssertEqual(input.toolName, "check_status")
        XCTAssertEqual(input.arguments, ["key": .string("val")])
        XCTAssertNil(input.uri)
        XCTAssertEqual(input.intervalMs, 5000)
        XCTAssertEqual(input.reason, "monitoring")
    }

    func testSubscribePollingInputInitDefaults() {
        let input = SubscribePollingInput(type: "resource", server: "srv", intervalMs: 1000)
        XCTAssertNil(input.toolName)
        XCTAssertNil(input.arguments)
        XCTAssertNil(input.uri)
        XCTAssertNil(input.reason)
    }

    func testSubscribePollingInputRoundTrip() throws {
        let input = SubscribePollingInput(
            type: "tool", server: "s", toolName: "t",
            arguments: ["a": .int(1)], uri: nil, intervalMs: 3000, reason: "test"
        )
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(SubscribePollingInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    func testSubscribePollingInputDecodeResource() throws {
        let json = """
        {
            "type": "resource",
            "server": "srv",
            "uri": "resource://data",
            "intervalMs": 2000
        }
        """.data(using: .utf8)!
        let input = try decoder.decode(SubscribePollingInput.self, from: json)
        XCTAssertEqual(input.type, "resource")
        XCTAssertEqual(input.uri, "resource://data")
        XCTAssertEqual(input.intervalMs, 2000)
    }

    // MARK: - SubscribePollingOutput

    func testSubscribePollingOutputRoundTrip() throws {
        let output = SubscribePollingOutput(subscribed: true, subscriptionId: "sub-1")
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(SubscribePollingOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    // MARK: - UnsubscribePollingInput

    func testUnsubscribePollingInputInitAllFields() {
        let input = UnsubscribePollingInput(subscriptionId: "sub-1", server: "srv", target: "tool")
        XCTAssertEqual(input.subscriptionId, "sub-1")
        XCTAssertEqual(input.server, "srv")
        XCTAssertEqual(input.target, "tool")
    }

    func testUnsubscribePollingInputInitDefaults() {
        let input = UnsubscribePollingInput()
        XCTAssertNil(input.subscriptionId)
        XCTAssertNil(input.server)
        XCTAssertNil(input.target)
    }

    func testUnsubscribePollingInputRoundTrip() throws {
        let input = UnsubscribePollingInput(subscriptionId: "sub-1", server: "srv", target: "tool")
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(UnsubscribePollingInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    // MARK: - UnsubscribePollingOutput

    func testUnsubscribePollingOutputRoundTrip() throws {
        let output = UnsubscribePollingOutput(unsubscribed: true)
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(UnsubscribePollingOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testUnsubscribePollingOutputFalse() throws {
        let output = UnsubscribePollingOutput(unsubscribed: false)
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(UnsubscribePollingOutput.self, from: data)
        XCTAssertEqual(decoded.unsubscribed, false)
    }

    // MARK: - TaskOutputInput

    func testTaskOutputInputInit() {
        let input = TaskOutputInput(taskId: "task-1", block: true, timeout: 30000)
        XCTAssertEqual(input.taskId, "task-1")
        XCTAssertTrue(input.block)
        XCTAssertEqual(input.timeout, 30000)
    }

    func testTaskOutputInputInitDefaults() {
        let input = TaskOutputInput(taskId: "task-2")
        XCTAssertTrue(input.block)
        XCTAssertEqual(input.timeout, 30000)
    }

    func testTaskOutputInputRoundTrip() throws {
        let input = TaskOutputInput(taskId: "t1", block: false, timeout: 5000)
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(TaskOutputInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    func testTaskOutputInputDecodeFromSnakeCaseJSON() throws {
        let json = """
        {"task_id": "t99", "block": false, "timeout": 10000}
        """.data(using: .utf8)!
        let input = try decoder.decode(TaskOutputInput.self, from: json)
        XCTAssertEqual(input.taskId, "t99")
        XCTAssertFalse(input.block)
        XCTAssertEqual(input.timeout, 10000)
    }

    // MARK: - TaskStopInput

    @available(*, deprecated, message: "Tests deprecated shellId property")
    func testTaskStopInputInit() {
        let input = TaskStopInput(taskId: "task-1", shellId: "shell-1")
        XCTAssertEqual(input.taskId, "task-1")
        XCTAssertEqual(input.shellId, "shell-1")
    }

    @available(*, deprecated, message: "Tests deprecated shellId property")
    func testTaskStopInputInitDefaults() {
        let input = TaskStopInput()
        XCTAssertNil(input.taskId)
        XCTAssertNil(input.shellId)
    }

    func testTaskStopInputRoundTrip() throws {
        let input = TaskStopInput(taskId: "t1", shellId: "s1")
        let data = try encoder.encode(input)
        let decoded = try decoder.decode(TaskStopInput.self, from: data)
        XCTAssertEqual(decoded, input)
    }

    @available(*, deprecated, message: "Tests deprecated shellId property")
    func testTaskStopInputDecodeFromSnakeCaseJSON() throws {
        let json = """
        {"task_id": "t42", "shell_id": "sh7"}
        """.data(using: .utf8)!
        let input = try decoder.decode(TaskStopInput.self, from: json)
        XCTAssertEqual(input.taskId, "t42")
        XCTAssertEqual(input.shellId, "sh7")
    }

    @available(*, deprecated, message: "Tests deprecated shellId property")
    func testTaskStopInputDecodeNilFields() throws {
        let json = """
        {}
        """.data(using: .utf8)!
        let input = try decoder.decode(TaskStopInput.self, from: json)
        XCTAssertNil(input.taskId)
        XCTAssertNil(input.shellId)
    }

    // MARK: - TaskStopOutput

    func testTaskStopOutputInit() {
        let output = TaskStopOutput(message: "stopped", taskId: "t1", taskType: "bash", command: "ls -la")
        XCTAssertEqual(output.message, "stopped")
        XCTAssertEqual(output.taskId, "t1")
        XCTAssertEqual(output.taskType, "bash")
        XCTAssertEqual(output.command, "ls -la")
    }

    func testTaskStopOutputInitNilCommand() {
        let output = TaskStopOutput(message: "stopped", taskId: "t2", taskType: "process")
        XCTAssertNil(output.command)
    }

    func testTaskStopOutputRoundTrip() throws {
        let output = TaskStopOutput(message: "done", taskId: "t1", taskType: "bash", command: "echo hi")
        let data = try encoder.encode(output)
        let decoded = try decoder.decode(TaskStopOutput.self, from: data)
        XCTAssertEqual(decoded, output)
    }

    func testTaskStopOutputDecodeFromSnakeCaseJSON() throws {
        let json = """
        {"message": "killed", "task_id": "t5", "task_type": "bash", "command": "sleep 100"}
        """.data(using: .utf8)!
        let output = try decoder.decode(TaskStopOutput.self, from: json)
        XCTAssertEqual(output.message, "killed")
        XCTAssertEqual(output.taskId, "t5")
        XCTAssertEqual(output.taskType, "bash")
        XCTAssertEqual(output.command, "sleep 100")
    }

    func testTaskStopOutputDecodeNilCommand() throws {
        let json = """
        {"message": "stopped", "task_id": "t6", "task_type": "process"}
        """.data(using: .utf8)!
        let output = try decoder.decode(TaskStopOutput.self, from: json)
        XCTAssertNil(output.command)
    }

    // MARK: - ConfigScope (bonus coverage for related file)

    func testConfigScopeAllCases() {
        XCTAssertEqual(ConfigScope.local.rawValue, "local")
        XCTAssertEqual(ConfigScope.user.rawValue, "user")
        XCTAssertEqual(ConfigScope.project.rawValue, "project")
    }

    func testConfigScopeRoundTrip() throws {
        for scope in [ConfigScope.local, .user, .project] {
            let data = try encoder.encode(scope)
            let decoded = try decoder.decode(ConfigScope.self, from: data)
            XCTAssertEqual(decoded, scope)
        }
    }
}
