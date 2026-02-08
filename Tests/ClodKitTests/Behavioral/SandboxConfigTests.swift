//
//  SandboxConfigTests.swift
//  ClodKitTests
//
//  Behavioral tests for sandbox configuration validation and encoding (bead h5d).
//

import XCTest
@testable import ClodKit

// MARK: - SandboxSettings Tests

final class SandboxSettingsTests: XCTestCase {

    func testEmptySettingsEncodesAsEmptyObject() throws {
        let settings = SandboxSettings()
        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertTrue(json.isEmpty)
    }

    func testAllFieldsOptional() {
        let settings = SandboxSettings()
        XCTAssertNil(settings.enabled)
        XCTAssertNil(settings.autoAllowBashIfSandboxed)
        XCTAssertNil(settings.allowUnsandboxedCommands)
        XCTAssertNil(settings.network)
        XCTAssertNil(settings.ignoreViolations)
        XCTAssertNil(settings.enableWeakerNestedSandbox)
        XCTAssertNil(settings.excludedCommands)
        XCTAssertNil(settings.ripgrep)
    }

    func testIgnoreViolationsIsOpenDictionary() throws {
        var settings = SandboxSettings()
        settings.ignoreViolations = [
            "file": ["/tmp/test", "/var/log"],
            "network": ["localhost"],
            "custom_category": ["something"],
        ]
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SandboxSettings.self, from: data)
        XCTAssertEqual(decoded.ignoreViolations?["file"], ["/tmp/test", "/var/log"])
        XCTAssertEqual(decoded.ignoreViolations?["network"], ["localhost"])
        XCTAssertEqual(decoded.ignoreViolations?["custom_category"], ["something"])
    }

    func testPartialConfigOmitsUnsetFields() throws {
        var settings = SandboxSettings()
        settings.enabled = true
        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["enabled"] as? Bool, true)
        XCTAssertNil(json["auto_allow_bash_if_sandboxed"])
        XCTAssertNil(json["network"])
        XCTAssertNil(json["ignore_violations"])
        XCTAssertNil(json["ripgrep"])
    }

    func testEnableWeakerNestedSandboxField() throws {
        var settings = SandboxSettings()
        settings.enableWeakerNestedSandbox = true
        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["enable_weaker_nested_sandbox"] as? Bool, true)
    }

    func testExcludedCommandsField() throws {
        var settings = SandboxSettings()
        settings.excludedCommands = ["docker", "kubectl"]
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SandboxSettings.self, from: data)
        XCTAssertEqual(decoded.excludedCommands, ["docker", "kubectl"])
    }

    func testFullConfigRoundTrip() throws {
        var settings = SandboxSettings()
        settings.enabled = true
        settings.autoAllowBashIfSandboxed = false
        settings.allowUnsandboxedCommands = true

        var network = SandboxNetworkConfig()
        network.allowedDomains = ["api.example.com", "cdn.example.com"]
        network.allowManagedDomainsOnly = true
        network.allowUnixSockets = ["/var/run/docker.sock"]
        network.allowAllUnixSockets = false
        network.allowLocalBinding = true
        network.httpProxyPort = 8080
        network.socksProxyPort = 1080
        settings.network = network

        settings.ignoreViolations = ["file": ["/tmp"], "net": ["127.0.0.1"]]
        settings.enableWeakerNestedSandbox = false
        settings.excludedCommands = ["git", "npm"]
        settings.ripgrep = RipgrepConfig(command: "/usr/bin/rg", args: ["--hidden", "--glob", "!.git"])

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SandboxSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }
}

// MARK: - SandboxNetworkConfig Tests

final class SandboxNetworkConfigTests: XCTestCase {

    func testAllowedDomainsField() throws {
        var config = SandboxNetworkConfig()
        config.allowedDomains = ["example.com", "api.test.org"]
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["allowed_domains"])
        let decoded = try JSONDecoder().decode(SandboxNetworkConfig.self, from: data)
        XCTAssertEqual(decoded.allowedDomains, ["example.com", "api.test.org"])
    }

    func testAllowManagedDomainsOnlyField() throws {
        var config = SandboxNetworkConfig()
        config.allowManagedDomainsOnly = true
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["allow_managed_domains_only"] as? Bool, true)
    }

    func testEmptyNetworkConfigEncodesAsEmpty() throws {
        let config = SandboxNetworkConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertTrue(json.isEmpty)
    }
}

// MARK: - RipgrepConfig Tests

final class RipgrepConfigTests: XCTestCase {

    func testCommandRequired() {
        let config = RipgrepConfig(command: "/usr/bin/rg")
        XCTAssertEqual(config.command, "/usr/bin/rg")
        XCTAssertNil(config.args)
    }

    func testArgsOptional() throws {
        let config = RipgrepConfig(command: "rg", args: ["--hidden"])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(RipgrepConfig.self, from: data)
        XCTAssertEqual(decoded.command, "rg")
        XCTAssertEqual(decoded.args, ["--hidden"])
    }

    func testCodableRoundTrip() throws {
        let config = RipgrepConfig(command: "/opt/bin/rg", args: ["-i", "--glob", "*.swift"])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(RipgrepConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}
