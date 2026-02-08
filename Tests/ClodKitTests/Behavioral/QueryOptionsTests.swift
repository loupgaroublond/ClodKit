//
//  QueryOptionsTests.swift
//  ClodKitTests
//
//  Behavioral tests for QueryOptions field existence and defaults (Bead dul).
//

import XCTest
@testable import ClodKit

final class QueryOptionsTests: XCTestCase {

    // MARK: - All Fields Exist

    func testModelFieldExists() {
        var options = QueryOptions()
        options.model = "claude-sonnet-4"
        XCTAssertEqual(options.model, "claude-sonnet-4")
    }

    func testMaxTurnsFieldExists() {
        var options = QueryOptions()
        options.maxTurns = 10
        XCTAssertEqual(options.maxTurns, 10)
    }

    func testMaxThinkingTokensFieldExists() {
        var options = QueryOptions()
        options.maxThinkingTokens = 5000
        XCTAssertEqual(options.maxThinkingTokens, 5000)
    }

    func testPermissionModeFieldExists() {
        var options = QueryOptions()
        options.permissionMode = .delegate
        XCTAssertEqual(options.permissionMode, .delegate)
    }

    func testSystemPromptFieldExists() {
        var options = QueryOptions()
        options.systemPrompt = "Custom prompt"
        XCTAssertEqual(options.systemPrompt, "Custom prompt")
    }

    func testAppendSystemPromptFieldExists() {
        var options = QueryOptions()
        options.appendSystemPrompt = "Additional instructions"
        XCTAssertEqual(options.appendSystemPrompt, "Additional instructions")
    }

    func testWorkingDirectoryFieldExists() {
        var options = QueryOptions()
        let url = URL(fileURLWithPath: "/tmp")
        options.workingDirectory = url
        XCTAssertEqual(options.workingDirectory, url)
    }

    func testEnvironmentFieldExists() {
        var options = QueryOptions()
        options.environment = ["KEY": "value"]
        XCTAssertEqual(options.environment, ["KEY": "value"])
    }

    func testCliPathFieldExists() {
        var options = QueryOptions()
        options.cliPath = "/usr/local/bin/claude"
        XCTAssertEqual(options.cliPath, "/usr/local/bin/claude")
    }

    func testAllowedToolsFieldExists() {
        var options = QueryOptions()
        options.allowedTools = ["Bash", "Read"]
        XCTAssertEqual(options.allowedTools, ["Bash", "Read"])
    }

    func testBlockedToolsFieldExists() {
        var options = QueryOptions()
        options.blockedTools = ["Write", "Edit"]
        XCTAssertEqual(options.blockedTools, ["Write", "Edit"])
    }

    func testAdditionalDirectoriesFieldExists() {
        var options = QueryOptions()
        options.additionalDirectories = ["/tmp", "/var"]
        XCTAssertEqual(options.additionalDirectories, ["/tmp", "/var"])
    }

    func testResumeFieldExists() {
        var options = QueryOptions()
        options.resume = "session-123"
        XCTAssertEqual(options.resume, "session-123")
    }

    func testAgentFieldExists() {
        var options = QueryOptions()
        options.agent = "my-agent"
        XCTAssertEqual(options.agent, "my-agent")
    }

    func testPersistSessionFieldExists() {
        var options = QueryOptions()
        options.persistSession = false
        XCTAssertEqual(options.persistSession, false)
    }

    func testSessionIdFieldExists() {
        var options = QueryOptions()
        options.sessionId = "custom-session-id"
        XCTAssertEqual(options.sessionId, "custom-session-id")
    }

    func testDebugFieldExists() {
        var options = QueryOptions()
        options.debug = true
        XCTAssertEqual(options.debug, true)
    }

    func testDebugFileFieldExists() {
        var options = QueryOptions()
        options.debugFile = "/tmp/debug.log"
        XCTAssertEqual(options.debugFile, "/tmp/debug.log")
    }

    func testMaxBudgetUsdFieldExists() {
        var options = QueryOptions()
        options.maxBudgetUsd = 5.0
        XCTAssertEqual(options.maxBudgetUsd, 5.0)
    }

    func testForkSessionFieldExists() {
        var options = QueryOptions()
        options.forkSession = true
        XCTAssertEqual(options.forkSession, true)
    }

    func testEnableFileCheckpointingFieldExists() {
        var options = QueryOptions()
        options.enableFileCheckpointing = true
        XCTAssertEqual(options.enableFileCheckpointing, true)
    }

    func testContinueConversationFieldExists() {
        var options = QueryOptions()
        options.continueConversation = true
        XCTAssertEqual(options.continueConversation, true)
    }

    func testBetasFieldExists() {
        var options = QueryOptions()
        options.betas = ["beta-1", "beta-2"]
        XCTAssertEqual(options.betas, ["beta-1", "beta-2"])
    }

    func testOutputFormatFieldExists() {
        var options = QueryOptions()
        let format = OutputFormat(schema: .object([:]))
        options.outputFormat = format
        XCTAssertEqual(options.outputFormat, format)
    }

    func testMcpServersFieldExists() {
        var options = QueryOptions()
        options.mcpServers = ["server1": MCPServerConfig(command: "cmd")]
        XCTAssertEqual(options.mcpServers.count, 1)
    }

    func testCanUseToolFieldExists() {
        var options = QueryOptions()
        let callback: CanUseToolCallback = { _, _, _ in .allow() }
        options.canUseTool = callback
        XCTAssertNotNil(options.canUseTool)
    }

    func testSpawnClaudeCodeProcessFieldExists() {
        var options = QueryOptions()
        let spawn: SpawnFunction = { _ in throw QueryError.invalidOptions("test") }
        options.spawnClaudeCodeProcess = spawn
        XCTAssertNotNil(options.spawnClaudeCodeProcess)
    }

    func testStderrHandlerFieldExists() {
        var options = QueryOptions()
        let handler: @Sendable (String) -> Void = { _ in }
        options.stderrHandler = handler
        XCTAssertNotNil(options.stderrHandler)
    }

    // MARK: - Hook Config Arrays

    func testPreToolUseHooksFieldExists() {
        var options = QueryOptions()
        options.preToolUseHooks = []
        XCTAssertEqual(options.preToolUseHooks.count, 0)
    }

    func testPostToolUseHooksFieldExists() {
        var options = QueryOptions()
        options.postToolUseHooks = []
        XCTAssertEqual(options.postToolUseHooks.count, 0)
    }

    func testPostToolUseFailureHooksFieldExists() {
        var options = QueryOptions()
        options.postToolUseFailureHooks = []
        XCTAssertEqual(options.postToolUseFailureHooks.count, 0)
    }

    func testUserPromptSubmitHooksFieldExists() {
        var options = QueryOptions()
        options.userPromptSubmitHooks = []
        XCTAssertEqual(options.userPromptSubmitHooks.count, 0)
    }

    func testStopHooksFieldExists() {
        var options = QueryOptions()
        options.stopHooks = []
        XCTAssertEqual(options.stopHooks.count, 0)
    }

    func testSetupHooksFieldExists() {
        var options = QueryOptions()
        options.setupHooks = []
        XCTAssertEqual(options.setupHooks.count, 0)
    }

    func testTeammateIdleHooksFieldExists() {
        var options = QueryOptions()
        options.teammateIdleHooks = []
        XCTAssertEqual(options.teammateIdleHooks.count, 0)
    }

    func testTaskCompletedHooksFieldExists() {
        var options = QueryOptions()
        options.taskCompletedHooks = []
        XCTAssertEqual(options.taskCompletedHooks.count, 0)
    }

    func testSessionStartHooksFieldExists() {
        var options = QueryOptions()
        options.sessionStartHooks = []
        XCTAssertEqual(options.sessionStartHooks.count, 0)
    }

    func testSessionEndHooksFieldExists() {
        var options = QueryOptions()
        options.sessionEndHooks = []
        XCTAssertEqual(options.sessionEndHooks.count, 0)
    }

    func testSubagentStartHooksFieldExists() {
        var options = QueryOptions()
        options.subagentStartHooks = []
        XCTAssertEqual(options.subagentStartHooks.count, 0)
    }

    func testSubagentStopHooksFieldExists() {
        var options = QueryOptions()
        options.subagentStopHooks = []
        XCTAssertEqual(options.subagentStopHooks.count, 0)
    }

    func testPreCompactHooksFieldExists() {
        var options = QueryOptions()
        options.preCompactHooks = []
        XCTAssertEqual(options.preCompactHooks.count, 0)
    }

    func testPermissionRequestHooksFieldExists() {
        var options = QueryOptions()
        options.permissionRequestHooks = []
        XCTAssertEqual(options.permissionRequestHooks.count, 0)
    }

    func testNotificationHooksFieldExists() {
        var options = QueryOptions()
        options.notificationHooks = []
        XCTAssertEqual(options.notificationHooks.count, 0)
    }

    // MARK: - Default Values

    func testDefaultPermissionModeIsNil() {
        let options = QueryOptions()
        XCTAssertNil(options.permissionMode)
    }

    func testDefaultDebugIsFalse() {
        let options = QueryOptions()
        XCTAssertFalse(options.debug)
    }

    func testDefaultPersistSessionIsTrue() {
        let options = QueryOptions()
        XCTAssertTrue(options.persistSession)
    }

    func testDefaultForkSessionIsFalse() {
        let options = QueryOptions()
        XCTAssertFalse(options.forkSession)
    }

    func testDefaultEnableFileCheckpointingIsFalse() {
        let options = QueryOptions()
        XCTAssertFalse(options.enableFileCheckpointing)
    }

    func testDefaultContinueConversationIsFalse() {
        let options = QueryOptions()
        XCTAssertFalse(options.continueConversation)
    }

    func testDefaultEnvironmentIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.environment.isEmpty)
    }

    func testDefaultAdditionalDirectoriesIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.additionalDirectories.isEmpty)
    }

    func testDefaultBetasIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.betas.isEmpty)
    }

    func testDefaultMcpServersIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.mcpServers.isEmpty)
    }

    func testDefaultSdkMcpServersIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.sdkMcpServers.isEmpty)
    }

    func testDefaultPreToolUseHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.preToolUseHooks.isEmpty)
    }

    func testDefaultPostToolUseHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.postToolUseHooks.isEmpty)
    }

    func testDefaultPostToolUseFailureHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.postToolUseFailureHooks.isEmpty)
    }

    func testDefaultUserPromptSubmitHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.userPromptSubmitHooks.isEmpty)
    }

    func testDefaultStopHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.stopHooks.isEmpty)
    }

    func testDefaultSetupHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.setupHooks.isEmpty)
    }

    func testDefaultTeammateIdleHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.teammateIdleHooks.isEmpty)
    }

    func testDefaultTaskCompletedHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.taskCompletedHooks.isEmpty)
    }

    func testDefaultSessionStartHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.sessionStartHooks.isEmpty)
    }

    func testDefaultSessionEndHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.sessionEndHooks.isEmpty)
    }

    func testDefaultSubagentStartHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.subagentStartHooks.isEmpty)
    }

    func testDefaultSubagentStopHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.subagentStopHooks.isEmpty)
    }

    func testDefaultPreCompactHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.preCompactHooks.isEmpty)
    }

    func testDefaultPermissionRequestHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.permissionRequestHooks.isEmpty)
    }

    func testDefaultNotificationHooksIsEmpty() {
        let options = QueryOptions()
        XCTAssertTrue(options.notificationHooks.isEmpty)
    }
}
