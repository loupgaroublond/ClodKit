//
//  AgentDefinitionTests.swift
//  ClodKitTests
//
//  Behavioral tests for AgentDefinition validation and serialization (bead 23j).
//

import XCTest
@testable import ClodKit

// MARK: - AgentDefinition Tests

final class AgentDefinitionTests: XCTestCase {

    func testRequiredFieldsMustNotBeNil() {
        let agent = AgentDefinition(description: "A helpful agent", prompt: "You are helpful")
        XCTAssertEqual(agent.description, "A helpful agent")
        XCTAssertEqual(agent.prompt, "You are helpful")
    }

    func testOptionalFieldsDefaultToNil() {
        let agent = AgentDefinition(description: "test", prompt: "test")
        XCTAssertNil(agent.tools)
        XCTAssertNil(agent.disallowedTools)
        XCTAssertNil(agent.model)
        XCTAssertNil(agent.mcpServers)
        XCTAssertNil(agent.criticalSystemReminderExperimental)
        XCTAssertNil(agent.skills)
        XCTAssertNil(agent.maxTurns)
    }

    func testMinimalAgentEncodesWithoutOptionalKeys() throws {
        let agent = AgentDefinition(description: "minimal", prompt: "do things")
        let data = try JSONEncoder().encode(agent)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["description"] as? String, "minimal")
        XCTAssertEqual(json["prompt"] as? String, "do things")
        XCTAssertNil(json["tools"])
        XCTAssertNil(json["disallowed_tools"])
        XCTAssertNil(json["model"])
        XCTAssertNil(json["mcp_servers"])
        XCTAssertNil(json["criticalSystemReminder_EXPERIMENTAL"])
        XCTAssertNil(json["skills"])
        XCTAssertNil(json["max_turns"])
    }

    func testCriticalSystemReminderExperimentalJsonKey() throws {
        let agent = AgentDefinition(
            description: "test",
            prompt: "test",
            criticalSystemReminderExperimental: "IMPORTANT: Be safe"
        )
        let data = try JSONEncoder().encode(agent)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["criticalSystemReminder_EXPERIMENTAL"] as? String, "IMPORTANT: Be safe")
    }

    func testFullRoundTrip() throws {
        let original = AgentDefinition(
            description: "Research agent",
            prompt: "You are a research assistant",
            tools: ["Bash", "Read", "Write"],
            disallowedTools: ["WebFetch"],
            model: .sonnet,
            mcpServers: ["filesystem", "github"],
            criticalSystemReminderExperimental: "Always cite sources",
            skills: ["search", "summarize"],
            maxTurns: 10
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentDefinition.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testAllFieldsPreservedAfterRoundTrip() throws {
        let original = AgentDefinition(
            description: "test",
            prompt: "test prompt",
            tools: ["A"],
            disallowedTools: ["B"],
            model: .opus,
            mcpServers: ["srv"],
            criticalSystemReminderExperimental: "reminder",
            skills: ["skill1"],
            maxTurns: 5
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AgentDefinition.self, from: data)
        XCTAssertEqual(decoded.description, "test")
        XCTAssertEqual(decoded.prompt, "test prompt")
        XCTAssertEqual(decoded.tools, ["A"])
        XCTAssertEqual(decoded.disallowedTools, ["B"])
        XCTAssertEqual(decoded.model, .opus)
        XCTAssertEqual(decoded.mcpServers, ["srv"])
        XCTAssertEqual(decoded.criticalSystemReminderExperimental, "reminder")
        XCTAssertEqual(decoded.skills, ["skill1"])
        XCTAssertEqual(decoded.maxTurns, 5)
    }
}

// MARK: - AgentModel Tests

final class AgentModelTests: XCTestCase {

    func testAllCasesEncode() throws {
        let cases: [(AgentModel, String)] = [
            (.sonnet, "\"sonnet\""),
            (.opus, "\"opus\""),
            (.haiku, "\"haiku\""),
            (.inherit, "\"inherit\""),
        ]
        let encoder = JSONEncoder()
        for (model, expected) in cases {
            let data = try encoder.encode(model)
            let str = String(data: data, encoding: .utf8)!
            XCTAssertEqual(str, expected, "AgentModel.\(model) should encode as \(expected)")
        }
    }

    func testAllCasesDecode() throws {
        let cases: [(String, AgentModel)] = [
            ("\"sonnet\"", .sonnet),
            ("\"opus\"", .opus),
            ("\"haiku\"", .haiku),
            ("\"inherit\"", .inherit),
        ]
        for (json, expected) in cases {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(AgentModel.self, from: data)
            XCTAssertEqual(decoded, expected)
        }
    }

    func testRawValuesAreLowercase() {
        XCTAssertEqual(AgentModel.sonnet.rawValue, "sonnet")
        XCTAssertEqual(AgentModel.opus.rawValue, "opus")
        XCTAssertEqual(AgentModel.haiku.rawValue, "haiku")
        XCTAssertEqual(AgentModel.inherit.rawValue, "inherit")
    }
}

// MARK: - Agents in QueryOptions Tests

final class AgentsInQueryOptionsTests: XCTestCase {

    func testAgentsDictionaryInQueryOptions() {
        var opts = QueryOptions()
        opts.agents = [
            "researcher": AgentDefinition(description: "Research", prompt: "research"),
            "coder": AgentDefinition(description: "Code", prompt: "code"),
        ]
        XCTAssertEqual(opts.agents?.count, 2)
        XCTAssertNotNil(opts.agents?["researcher"])
        XCTAssertNotNil(opts.agents?["coder"])
    }

    func testAgentsDefaultsToNil() {
        let opts = QueryOptions()
        XCTAssertNil(opts.agents)
    }
}
