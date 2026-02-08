//
//  InitMessageTests.swift
//  ClodKitTests
//
//  Behavioral tests for SDKInitMessage decoding (Bead 2ln).
//

import XCTest
@testable import ClodKit

final class InitMessageTests: XCTestCase {

    // MARK: - Comprehensive JSON Fixture Decoding

    func testDecodeComprehensiveInitMessage() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "abc-123-xyz",
            "api_key_source": "environment",
            "cwd": "/Users/test/project",
            "model": "claude-sonnet-4",
            "permission_mode": "delegate",
            "uuid": "unique-id-456",
            "agents": ["agent1", "agent2"],
            "betas": ["beta-feature-1", "beta-feature-2"],
            "claude_code_version": "1.2.3",
            "output_style": "concise",
            "skills": ["skill1", "skill2"],
            "plugins": [
                {"name": "plugin1", "path": "/path/to/plugin1"},
                {"name": "plugin2", "path": "/path/to/plugin2"}
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let message = try decoder.decode(SDKInitMessage.self, from: json)

        XCTAssertEqual(message.type, "system")
        XCTAssertEqual(message.subtype, "init")
        XCTAssertEqual(message.sessionId, "abc-123-xyz")
        XCTAssertEqual(message.apiKeySource, "environment")
        XCTAssertEqual(message.cwd, "/Users/test/project")
        XCTAssertEqual(message.model, "claude-sonnet-4")
        XCTAssertEqual(message.permissionMode, "delegate")
        XCTAssertEqual(message.uuid, "unique-id-456")
        XCTAssertEqual(message.agents, ["agent1", "agent2"])
        XCTAssertEqual(message.betas, ["beta-feature-1", "beta-feature-2"])
        XCTAssertEqual(message.claudeCodeVersion, "1.2.3")
        XCTAssertEqual(message.outputStyle, "concise")
        XCTAssertEqual(message.skills, ["skill1", "skill2"])
        XCTAssertEqual(message.plugins?.count, 2)
        XCTAssertEqual(message.plugins?[0].name, "plugin1")
        XCTAssertEqual(message.plugins?[0].path, "/path/to/plugin1")
        XCTAssertEqual(message.plugins?[1].name, "plugin2")
        XCTAssertEqual(message.plugins?[1].path, "/path/to/plugin2")
    }

    // MARK: - Minimal Init Message

    func testDecodeMinimalInitMessage() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "minimal-session"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let message = try decoder.decode(SDKInitMessage.self, from: json)

        XCTAssertEqual(message.type, "system")
        XCTAssertEqual(message.subtype, "init")
        XCTAssertEqual(message.sessionId, "minimal-session")
        XCTAssertNil(message.apiKeySource)
        XCTAssertNil(message.cwd)
        XCTAssertNil(message.model)
        XCTAssertNil(message.permissionMode)
        XCTAssertNil(message.uuid)
        XCTAssertNil(message.agents)
        XCTAssertNil(message.betas)
        XCTAssertNil(message.claudeCodeVersion)
        XCTAssertNil(message.outputStyle)
        XCTAssertNil(message.skills)
        XCTAssertNil(message.plugins)
    }

    // MARK: - Field Verification

    func testTypeFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.type, "system")
    }

    func testSubtypeFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.subtype, "init")
    }

    func testSessionIdFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "session-abc"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.sessionId, "session-abc")
    }

    func testApiKeySourceFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "api_key_source": "file"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.apiKeySource, "file")
    }

    func testCwdFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "cwd": "/home/user"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.cwd, "/home/user")
    }

    func testModelFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "model": "claude-opus-4"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.model, "claude-opus-4")
    }

    func testPermissionModeFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "permission_mode": "plan"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.permissionMode, "plan")
    }

    func testUuidFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "uuid": "unique-uuid"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.uuid, "unique-uuid")
    }

    func testAgentsFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "agents": ["a1", "a2"]}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.agents, ["a1", "a2"])
    }

    func testBetasFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "betas": ["b1", "b2"]}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.betas, ["b1", "b2"])
    }

    func testClaudeCodeVersionFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "claude_code_version": "2.0.0"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.claudeCodeVersion, "2.0.0")
    }

    func testOutputStyleFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "output_style": "verbose"}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.outputStyle, "verbose")
    }

    func testSkillsFieldPresent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "skills": ["s1", "s2"]}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.skills, ["s1", "s2"])
    }

    func testPluginsFieldPresent() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "test",
            "plugins": [{"name": "p1", "path": "/p1"}]
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.plugins?.count, 1)
        XCTAssertEqual(message.plugins?[0].name, "p1")
        XCTAssertEqual(message.plugins?[0].path, "/p1")
    }

    // MARK: - Snake Case to Camel Case Mapping

    func testSnakeCaseFieldsMappedCorrectly() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "s1",
            "api_key_source": "env",
            "permission_mode": "default",
            "claude_code_version": "1.0",
            "output_style": "compact"
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)

        XCTAssertEqual(message.sessionId, "s1")
        XCTAssertEqual(message.apiKeySource, "env")
        XCTAssertEqual(message.permissionMode, "default")
        XCTAssertEqual(message.claudeCodeVersion, "1.0")
        XCTAssertEqual(message.outputStyle, "compact")
    }

    // MARK: - Empty Arrays

    func testEmptyAgentsArray() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "agents": []}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.agents, [])
    }

    func testEmptyBetasArray() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "betas": []}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.betas, [])
    }

    func testEmptySkillsArray() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "skills": []}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.skills, [])
    }

    func testEmptyPluginsArray() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "test", "plugins": []}
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(message.plugins, [])
    }

    // MARK: - Round-Trip Encoding

    func testRoundTripEncoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "round-trip-test",
            "api_key_source": "env",
            "cwd": "/test",
            "model": "claude-sonnet-4",
            "permission_mode": "delegate",
            "uuid": "uuid-123",
            "agents": ["a1"],
            "betas": ["b1"],
            "claude_code_version": "1.0",
            "output_style": "verbose",
            "skills": ["s1"],
            "plugins": [{"name": "p1", "path": "/p1"}]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let original = try decoder.decode(SDKInitMessage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKInitMessage.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.subtype, original.subtype)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.apiKeySource, original.apiKeySource)
        XCTAssertEqual(decoded.cwd, original.cwd)
        XCTAssertEqual(decoded.model, original.model)
        XCTAssertEqual(decoded.permissionMode, original.permissionMode)
        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.agents, original.agents)
        XCTAssertEqual(decoded.betas, original.betas)
        XCTAssertEqual(decoded.claudeCodeVersion, original.claudeCodeVersion)
        XCTAssertEqual(decoded.outputStyle, original.outputStyle)
        XCTAssertEqual(decoded.skills, original.skills)
        XCTAssertEqual(decoded.plugins, original.plugins)
    }
}
