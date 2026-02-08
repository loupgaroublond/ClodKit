//
//  McpServerStatusTests.swift
//  ClodKitTests
//
//  Behavioral tests for MCP server status reporting and lifecycle (bead x18).
//

import XCTest
@testable import ClodKit

// MARK: - McpServerStatus Tests

final class McpServerStatusTests: XCTestCase {

    func testConnectedStatus() throws {
        let status = McpServerStatus(
            name: "filesystem",
            status: "connected",
            serverInfo: McpServerInfo(name: "filesystem", version: "1.0.0"),
            tools: [
                McpToolInfo(name: "read_file", description: "Read a file"),
                McpToolInfo(name: "write_file", description: "Write a file"),
            ]
        )
        XCTAssertEqual(status.status, "connected")
        XCTAssertEqual(status.serverInfo?.name, "filesystem")
        XCTAssertEqual(status.serverInfo?.version, "1.0.0")
        XCTAssertEqual(status.tools?.count, 2)
        XCTAssertEqual(status.tools?[0].name, "read_file")
    }

    func testFailedStatus() {
        let status = McpServerStatus(
            name: "broken-server",
            status: "failed",
            error: "Connection refused"
        )
        XCTAssertEqual(status.status, "failed")
        XCTAssertEqual(status.error, "Connection refused")
    }

    func testNeedsAuthStatus() {
        let status = McpServerStatus(name: "github", status: "needs-auth")
        XCTAssertEqual(status.status, "needs-auth")
    }

    func testPendingStatus() {
        let status = McpServerStatus(name: "starting", status: "pending")
        XCTAssertEqual(status.status, "pending")
    }

    func testDisabledStatus() {
        let status = McpServerStatus(name: "unused", status: "disabled")
        XCTAssertEqual(status.status, "disabled")
    }

    func testAllFiveStatusValuesDecodeFromJSON() throws {
        let statuses = ["connected", "failed", "needs-auth", "pending", "disabled"]
        for statusValue in statuses {
            let json = """
            {"name": "test", "status": "\(statusValue)"}
            """
            let data = json.data(using: .utf8)!
            let status = try JSONDecoder().decode(McpServerStatus.self, from: data)
            XCTAssertEqual(status.status, statusValue)
        }
    }

    func testScopeFieldValues() throws {
        let scopes = ["project", "user", "local", "claudeai", "managed"]
        for scope in scopes {
            let status = McpServerStatus(name: "test", status: "connected", scope: scope)
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(McpServerStatus.self, from: data)
            XCTAssertEqual(decoded.scope, scope)
        }
    }

    func testCodableRoundTrip() throws {
        let original = McpServerStatus(
            name: "my-server",
            status: "connected",
            serverInfo: McpServerInfo(name: "my-server", version: "2.0.0"),
            error: nil,
            config: .object(["command": .string("node"), "args": .array([.string("server.js")])]),
            scope: "project",
            tools: [
                McpToolInfo(
                    name: "search",
                    description: "Search files",
                    annotations: McpToolAnnotations(readOnly: true, destructive: false, openWorld: false)
                ),
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(McpServerStatus.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - McpServerInfo Tests

final class McpServerInfoTests: XCTestCase {

    func testFields() {
        let info = McpServerInfo(name: "test-server", version: "3.1.0")
        XCTAssertEqual(info.name, "test-server")
        XCTAssertEqual(info.version, "3.1.0")
    }

    func testCodableRoundTrip() throws {
        let original = McpServerInfo(name: "srv", version: "1.0")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(McpServerInfo.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - McpToolInfo Tests

final class McpToolInfoTests: XCTestCase {

    func testToolWithAnnotations() {
        let tool = McpToolInfo(
            name: "delete_file",
            description: "Delete a file",
            annotations: McpToolAnnotations(readOnly: false, destructive: true, openWorld: false)
        )
        XCTAssertEqual(tool.annotations?.destructive, true)
        XCTAssertEqual(tool.annotations?.readOnly, false)
    }

    func testToolWithoutAnnotations() {
        let tool = McpToolInfo(name: "echo", description: "Echo text")
        XCTAssertNil(tool.annotations)
    }
}

// MARK: - McpToolAnnotations Tests

final class McpToolAnnotationsTests: XCTestCase {

    func testAllFieldsOptional() {
        let ann = McpToolAnnotations()
        XCTAssertNil(ann.readOnly)
        XCTAssertNil(ann.destructive)
        XCTAssertNil(ann.openWorld)
    }

    func testCodableRoundTrip() throws {
        let original = McpToolAnnotations(readOnly: true, destructive: false, openWorld: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(McpToolAnnotations.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testCodingKeysUseSnakeCase() throws {
        let ann = McpToolAnnotations(readOnly: true, openWorld: false)
        let data = try JSONEncoder().encode(ann)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["read_only"])
        XCTAssertNotNil(json["open_world"])
        XCTAssertNil(json["readOnly"])
        XCTAssertNil(json["openWorld"])
    }
}

// MARK: - McpClaudeAIProxyServerConfig Tests

final class McpClaudeAIProxyServerConfigTests: XCTestCase {

    func testTypeIsAlwaysClaudeaiProxy() {
        let config = McpClaudeAIProxyServerConfig(url: "https://proxy.example.com", id: "proxy-1")
        XCTAssertEqual(config.type, "claudeai-proxy")
    }

    func testFields() {
        let config = McpClaudeAIProxyServerConfig(url: "https://api.claude.ai/proxy", id: "srv-42")
        XCTAssertEqual(config.url, "https://api.claude.ai/proxy")
        XCTAssertEqual(config.id, "srv-42")
    }

    func testCodableRoundTrip() throws {
        let original = McpClaudeAIProxyServerConfig(url: "https://proxy.test", id: "test-id")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(McpClaudeAIProxyServerConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeFromJSON() throws {
        let json = """
        {"type": "claudeai-proxy", "url": "https://example.com", "id": "abc"}
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(McpClaudeAIProxyServerConfig.self, from: data)
        XCTAssertEqual(config.type, "claudeai-proxy")
        XCTAssertEqual(config.url, "https://example.com")
        XCTAssertEqual(config.id, "abc")
    }
}
