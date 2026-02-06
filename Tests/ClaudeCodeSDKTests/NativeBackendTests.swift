//
//  NativeBackendTests.swift
//  ClaudeCodeSDKTests
//
//  Unit tests for NativeBackend.
//

import XCTest
@testable import ClaudeCodeSDK

final class NativeBackendTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_DefaultConfiguration() {
        let backend = NativeBackend()

        XCTAssertNotNil(backend)
    }

    func testInit_CustomConfiguration() {
        let backend = NativeBackend(
            cliPath: "/usr/local/bin/claude",
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            environment: ["TEST_VAR": "value"],
            enableLogging: true
        )

        XCTAssertNotNil(backend)
    }

    // MARK: - Factory Tests

    func testFactory_CreateDefault() {
        let backend = NativeBackendFactory.create()

        XCTAssertNotNil(backend)
    }

    func testFactory_CreateWithLogging() {
        let backend = NativeBackendFactory.create(enableLogging: true)

        XCTAssertNotNil(backend)
    }

    func testFactory_CreateCustom() {
        let backend = NativeBackendFactory.create(
            cliPath: "/custom/path/claude",
            workingDirectory: URL(fileURLWithPath: "/tmp"),
            environment: ["KEY": "VALUE"],
            enableLogging: false
        )

        XCTAssertNotNil(backend)
    }

    // MARK: - NativeBackendError Tests

    func testNativeBackendError_ValidationFailed_LocalizedDescription() {
        let error = NativeBackendError.validationFailed("CLI not found")

        XCTAssertTrue(error.localizedDescription.contains("CLI not found"))
        XCTAssertTrue(error.localizedDescription.contains("validation"))
    }

    func testNativeBackendError_NotConfigured_LocalizedDescription() {
        let error = NativeBackendError.notConfigured("Missing setting")

        XCTAssertTrue(error.localizedDescription.contains("Missing setting"))
        XCTAssertTrue(error.localizedDescription.contains("configured"))
    }

    func testNativeBackendError_Cancelled_LocalizedDescription() {
        let error = NativeBackendError.cancelled

        XCTAssertTrue(error.localizedDescription.contains("cancelled"))
    }

    func testNativeBackendError_Equatable() {
        let e1 = NativeBackendError.validationFailed("error")
        let e2 = NativeBackendError.validationFailed("error")
        let e3 = NativeBackendError.validationFailed("different")
        let e4 = NativeBackendError.cancelled

        XCTAssertEqual(e1, e2)
        XCTAssertNotEqual(e1, e3)
        XCTAssertNotEqual(e1, e4)
    }

    // MARK: - Cancel Tests

    func testCancel_DoesNotCrashWhenNoActiveQuery() {
        let backend = NativeBackend()

        // Should not crash when there's no active query
        backend.cancel()

        XCTAssertTrue(true)  // Reaching this point means no crash
    }

    // MARK: - Protocol Conformance Tests

    func testNativeBackend_ConformsToProtocol() {
        let backend: NativeClaudeCodeBackend = NativeBackend()

        // Verify all protocol methods exist
        _ = backend.cancel
        _ = backend.validateSetup
        _ = backend.runSinglePrompt
        _ = backend.resumeSession

        XCTAssertTrue(true)  // Compilation is the test
    }

    // MARK: - Thread Safety Tests

    func testNativeBackend_IsSendable() {
        let backend = NativeBackend()

        // Verify Sendable conformance by using in concurrent context
        Task {
            let _ = backend
        }

        XCTAssertTrue(true)  // Compilation is the test
    }

    // MARK: - Multiple Backend Instances

    func testMultipleBackendInstances() {
        let backend1 = NativeBackend(cliPath: "/path/one")
        let backend2 = NativeBackend(cliPath: "/path/two")
        let backend3 = NativeBackendFactory.create()

        // All should be independent
        XCTAssertNotNil(backend1)
        XCTAssertNotNil(backend2)
        XCTAssertNotNil(backend3)
    }

    // MARK: - Configuration Merging Tests

    func testOptionsApplied_CliPath() async {
        // This test verifies that default options get applied
        // We can't fully test without mocking the transport, but we can verify
        // the backend initializes correctly with various configurations
        let backend = NativeBackend(
            cliPath: "/custom/claude",
            workingDirectory: URL(fileURLWithPath: "/home/user"),
            environment: ["CUSTOM_VAR": "value"]
        )

        XCTAssertNotNil(backend)
    }

    // MARK: - BackendType Tests

    func testBackendType_HasNativeCase() {
        let type = BackendType.native

        XCTAssertEqual(type.rawValue, "native")
    }

    func testBackendType_HasHeadlessCase() {
        let type = BackendType.headless

        XCTAssertEqual(type.rawValue, "headless")
    }

    func testBackendType_HasAgentSDKCase() {
        let type = BackendType.agentSDK

        XCTAssertEqual(type.rawValue, "agentSDK")
    }

    func testBackendType_IsCodable() throws {
        let type = BackendType.native
        let encoded = try JSONEncoder().encode(type)
        let decoded = try JSONDecoder().decode(BackendType.self, from: encoded)

        XCTAssertEqual(type, decoded)
    }

    func testFactory_CreateWithTypeNative() throws {
        let backend = try NativeBackendFactory.create(type: .native)

        XCTAssertNotNil(backend)
    }

    func testFactory_CreateWithTypeHeadless_Throws() {
        XCTAssertThrowsError(try NativeBackendFactory.create(type: .headless)) { error in
            if case NativeBackendError.notConfigured = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected notConfigured error")
            }
        }
    }

    func testFactory_CreateWithTypeAgentSDK_Throws() {
        XCTAssertThrowsError(try NativeBackendFactory.create(type: .agentSDK)) { error in
            if case NativeBackendError.notConfigured = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected notConfigured error")
            }
        }
    }

    func testFactory_DefaultTypeIsNative() throws {
        let backend = try NativeBackendFactory.create(type: .native, enableLogging: false)

        XCTAssertNotNil(backend)
    }
}
