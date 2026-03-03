//
//  QueryOptionsExpansionTests.swift
//  ClodKitTests
//
//  Behavioral tests for new QueryOptions fields, ThinkingConfig, SdkPluginConfig,
//  ToolsConfig, ElicitationRequest/Result, SandboxFilesystemConfig, and
//  PermissionUpdate directory variants (Bead dge4).
//

import XCTest
@testable import ClodKit

// MARK: - New QueryOptions Fields

final class QueryOptionsExpansionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testExecutableArgsFieldExists() {
        var options = QueryOptions()
        options.executableArgs = ["--inspect", "--max-old-space-size=4096"]
        XCTAssertEqual(options.executableArgs, ["--inspect", "--max-old-space-size=4096"])
    }

    func testExtraArgsFieldExists() {
        var options = QueryOptions()
        options.extraArgs = ["verbose": nil, "output": "json"]
        XCTAssertNotNil(options.extraArgs)
        XCTAssertEqual(options.extraArgs?.count, 2)
        // nil value for boolean flags
        XCTAssertEqual(options.extraArgs?["verbose"], .some(nil))
        // string value for key-value args
        XCTAssertEqual(options.extraArgs?["output"], .some("json"))
    }

    func testFallbackModelFieldExists() {
        var options = QueryOptions()
        options.fallbackModel = "claude-haiku-4"
        XCTAssertEqual(options.fallbackModel, "claude-haiku-4")
    }

    func testThinkingFieldExists() {
        var options = QueryOptions()
        options.thinking = .adaptive
        XCTAssertEqual(options.thinking, .adaptive)
    }

    func testEffortFieldExists() {
        var options = QueryOptions()
        options.effort = "high"
        XCTAssertEqual(options.effort, "high")
    }

    func testPluginsFieldExists() {
        var options = QueryOptions()
        options.plugins = [SdkPluginConfig(path: "./my-plugin")]
        XCTAssertEqual(options.plugins?.count, 1)
    }

    func testPromptSuggestionsFieldExists() {
        var options = QueryOptions()
        options.promptSuggestions = true
        XCTAssertEqual(options.promptSuggestions, true)
    }

    func testResumeSessionAtFieldExists() {
        var options = QueryOptions()
        options.resumeSessionAt = "550e8400-e29b-41d4-a716-446655440000"
        XCTAssertEqual(options.resumeSessionAt, "550e8400-e29b-41d4-a716-446655440000")
    }

    func testSettingSourcesFieldExists() {
        var options = QueryOptions()
        options.settingSources = ["user", "project"]
        XCTAssertEqual(options.settingSources, ["user", "project"])
    }

    func testStrictMcpConfigFieldExists() {
        var options = QueryOptions()
        options.strictMcpConfig = true
        XCTAssertEqual(options.strictMcpConfig, true)
    }

    func testIncludePartialMessagesFieldExists() {
        var options = QueryOptions()
        options.includePartialMessages = true
        XCTAssertEqual(options.includePartialMessages, true)
    }

    func testOnElicitationFieldExists() {
        var options = QueryOptions()
        let callback: @Sendable (ElicitationRequest) async throws -> ElicitationResult = { _ in
            .accept()
        }
        options.onElicitation = callback
        XCTAssertNotNil(options.onElicitation)
    }

    func testDisallowedToolsFieldExists() {
        var options = QueryOptions()
        options.disallowedTools = ["WebSearch", "WebFetch"]
        XCTAssertEqual(options.disallowedTools, ["WebSearch", "WebFetch"])
    }

    func testToolsFieldExistsAsListVariant() {
        var options = QueryOptions()
        options.tools = .list(["Bash", "Read", "Write"])
        XCTAssertEqual(options.tools, .list(["Bash", "Read", "Write"]))
    }

    func testToolsFieldExistsAsPresetVariant() {
        var options = QueryOptions()
        options.tools = .claudeCodePreset
        XCTAssertEqual(options.tools, .claudeCodePreset)
    }

    // MARK: - Default Values for New Fields

    func testNewFieldsDefaultToNil() {
        let options = QueryOptions()
        XCTAssertNil(options.executableArgs)
        XCTAssertNil(options.extraArgs)
        XCTAssertNil(options.fallbackModel)
        XCTAssertNil(options.thinking)
        XCTAssertNil(options.effort)
        XCTAssertNil(options.plugins)
        XCTAssertNil(options.promptSuggestions)
        XCTAssertNil(options.resumeSessionAt)
        XCTAssertNil(options.settingSources)
        XCTAssertNil(options.strictMcpConfig)
        XCTAssertNil(options.includePartialMessages)
        XCTAssertNil(options.onElicitation)
        XCTAssertNil(options.disallowedTools)
        XCTAssertNil(options.tools)
    }
}

// MARK: - ThinkingConfig

final class ThinkingConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testAdaptiveVariantEncoding() throws {
        let config = ThinkingConfig.adaptive
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "adaptive")
        XCTAssertNil(json["budget_tokens"])
    }

    func testEnabledVariantWithBudgetEncoding() throws {
        let config = ThinkingConfig.enabled(budgetTokens: 8000)
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "enabled")
        XCTAssertEqual(json["budget_tokens"] as? Int, 8000)
    }

    func testEnabledVariantWithoutBudgetEncoding() throws {
        let config = ThinkingConfig.enabled(budgetTokens: nil)
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "enabled")
        XCTAssertNil(json["budget_tokens"])
    }

    func testDisabledVariantEncoding() throws {
        let config = ThinkingConfig.disabled
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "disabled")
    }

    func testAdaptiveRoundTrip() throws {
        let original = ThinkingConfig.adaptive
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEnabledRoundTrip() throws {
        let original = ThinkingConfig.enabled(budgetTokens: 16000)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDisabledRoundTrip() throws {
        let original = ThinkingConfig.disabled
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testUnknownTypeThrows() throws {
        let json = #"{"type":"unknown"}"#
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ThinkingConfig.self, from: data))
    }

    func testAllThreeVariantsAreDistinct() {
        XCTAssertNotEqual(ThinkingConfig.adaptive, ThinkingConfig.disabled)
        XCTAssertNotEqual(ThinkingConfig.adaptive, ThinkingConfig.enabled(budgetTokens: nil))
        XCTAssertNotEqual(ThinkingConfig.disabled, ThinkingConfig.enabled(budgetTokens: 1000))
    }
}

// MARK: - SdkPluginConfig

final class SdkPluginConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testDefaultTypeIsLocal() {
        let config = SdkPluginConfig(path: "./my-plugin")
        XCTAssertEqual(config.type, "local")
        XCTAssertEqual(config.path, "./my-plugin")
    }

    func testAbsolutePathPreserved() {
        let config = SdkPluginConfig(path: "/absolute/path/to/plugin")
        XCTAssertEqual(config.path, "/absolute/path/to/plugin")
    }

    func testCodableRoundTrip() throws {
        let original = SdkPluginConfig(type: "local", path: "./plugins/my-tool")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SdkPluginConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEncodesTypeAndPath() throws {
        let config = SdkPluginConfig(path: "./test-plugin")
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "local")
        XCTAssertEqual(json["path"] as? String, "./test-plugin")
    }

    func testEquality() {
        let a = SdkPluginConfig(path: "./plugin")
        let b = SdkPluginConfig(path: "./plugin")
        let c = SdkPluginConfig(path: "./other")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - ToolsConfig

final class ToolsConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testListVariant() {
        let config = ToolsConfig.list(["Bash", "Read", "Write"])
        if case .list(let tools) = config {
            XCTAssertEqual(tools, ["Bash", "Read", "Write"])
        } else {
            XCTFail("Expected .list variant")
        }
    }

    func testPresetVariant() {
        let config = ToolsConfig.claudeCodePreset
        if case .claudeCodePreset = config {
            // passes
        } else {
            XCTFail("Expected .claudeCodePreset variant")
        }
    }

    func testEmptyListVariant() {
        let config = ToolsConfig.list([])
        if case .list(let tools) = config {
            XCTAssertTrue(tools.isEmpty)
        } else {
            XCTFail("Expected .list variant")
        }
    }

    func testListEquality() {
        let a = ToolsConfig.list(["Bash"])
        let b = ToolsConfig.list(["Bash"])
        let c = ToolsConfig.list(["Read"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testPresetEquality() {
        XCTAssertEqual(ToolsConfig.claudeCodePreset, ToolsConfig.claudeCodePreset)
    }

    func testListAndPresetNotEqual() {
        XCTAssertNotEqual(ToolsConfig.list(["Bash"]), ToolsConfig.claudeCodePreset)
    }
}

// MARK: - ElicitationRequest

final class ElicitationRequestTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testMinimalInitialization() {
        let request = ElicitationRequest(serverName: "my-server", message: "Please enter your name")
        XCTAssertEqual(request.serverName, "my-server")
        XCTAssertEqual(request.message, "Please enter your name")
        XCTAssertNil(request.mode)
        XCTAssertNil(request.url)
        XCTAssertNil(request.elicitationId)
        XCTAssertNil(request.requestedSchema)
    }

    func testFormModeInitialization() {
        let schema = JSONValue.object(["name": .object(["type": .string("string")])])
        let request = ElicitationRequest(
            serverName: "auth-server",
            message: "Please fill in the form",
            mode: "form",
            requestedSchema: schema
        )
        XCTAssertEqual(request.mode, "form")
        XCTAssertEqual(request.requestedSchema, schema)
    }

    func testUrlModeInitialization() {
        let request = ElicitationRequest(
            serverName: "oauth-server",
            message: "Please authenticate",
            mode: "url",
            url: "https://auth.example.com/oauth",
            elicitationId: "elicit-123"
        )
        XCTAssertEqual(request.mode, "url")
        XCTAssertEqual(request.url, "https://auth.example.com/oauth")
        XCTAssertEqual(request.elicitationId, "elicit-123")
    }

    func testCodingKeysUseSnakeCase() throws {
        let request = ElicitationRequest(
            serverName: "srv",
            message: "msg",
            mode: "form",
            elicitationId: "eid-1"
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["server_name"])
        XCTAssertNotNil(json["message"])
        XCTAssertNotNil(json["mode"])
        XCTAssertNotNil(json["elicitation_id"])
        XCTAssertNil(json["serverName"])
        XCTAssertNil(json["elicitationId"])
    }

    func testCodableRoundTrip() throws {
        let original = ElicitationRequest(
            serverName: "test-server",
            message: "Enter value",
            mode: "form",
            url: nil,
            elicitationId: "abc-123",
            requestedSchema: .object(["field": .string("value")])
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ElicitationRequest.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ElicitationResult

final class ElicitationResultTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testAcceptConvenience() {
        let result = ElicitationResult.accept()
        XCTAssertEqual(result.action, "accept")
        XCTAssertNil(result.content)
    }

    func testAcceptWithContent() {
        let content = JSONValue.object(["name": .string("Alice")])
        let result = ElicitationResult.accept(content: content)
        XCTAssertEqual(result.action, "accept")
        XCTAssertEqual(result.content, content)
    }

    func testDeclineConvenience() {
        let result = ElicitationResult.decline()
        XCTAssertEqual(result.action, "decline")
        XCTAssertNil(result.content)
    }

    func testCancelConvenience() {
        let result = ElicitationResult.cancel()
        XCTAssertEqual(result.action, "cancel")
        XCTAssertNil(result.content)
    }

    func testCodableRoundTrip() throws {
        let content = JSONValue.object(["answer": .string("yes")])
        let original = ElicitationResult.accept(content: content)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ElicitationResult.self, from: data)
        XCTAssertEqual(decoded.action, "accept")
        XCTAssertEqual(decoded.content, content)
    }

    func testDeclineRoundTrip() throws {
        let original = ElicitationResult.decline()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ElicitationResult.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEquality() {
        XCTAssertEqual(ElicitationResult.decline(), ElicitationResult.decline())
        XCTAssertNotEqual(ElicitationResult.accept(), ElicitationResult.decline())
        XCTAssertNotEqual(ElicitationResult.cancel(), ElicitationResult.decline())
    }
}

// MARK: - SandboxFilesystemConfig

final class SandboxFilesystemConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testAllFieldsOptional() {
        let config = SandboxFilesystemConfig()
        XCTAssertNil(config.allowWrite)
        XCTAssertNil(config.denyWrite)
        XCTAssertNil(config.denyRead)
    }

    func testAllowWritePaths() {
        let config = SandboxFilesystemConfig(allowWrite: ["/tmp", "/var/log"])
        XCTAssertEqual(config.allowWrite, ["/tmp", "/var/log"])
    }

    func testDenyWritePaths() {
        let config = SandboxFilesystemConfig(denyWrite: ["/etc", "/sys"])
        XCTAssertEqual(config.denyWrite, ["/etc", "/sys"])
    }

    func testDenyReadPaths() {
        let config = SandboxFilesystemConfig(denyRead: ["/root", "/private"])
        XCTAssertEqual(config.denyRead, ["/root", "/private"])
    }

    func testCodingKeysUseSnakeCase() throws {
        let config = SandboxFilesystemConfig(
            allowWrite: ["/tmp"],
            denyWrite: ["/etc"],
            denyRead: ["/root"]
        )
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(json["allow_write"])
        XCTAssertNotNil(json["deny_write"])
        XCTAssertNotNil(json["deny_read"])
        XCTAssertNil(json["allowWrite"])
        XCTAssertNil(json["denyWrite"])
        XCTAssertNil(json["denyRead"])
    }

    func testCodableRoundTrip() throws {
        let original = SandboxFilesystemConfig(
            allowWrite: ["/tmp", "/home/user"],
            denyWrite: ["/etc", "/sys"],
            denyRead: ["/root"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SandboxFilesystemConfig.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEmptyConfigEncodesAsEmptyObject() throws {
        let config = SandboxFilesystemConfig()
        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertTrue(json.isEmpty)
    }

    func testFilesystemIntegratedInSandboxSettings() {
        var settings = SandboxSettings()
        settings.filesystem = SandboxFilesystemConfig(allowWrite: ["/tmp"])
        XCTAssertEqual(settings.filesystem?.allowWrite, ["/tmp"])
    }

    func testSandboxSettingsRoundTripWithFilesystem() throws {
        var settings = SandboxSettings()
        settings.enabled = true
        settings.filesystem = SandboxFilesystemConfig(
            allowWrite: ["/tmp"],
            denyRead: ["/private"]
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SandboxSettings.self, from: data)
        XCTAssertEqual(decoded.filesystem?.allowWrite, ["/tmp"])
        XCTAssertEqual(decoded.filesystem?.denyRead, ["/private"])
        XCTAssertNil(decoded.filesystem?.denyWrite)
    }
}

// MARK: - PermissionUpdate Directory Variants

final class PermissionUpdateDirectoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    func testAddDirectoriesUpdateType() {
        let update = PermissionUpdate.addDirectories(["/tmp", "/var"])
        XCTAssertEqual(update.type, .addDirectories)
        XCTAssertEqual(update.directories, ["/tmp", "/var"])
        XCTAssertNil(update.rules)
        XCTAssertNil(update.mode)
    }

    func testRemoveDirectoriesUpdateType() {
        let update = PermissionUpdate.removeDirectories(["/tmp"])
        XCTAssertEqual(update.type, .removeDirectories)
        XCTAssertEqual(update.directories, ["/tmp"])
    }

    func testAddDirectoriesDefaultDestinationIsSession() {
        let update = PermissionUpdate.addDirectories(["/tmp"])
        XCTAssertEqual(update.destination, .session)
    }

    func testRemoveDirectoriesDefaultDestinationIsSession() {
        let update = PermissionUpdate.removeDirectories(["/tmp"])
        XCTAssertEqual(update.destination, .session)
    }

    func testAddDirectoriesWithCustomDestination() {
        let update = PermissionUpdate.addDirectories(["/projects"], destination: .userSettings)
        XCTAssertEqual(update.destination, .userSettings)
        XCTAssertEqual(update.directories, ["/projects"])
    }

    func testRemoveDirectoriesWithCustomDestination() {
        let update = PermissionUpdate.removeDirectories(["/old"], destination: .projectSettings)
        XCTAssertEqual(update.destination, .projectSettings)
    }

    func testAddDirectoriesCodableRoundTrip() throws {
        let original = PermissionUpdate.addDirectories(["/tmp", "/home/user"])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PermissionUpdate.self, from: data)
        XCTAssertEqual(decoded.type, .addDirectories)
        XCTAssertEqual(decoded.directories, ["/tmp", "/home/user"])
    }

    func testRemoveDirectoriesCodableRoundTrip() throws {
        let original = PermissionUpdate.removeDirectories(["/var/log"], destination: .localSettings)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PermissionUpdate.self, from: data)
        XCTAssertEqual(decoded.type, .removeDirectories)
        XCTAssertEqual(decoded.directories, ["/var/log"])
        XCTAssertEqual(decoded.destination, .localSettings)
    }

    func testAddDirectoriesToDictionaryContainsType() {
        let update = PermissionUpdate.addDirectories(["/tmp"])
        let dict = update.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "addDirectories")
        XCTAssertEqual(dict["directories"] as? [String], ["/tmp"])
    }

    func testRemoveDirectoriesToDictionaryContainsType() {
        let update = PermissionUpdate.removeDirectories(["/old"])
        let dict = update.toDictionary()
        XCTAssertEqual(dict["type"] as? String, "removeDirectories")
        XCTAssertEqual(dict["directories"] as? [String], ["/old"])
    }

    func testAllSixUpdateTypesExist() {
        // Verify the UpdateType enum has all 6 cases
        let types: [PermissionUpdate.UpdateType] = [
            .addRules, .replaceRules, .removeRules,
            .setMode, .addDirectories, .removeDirectories,
        ]
        XCTAssertEqual(types.count, 6)
    }

    func testUpdateTypeRawValues() {
        XCTAssertEqual(PermissionUpdate.UpdateType.addDirectories.rawValue, "addDirectories")
        XCTAssertEqual(PermissionUpdate.UpdateType.removeDirectories.rawValue, "removeDirectories")
    }

    func testEmptyDirectoriesList() {
        let update = PermissionUpdate.addDirectories([])
        XCTAssertEqual(update.directories, [])
        XCTAssertEqual(update.type, .addDirectories)
    }
}
