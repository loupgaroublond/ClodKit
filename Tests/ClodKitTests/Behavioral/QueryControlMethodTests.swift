//
//  QueryControlMethodTests.swift
//  ClodKitTests
//
//  Behavioral tests for Query control method contracts (Bead 425).
//

import XCTest
@testable import ClodKit

final class QueryControlMethodTests: XCTestCase {

    // MARK: - SDKControlInitializeResponse

    func testInitializeResponseDecodesAllFields() throws {
        let json = """
        {
            "commands": [
                {"name": "/help", "description": "Show help", "argument_hint": ""}
            ],
            "output_style": "concise",
            "available_output_styles": ["concise", "verbose", "streaming-json"],
            "models": [
                {"value": "claude-sonnet-4-20250514", "display_name": "Claude Sonnet 4", "description": "Fast model"}
            ],
            "account": {
                "email": "user@example.com",
                "organization": "Acme Corp",
                "subscription_type": "pro",
                "token_source": "api_key",
                "api_key_source": "env"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SDKControlInitializeResponse.self, from: data)

        XCTAssertEqual(response.commands.count, 1)
        XCTAssertEqual(response.commands[0].name, "/help")
        XCTAssertEqual(response.commands[0].description, "Show help")
        XCTAssertEqual(response.outputStyle, "concise")
        XCTAssertEqual(response.availableOutputStyles, ["concise", "verbose", "streaming-json"])
        XCTAssertEqual(response.models.count, 1)
        XCTAssertEqual(response.models[0].value, "claude-sonnet-4-20250514")
        XCTAssertEqual(response.models[0].displayName, "Claude Sonnet 4")
        XCTAssertEqual(response.account.email, "user@example.com")
        XCTAssertEqual(response.account.organization, "Acme Corp")
        XCTAssertEqual(response.account.subscriptionType, "pro")
        XCTAssertEqual(response.account.tokenSource, "api_key")
        XCTAssertEqual(response.account.apiKeySource, "env")
    }

    func testInitializeResponseRoundTrip() throws {
        let response = SDKControlInitializeResponse(
            commands: [SlashCommand(name: "/commit", description: "Create a commit", argumentHint: "[message]")],
            outputStyle: "verbose",
            availableOutputStyles: ["verbose"],
            models: [ModelInfo(value: "claude-opus-4-6", displayName: "Claude Opus 4.6", description: "Most capable")],
            account: AccountInfo(email: "test@test.com")
        )
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(SDKControlInitializeResponse.self, from: data)
        XCTAssertEqual(decoded, response)
    }

    // MARK: - McpSetServersResult

    func testMcpSetServersResultDecoding() throws {
        let json = """
        {
            "added": ["server-a", "server-b"],
            "removed": ["server-c"],
            "errors": {"server-d": "Connection refused"}
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(McpSetServersResult.self, from: data)

        XCTAssertEqual(result.added, ["server-a", "server-b"])
        XCTAssertEqual(result.removed, ["server-c"])
        XCTAssertEqual(result.errors["server-d"], "Connection refused")
    }

    func testMcpSetServersResultEmptyDefaults() {
        let result = McpSetServersResult()
        XCTAssertEqual(result.added, [])
        XCTAssertEqual(result.removed, [])
        XCTAssertEqual(result.errors, [:])
    }

    // MARK: - RewindFilesResult

    func testRewindFilesResultDecodesAllFields() throws {
        let json = """
        {
            "can_rewind": true,
            "files_changed": ["src/main.swift", "tests/test.swift"],
            "insertions": 42,
            "deletions": 10
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(RewindFilesResult.self, from: data)

        XCTAssertTrue(result.canRewind)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.filesChanged, ["src/main.swift", "tests/test.swift"])
        XCTAssertEqual(result.insertions, 42)
        XCTAssertEqual(result.deletions, 10)
    }

    func testRewindFilesResultWithError() throws {
        let json = """
        {
            "can_rewind": false,
            "error": "No checkpoint found for the given message ID"
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(RewindFilesResult.self, from: data)

        XCTAssertFalse(result.canRewind)
        XCTAssertEqual(result.error, "No checkpoint found for the given message ID")
        XCTAssertNil(result.filesChanged)
    }

    func testRewindFilesResultRoundTrip() throws {
        let result = RewindFilesResult(
            canRewind: true,
            filesChanged: ["a.swift"],
            insertions: 5,
            deletions: 3
        )
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(RewindFilesResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    // MARK: - FullControlResponsePayload

    func testSuccessResponseDecoding() throws {
        let json = """
        {
            "subtype": "success",
            "request_id": "req-1",
            "response": {"status": "ok"}
        }
        """
        let data = json.data(using: .utf8)!
        let payload = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)

        if case .success(let requestId, let response) = payload {
            XCTAssertEqual(requestId, "req-1")
            XCTAssertNotNil(response)
        } else {
            XCTFail("Expected success payload")
        }
    }

    func testErrorResponseDecoding() throws {
        let json = """
        {
            "subtype": "error",
            "request_id": "req-2",
            "error": "Timeout waiting for response",
            "pending_permission_requests": ["perm-1", "perm-2"]
        }
        """
        let data = json.data(using: .utf8)!
        let payload = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)

        if case .error(let requestId, let error, let pending) = payload {
            XCTAssertEqual(requestId, "req-2")
            XCTAssertEqual(error, "Timeout waiting for response")
            XCTAssertEqual(pending, ["perm-1", "perm-2"])
        } else {
            XCTFail("Expected error payload")
        }
    }

    func testUnknownSubtypeThrows() {
        let json = """
        {
            "subtype": "warning",
            "request_id": "req-3"
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(FullControlResponsePayload.self, from: data))
    }

    func testSuccessResponseRoundTrip() throws {
        let payload = FullControlResponsePayload.success(
            requestId: "req-rt",
            response: .object(["key": .string("value")])
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testErrorResponseRoundTrip() throws {
        let payload = FullControlResponsePayload.error(
            requestId: "req-rt2",
            error: "Something went wrong",
            pendingPermissionRequests: ["p1"]
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(FullControlResponsePayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    func testRequestIdAccessor() {
        let success = FullControlResponsePayload.success(requestId: "r1", response: nil)
        let error = FullControlResponsePayload.error(requestId: "r2", error: "err", pendingPermissionRequests: nil)
        XCTAssertEqual(success.requestId, "r1")
        XCTAssertEqual(error.requestId, "r2")
    }

    // MARK: - ClaudeQuery Control Method Existence

    func testClaudeQueryHasInterruptMethod() {
        // Verify the method exists on ClaudeQuery via compilation
        let f: (ClaudeQuery) -> () async throws -> Void = { q in q.interrupt }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasSetModelMethod() {
        let f: (ClaudeQuery) -> (String?) async throws -> Void = { q in q.setModel }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasSetPermissionModeMethod() {
        let f: (ClaudeQuery) -> (PermissionMode) async throws -> Void = { q in q.setPermissionMode }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasSetMaxThinkingTokensMethod() {
        let f: (ClaudeQuery) -> (Int?) async throws -> Void = { q in q.setMaxThinkingTokens }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasRewindFilesMethod() {
        let f: (ClaudeQuery) -> (String, Bool) async throws -> FullControlResponsePayload = { q in q.rewindFiles }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasMcpStatusMethod() {
        let f: (ClaudeQuery) -> () async throws -> FullControlResponsePayload = { q in q.mcpStatus }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasInitializationResultMethod() {
        let f: (ClaudeQuery) -> () async throws -> SDKControlInitializeResponse = { q in q.initializationResult }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasSetMcpServersMethod() {
        let f: (ClaudeQuery) -> ([String: MCPServerConfig]) async throws -> McpSetServersResult = { q in q.setMcpServers }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasCloseMethod() {
        let f: (ClaudeQuery) -> () async -> Void = { q in q.close }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasReconnectMcpServerMethod() {
        let f: (ClaudeQuery) -> (String) async throws -> Void = { q in { name in try await q.reconnectMcpServer(name: name) } }
        XCTAssertNotNil(f)
    }

    func testClaudeQueryHasToggleMcpServerMethod() {
        let f: (ClaudeQuery) -> (String, Bool) async throws -> Void = { q in { name, enabled in try await q.toggleMcpServer(name: name, enabled: enabled) } }
        XCTAssertNotNil(f)
    }

    // MARK: - SDKUserMessage for streamInput

    func testSDKUserMessageEncoding() throws {
        let msg = SDKUserMessage(content: "Hello Claude")
        let data = try JSONEncoder().encode(msg)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["type"] as? String, "user")
        let message = json["message"] as! [String: Any]
        XCTAssertEqual(message["role"] as? String, "user")
        XCTAssertEqual(message["content"] as? String, "Hello Claude")
    }

    func testSDKUserMessageRoundTrip() throws {
        let msg = SDKUserMessage(content: "Test message")
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(SDKUserMessage.self, from: data)
        XCTAssertEqual(decoded, msg)
    }

    // MARK: - SlashCommand

    func testSlashCommandDecoding() throws {
        let json = """
        {"name": "/review-pr", "description": "Review a PR", "argument_hint": "[PR number]"}
        """
        let data = json.data(using: .utf8)!
        let cmd = try JSONDecoder().decode(SlashCommand.self, from: data)
        XCTAssertEqual(cmd.name, "/review-pr")
        XCTAssertEqual(cmd.description, "Review a PR")
        XCTAssertEqual(cmd.argumentHint, "[PR number]")
    }

    // MARK: - ModelInfo

    func testModelInfoDecoding() throws {
        let json = """
        {"value": "claude-haiku-4-5-20251001", "display_name": "Claude Haiku 4.5", "description": "Fast"}
        """
        let data = json.data(using: .utf8)!
        let model = try JSONDecoder().decode(ModelInfo.self, from: data)
        XCTAssertEqual(model.value, "claude-haiku-4-5-20251001")
        XCTAssertEqual(model.displayName, "Claude Haiku 4.5")
    }

    // MARK: - AccountInfo

    func testAccountInfoOptionalFields() throws {
        let json = """
        {}
        """
        let data = json.data(using: .utf8)!
        let account = try JSONDecoder().decode(AccountInfo.self, from: data)
        XCTAssertNil(account.email)
        XCTAssertNil(account.organization)
        XCTAssertNil(account.subscriptionType)
        XCTAssertNil(account.tokenSource)
        XCTAssertNil(account.apiKeySource)
    }
}
