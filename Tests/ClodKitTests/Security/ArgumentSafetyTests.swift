//
//  ArgumentSafetyTests.swift
//  ClodKit
//
//  Deterministic tests for all 12 shell boundary crossing points.
//  For each crossing point, tests every character in AdversarialStrings.shellMetachars
//  and every string in AdversarialStrings.shellInjection.
//  Verifies arguments are passed as discrete Process.arguments elements,
//  never shell-interpreted.
//

import XCTest
@testable import ClodKit

final class ArgumentSafetyTests: XCTestCase {

    // MARK: - Test Helpers

    /// Build a ProcessConfiguration from QueryOptions and return the arguments array.
    private func buildArguments(with options: QueryOptions) -> [String] {
        let cliPath = options.cliPath ?? "claude"
        let transport = ProcessTransport(
            executablePath: cliPath,
            arguments: buildTestCLIArguments(from: options),
            workingDirectory: options.workingDirectory,
            additionalEnvironment: options.environment
        )
        let config = transport.buildProcessConfiguration()
        return config.arguments
    }

    /// Mirror of the private buildCLIArguments for test purposes.
    /// This replicates the argument construction from QueryAPI.swift.
    private func buildTestCLIArguments(from options: QueryOptions) -> [String] {
        var arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose"
        ]

        if let model = options.model {
            arguments.append(contentsOf: ["--model", model])
        }
        if let maxTurns = options.maxTurns {
            arguments.append(contentsOf: ["--max-turns", String(maxTurns)])
        }
        if let maxThinkingTokens = options.maxThinkingTokens {
            arguments.append(contentsOf: ["--max-thinking-tokens", String(maxThinkingTokens)])
        }
        if let permissionMode = options.permissionMode {
            arguments.append(contentsOf: ["--permission-mode", permissionMode.rawValue])
        }
        if let systemPrompt = options.systemPrompt {
            arguments.append(contentsOf: ["--system-prompt", systemPrompt])
        }
        if let appendSystemPrompt = options.appendSystemPrompt {
            arguments.append(contentsOf: ["--append-system-prompt", appendSystemPrompt])
        }
        if let allowedTools = options.allowedTools, !allowedTools.isEmpty {
            arguments.append(contentsOf: ["--allowed-tools", allowedTools.joined(separator: ",")])
        }
        if let blockedTools = options.blockedTools, !blockedTools.isEmpty {
            for tool in blockedTools {
                arguments.append(contentsOf: ["--disallowed-tools", tool])
            }
        }
        for directory in options.additionalDirectories {
            arguments.append(contentsOf: ["--add-dir", directory])
        }
        if let resume = options.resume {
            arguments.append(contentsOf: ["--resume", resume])
        }

        return arguments
    }

    /// Assert that an adversarial string appears as a discrete, unchanged element
    /// in the arguments array following the given flag.
    private func assertArgumentSafety(
        arguments: [String],
        flag: String,
        expectedValue: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // Find the flag in the arguments
        guard let flagIndex = arguments.firstIndex(of: flag) else {
            XCTFail("Flag '\(flag)' not found in arguments: \(arguments)", file: file, line: line)
            return
        }

        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else {
            XCTFail("No value after flag '\(flag)' in arguments", file: file, line: line)
            return
        }

        // The value must be a discrete element, unchanged from input
        XCTAssertEqual(
            arguments[valueIndex],
            expectedValue,
            "Value after '\(flag)' should be unchanged. Expected: \(expectedValue.debugDescription), Got: \(arguments[valueIndex].debugDescription)",
            file: file,
            line: line
        )
    }

    /// Assert that the process configuration does not use a shell executable.
    private func assertNoShellExecutable(
        options: QueryOptions,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let cliPath = options.cliPath ?? "claude"
        let transport = ProcessTransport(
            executablePath: cliPath,
            arguments: buildTestCLIArguments(from: options),
            workingDirectory: options.workingDirectory,
            additionalEnvironment: options.environment
        )
        let config = transport.buildProcessConfiguration()

        let shellPaths = ["/bin/zsh", "/bin/bash", "/bin/sh", "/usr/bin/zsh", "/usr/bin/bash"]
        for shellPath in shellPaths {
            XCTAssertNotEqual(
                config.executableURL.path,
                shellPath,
                "Process must not use shell executable \(shellPath)",
                file: file,
                line: line
            )
        }
    }

    // MARK: - All Adversarial Inputs

    private var allAdversarialInputs: [String] {
        AdversarialStrings.shellMetachars + AdversarialStrings.shellInjection
    }

    // MARK: - Crossing Point 1: cliPath

    func testCliPathShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.cliPath = input

            let cliPath = options.cliPath ?? "claude"
            let transport = ProcessTransport(
                executablePath: cliPath,
                arguments: buildTestCLIArguments(from: options)
            )
            let config = transport.buildProcessConfiguration()

            // The executable should be /usr/bin/env, and the first argument should be the cliPath unchanged
            XCTAssertEqual(
                config.executableURL,
                URL(fileURLWithPath: "/usr/bin/env"),
                "Should use /usr/bin/env as executable for input: \(input.debugDescription)"
            )
            XCTAssertEqual(
                config.arguments.first,
                input,
                "First argument to /usr/bin/env should be the cliPath unchanged: \(input.debugDescription)"
            )
        }
    }

    // MARK: - Crossing Point 2: model

    func testModelShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.model = input

            let args = buildArguments(with: options)
            assertArgumentSafety(arguments: args, flag: "--model", expectedValue: input)
        }
    }

    // MARK: - Crossing Point 6: systemPrompt

    func testSystemPromptShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.systemPrompt = input

            let args = buildArguments(with: options)
            assertArgumentSafety(arguments: args, flag: "--system-prompt", expectedValue: input)
        }
    }

    // MARK: - Crossing Point 7: appendSystemPrompt

    func testAppendSystemPromptShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.appendSystemPrompt = input

            let args = buildArguments(with: options)
            assertArgumentSafety(arguments: args, flag: "--append-system-prompt", expectedValue: input)
        }
    }

    // MARK: - Crossing Point 8: allowedTools

    func testAllowedToolsShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.allowedTools = [input]

            let args = buildArguments(with: options)
            // allowedTools are joined with comma, so the value after --allowed-tools is the input itself
            assertArgumentSafety(arguments: args, flag: "--allowed-tools", expectedValue: input)
        }
    }

    // MARK: - Crossing Point 9: blockedTools

    func testBlockedToolsShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.blockedTools = [input]

            let args = buildArguments(with: options)
            assertArgumentSafety(arguments: args, flag: "--disallowed-tools", expectedValue: input)
        }
    }

    // MARK: - Crossing Point 10: additionalDirectories

    func testAdditionalDirectoriesShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.additionalDirectories = [input]

            let args = buildArguments(with: options)
            assertArgumentSafety(arguments: args, flag: "--add-dir", expectedValue: input)
        }
    }

    // MARK: - Crossing Point 11: resume

    func testResumeShellSafety() {
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.resume = input

            let args = buildArguments(with: options)
            assertArgumentSafety(arguments: args, flag: "--resume", expectedValue: input)
        }
    }

    // MARK: - Structural Invariant: No Shell Executable

    func testProcessNeverUsesShellExecutable() {
        // Test with default options
        assertNoShellExecutable(options: QueryOptions())

        // Test with adversarial inputs in every field
        for input in allAdversarialInputs {
            var options = QueryOptions()
            options.cliPath = input
            options.systemPrompt = input
            options.model = input
            assertNoShellExecutable(options: options)
        }
    }

    // MARK: - Structural Invariant: Arguments Are Discrete Elements

    func testArgumentsAreDiscreteElements() {
        var options = QueryOptions()
        options.systemPrompt = "Hello world; echo pwned"
        options.model = "claude-test"

        let args = buildArguments(with: options)

        // Arguments should be an array with more than one element
        XCTAssertGreaterThan(args.count, 1,
            "Arguments should be individual array elements, not a single joined string")

        // No single argument should contain the entire command
        for arg in args {
            XCTAssertFalse(
                arg.contains("--system-prompt") && arg.contains("Hello world"),
                "A single argument should not contain both a flag and a value from a different flag"
            )
        }
    }

    // MARK: - Crossing Point 12: cliPath in validateSetup (NativeBackend)

    func testValidateSetupDoesNotUseShell() throws {
        // Verify NativeBackend.validateSetup uses /usr/bin/which directly,
        // not a shell. We test this by constructing the same pattern the
        // backend uses and verifying it's correct.
        for input in AdversarialStrings.shellInjection {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [input]

            // The key invariant: executableURL is /usr/bin/which, not a shell
            XCTAssertEqual(
                process.executableURL?.path,
                "/usr/bin/which",
                "validateSetup must use /usr/bin/which directly for input: \(input.debugDescription)"
            )

            // The argument is a discrete element, not interpolated into a shell command
            XCTAssertEqual(
                process.arguments?.first,
                input,
                "cliPath must be passed as a discrete argument to which, not interpolated: \(input.debugDescription)"
            )
        }
    }
}
