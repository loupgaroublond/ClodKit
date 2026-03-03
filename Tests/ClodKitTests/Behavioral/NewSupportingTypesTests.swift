//
//  NewSupportingTypesTests.swift
//  ClodKitTests
//
//  JSON round-trip encoding tests for new supporting types added in SDK v0.2.63:
//  FastModeState, ThinkingConfig, SdkBeta, SdkPluginConfig, ElicitationRequest/Result,
//  SDKSessionInfo, SessionMessage, ApiKeySource, PromptRequest/Option/Response,
//  ModelInfo expanded fields, SDKControlInitializeResponse with agents/fastModeState,
//  AgentInfo.
//

import XCTest
@testable import ClodKit

final class NewSupportingTypesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - FastModeState

    func testFastModeStateAllCases() {
        XCTAssertEqual(FastModeState.off.rawValue, "off")
        XCTAssertEqual(FastModeState.cooldown.rawValue, "cooldown")
        XCTAssertEqual(FastModeState.on.rawValue, "on")
    }

    func testFastModeStateRoundTripOff() throws {
        let data = try encoder.encode(FastModeState.off)
        let decoded = try decoder.decode(FastModeState.self, from: data)
        XCTAssertEqual(decoded, .off)
    }

    func testFastModeStateRoundTripCooldown() throws {
        let data = try encoder.encode(FastModeState.cooldown)
        let decoded = try decoder.decode(FastModeState.self, from: data)
        XCTAssertEqual(decoded, .cooldown)
    }

    func testFastModeStateRoundTripOn() throws {
        let data = try encoder.encode(FastModeState.on)
        let decoded = try decoder.decode(FastModeState.self, from: data)
        XCTAssertEqual(decoded, .on)
    }

    func testFastModeStateDecodesFromString() throws {
        let json = "\"cooldown\"".data(using: .utf8)!
        let state = try decoder.decode(FastModeState.self, from: json)
        XCTAssertEqual(state, .cooldown)
    }

    // MARK: - ThinkingConfig

    func testThinkingConfigAdaptiveRoundTrip() throws {
        let config = ThinkingConfig.adaptive
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, .adaptive)
    }

    func testThinkingConfigDisabledRoundTrip() throws {
        let config = ThinkingConfig.disabled
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, .disabled)
    }

    func testThinkingConfigEnabledWithBudgetRoundTrip() throws {
        let config = ThinkingConfig.enabled(budgetTokens: 4096)
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, .enabled(budgetTokens: 4096))
    }

    func testThinkingConfigEnabledWithoutBudgetRoundTrip() throws {
        let config = ThinkingConfig.enabled(budgetTokens: nil)
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(ThinkingConfig.self, from: data)
        XCTAssertEqual(decoded, .enabled(budgetTokens: nil))
    }

    func testThinkingConfigAdaptiveEncodesType() throws {
        let data = try encoder.encode(ThinkingConfig.adaptive)
        let json = try decoder.decode([String: JSONValue].self, from: data)
        XCTAssertEqual(json["type"]?.stringValue, "adaptive")
    }

    func testThinkingConfigEnabledEncodesTypeAndBudget() throws {
        let data = try encoder.encode(ThinkingConfig.enabled(budgetTokens: 8000))
        let json = try decoder.decode([String: JSONValue].self, from: data)
        XCTAssertEqual(json["type"]?.stringValue, "enabled")
        XCTAssertEqual(json["budget_tokens"]?.intValue, 8000)
    }

    func testThinkingConfigDisabledEncodesType() throws {
        let data = try encoder.encode(ThinkingConfig.disabled)
        let json = try decoder.decode([String: JSONValue].self, from: data)
        XCTAssertEqual(json["type"]?.stringValue, "disabled")
    }

    func testThinkingConfigDecodesFromJSON() throws {
        let json = #"{"type": "adaptive"}"#.data(using: .utf8)!
        let config = try decoder.decode(ThinkingConfig.self, from: json)
        XCTAssertEqual(config, .adaptive)
    }

    func testThinkingConfigEnabledDecodesFromJSON() throws {
        let json = #"{"type": "enabled", "budget_tokens": 2048}"#.data(using: .utf8)!
        let config = try decoder.decode(ThinkingConfig.self, from: json)
        XCTAssertEqual(config, .enabled(budgetTokens: 2048))
    }

    func testThinkingConfigUnknownTypeThrows() {
        let json = #"{"type": "unknown"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(ThinkingConfig.self, from: json))
    }

    // MARK: - SdkBeta

    func testSdkBetaContext1mRawValue() {
        XCTAssertEqual(SdkBeta.context1m.rawValue, "context-1m-2025-08-07")
    }

    func testSdkBetaRoundTrip() throws {
        let data = try encoder.encode(SdkBeta.context1m)
        let decoded = try decoder.decode(SdkBeta.self, from: data)
        XCTAssertEqual(decoded, .context1m)
    }

    func testSdkBetaDecodesFromString() throws {
        let json = "\"context-1m-2025-08-07\"".data(using: .utf8)!
        let beta = try decoder.decode(SdkBeta.self, from: json)
        XCTAssertEqual(beta, .context1m)
    }

    // MARK: - ApiKeySource

    func testApiKeySourceKnownCases() throws {
        let knownCases: [ApiKeySource] = [.user, .project, .org, .temporary, .oauth]
        for source in knownCases {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(ApiKeySource.self, from: data)
            XCTAssertEqual(decoded, source)
        }
    }

    func testApiKeySourceUnknownValue() throws {
        let json = "\"env\"".data(using: .utf8)!
        let decoded = try decoder.decode(ApiKeySource.self, from: json)
        XCTAssertEqual(decoded, .unknown("env"))
    }

    func testApiKeySourceDecodesFromStrings() throws {
        let pairs: [(String, ApiKeySource)] = [
            ("user", .user), ("project", .project), ("org", .org),
            ("temporary", .temporary), ("oauth", .oauth)
        ]
        for (raw, expected) in pairs {
            let json = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try decoder.decode(ApiKeySource.self, from: json)
            XCTAssertEqual(decoded, expected)
        }
    }

    // MARK: - SdkPluginConfig

    func testSdkPluginConfigInit() {
        let config = SdkPluginConfig(path: "/path/to/plugin")
        XCTAssertEqual(config.type, "local")
        XCTAssertEqual(config.path, "/path/to/plugin")
    }

    func testSdkPluginConfigCustomType() {
        let config = SdkPluginConfig(type: "remote", path: "/remote/plugin")
        XCTAssertEqual(config.type, "remote")
    }

    func testSdkPluginConfigRoundTrip() throws {
        let config = SdkPluginConfig(path: "/my/plugin")
        let data = try encoder.encode(config)
        let decoded = try decoder.decode(SdkPluginConfig.self, from: data)
        XCTAssertEqual(decoded, config)
    }

    func testSdkPluginConfigDecodesFromJSON() throws {
        let json = #"{"type": "local", "path": "/usr/local/plugins/my-plugin"}"#.data(using: .utf8)!
        let config = try decoder.decode(SdkPluginConfig.self, from: json)
        XCTAssertEqual(config.type, "local")
        XCTAssertEqual(config.path, "/usr/local/plugins/my-plugin")
    }

    // MARK: - ElicitationRequest

    func testElicitationRequestMinimalInit() {
        let req = ElicitationRequest(serverName: "my-server", message: "Enter value")
        XCTAssertEqual(req.serverName, "my-server")
        XCTAssertEqual(req.message, "Enter value")
        XCTAssertNil(req.mode)
        XCTAssertNil(req.url)
        XCTAssertNil(req.elicitationId)
        XCTAssertNil(req.requestedSchema)
    }

    func testElicitationRequestAllFields() {
        let req = ElicitationRequest(
            serverName: "auth-srv",
            message: "Authenticate",
            mode: "url",
            url: "https://example.com/auth",
            elicitationId: "elic-123",
            requestedSchema: .object(["type": .string("object")])
        )
        XCTAssertEqual(req.serverName, "auth-srv")
        XCTAssertEqual(req.mode, "url")
        XCTAssertEqual(req.url, "https://example.com/auth")
        XCTAssertEqual(req.elicitationId, "elic-123")
        XCTAssertNotNil(req.requestedSchema)
    }

    func testElicitationRequestRoundTrip() throws {
        let req = ElicitationRequest(
            serverName: "form-srv",
            message: "Fill out this form",
            mode: "form",
            elicitationId: "elic-rt"
        )
        let data = try encoder.encode(req)
        let decoded = try decoder.decode(ElicitationRequest.self, from: data)
        XCTAssertEqual(decoded, req)
    }

    func testElicitationRequestDecodesFromJSON() throws {
        let json = """
        {
            "server_name": "test-server",
            "message": "Please authenticate",
            "mode": "form",
            "elicitation_id": "elic-json"
        }
        """.data(using: .utf8)!
        let req = try decoder.decode(ElicitationRequest.self, from: json)
        XCTAssertEqual(req.serverName, "test-server")
        XCTAssertEqual(req.message, "Please authenticate")
        XCTAssertEqual(req.mode, "form")
        XCTAssertEqual(req.elicitationId, "elic-json")
    }

    // MARK: - ElicitationResult

    func testElicitationResultAcceptConvenience() {
        let result = ElicitationResult.accept(content: .object(["name": .string("Alice")]))
        XCTAssertEqual(result.action, "accept")
        XCTAssertNotNil(result.content)
    }

    func testElicitationResultDeclineConvenience() {
        let result = ElicitationResult.decline()
        XCTAssertEqual(result.action, "decline")
        XCTAssertNil(result.content)
    }

    func testElicitationResultCancelConvenience() {
        let result = ElicitationResult.cancel()
        XCTAssertEqual(result.action, "cancel")
        XCTAssertNil(result.content)
    }

    func testElicitationResultAcceptRoundTrip() throws {
        let result = ElicitationResult.accept(content: .string("some data"))
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(ElicitationResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testElicitationResultDeclineRoundTrip() throws {
        let result = ElicitationResult.decline()
        let data = try encoder.encode(result)
        let decoded = try decoder.decode(ElicitationResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testElicitationResultDecodesFromJSON() throws {
        let json = #"{"action": "accept", "content": {"name": "Bob"}}"#.data(using: .utf8)!
        let result = try decoder.decode(ElicitationResult.self, from: json)
        XCTAssertEqual(result.action, "accept")
        XCTAssertNotNil(result.content)
    }

    // MARK: - SDKSessionInfo

    func testSDKSessionInfoAllFields() throws {
        let json = """
        {
            "sessionId": "sess-si1",
            "summary": "Fixed the login bug",
            "lastModified": 1740000000.0,
            "fileSize": 4096,
            "customTitle": "Login Fix Session",
            "firstPrompt": "Help me debug the login issue",
            "gitBranch": "fix/login-bug",
            "cwd": "/project"
        }
        """.data(using: .utf8)!
        let info = try decoder.decode(SDKSessionInfo.self, from: json)
        XCTAssertEqual(info.sessionId, "sess-si1")
        XCTAssertEqual(info.summary, "Fixed the login bug")
        XCTAssertEqual(info.lastModified, 1740000000.0)
        XCTAssertEqual(info.fileSize, 4096)
        XCTAssertEqual(info.customTitle, "Login Fix Session")
        XCTAssertEqual(info.firstPrompt, "Help me debug the login issue")
        XCTAssertEqual(info.gitBranch, "fix/login-bug")
        XCTAssertEqual(info.cwd, "/project")
    }

    func testSDKSessionInfoMinimalFields() throws {
        let json = """
        {
            "sessionId": "sess-min",
            "summary": "Quick session",
            "lastModified": 1740000001.0,
            "fileSize": 512
        }
        """.data(using: .utf8)!
        let info = try decoder.decode(SDKSessionInfo.self, from: json)
        XCTAssertEqual(info.sessionId, "sess-min")
        XCTAssertNil(info.customTitle)
        XCTAssertNil(info.firstPrompt)
        XCTAssertNil(info.gitBranch)
        XCTAssertNil(info.cwd)
    }

    func testSDKSessionInfoRoundTrip() throws {
        let info = SDKSessionInfo(
            sessionId: "sess-rt",
            summary: "Round trip session",
            lastModified: 1740000002.0,
            fileSize: 2048,
            customTitle: "Test",
            firstPrompt: "Hello"
        )
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(SDKSessionInfo.self, from: data)
        XCTAssertEqual(decoded, info)
    }

    // MARK: - SessionMessage

    func testSessionMessageAllFields() throws {
        let json = """
        {
            "type": "assistant",
            "uuid": "msg-uuid-1",
            "session_id": "sess-sm1",
            "message": {"role": "assistant", "content": "Hello"},
            "parent_tool_use_id": null
        }
        """.data(using: .utf8)!
        let msg = try decoder.decode(SessionMessage.self, from: json)
        XCTAssertEqual(msg.type, "assistant")
        XCTAssertEqual(msg.uuid, "msg-uuid-1")
        XCTAssertEqual(msg.sessionId, "sess-sm1")
        XCTAssertNil(msg.parentToolUseId)
    }

    func testSessionMessageWithParentToolUseId() throws {
        let json = """
        {
            "type": "tool_result",
            "uuid": "msg-uuid-2",
            "session_id": "sess-sm2",
            "message": {"content": "result data"},
            "parent_tool_use_id": "tu-parent-1"
        }
        """.data(using: .utf8)!
        let msg = try decoder.decode(SessionMessage.self, from: json)
        XCTAssertEqual(msg.type, "tool_result")
        XCTAssertNotNil(msg.parentToolUseId)
    }

    func testSessionMessageRoundTrip() throws {
        let msg = SessionMessage(
            type: "user",
            uuid: "uuid-rt",
            sessionId: "sess-rt",
            message: .string("Hello"),
            parentToolUseId: nil
        )
        let data = try encoder.encode(msg)
        let decoded = try decoder.decode(SessionMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    // MARK: - PromptRequest / PromptRequestOption / PromptResponse

    func testPromptRequestAllFields() throws {
        let req = PromptRequest(
            prompt: "req-1",
            message: "Choose your model",
            options: [
                PromptRequestOption(key: "sonnet", label: "Claude Sonnet", description: "Fast and capable"),
                PromptRequestOption(key: "opus", label: "Claude Opus", description: "Most capable")
            ]
        )
        XCTAssertEqual(req.prompt, "req-1")
        XCTAssertEqual(req.message, "Choose your model")
        XCTAssertEqual(req.options.count, 2)
        XCTAssertEqual(req.options[0].key, "sonnet")
        XCTAssertEqual(req.options[1].label, "Claude Opus")
    }

    func testPromptRequestRoundTrip() throws {
        let req = PromptRequest(
            prompt: "req-rt",
            message: "Select an option",
            options: [PromptRequestOption(key: "yes", label: "Yes")]
        )
        let data = try encoder.encode(req)
        let decoded = try decoder.decode(PromptRequest.self, from: data)
        XCTAssertEqual(decoded, req)
    }

    func testPromptRequestOptionWithoutDescription() {
        let opt = PromptRequestOption(key: "no", label: "No")
        XCTAssertEqual(opt.key, "no")
        XCTAssertEqual(opt.label, "No")
        XCTAssertNil(opt.description)
    }

    func testPromptRequestOptionRoundTrip() throws {
        let opt = PromptRequestOption(key: "maybe", label: "Maybe", description: "It depends")
        let data = try encoder.encode(opt)
        let decoded = try decoder.decode(PromptRequestOption.self, from: data)
        XCTAssertEqual(decoded, opt)
    }

    func testPromptResponseRoundTrip() throws {
        let resp = PromptResponse(promptResponse: "req-1", selected: "sonnet")
        let data = try encoder.encode(resp)
        let decoded = try decoder.decode(PromptResponse.self, from: data)
        XCTAssertEqual(decoded, resp)
    }

    func testPromptResponseDecodesSnakeCase() throws {
        let json = #"{"prompt_response": "req-2", "selected": "opus"}"#.data(using: .utf8)!
        let resp = try decoder.decode(PromptResponse.self, from: json)
        XCTAssertEqual(resp.promptResponse, "req-2")
        XCTAssertEqual(resp.selected, "opus")
    }

    // MARK: - ModelInfo Expanded Fields

    func testModelInfoAllFields() throws {
        let json = """
        {
            "value": "claude-opus-4-6",
            "display_name": "Claude Opus 4.6",
            "description": "Most capable model",
            "supportsEffort": true,
            "supportedEffortLevels": ["low", "medium", "high", "max"],
            "supportsAdaptiveThinking": true
        }
        """.data(using: .utf8)!
        let info = try decoder.decode(ModelInfo.self, from: json)
        XCTAssertEqual(info.value, "claude-opus-4-6")
        XCTAssertEqual(info.displayName, "Claude Opus 4.6")
        XCTAssertEqual(info.description, "Most capable model")
        XCTAssertEqual(info.supportsEffort, true)
        XCTAssertEqual(info.supportedEffortLevels, ["low", "medium", "high", "max"])
        XCTAssertEqual(info.supportsAdaptiveThinking, true)
    }

    func testModelInfoOptionalFieldsDefaultNil() throws {
        let json = """
        {
            "value": "claude-haiku-4-5",
            "display_name": "Claude Haiku 4.5",
            "description": "Fastest model"
        }
        """.data(using: .utf8)!
        let info = try decoder.decode(ModelInfo.self, from: json)
        XCTAssertNil(info.supportsEffort)
        XCTAssertNil(info.supportedEffortLevels)
        XCTAssertNil(info.supportsAdaptiveThinking)
    }

    func testModelInfoRoundTrip() throws {
        let info = ModelInfo(
            value: "claude-sonnet-4-6",
            displayName: "Claude Sonnet 4.6",
            description: "Fast and capable",
            supportsEffort: true,
            supportedEffortLevels: ["low", "high"],
            supportsAdaptiveThinking: false
        )
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(ModelInfo.self, from: data)
        XCTAssertEqual(decoded, info)
    }

    // MARK: - SDKControlInitializeResponse with agents and fastModeState

    func testSDKControlInitializeResponseWithAgents() throws {
        let json = """
        {
            "commands": [],
            "agents": [
                {"name": "Explore", "description": "Explores codebase", "model": "sonnet"},
                {"name": "Commit", "description": "Creates commits"}
            ],
            "output_style": "concise",
            "available_output_styles": ["concise"],
            "models": [
                {"value": "claude-sonnet-4-6", "display_name": "Sonnet", "description": "Fast"}
            ],
            "account": {"email": "test@test.com"},
            "fast_mode_state": "on"
        }
        """.data(using: .utf8)!
        let resp = try decoder.decode(SDKControlInitializeResponse.self, from: json)
        XCTAssertEqual(resp.agents.count, 2)
        XCTAssertEqual(resp.agents[0].name, "Explore")
        XCTAssertEqual(resp.agents[0].model, "sonnet")
        XCTAssertEqual(resp.agents[1].name, "Commit")
        XCTAssertNil(resp.agents[1].model)
        XCTAssertEqual(resp.fastModeState, "on")
    }

    func testSDKControlInitializeResponseWithoutFastModeState() throws {
        let json = """
        {
            "commands": [],
            "agents": [],
            "output_style": "verbose",
            "available_output_styles": ["verbose"],
            "models": [],
            "account": {}
        }
        """.data(using: .utf8)!
        let resp = try decoder.decode(SDKControlInitializeResponse.self, from: json)
        XCTAssertNil(resp.fastModeState)
        XCTAssertTrue(resp.agents.isEmpty)
    }

    func testSDKControlInitializeResponseRoundTrip() throws {
        let resp = SDKControlInitializeResponse(
            commands: [SlashCommand(name: "/help", description: "Help")],
            agents: [AgentInfo(name: "Explore", description: "Explores")],
            outputStyle: "concise",
            availableOutputStyles: ["concise"],
            models: [ModelInfo(value: "claude-sonnet-4-6", displayName: "Sonnet", description: "Fast")],
            account: AccountInfo(email: "user@test.com"),
            fastModeState: "off"
        )
        let data = try encoder.encode(resp)
        let decoded = try decoder.decode(SDKControlInitializeResponse.self, from: data)
        XCTAssertEqual(decoded, resp)
    }

    // MARK: - AgentInfo

    func testAgentInfoWithModel() {
        let info = AgentInfo(name: "Explore", description: "Explores the codebase", model: "sonnet")
        XCTAssertEqual(info.name, "Explore")
        XCTAssertEqual(info.description, "Explores the codebase")
        XCTAssertEqual(info.model, "sonnet")
    }

    func testAgentInfoWithoutModel() {
        let info = AgentInfo(name: "Task", description: "Runs tasks")
        XCTAssertNil(info.model)
    }

    func testAgentInfoRoundTrip() throws {
        let info = AgentInfo(name: "Explore", description: "Explores", model: "opus")
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(AgentInfo.self, from: data)
        XCTAssertEqual(decoded, info)
    }

    func testAgentInfoDecodesFromJSON() throws {
        let json = """
        {"name": "Commit", "description": "Creates git commits", "model": null}
        """.data(using: .utf8)!
        let info = try decoder.decode(AgentInfo.self, from: json)
        XCTAssertEqual(info.name, "Commit")
        XCTAssertNil(info.model)
    }

    // MARK: - AccountInfo with ApiKeySource

    func testAccountInfoWithApiKeySource() throws {
        let json = """
        {
            "email": "user@example.com",
            "organization": "Acme",
            "subscription_type": "pro",
            "token_source": "api_key",
            "api_key_source": "oauth"
        }
        """.data(using: .utf8)!
        let info = try decoder.decode(AccountInfo.self, from: json)
        XCTAssertEqual(info.email, "user@example.com")
        XCTAssertEqual(info.apiKeySource, .oauth)
    }

    func testAccountInfoApiKeySourceRoundTrip() throws {
        let info = AccountInfo(
            email: "a@b.com",
            organization: "Org",
            subscriptionType: "free",
            tokenSource: "oauth",
            apiKeySource: .temporary
        )
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(AccountInfo.self, from: data)
        XCTAssertEqual(decoded, info)
        XCTAssertEqual(decoded.apiKeySource, .temporary)
    }
}
