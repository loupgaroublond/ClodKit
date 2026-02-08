//
//  CustomSpawnTests.swift
//  ClodKitTests
//
//  Behavioral tests for SpawnedProcess protocol and SpawnOptions (Bead z1e).
//

import XCTest
@testable import ClodKit

final class CustomSpawnTests: XCTestCase {

    // MARK: - SpawnedProcess Protocol

    func testSpawnedProcessProtocolSatisfiableByMock() {
        let mockProcess = MockSpawnedProcess()
        let _: any SpawnedProcess = mockProcess

        XCTAssertNotNil(mockProcess.exitCode)
        XCTAssertFalse(mockProcess.isKilled)
    }

    func testSpawnedProcessHasExitCodeProperty() {
        let process = MockSpawnedProcess()
        XCTAssertNil(process.exitCode)

        process.mockExitCode = 0
        XCTAssertEqual(process.exitCode, 0)

        process.mockExitCode = 1
        XCTAssertEqual(process.exitCode, 1)
    }

    func testSpawnedProcessHasIsKilledProperty() {
        let process = MockSpawnedProcess()
        XCTAssertFalse(process.isKilled)

        process.mockIsKilled = true
        XCTAssertTrue(process.isKilled)
    }

    func testSpawnedProcessHasKillMethod() {
        let process = MockSpawnedProcess()
        let result = process.kill(signal: 15) // SIGTERM

        XCTAssertTrue(result)
        XCTAssertEqual(process.lastKillSignal, 15)
    }

    func testSpawnedProcessKillCanFail() {
        let process = MockSpawnedProcess()
        process.killShouldFail = true

        let result = process.kill(signal: 9) // SIGKILL
        XCTAssertFalse(result)
    }

    func testMultipleSpawnedProcessInstancesAreIndependent() {
        let process1 = MockSpawnedProcess()
        let process2 = MockSpawnedProcess()

        process1.mockExitCode = 0
        process2.mockExitCode = 1

        XCTAssertNotEqual(process1.exitCode, process2.exitCode)

        _ = process1.kill(signal: 15)
        process1.mockIsKilled = true

        XCTAssertTrue(process1.isKilled)
        XCTAssertFalse(process2.isKilled)
    }

    // MARK: - SpawnOptions Fields

    func testSpawnOptionsHasCommandField() {
        let options = SpawnOptions(command: "/usr/bin/claude")
        XCTAssertEqual(options.command, "/usr/bin/claude")
    }

    func testSpawnOptionsHasArgsField() {
        let options = SpawnOptions(command: "claude", args: ["--version", "--debug"])
        XCTAssertEqual(options.args, ["--version", "--debug"])
    }

    func testSpawnOptionsHasCwdField() {
        let options = SpawnOptions(command: "claude", cwd: "/home/user/project")
        XCTAssertEqual(options.cwd, "/home/user/project")
    }

    func testSpawnOptionsHasEnvField() {
        let options = SpawnOptions(
            command: "claude",
            env: ["PATH": "/usr/bin", "HOME": "/home/user"]
        )
        XCTAssertEqual(options.env["PATH"], "/usr/bin")
        XCTAssertEqual(options.env["HOME"], "/home/user")
    }

    func testSpawnOptionsDefaultArgs() {
        let options = SpawnOptions(command: "claude")
        XCTAssertTrue(options.args.isEmpty)
    }

    func testSpawnOptionsDefaultCwd() {
        let options = SpawnOptions(command: "claude")
        XCTAssertNil(options.cwd)
    }

    func testSpawnOptionsDefaultEnv() {
        let options = SpawnOptions(command: "claude")
        XCTAssertTrue(options.env.isEmpty)
    }

    func testSpawnOptionsComprehensive() {
        let options = SpawnOptions(
            command: "/usr/local/bin/claude",
            args: ["--model", "claude-sonnet-4", "--debug"],
            cwd: "/projects/test",
            env: ["DEBUG": "1", "LOG_LEVEL": "trace"]
        )

        XCTAssertEqual(options.command, "/usr/local/bin/claude")
        XCTAssertEqual(options.args.count, 3)
        XCTAssertEqual(options.args[0], "--model")
        XCTAssertEqual(options.args[1], "claude-sonnet-4")
        XCTAssertEqual(options.args[2], "--debug")
        XCTAssertEqual(options.cwd, "/projects/test")
        XCTAssertEqual(options.env.count, 2)
        XCTAssertEqual(options.env["DEBUG"], "1")
        XCTAssertEqual(options.env["LOG_LEVEL"], "trace")
    }

    // MARK: - SpawnFunction Type Signature

    func testSpawnFunctionTypeSignature() async throws {
        let spawnFunc: SpawnFunction = { options in
            XCTAssertEqual(options.command, "test-command")
            return MockSpawnedProcess()
        }

        let options = SpawnOptions(command: "test-command")
        let process = try await spawnFunc(options)

        XCTAssertNotNil(process)
    }

    func testSpawnFunctionCanThrow() async {
        let spawnFunc: SpawnFunction = { _ in
            throw SpawnError.commandNotFound
        }

        let options = SpawnOptions(command: "nonexistent")

        do {
            _ = try await spawnFunc(options)
            XCTFail("Expected spawn function to throw")
        } catch {
            XCTAssertTrue(error is SpawnError)
        }
    }

    func testSpawnFunctionIsAsync() async throws {
        let spawnFunc: SpawnFunction = { options in
            // Simulate async spawn delay
            try await Task.sleep(nanoseconds: 1_000_000)
            let process = MockSpawnedProcess()
            process.mockExitCode = 0
            return process
        }

        let options = SpawnOptions(command: "claude")
        let process = try await spawnFunc(options)

        XCTAssertEqual(process.exitCode, 0)
    }

    func testSpawnFunctionAcceptsSpawnOptions() async throws {
        actor CaptureBox {
            var options: SpawnOptions?
            func set(_ options: SpawnOptions) {
                self.options = options
            }
        }
        let capture = CaptureBox()

        let spawnFunc: SpawnFunction = { options in
            await capture.set(options)
            return MockSpawnedProcess()
        }

        let options = SpawnOptions(
            command: "/bin/claude",
            args: ["--help"],
            cwd: "/tmp",
            env: ["KEY": "value"]
        )

        _ = try await spawnFunc(options)

        let capturedOptions = await capture.options
        XCTAssertNotNil(capturedOptions)
        XCTAssertEqual(capturedOptions?.command, "/bin/claude")
        XCTAssertEqual(capturedOptions?.args, ["--help"])
        XCTAssertEqual(capturedOptions?.cwd, "/tmp")
        XCTAssertEqual(capturedOptions?.env["KEY"], "value")
    }

    func testSpawnFunctionReturnsSpawnedProcess() async throws {
        let spawnFunc: SpawnFunction = { _ in
            let process = MockSpawnedProcess()
            process.mockExitCode = 42
            return process
        }

        let options = SpawnOptions(command: "test")
        let process = try await spawnFunc(options)

        XCTAssertEqual(process.exitCode, 42)
    }

    // MARK: - QueryOptions Integration

    func testSpawnFunctionCanBeAssignedToQueryOptions() {
        let spawnFunc: SpawnFunction = { _ in MockSpawnedProcess() }

        var options = QueryOptions()
        options.spawnClaudeCodeProcess = spawnFunc

        XCTAssertNotNil(options.spawnClaudeCodeProcess)
    }

    func testSpawnFunctionInQueryOptionsCanBeInvoked() async throws {
        let spawnFunc: SpawnFunction = { options in
            XCTAssertEqual(options.command, "custom-claude")
            let process = MockSpawnedProcess()
            process.mockExitCode = 0
            return process
        }

        var queryOptions = QueryOptions()
        queryOptions.spawnClaudeCodeProcess = spawnFunc

        let spawnOptions = SpawnOptions(command: "custom-claude")
        let process = try await queryOptions.spawnClaudeCodeProcess?(spawnOptions)

        XCTAssertNotNil(process)
        XCTAssertEqual(process?.exitCode, 0)
    }

    // MARK: - Interface Contracts

    func testSpawnOptionsIsSendable() {
        let options = SpawnOptions(command: "test")
        Task {
            let _: SpawnOptions = options
            XCTAssertEqual(options.command, "test")
        }
    }

    func testSpawnedProcessIsSendable() {
        let process = MockSpawnedProcess()
        Task {
            let _: any SpawnedProcess = process
            XCTAssertNotNil(process)
        }
    }

    func testSpawnFunctionIsSendable() {
        let spawnFunc: SpawnFunction = { _ in MockSpawnedProcess() }
        Task {
            let _: SpawnFunction = spawnFunc
            XCTAssertNotNil(spawnFunc)
        }
    }
}

// MARK: - Mock SpawnedProcess

final class MockSpawnedProcess: SpawnedProcess, @unchecked Sendable {
    var mockExitCode: Int32? = nil
    var mockIsKilled: Bool = false
    var lastKillSignal: Int32? = nil
    var killShouldFail: Bool = false

    var exitCode: Int32? {
        mockExitCode
    }

    var isKilled: Bool {
        mockIsKilled
    }

    func kill(signal: Int32) -> Bool {
        lastKillSignal = signal
        if killShouldFail {
            return false
        }
        mockIsKilled = true
        return true
    }
}

// MARK: - Test Error Type

enum SpawnError: Error {
    case commandNotFound
    case permissionDenied
}
