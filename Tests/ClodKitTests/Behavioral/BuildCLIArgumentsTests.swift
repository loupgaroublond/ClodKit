//
//  BuildCLIArgumentsTests.swift
//  ClodKitTests
//
//  Tests for buildCLIArguments option branches and NativeBackend.applyDefaultOptions.
//

import XCTest
@testable import ClodKit

final class BuildCLIArgumentsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Default Arguments

    func testDefaultArguments() {
        let opts = QueryOptions()
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("-p"))
        XCTAssertTrue(args.contains("--output-format"))
        XCTAssertTrue(args.contains("stream-json"))
        XCTAssertTrue(args.contains("--input-format"))
        XCTAssertTrue(args.contains("--verbose"))
    }

    // MARK: - Agent Option

    func testAgentOption() {
        var opts = QueryOptions()
        opts.agent = "my-agent"
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--agent"))
        XCTAssertTrue(args.contains("my-agent"))
    }

    // MARK: - No Persist

    func testPersistSessionFalse() {
        var opts = QueryOptions()
        opts.persistSession = false
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--no-persist"))
    }

    func testPersistSessionTrue_NoFlag() {
        var opts = QueryOptions()
        opts.persistSession = true
        let args = buildCLIArguments(from: opts)
        XCTAssertFalse(args.contains("--no-persist"))
    }

    // MARK: - Session ID

    func testSessionId() {
        var opts = QueryOptions()
        opts.sessionId = "sess-123"
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--session-id"))
        XCTAssertTrue(args.contains("sess-123"))
    }

    // MARK: - Debug Options

    func testDebugFlag() {
        var opts = QueryOptions()
        opts.debug = true
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--debug"))
    }

    func testDebugFile() {
        var opts = QueryOptions()
        opts.debugFile = "/tmp/debug.log"
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--debug-file"))
        XCTAssertTrue(args.contains("/tmp/debug.log"))
    }

    // MARK: - Max Budget

    func testMaxBudgetUsd() {
        var opts = QueryOptions()
        opts.maxBudgetUsd = 10.5
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--max-budget-usd"))
        XCTAssertTrue(args.contains("10.5"))
    }

    // MARK: - Fork Session

    func testForkSession() {
        var opts = QueryOptions()
        opts.forkSession = true
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--fork-session"))
    }

    // MARK: - File Checkpointing

    func testEnableFileCheckpointing() {
        var opts = QueryOptions()
        opts.enableFileCheckpointing = true
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--enable-file-checkpointing"))
    }

    // MARK: - Continue Conversation

    func testContinueConversation() {
        var opts = QueryOptions()
        opts.continueConversation = true
        let args = buildCLIArguments(from: opts)
        XCTAssertTrue(args.contains("--continue"))
    }

    // MARK: - Betas

    func testBetas() {
        var opts = QueryOptions()
        opts.betas = ["beta1", "beta2"]
        let args = buildCLIArguments(from: opts)
        // Each beta gets its own --beta flag
        let betaCount = args.filter { $0 == "--beta" }.count
        XCTAssertEqual(betaCount, 2)
        XCTAssertTrue(args.contains("beta1"))
        XCTAssertTrue(args.contains("beta2"))
    }

    // MARK: - All Options Together

    func testAllOptionsCombined() {
        var opts = QueryOptions()
        opts.model = "claude-sonnet-4-20250514"
        opts.maxTurns = 5
        opts.maxThinkingTokens = 1000
        opts.permissionMode = .default
        opts.canUseTool = { _, _, _ in .allow() }
        opts.systemPrompt = "Be helpful"
        opts.appendSystemPrompt = "Extra"
        opts.allowedTools = ["Bash", "Read"]
        opts.blockedTools = ["Write"]
        opts.additionalDirectories = ["/tmp"]
        opts.resume = "sess-old"
        opts.agent = "test-agent"
        opts.persistSession = false
        opts.sessionId = "sess-new"
        opts.debug = true
        opts.debugFile = "/tmp/dbg.log"
        opts.maxBudgetUsd = 5.0
        opts.forkSession = true
        opts.enableFileCheckpointing = true
        opts.continueConversation = true
        opts.betas = ["b1"]

        let args = buildCLIArguments(from: opts)

        XCTAssertTrue(args.contains("--model"))
        XCTAssertTrue(args.contains("claude-sonnet-4-20250514"))
        XCTAssertTrue(args.contains("--max-turns"))
        XCTAssertTrue(args.contains("5"))
        XCTAssertTrue(args.contains("--max-thinking-tokens"))
        XCTAssertTrue(args.contains("1000"))
        XCTAssertTrue(args.contains("--permission-mode"))
        XCTAssertTrue(args.contains("default"))
        XCTAssertTrue(args.contains("--permission-prompt-tool"))
        XCTAssertTrue(args.contains("stdio"))
        XCTAssertTrue(args.contains("--system-prompt"))
        XCTAssertTrue(args.contains("Be helpful"))
        XCTAssertTrue(args.contains("--append-system-prompt"))
        XCTAssertTrue(args.contains("Extra"))
        XCTAssertTrue(args.contains("--allowed-tools"))
        XCTAssertTrue(args.contains("Bash,Read"))
        XCTAssertTrue(args.contains("--disallowed-tools"))
        XCTAssertTrue(args.contains("Write"))
        XCTAssertTrue(args.contains("--add-dir"))
        XCTAssertTrue(args.contains("/tmp"))
        XCTAssertTrue(args.contains("--resume"))
        XCTAssertTrue(args.contains("sess-old"))
        XCTAssertTrue(args.contains("--agent"))
        XCTAssertTrue(args.contains("test-agent"))
        XCTAssertTrue(args.contains("--no-persist"))
        XCTAssertTrue(args.contains("--session-id"))
        XCTAssertTrue(args.contains("sess-new"))
        XCTAssertTrue(args.contains("--debug"))
        XCTAssertTrue(args.contains("--debug-file"))
        XCTAssertTrue(args.contains("/tmp/dbg.log"))
        XCTAssertTrue(args.contains("--max-budget-usd"))
        XCTAssertTrue(args.contains("5.0"))
        XCTAssertTrue(args.contains("--fork-session"))
        XCTAssertTrue(args.contains("--enable-file-checkpointing"))
        XCTAssertTrue(args.contains("--continue"))
        XCTAssertTrue(args.contains("--beta"))
        XCTAssertTrue(args.contains("b1"))
    }
}

// MARK: - NativeBackend applyDefaultOptions Tests

final class NativeBackendApplyDefaultOptionsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testApplyDefaultOptions_SetsCliPath() {
        let backend = NativeBackend(cliPath: "/custom/claude")
        var opts = QueryOptions()
        XCTAssertNil(opts.cliPath)
        backend.applyDefaultOptions(&opts)
        XCTAssertEqual(opts.cliPath, "/custom/claude")
    }

    func testApplyDefaultOptions_DoesNotOverrideCliPath() {
        let backend = NativeBackend(cliPath: "/custom/claude")
        var opts = QueryOptions()
        opts.cliPath = "/user/claude"
        backend.applyDefaultOptions(&opts)
        XCTAssertEqual(opts.cliPath, "/user/claude")
    }

    func testApplyDefaultOptions_SetsWorkingDirectory() {
        let dir = URL(fileURLWithPath: "/tmp/work")
        let backend = NativeBackend(workingDirectory: dir)
        var opts = QueryOptions()
        XCTAssertNil(opts.workingDirectory)
        backend.applyDefaultOptions(&opts)
        XCTAssertEqual(opts.workingDirectory, dir)
    }

    func testApplyDefaultOptions_SetsLogger() {
        let backend = NativeBackend(enableLogging: true)
        var opts = QueryOptions()
        XCTAssertNil(opts.logger)
        backend.applyDefaultOptions(&opts)
        XCTAssertNotNil(opts.logger)
    }

    func testApplyDefaultOptions_MergesEnvironment_NoOverride() {
        let backend = NativeBackend(environment: ["KEY_A": "from_backend", "KEY_B": "from_backend"])
        var opts = QueryOptions()
        opts.environment["KEY_A"] = "from_opts"
        backend.applyDefaultOptions(&opts)
        // Existing key should NOT be overridden
        XCTAssertEqual(opts.environment["KEY_A"], "from_opts")
        // Missing key should be added
        XCTAssertEqual(opts.environment["KEY_B"], "from_backend")
    }

    func testApplyDefaultOptions_AllFields() {
        let dir = URL(fileURLWithPath: "/work")
        let backend = NativeBackend(
            cliPath: "/bin/claude",
            workingDirectory: dir,
            environment: ["E1": "v1", "E2": "v2"],
            enableLogging: true
        )
        var opts = QueryOptions()
        opts.environment["E1"] = "existing"

        backend.applyDefaultOptions(&opts)

        XCTAssertEqual(opts.cliPath, "/bin/claude")
        XCTAssertEqual(opts.workingDirectory, dir)
        XCTAssertNotNil(opts.logger)
        XCTAssertEqual(opts.environment["E1"], "existing") // not overridden
        XCTAssertEqual(opts.environment["E2"], "v2") // merged
    }
}
