//
//  QueryAPITests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for QueryAPI and QueryOptions.
//

import XCTest
@testable import ClaudeCodeSDK

final class QueryAPITests: XCTestCase {

    // MARK: - QueryOptions Tests

    func testQueryOptions_DefaultValues() {
        let options = QueryOptions()

        XCTAssertNil(options.model)
        XCTAssertNil(options.maxTurns)
        XCTAssertNil(options.maxThinkingTokens)
        XCTAssertNil(options.permissionMode)
        XCTAssertNil(options.systemPrompt)
        XCTAssertNil(options.appendSystemPrompt)
        XCTAssertNil(options.workingDirectory)
        XCTAssertTrue(options.environment.isEmpty)
        XCTAssertNil(options.cliPath)
        XCTAssertNil(options.allowedTools)
        XCTAssertNil(options.blockedTools)
        XCTAssertTrue(options.additionalDirectories.isEmpty)
        XCTAssertNil(options.resume)
        XCTAssertTrue(options.mcpServers.isEmpty)
        XCTAssertTrue(options.sdkMcpServers.isEmpty)
        XCTAssertTrue(options.preToolUseHooks.isEmpty)
        XCTAssertTrue(options.postToolUseHooks.isEmpty)
        XCTAssertNil(options.canUseTool)
    }

    func testQueryOptions_SettingValues() {
        var options = QueryOptions()

        options.model = "claude-sonnet-4-20250514"
        options.maxTurns = 10
        options.maxThinkingTokens = 1000
        options.permissionMode = .bypassPermissions
        options.systemPrompt = "You are a helpful assistant."
        options.appendSystemPrompt = "Be concise."
        options.workingDirectory = URL(fileURLWithPath: "/tmp")
        options.environment = ["API_KEY": "test"]
        options.cliPath = "/usr/local/bin/claude"
        options.allowedTools = ["Read", "Write"]
        options.blockedTools = ["Bash"]
        options.additionalDirectories = ["/home", "/var"]
        options.resume = "session-123"

        XCTAssertEqual(options.model, "claude-sonnet-4-20250514")
        XCTAssertEqual(options.maxTurns, 10)
        XCTAssertEqual(options.maxThinkingTokens, 1000)
        XCTAssertEqual(options.permissionMode, .bypassPermissions)
        XCTAssertEqual(options.systemPrompt, "You are a helpful assistant.")
        XCTAssertEqual(options.appendSystemPrompt, "Be concise.")
        XCTAssertEqual(options.workingDirectory?.path, "/tmp")
        XCTAssertEqual(options.environment["API_KEY"], "test")
        XCTAssertEqual(options.cliPath, "/usr/local/bin/claude")
        XCTAssertEqual(options.allowedTools, ["Read", "Write"])
        XCTAssertEqual(options.blockedTools, ["Bash"])
        XCTAssertEqual(options.additionalDirectories, ["/home", "/var"])
        XCTAssertEqual(options.resume, "session-123")
    }

    // MARK: - MCPServerConfig Tests

    func testMCPServerConfig_BasicInit() {
        let config = MCPServerConfig(command: "node")

        XCTAssertEqual(config.command, "node")
        XCTAssertTrue(config.args.isEmpty)
        XCTAssertNil(config.env)
    }

    func testMCPServerConfig_FullInit() {
        let config = MCPServerConfig(
            command: "node",
            args: ["server.js", "--port", "8080"],
            env: ["NODE_ENV": "production"]
        )

        XCTAssertEqual(config.command, "node")
        XCTAssertEqual(config.args, ["server.js", "--port", "8080"])
        XCTAssertEqual(config.env?["NODE_ENV"], "production")
    }

    func testMCPServerConfig_ToDictionary() {
        let config = MCPServerConfig(
            command: "python",
            args: ["-m", "mcp_server"],
            env: ["DEBUG": "true"]
        )

        let dict = config.toDictionary()

        XCTAssertEqual(dict["command"] as? String, "python")
        XCTAssertEqual(dict["args"] as? [String], ["-m", "mcp_server"])
        XCTAssertEqual((dict["env"] as? [String: String])?["DEBUG"], "true")
    }

    func testMCPServerConfig_ToDictionary_NoArgsOrEnv() {
        let config = MCPServerConfig(command: "simple")

        let dict = config.toDictionary()

        XCTAssertEqual(dict["command"] as? String, "simple")
        XCTAssertNil(dict["args"])
        XCTAssertNil(dict["env"])
    }

    func testMCPServerConfig_Equatable() {
        let config1 = MCPServerConfig(command: "node", args: ["server.js"])
        let config2 = MCPServerConfig(command: "node", args: ["server.js"])
        let config3 = MCPServerConfig(command: "python", args: ["server.py"])

        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }

    // MARK: - Hook Config Tests

    func testPreToolUseHookConfig_DefaultTimeout() {
        let hook = PreToolUseHookConfig { _ in
            return HookOutput()
        }

        XCTAssertNil(hook.pattern)
        XCTAssertEqual(hook.timeout, 60.0)
    }

    func testPreToolUseHookConfig_CustomValues() {
        let hook = PreToolUseHookConfig(
            pattern: "Read|Write",
            timeout: 30.0
        ) { _ in
            return HookOutput()
        }

        XCTAssertEqual(hook.pattern, "Read|Write")
        XCTAssertEqual(hook.timeout, 30.0)
    }

    func testPostToolUseHookConfig_DefaultTimeout() {
        let hook = PostToolUseHookConfig { _ in
            return HookOutput()
        }

        XCTAssertNil(hook.pattern)
        XCTAssertEqual(hook.timeout, 60.0)
    }

    func testPostToolUseFailureHookConfig_DefaultTimeout() {
        let hook = PostToolUseFailureHookConfig { _ in
            return HookOutput()
        }

        XCTAssertNil(hook.pattern)
        XCTAssertEqual(hook.timeout, 60.0)
    }

    func testUserPromptSubmitHookConfig_DefaultTimeout() {
        let hook = UserPromptSubmitHookConfig { _ in
            return HookOutput()
        }

        XCTAssertEqual(hook.timeout, 60.0)
    }

    func testStopHookConfig_DefaultTimeout() {
        let hook = StopHookConfig { _ in
            return HookOutput()
        }

        XCTAssertEqual(hook.timeout, 60.0)
    }

    // MARK: - QueryError Tests

    func testQueryError_LaunchFailed_LocalizedDescription() {
        let error = QueryError.launchFailed("Process not found")

        XCTAssertTrue(error.localizedDescription.contains("Process not found"))
        XCTAssertTrue(error.localizedDescription.contains("launch"))
    }

    func testQueryError_MCPConfigFailed_LocalizedDescription() {
        let error = QueryError.mcpConfigFailed("Invalid server config")

        XCTAssertTrue(error.localizedDescription.contains("Invalid server config"))
        XCTAssertTrue(error.localizedDescription.contains("MCP"))
    }

    func testQueryError_InvalidOptions_LocalizedDescription() {
        let error = QueryError.invalidOptions("Missing required field")

        XCTAssertTrue(error.localizedDescription.contains("Missing required field"))
        XCTAssertTrue(error.localizedDescription.contains("options"))
    }

    func testQueryError_Equatable() {
        let e1 = QueryError.launchFailed("error")
        let e2 = QueryError.launchFailed("error")
        let e3 = QueryError.launchFailed("different")
        let e4 = QueryError.mcpConfigFailed("error")

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
        XCTAssertNotEqual(e1, e4)
    }

    // MARK: - ClaudeCode Namespace Tests

    func testClaudeCode_NamespaceExists() {
        // Verify that the ClaudeCode namespace enum exists with the query function
        // We can't easily test the actual function without mocking the transport
        // but we can verify the function signature exists
        let _: (String, QueryOptions) async throws -> ClaudeQuery = ClaudeCode.query
        XCTAssertTrue(true)  // Compilation is the test
    }

    // MARK: - QueryOptions with MCP Servers

    func testQueryOptions_WithMCPServers() {
        var options = QueryOptions()

        let externalServer = MCPServerConfig(command: "node", args: ["server.js"])
        options.mcpServers["test-server"] = externalServer

        let sdkServer = SDKMCPServer(name: "sdk-server", tools: [])
        options.sdkMcpServers["sdk-server"] = sdkServer

        XCTAssertEqual(options.mcpServers.count, 1)
        XCTAssertEqual(options.sdkMcpServers.count, 1)
        XCTAssertEqual(options.mcpServers["test-server"]?.command, "node")
        XCTAssertEqual(options.sdkMcpServers["sdk-server"]?.name, "sdk-server")
    }

    // MARK: - QueryOptions with Hooks

    func testQueryOptions_WithHooks() {
        var options = QueryOptions()

        options.preToolUseHooks.append(PreToolUseHookConfig { _ in HookOutput() })
        options.postToolUseHooks.append(PostToolUseHookConfig { _ in HookOutput() })
        options.postToolUseFailureHooks.append(PostToolUseFailureHookConfig { _ in HookOutput() })
        options.userPromptSubmitHooks.append(UserPromptSubmitHookConfig { _ in HookOutput() })
        options.stopHooks.append(StopHookConfig { _ in HookOutput() })

        XCTAssertEqual(options.preToolUseHooks.count, 1)
        XCTAssertEqual(options.postToolUseHooks.count, 1)
        XCTAssertEqual(options.postToolUseFailureHooks.count, 1)
        XCTAssertEqual(options.userPromptSubmitHooks.count, 1)
        XCTAssertEqual(options.stopHooks.count, 1)
    }

    // MARK: - QueryOptions with Permission Callback

    func testQueryOptions_WithPermissionCallback() async {
        var options = QueryOptions()

        actor CallTracker {
            var wasCalled = false
            func setCalled() { wasCalled = true }
        }
        let tracker = CallTracker()

        options.canUseTool = { _, _, _ in
            await tracker.setCalled()
            return .allowTool()
        }

        // Invoke the callback to verify it's set correctly
        let result = try? await options.canUseTool?("TestTool", [:], ToolPermissionContext())
        let wasCalled = await tracker.wasCalled

        XCTAssertTrue(wasCalled)
        if case .allow(_, _) = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected allow result")
        }
    }
}
