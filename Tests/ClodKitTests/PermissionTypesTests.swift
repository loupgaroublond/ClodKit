//
//  PermissionTypesTests.swift
//  ClodKitTests
//
//  Unit tests for permission type definitions.
//

import XCTest
@testable import ClodKit

// MARK: - PermissionMode Tests

final class PermissionModeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PermissionMode.default.rawValue, "default")
        XCTAssertEqual(PermissionMode.acceptEdits.rawValue, "acceptEdits")
        XCTAssertEqual(PermissionMode.bypassPermissions.rawValue, "bypassPermissions")
        XCTAssertEqual(PermissionMode.plan.rawValue, "plan")
    }

    func testAllCasesCount() {
        XCTAssertEqual(PermissionMode.allCases.count, 4)
    }

    func testCodableRoundTrip() throws {
        for mode in PermissionMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(PermissionMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testDecodeFromJSON() throws {
        let json = "\"acceptEdits\""
        let data = json.data(using: .utf8)!
        let mode = try JSONDecoder().decode(PermissionMode.self, from: data)
        XCTAssertEqual(mode, .acceptEdits)
    }
}

// MARK: - ToolPermissionContext Tests

final class ToolPermissionContextTests: XCTestCase {

    func testDefaultInitialization() {
        let context = ToolPermissionContext(toolUseID: "test-id")
        XCTAssertTrue(context.suggestions.isEmpty)
        XCTAssertNil(context.blockedPath)
        XCTAssertNil(context.decisionReason)
        XCTAssertNil(context.agentId)
        XCTAssertEqual(context.toolUseID, "test-id")
    }

    func testFullInitialization() {
        let rule = PermissionRule.tool("Bash")
        let update = PermissionUpdate.addRules([rule], behavior: .allow)

        let context = ToolPermissionContext(
            suggestions: [update],
            blockedPath: "/etc/passwd",
            decisionReason: "Sensitive file",
            agentId: "agent-123",
            toolUseID: "tool-use-456"
        )

        XCTAssertEqual(context.suggestions.count, 1)
        XCTAssertEqual(context.blockedPath, "/etc/passwd")
        XCTAssertEqual(context.decisionReason, "Sensitive file")
        XCTAssertEqual(context.agentId, "agent-123")
    }
}

// MARK: - PermissionResult Tests

final class PermissionResultTests: XCTestCase {

    func testAllow_MinimalToDictionary() {
        let result = PermissionResult.allowTool()
        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNil(dict["updatedInput"])
        XCTAssertNil(dict["updatedPermissions"])
    }

    func testAllow_WithUpdatedInputToDictionary() {
        let result = PermissionResult.allowTool(updatedInput: [
            "command": .string("echo safe"),
            "timeout": .int(30)
        ])
        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "allow")

        if let updatedInput = dict["updatedInput"] as? [String: Any] {
            XCTAssertEqual(updatedInput["command"] as? String, "echo safe")
            XCTAssertEqual(updatedInput["timeout"] as? Int, 30)
        } else {
            XCTFail("Expected updatedInput dictionary")
        }
    }

    func testAllow_WithPermissionUpdatesToDictionary() {
        let rule = PermissionRule.tool("Bash", content: "allow all")
        let update = PermissionUpdate.addRules([rule], behavior: .allow, destination: .session)

        let result = PermissionResult.allowTool(permissionUpdates: [update])
        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "allow")

        if let updates = dict["updatedPermissions"] as? [[String: Any]] {
            XCTAssertEqual(updates.count, 1)
            XCTAssertEqual(updates[0]["type"] as? String, "addRules")
        } else {
            XCTFail("Expected updatedPermissions array")
        }
    }

    func testDeny_ToDictionary() {
        let result = PermissionResult.denyTool("Not allowed")
        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Not allowed")
        XCTAssertEqual(dict["interrupt"] as? Bool, false)
    }

    func testDenyAndInterrupt_ToDictionary() {
        let result = PermissionResult.denyToolAndInterrupt("Critical error")
        let dict = result.toDictionary()

        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Critical error")
        XCTAssertEqual(dict["interrupt"] as? Bool, true)
    }

    func testConvenienceAllow() {
        let result = PermissionResult.allowTool()
        if case .allow(let input, let updates, _) = result {
            XCTAssertNil(input)
            XCTAssertNil(updates)
        } else {
            XCTFail("Expected allow case")
        }
    }

    func testConvenienceDeny() {
        let result = PermissionResult.denyTool("Blocked")
        if case .deny(let message, let interrupt, _) = result {
            XCTAssertEqual(message, "Blocked")
            XCTAssertFalse(interrupt)
        } else {
            XCTFail("Expected deny case")
        }
    }
}

// MARK: - PermissionUpdate Tests

final class PermissionUpdateTests: XCTestCase {

    func testAddRules_ToDictionary() {
        let rule = PermissionRule.tool("Bash")
        let update = PermissionUpdate.addRules([rule], behavior: .allow, destination: .session)
        let dict = update.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "addRules")
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertEqual(dict["destination"] as? String, "session")

        if let rules = dict["rules"] as? [[String: Any]] {
            XCTAssertEqual(rules.count, 1)
            XCTAssertEqual(rules[0]["toolName"] as? String, "Bash")
        } else {
            XCTFail("Expected rules array")
        }
    }

    func testReplaceRules_ToDictionary() {
        let rules = [
            PermissionRule.tool("Bash"),
            PermissionRule.tool("Write", content: "/tmp/*")
        ]
        let update = PermissionUpdate.replaceRules(rules, behavior: .deny, destination: .projectSettings)
        let dict = update.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "replaceRules")
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["destination"] as? String, "projectSettings")
        XCTAssertEqual((dict["rules"] as? [[String: Any]])?.count, 2)
    }

    func testSetMode_ToDictionary() {
        let update = PermissionUpdate.setMode(.acceptEdits, destination: .userSettings)
        let dict = update.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "setMode")
        XCTAssertEqual(dict["mode"] as? String, "acceptEdits")
        XCTAssertEqual(dict["destination"] as? String, "userSettings")
        XCTAssertNil(dict["rules"])
    }

    func testAddDirectories_ToDictionary() {
        let update = PermissionUpdate.addDirectories(["/home/user/projects", "/tmp"], destination: .localSettings)
        let dict = update.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "addDirectories")
        XCTAssertEqual(dict["destination"] as? String, "localSettings")

        if let dirs = dict["directories"] as? [String] {
            XCTAssertEqual(dirs, ["/home/user/projects", "/tmp"])
        } else {
            XCTFail("Expected directories array")
        }
    }

    func testRemoveDirectories_ToDictionary() {
        let update = PermissionUpdate.removeDirectories(["/sensitive"])
        let dict = update.toDictionary()

        XCTAssertEqual(dict["type"] as? String, "removeDirectories")
        XCTAssertEqual(dict["destination"] as? String, "session")
        XCTAssertEqual(dict["directories"] as? [String], ["/sensitive"])
    }

    func testCodableRoundTrip() throws {
        let rule = PermissionRule.tool("Bash", content: "ls *")
        let update = PermissionUpdate(
            type: .addRules,
            rules: [rule],
            behavior: .allow,
            mode: nil,
            directories: nil,
            destination: .session
        )

        let data = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(PermissionUpdate.self, from: data)

        XCTAssertEqual(decoded.type, .addRules)
        XCTAssertEqual(decoded.behavior, .allow)
        XCTAssertEqual(decoded.destination, .session)
        XCTAssertEqual(decoded.rules?.count, 1)
        XCTAssertEqual(decoded.rules?.first?.toolName, "Bash")
    }

    func testEquatable() {
        let update1 = PermissionUpdate.setMode(.acceptEdits)
        let update2 = PermissionUpdate.setMode(.acceptEdits)
        let update3 = PermissionUpdate.setMode(.plan)

        XCTAssertEqual(update1, update2)
        XCTAssertNotEqual(update1, update3)
    }
}

// MARK: - PermissionUpdate.UpdateType Tests

final class PermissionUpdateTypeTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PermissionUpdate.UpdateType.addRules.rawValue, "addRules")
        XCTAssertEqual(PermissionUpdate.UpdateType.replaceRules.rawValue, "replaceRules")
        XCTAssertEqual(PermissionUpdate.UpdateType.removeRules.rawValue, "removeRules")
        XCTAssertEqual(PermissionUpdate.UpdateType.setMode.rawValue, "setMode")
        XCTAssertEqual(PermissionUpdate.UpdateType.addDirectories.rawValue, "addDirectories")
        XCTAssertEqual(PermissionUpdate.UpdateType.removeDirectories.rawValue, "removeDirectories")
    }
}

// MARK: - PermissionUpdate.Behavior Tests

final class PermissionUpdateBehaviorTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PermissionUpdate.Behavior.allow.rawValue, "allow")
        XCTAssertEqual(PermissionUpdate.Behavior.deny.rawValue, "deny")
        XCTAssertEqual(PermissionUpdate.Behavior.ask.rawValue, "ask")
    }
}

// MARK: - PermissionUpdate.Destination Tests

final class PermissionUpdateDestinationTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(PermissionUpdate.Destination.userSettings.rawValue, "userSettings")
        XCTAssertEqual(PermissionUpdate.Destination.projectSettings.rawValue, "projectSettings")
        XCTAssertEqual(PermissionUpdate.Destination.localSettings.rawValue, "localSettings")
        XCTAssertEqual(PermissionUpdate.Destination.session.rawValue, "session")
    }
}

// MARK: - PermissionRule Tests

final class PermissionRuleTests: XCTestCase {

    func testToolOnlyToDictionary() {
        let rule = PermissionRule.tool("Bash")
        let dict = rule.toDictionary()

        XCTAssertEqual(dict["toolName"] as? String, "Bash")
        XCTAssertNil(dict["ruleContent"])
    }

    func testToolWithContentToDictionary() {
        let rule = PermissionRule.tool("Write", content: "/tmp/**")
        let dict = rule.toDictionary()

        XCTAssertEqual(dict["toolName"] as? String, "Write")
        XCTAssertEqual(dict["ruleContent"] as? String, "/tmp/**")
    }

    func testCodableRoundTrip() throws {
        let rule = PermissionRule(toolName: "Read", ruleContent: "/etc/*")

        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(PermissionRule.self, from: data)

        XCTAssertEqual(decoded.toolName, "Read")
        XCTAssertEqual(decoded.ruleContent, "/etc/*")
    }

    func testEquatable() {
        let rule1 = PermissionRule.tool("Bash")
        let rule2 = PermissionRule.tool("Bash")
        let rule3 = PermissionRule.tool("Write")
        let rule4 = PermissionRule.tool("Bash", content: "ls")

        XCTAssertEqual(rule1, rule2)
        XCTAssertNotEqual(rule1, rule3)
        XCTAssertNotEqual(rule1, rule4)
    }
}
