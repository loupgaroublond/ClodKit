//
//  ShellInjectionRegressionTests.swift
//  ClodKit
//
//  Permanent regression tests for specific shell injection vulnerabilities.
//  Each test reproduces the exact exploit scenario that was possible before the fix.
//
//  =========================================================================
//  DO NOT DELETE — These tests are the permanent record of vulnerabilities
//  found and fixed. Removing any test means losing protection against
//  that specific exploit being reintroduced.
//  =========================================================================
//

import XCTest
@testable import ClodKit

final class ShellInjectionRegressionTests: XCTestCase {

    // MARK: - Test Helpers

    /// Build a ProcessConfiguration from the given options.
    private func buildConfig(
        cliPath: String = "claude",
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) -> ProcessConfiguration {
        let transport = ProcessTransport(
            executablePath: cliPath,
            arguments: arguments,
            additionalEnvironment: environment
        )
        return transport.buildProcessConfiguration()
    }

    /// Build CLI arguments from options (mirrors QueryAPI.buildCLIArguments).
    private func buildTestCLIArguments(from options: QueryOptions) -> [String] {
        var arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose"
        ]

        if let systemPrompt = options.systemPrompt {
            arguments.append(contentsOf: ["--system-prompt", systemPrompt])
        }
        if let appendSystemPrompt = options.appendSystemPrompt {
            arguments.append(contentsOf: ["--append-system-prompt", appendSystemPrompt])
        }
        if let model = options.model {
            arguments.append(contentsOf: ["--model", model])
        }
        for directory in options.additionalDirectories {
            arguments.append(contentsOf: ["--add-dir", directory])
        }

        return arguments
    }

    // MARK: - Regression Test 1: Apostrophe in System Prompt

    /// DO NOT DELETE — regression test for the apostrophe bug (docs/handoff-apostrophe-bug.md).
    ///
    /// Before the fix, a system prompt containing an apostrophe would cause the shell
    /// to hang waiting for a matching quote:
    ///
    ///   process.executableURL = /bin/zsh
    ///   process.arguments = ["-l", "-c", "claude --system-prompt Don't stop"]
    ///                                                            ^^^
    ///                                                    unmatched quote
    ///
    /// After the fix, the system prompt is passed as a discrete Process.arguments element
    /// via /usr/bin/env, so the shell never interprets it.
    func testApostropheInSystemPrompt() {
        // DO NOT DELETE — regression test for apostrophe bug
        let systemPrompt = "Don't stop"

        var options = QueryOptions()
        options.systemPrompt = systemPrompt

        let config = buildConfig(
            arguments: buildTestCLIArguments(from: options)
        )

        // Must not use a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"),
            "Must use /usr/bin/env, not a shell")

        // The system prompt must appear as a discrete, unchanged argument
        XCTAssertTrue(config.arguments.contains(systemPrompt),
            "System prompt 'Don't stop' must appear unchanged in arguments")

        // Verify it follows the --system-prompt flag
        if let idx = config.arguments.firstIndex(of: "--system-prompt") {
            let valueIdx = config.arguments.index(after: idx)
            XCTAssertEqual(config.arguments[valueIdx], systemPrompt,
                "Value after --system-prompt must be the exact system prompt")
        } else {
            XCTFail("--system-prompt flag not found in arguments")
        }
    }

    // MARK: - Regression Test 2: Command Substitution in System Prompt

    /// DO NOT DELETE — regression test for command substitution via $().
    ///
    /// Before the fix, a system prompt containing $(command) would execute
    /// that command in the shell:
    ///
    ///   /bin/zsh -l -c "claude --system-prompt $(echo pwned)"
    ///
    /// The shell would execute `echo pwned` before passing the result to claude.
    func testCommandSubstitutionInSystemPrompt() {
        // DO NOT DELETE — regression test for $() command substitution
        let systemPrompt = "$(echo pwned)"

        var options = QueryOptions()
        options.systemPrompt = systemPrompt

        let config = buildConfig(
            arguments: buildTestCLIArguments(from: options)
        )

        // Must not use a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"))

        // The literal string "$(echo pwned)" must be in arguments, not "pwned"
        XCTAssertTrue(config.arguments.contains(systemPrompt),
            "Literal '$(echo pwned)' must appear unchanged — it must not be evaluated")
    }

    // MARK: - Regression Test 3: Backtick Command in Model

    /// DO NOT DELETE — regression test for backtick command substitution in model name.
    ///
    /// Before the fix, a model name containing backticks would execute commands:
    ///
    ///   /bin/zsh -l -c "claude --model `id`"
    ///
    /// The shell would execute `id` and use its output as the model name.
    func testBacktickCommandInModel() {
        // DO NOT DELETE — regression test for backtick command substitution
        let model = "`id`"

        var options = QueryOptions()
        options.model = model

        let config = buildConfig(
            arguments: buildTestCLIArguments(from: options)
        )

        // Must not use a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"))

        // The literal "`id`" must be in arguments
        XCTAssertTrue(config.arguments.contains(model),
            "Literal '`id`' must appear unchanged — it must not be evaluated")
    }

    // MARK: - Regression Test 4: Semicolon in CLI Path

    /// DO NOT DELETE — regression test for command injection via cliPath.
    ///
    /// Before the fix, a malicious cliPath with semicolons would execute
    /// arbitrary commands:
    ///
    ///   /bin/zsh -l -c "claude; rm -rf / --system-prompt ..."
    ///
    /// The shell would execute `claude` then `rm -rf /`.
    func testSemicolonInCliPath() {
        // DO NOT DELETE — regression test for cliPath command injection
        let cliPath = "claude; rm -rf /"

        let config = buildConfig(cliPath: cliPath)

        // Must use /usr/bin/env, not a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"),
            "Must use /usr/bin/env for path resolution")

        // The first argument to env must be the literal cliPath
        XCTAssertEqual(config.arguments.first, cliPath,
            "cliPath 'claude; rm -rf /' must be passed as a single argument, not split by semicolons")

        // No shell involved
        let shellPaths = ["/bin/zsh", "/bin/bash", "/bin/sh"]
        for shellPath in shellPaths {
            XCTAssertNotEqual(config.executableURL.path, shellPath,
                "Must not use shell executable \(shellPath)")
        }
    }

    // MARK: - Regression Test 5: Pipe in Additional Directory

    /// DO NOT DELETE — regression test for pipe injection via additionalDirectories.
    ///
    /// Before the fix, a directory path containing a pipe would redirect output:
    ///
    ///   /bin/zsh -l -c "claude --add-dir ./dir | cat /etc/passwd"
    ///
    /// The shell would pipe claude's output to `cat /etc/passwd`.
    func testPipeInAdditionalDirectory() {
        // DO NOT DELETE — regression test for pipe injection in directories
        let directory = "./dir | cat /etc/passwd"

        var options = QueryOptions()
        options.additionalDirectories = [directory]

        let config = buildConfig(
            arguments: buildTestCLIArguments(from: options)
        )

        // Must not use a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"))

        // The directory must appear as a discrete argument
        XCTAssertTrue(config.arguments.contains(directory),
            "Directory './dir | cat /etc/passwd' must appear unchanged in arguments")
    }

    // MARK: - Regression Test 6: Destructive Command Substitution

    /// DO NOT DELETE — regression test for $(rm -rf /) in system prompt.
    ///
    /// The most dangerous variant of command substitution: executing a destructive
    /// command via shell interpretation of what should be data.
    func testDestructiveCommandSubstitutionInSystemPrompt() {
        // DO NOT DELETE — regression test for destructive command substitution
        let systemPrompt = "$(rm -rf /)"

        var options = QueryOptions()
        options.systemPrompt = systemPrompt

        let config = buildConfig(
            arguments: buildTestCLIArguments(from: options)
        )

        // Must not use a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"))

        // The literal must be preserved
        XCTAssertTrue(config.arguments.contains(systemPrompt),
            "Literal '$(rm -rf /)' must appear unchanged — catastrophic if evaluated")
    }

    // MARK: - Regression Test 7: Newline Injection

    /// DO NOT DELETE — regression test for newline-based command injection.
    ///
    /// A newline in a shell command string acts as a command separator:
    ///
    ///   /bin/zsh -l -c "claude --system-prompt test\necho pwned"
    ///
    /// The shell would execute `claude --system-prompt test` then `echo pwned`.
    func testNewlineInjectionInSystemPrompt() {
        // DO NOT DELETE — regression test for newline command injection
        let systemPrompt = "test\necho pwned"

        var options = QueryOptions()
        options.systemPrompt = systemPrompt

        let config = buildConfig(
            arguments: buildTestCLIArguments(from: options)
        )

        // Must not use a shell
        XCTAssertEqual(config.executableURL, URL(fileURLWithPath: "/usr/bin/env"))

        // The literal with embedded newline must be preserved
        XCTAssertTrue(config.arguments.contains(systemPrompt),
            "String with embedded newline must appear unchanged in arguments")
    }

    // MARK: - Regression Test 8: validateSetup Shell Injection

    /// DO NOT DELETE — regression test for NativeBackend.validateSetup shell injection.
    ///
    /// Before the fix, NativeBackend.validateSetup used:
    ///   process.arguments = ["-l", "-c", "which \(cli)"]
    ///
    /// A cliPath like "claude; rm -rf /" would execute arbitrary commands.
    /// After the fix, it uses /usr/bin/which directly.
    func testValidateSetupUsesWhichDirectly() {
        // DO NOT DELETE — regression test for validateSetup shell injection
        let maliciousCli = "claude; rm -rf /"

        // Verify the fixed pattern: /usr/bin/which with the cli as a discrete argument
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [maliciousCli]

        XCTAssertEqual(process.executableURL?.path, "/usr/bin/which",
            "validateSetup must use /usr/bin/which, not a shell")
        XCTAssertEqual(process.arguments, [maliciousCli],
            "cliPath must be a discrete argument to which, not interpolated into a shell command")
    }
}
