//
//  ArgumentSafetyPropertyTests.swift
//  ClodKit
//
//  Property-based tests for shell boundary crossing points.
//  Uses PropertyTest.forAll with AdversarialStringGenerator to test
//  random inputs across all string-typed QueryOptions fields.
//  Each test runs 1000 iterations with seed 42 for reproducibility.
//

import XCTest
@testable import ClodKit

final class ArgumentSafetyPropertyTests: XCTestCase {

    // MARK: - Test Helpers

    /// Build CLI arguments from options (mirrors QueryAPI.buildCLIArguments).
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

    /// Build ProcessConfiguration and return the arguments array.
    private func buildArguments(cliPath: String = "claude", cliArguments: [String]) -> [String] {
        let transport = ProcessTransport(
            executablePath: cliPath,
            arguments: cliArguments
        )
        return transport.buildProcessConfiguration().arguments
    }

    /// Assert that a value appears as a discrete, unchanged argument after a flag.
    private func assertContainsDiscreteArgument(
        _ arguments: [String],
        flag: String,
        value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let flagIndex = arguments.firstIndex(of: flag) else {
            XCTFail("Flag '\(flag)' not found in arguments", file: file, line: line)
            return
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else {
            XCTFail("No value after flag '\(flag)'", file: file, line: line)
            return
        }
        XCTAssertEqual(arguments[valueIndex], value,
            "Value after '\(flag)' must be unchanged from input", file: file, line: line)
    }

    // MARK: - Property: systemPrompt

    func testSystemPromptPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.systemPrompt = input
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--system-prompt"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "systemPrompt not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "systemPrompt property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: appendSystemPrompt

    func testAppendSystemPromptPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.appendSystemPrompt = input
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--append-system-prompt"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "appendSystemPrompt not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "appendSystemPrompt property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: model

    func testModelPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.model = input
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--model"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "model not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "model property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: cliPath

    func testCliPathPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            let transport = ProcessTransport(executablePath: input, arguments: ["-p"])
            let config = transport.buildProcessConfiguration()

            // Must use /usr/bin/env
            guard config.executableURL == URL(fileURLWithPath: "/usr/bin/env") else {
                throw PropertyTestFailure(message: "Must use /usr/bin/env, got \(config.executableURL)")
            }
            // First argument must be the cliPath unchanged
            guard config.arguments.first == input else {
                throw PropertyTestFailure(message: "cliPath not preserved as first argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "cliPath property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: resume

    func testResumePropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.resume = input
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--resume"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "resume not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "resume property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: additionalDirectories

    func testAdditionalDirectoriesPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.additionalDirectories = [input]
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--add-dir"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "additionalDirectory not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "additionalDirectories property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: allowedTools

    func testAllowedToolsPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.allowedTools = [input]
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--allowed-tools"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "allowedTools not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "allowedTools property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: blockedTools

    func testBlockedToolsPropertySafety() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            var options = QueryOptions()
            options.blockedTools = [input]
            let args = self.buildArguments(cliArguments: self.buildTestCLIArguments(from: options))
            guard let idx = args.firstIndex(of: "--disallowed-tools"),
                  idx + 1 < args.count,
                  args[idx + 1] == input else {
                throw PropertyTestFailure(message: "blockedTools not preserved as discrete argument")
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "blockedTools property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Property: No Shell Executable (structural)

    func testNoShellExecutableProperty() {
        let gen = AdversarialStringGenerator(mode: .shellFocused)
        let failures = PropertyTest.forAll(iterations: 1000, seed: 42, generator: { rng in
            gen.generate(using: &rng)
        }, property: { input in
            let transport = ProcessTransport(executablePath: input, arguments: ["-p"])
            let config = transport.buildProcessConfiguration()

            let shellPaths = ["/bin/zsh", "/bin/bash", "/bin/sh", "/usr/bin/zsh", "/usr/bin/bash"]
            for shellPath in shellPaths {
                guard config.executableURL.path != shellPath else {
                    throw PropertyTestFailure(message: "Used shell executable \(shellPath)")
                }
            }
        })
        XCTAssertTrue(failures.isEmpty,
            "No-shell property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }
}

// MARK: - Helper Error

/// Simple error for property test assertions.
private struct PropertyTestFailure: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
