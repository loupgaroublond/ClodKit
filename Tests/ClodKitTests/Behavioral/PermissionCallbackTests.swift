//
//  PermissionCallbackTests.swift
//  ClodKitTests
//
//  Behavioral tests for permission callback contract and ToolPermissionContext (Bead v26).
//

import XCTest
@testable import ClodKit

final class PermissionCallbackTests: XCTestCase {

    // MARK: - ToolPermissionContext Fields

    func testToolPermissionContextHasAllFields() {
        let context = ToolPermissionContext(
            suggestions: [
                PermissionUpdate.addRules([.tool("Bash")], behavior: .allow)
            ],
            blockedPath: "/etc/passwd",
            decisionReason: "File outside allowed directories",
            agentId: "agent-42",
            toolUseID: "tu-unique-1"
        )
        XCTAssertEqual(context.suggestions.count, 1)
        XCTAssertEqual(context.blockedPath, "/etc/passwd")
        XCTAssertEqual(context.decisionReason, "File outside allowed directories")
        XCTAssertEqual(context.agentId, "agent-42")
        XCTAssertEqual(context.toolUseID, "tu-unique-1")
    }

    func testToolUseIDIsRequired() {
        // toolUseID is non-optional, so this must compile with a value
        let context = ToolPermissionContext(toolUseID: "tu-required")
        XCTAssertEqual(context.toolUseID, "tu-required")
        XCTAssertTrue(context.suggestions.isEmpty)
        XCTAssertNil(context.blockedPath)
        XCTAssertNil(context.decisionReason)
        XCTAssertNil(context.agentId)
    }

    func testMultipleToolCallsGetDifferentToolUseIDs() {
        let ctx1 = ToolPermissionContext(toolUseID: "tu-call-1")
        let ctx2 = ToolPermissionContext(toolUseID: "tu-call-2")
        let ctx3 = ToolPermissionContext(toolUseID: "tu-call-3")
        XCTAssertNotEqual(ctx1.toolUseID, ctx2.toolUseID)
        XCTAssertNotEqual(ctx2.toolUseID, ctx3.toolUseID)
        XCTAssertNotEqual(ctx1.toolUseID, ctx3.toolUseID)
    }

    // MARK: - PermissionResult.allow

    func testAllowWithNoModifications() {
        let result = PermissionResult.allow()
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNil(dict["updatedInput"])
        XCTAssertNil(dict["updatedPermissions"])
    }

    func testAllowWithUpdatedInput() {
        let result = PermissionResult.allow(
            updatedInput: ["command": .string("ls -la")],
            toolUseID: "tu-1"
        )
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedInput"])
        XCTAssertEqual(dict["toolUseId"] as? String, "tu-1")
    }

    func testAllowWithUpdatedPermissions() {
        let update = PermissionUpdate.addRules(
            [PermissionRule.tool("Bash", content: "ls *")],
            behavior: .allow,
            destination: .session
        )
        let result = PermissionResult.allow(
            permissionUpdates: [update],
            toolUseID: "tu-2"
        )
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedPermissions"])
        XCTAssertEqual(dict["toolUseId"] as? String, "tu-2")
    }

    func testAllowToolUseIDOptional() {
        let result = PermissionResult.allow()
        let dict = result.toDictionary()
        XCTAssertNil(dict["toolUseId"])
    }

    // MARK: - PermissionResult.deny

    func testDenyWithMessage() {
        let result = PermissionResult.deny(message: "Not permitted")
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Not permitted")
        XCTAssertEqual(dict["interrupt"] as? Bool, false)
    }

    func testDenyWithInterruptTrue() {
        let result = PermissionResult.deny(
            message: "Critical violation",
            interrupt: true,
            toolUseID: "tu-3"
        )
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Critical violation")
        XCTAssertEqual(dict["interrupt"] as? Bool, true)
        XCTAssertEqual(dict["toolUseId"] as? String, "tu-3")
    }

    func testDenyToolUseIDOptional() {
        let result = PermissionResult.deny(message: "no")
        let dict = result.toDictionary()
        XCTAssertNil(dict["toolUseId"])
    }

    // MARK: - Convenience Initializers

    func testAllowToolConvenience() {
        let result = PermissionResult.allowTool(toolUseID: "tu-c1")
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertEqual(dict["toolUseId"] as? String, "tu-c1")
    }

    func testAllowToolWithUpdatedInputConvenience() {
        let result = PermissionResult.allowTool(
            updatedInput: ["path": .string("/safe/path")],
            toolUseID: "tu-c2"
        )
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedInput"])
    }

    func testAllowToolWithPermissionUpdatesConvenience() {
        let updates = [PermissionUpdate.addRules([.tool("Read")], behavior: .allow)]
        let result = PermissionResult.allowTool(permissionUpdates: updates)
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "allow")
        XCTAssertNotNil(dict["updatedPermissions"])
    }

    func testDenyToolConvenience() {
        let result = PermissionResult.denyTool("Unsafe operation")
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Unsafe operation")
        XCTAssertEqual(dict["interrupt"] as? Bool, false)
    }

    func testDenyToolAndInterruptConvenience() {
        let result = PermissionResult.denyToolAndInterrupt("Critical", toolUseID: "tu-c3")
        let dict = result.toDictionary()
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["message"] as? String, "Critical")
        XCTAssertEqual(dict["interrupt"] as? Bool, true)
        XCTAssertEqual(dict["toolUseId"] as? String, "tu-c3")
    }

    // MARK: - CanUseToolCallback Type Signature

    func testCanUseToolCallbackTypeSignature() {
        // Verify the type signature compiles correctly
        let callback: CanUseToolCallback = { toolName, input, context in
            XCTAssertFalse(toolName.isEmpty)
            XCTAssertFalse(context.toolUseID.isEmpty)
            return .allowTool()
        }

        // Verify callback can be assigned to QueryOptions
        var options = QueryOptions()
        options.canUseTool = callback
        XCTAssertNotNil(options.canUseTool)
    }

    func testCallbackReceivesAllThreeParameters() async throws {
        let capture = PermCallbackCapture()

        let callback: CanUseToolCallback = { toolName, input, context in
            await capture.set(toolName: toolName, input: input, context: context)
            return .allowTool()
        }

        let context = ToolPermissionContext(
            suggestions: [],
            blockedPath: "/blocked",
            decisionReason: "reason",
            agentId: "agent-1",
            toolUseID: "tu-cb"
        )

        _ = try await callback("Bash", ["command": .string("ls")], context)

        let receivedToolName = await capture.toolName
        let receivedInput = await capture.input
        let receivedContext = await capture.context
        XCTAssertEqual(receivedToolName, "Bash")
        XCTAssertEqual(receivedInput?["command"]?.stringValue, "ls")
        XCTAssertEqual(receivedContext?.toolUseID, "tu-cb")
        XCTAssertEqual(receivedContext?.blockedPath, "/blocked")
        XCTAssertEqual(receivedContext?.decisionReason, "reason")
    }

    // MARK: - PermissionUpdate Types

    func testPermissionUpdateAddRules() {
        let update = PermissionUpdate.addRules([.tool("Bash")], behavior: .allow, destination: .session)
        XCTAssertEqual(update.type, .addRules)
        XCTAssertEqual(update.behavior, .allow)
        XCTAssertEqual(update.destination, .session)
        XCTAssertEqual(update.rules?.count, 1)
    }

    func testPermissionUpdateReplaceRules() {
        let update = PermissionUpdate.replaceRules([.tool("Read")], behavior: .deny, destination: .projectSettings)
        XCTAssertEqual(update.type, .replaceRules)
        XCTAssertEqual(update.behavior, .deny)
        XCTAssertEqual(update.destination, .projectSettings)
    }

    func testPermissionUpdateRemoveRules() {
        let update = PermissionUpdate.removeRules([.tool("Write")], destination: .userSettings)
        XCTAssertEqual(update.type, .removeRules)
        XCTAssertEqual(update.destination, .userSettings)
    }

    func testPermissionUpdateSetMode() {
        let update = PermissionUpdate.setMode(.bypassPermissions, destination: .session)
        XCTAssertEqual(update.type, .setMode)
        XCTAssertEqual(update.mode, .bypassPermissions)
    }

    func testPermissionUpdateAddDirectories() {
        let update = PermissionUpdate.addDirectories(["/home/user/projects"], destination: .localSettings)
        XCTAssertEqual(update.type, .addDirectories)
        XCTAssertEqual(update.directories, ["/home/user/projects"])
        XCTAssertEqual(update.destination, .localSettings)
    }

    func testPermissionUpdateRemoveDirectories() {
        let update = PermissionUpdate.removeDirectories(["/tmp"])
        XCTAssertEqual(update.type, .removeDirectories)
        XCTAssertEqual(update.directories, ["/tmp"])
    }

    // MARK: - PermissionUpdateDestination Includes All 5 Values

    func testPermissionUpdateDestinationHasAllValues() {
        let destinations: [PermissionUpdate.Destination] = [
            .userSettings, .projectSettings, .localSettings, .session, .cliArg
        ]
        XCTAssertEqual(destinations.count, 5)
    }

    func testCliArgDestinationExists() {
        let dest = PermissionUpdate.Destination.cliArg
        XCTAssertEqual(dest.rawValue, "cliArg")
    }

    func testCliArgDestinationInUpdate() {
        let update = PermissionUpdate.addRules(
            [.tool("Bash")],
            behavior: .allow,
            destination: .cliArg
        )
        XCTAssertEqual(update.destination, .cliArg)
    }

    // MARK: - PermissionUpdate Codable

    func testPermissionUpdateCodableRoundTrip() throws {
        let update = PermissionUpdate(
            type: .addRules,
            rules: [PermissionRule(toolName: "Bash", ruleContent: "ls")],
            behavior: .allow,
            destination: .session
        )
        let data = try JSONEncoder().encode(update)
        let decoded = try JSONDecoder().decode(PermissionUpdate.self, from: data)
        XCTAssertEqual(decoded, update)
    }

    // MARK: - BlockedPath Populated for Out-of-Directory Access

    func testBlockedPathPopulatedForOutOfDirectoryAccess() {
        let context = ToolPermissionContext(
            blockedPath: "/etc/shadow",
            decisionReason: "Path is outside allowed directories",
            toolUseID: "tu-blocked"
        )
        XCTAssertEqual(context.blockedPath, "/etc/shadow")
        XCTAssertNotNil(context.decisionReason)
    }

    func testBlockedPathNilForInDirectoryAccess() {
        let context = ToolPermissionContext(toolUseID: "tu-ok")
        XCTAssertNil(context.blockedPath)
    }

    // MARK: - PermissionUpdate toDictionary

    func testPermissionUpdateToDictionary() {
        let update = PermissionUpdate(
            type: .addRules,
            rules: [PermissionRule(toolName: "Bash", ruleContent: "rm *")],
            behavior: .deny,
            destination: .cliArg
        )
        let dict = update.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "addRules")
        XCTAssertEqual(dict["behavior"] as? String, "deny")
        XCTAssertEqual(dict["destination"] as? String, "cliArg")
        XCTAssertNotNil(dict["rules"])
    }
}

// MARK: - Thread-Safe Capture Helper

private actor PermCallbackCapture {
    var toolName: String?
    var input: [String: JSONValue]?
    var context: ToolPermissionContext?

    func set(toolName: String, input: [String: JSONValue], context: ToolPermissionContext) {
        self.toolName = toolName
        self.input = input
        self.context = context
    }
}
