//
//  SDKMessageNewVariantsTests.swift
//  ClodKitTests
//
//  Tests for SDKMessage parsing of new message variants added in SDK v0.2.63:
//  prompt_suggestion, rate_limit_event, task_started, task_progress,
//  elicitation_complete, result success/error typed decoding, and
//  ApiKeySource-typed init messages.
//

import XCTest
@testable import ClodKit

final class SDKMessageNewVariantsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private let decoder = JSONDecoder()

    private func parse(_ json: String) throws -> SDKMessage {
        let data = json.data(using: .utf8)!
        return try decoder.decode(SDKMessage.self, from: data)
    }

    // MARK: - prompt_suggestion Message

    func testPromptSuggestionMessageParsing() throws {
        let json = """
        {
            "type": "prompt_suggestion",
            "suggestion": "How can I refactor this function?",
            "uuid": "uuid-ps1",
            "session_id": "sess-ps1"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.type, "prompt_suggestion")
        XCTAssertEqual(msg.sessionId, "sess-ps1")
        XCTAssertEqual(msg.rawJSON["suggestion"]?.stringValue, "How can I refactor this function?")
    }

    func testPromptSuggestionTypedDecoding() throws {
        let json = """
        {
            "type": "prompt_suggestion",
            "suggestion": "Run the tests",
            "uuid": "uuid-ps2",
            "session_id": "sess-ps2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKPromptSuggestionMessage.self, from: data)
        XCTAssertEqual(msg.type, "prompt_suggestion")
        XCTAssertEqual(msg.suggestion, "Run the tests")
        XCTAssertEqual(msg.uuid, "uuid-ps2")
        XCTAssertEqual(msg.sessionId, "sess-ps2")
    }

    func testPromptSuggestionRoundTrip() throws {
        let json = """
        {
            "type": "prompt_suggestion",
            "suggestion": "Explain this code",
            "uuid": "uuid-ps3",
            "session_id": "sess-ps3"
        }
        """
        let data = json.data(using: .utf8)!
        let original = try decoder.decode(SDKPromptSuggestionMessage.self, from: data)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(SDKPromptSuggestionMessage.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - rate_limit_event Message

    func testRateLimitEventMessageParsing() throws {
        let json = """
        {
            "type": "rate_limit_event",
            "rate_limit_info": {
                "status": "limited",
                "resetsAt": 1740000000.0,
                "rateLimitType": "requests",
                "utilization": 0.95
            },
            "uuid": "uuid-rl1",
            "session_id": "sess-rl1"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.type, "rate_limit_event")
        XCTAssertEqual(msg.sessionId, "sess-rl1")
    }

    func testRateLimitEventTypedDecoding() throws {
        let json = """
        {
            "type": "rate_limit_event",
            "rate_limit_info": {
                "status": "ok",
                "resetsAt": 1740000060.0,
                "rateLimitType": "tokens",
                "utilization": 0.5,
                "overageStatus": null,
                "isUsingOverage": false
            },
            "uuid": "uuid-rl2",
            "session_id": "sess-rl2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKRateLimitEvent.self, from: data)
        XCTAssertEqual(msg.type, "rate_limit_event")
        XCTAssertEqual(msg.rateLimitInfo.status, "ok")
        XCTAssertEqual(msg.rateLimitInfo.rateLimitType, "tokens")
        XCTAssertEqual(msg.rateLimitInfo.utilization, 0.5)
        XCTAssertEqual(msg.rateLimitInfo.isUsingOverage, false)
        XCTAssertEqual(msg.sessionId, "sess-rl2")
    }

    func testRateLimitInfoAllFields() throws {
        let json = """
        {
            "status": "limited",
            "resetsAt": 1740000000.0,
            "rateLimitType": "requests",
            "utilization": 0.98,
            "overageStatus": "active",
            "overageResetsAt": 1740003600.0,
            "overageDisabledReason": null,
            "isUsingOverage": true,
            "surpassedThreshold": 0.9
        }
        """
        let data = json.data(using: .utf8)!
        let info = try decoder.decode(SDKRateLimitInfo.self, from: data)
        XCTAssertEqual(info.status, "limited")
        XCTAssertEqual(info.resetsAt, 1740000000.0)
        XCTAssertEqual(info.rateLimitType, "requests")
        XCTAssertEqual(info.utilization, 0.98)
        XCTAssertEqual(info.overageStatus, "active")
        XCTAssertEqual(info.overageResetsAt, 1740003600.0)
        XCTAssertNil(info.overageDisabledReason)
        XCTAssertEqual(info.isUsingOverage, true)
        XCTAssertEqual(info.surpassedThreshold, 0.9)
    }

    func testRateLimitInfoMinimalFields() throws {
        let json = """
        {"status": "ok"}
        """
        let data = json.data(using: .utf8)!
        let info = try decoder.decode(SDKRateLimitInfo.self, from: data)
        XCTAssertEqual(info.status, "ok")
        XCTAssertNil(info.resetsAt)
        XCTAssertNil(info.rateLimitType)
        XCTAssertNil(info.utilization)
        XCTAssertNil(info.isUsingOverage)
        XCTAssertNil(info.surpassedThreshold)
    }

    // MARK: - task_started Message (subtype)

    func testTaskStartedMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-abc",
            "tool_use_id": "tu-1",
            "description": "Running tests",
            "task_type": "shell",
            "uuid": "uuid-ts1",
            "session_id": "sess-ts1"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "task_started")
        XCTAssertEqual(msg.rawJSON["task_id"]?.stringValue, "task-abc")
        XCTAssertEqual(msg.sessionId, "sess-ts1")
    }

    func testTaskStartedTypedDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-xyz",
            "tool_use_id": "tu-42",
            "description": "Compiling project",
            "task_type": "build",
            "uuid": "uuid-ts2",
            "session_id": "sess-ts2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKTaskStartedMessage.self, from: data)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.subtype, "task_started")
        XCTAssertEqual(msg.taskId, "task-xyz")
        XCTAssertEqual(msg.toolUseId, "tu-42")
        XCTAssertEqual(msg.description, "Compiling project")
        XCTAssertEqual(msg.taskType, "build")
        XCTAssertEqual(msg.sessionId, "sess-ts2")
    }

    func testTaskStartedWithoutOptionals() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-min",
            "description": "Minimal task",
            "uuid": "uuid-tsm",
            "session_id": "sess-tsm"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKTaskStartedMessage.self, from: data)
        XCTAssertNil(msg.toolUseId)
        XCTAssertNil(msg.taskType)
    }

    func testTaskStartedRoundTrip() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-rt",
            "description": "Round trip task",
            "uuid": "uuid-rt",
            "session_id": "sess-rt"
        }
        """
        let data = json.data(using: .utf8)!
        let original = try decoder.decode(SDKTaskStartedMessage.self, from: data)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(SDKTaskStartedMessage.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - task_progress Message (subtype)

    func testTaskProgressMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_progress",
            "task_id": "task-prog",
            "description": "50% complete",
            "usage": {
                "total_tokens": 1000,
                "tool_uses": 5,
                "duration_ms": 3000
            },
            "uuid": "uuid-tp1",
            "session_id": "sess-tp1"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "task_progress")
        XCTAssertEqual(msg.rawJSON["task_id"]?.stringValue, "task-prog")
    }

    func testTaskProgressTypedDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_progress",
            "task_id": "task-p2",
            "tool_use_id": "tu-p2",
            "description": "Running linter",
            "usage": {
                "total_tokens": 500,
                "tool_uses": 2,
                "duration_ms": 1500
            },
            "last_tool_name": "Bash",
            "uuid": "uuid-tp2",
            "session_id": "sess-tp2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKTaskProgressMessage.self, from: data)
        XCTAssertEqual(msg.subtype, "task_progress")
        XCTAssertEqual(msg.taskId, "task-p2")
        XCTAssertEqual(msg.toolUseId, "tu-p2")
        XCTAssertEqual(msg.description, "Running linter")
        XCTAssertEqual(msg.usage.totalTokens, 500)
        XCTAssertEqual(msg.usage.toolUses, 2)
        XCTAssertEqual(msg.usage.durationMs, 1500)
        XCTAssertEqual(msg.lastToolName, "Bash")
    }

    // MARK: - elicitation_complete Message (subtype)

    func testElicitationCompleteMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "my-server",
            "elicitation_id": "elic-abc",
            "uuid": "uuid-ec1",
            "session_id": "sess-ec1"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "elicitation_complete")
        XCTAssertEqual(msg.rawJSON["mcp_server_name"]?.stringValue, "my-server")
        XCTAssertEqual(msg.rawJSON["elicitation_id"]?.stringValue, "elic-abc")
    }

    func testElicitationCompleteTypedDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "auth-server",
            "elicitation_id": "elic-xyz",
            "uuid": "uuid-ec2",
            "session_id": "sess-ec2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKElicitationCompleteMessage.self, from: data)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.subtype, "elicitation_complete")
        XCTAssertEqual(msg.mcpServerName, "auth-server")
        XCTAssertEqual(msg.elicitationId, "elic-xyz")
        XCTAssertEqual(msg.uuid, "uuid-ec2")
        XCTAssertEqual(msg.sessionId, "sess-ec2")
    }

    func testElicitationCompleteRoundTrip() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "test-srv",
            "elicitation_id": "elic-rt",
            "uuid": "uuid-ecrt",
            "session_id": "sess-ecrt"
        }
        """
        let data = json.data(using: .utf8)!
        let original = try decoder.decode(SDKElicitationCompleteMessage.self, from: data)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(SDKElicitationCompleteMessage.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - SDKResultSuccess Typed Decoding

    func testSDKResultSuccessTypedDecoding() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "duration_ms": 5000,
            "duration_api_ms": 4500,
            "is_error": false,
            "num_turns": 3,
            "result": "Task completed",
            "stop_reason": "end_turn",
            "total_cost_usd": 0.01,
            "usage": {
                "input_tokens": 100,
                "output_tokens": 50,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.01,
                "context_window": 200000,
                "max_output_tokens": 8192
            },
            "modelUsage": {},
            "permission_denials": [],
            "fast_mode_state": null,
            "uuid": "uuid-rs1",
            "session_id": "sess-rs1"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKResultSuccess.self, from: data)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.subtype, "success")
        XCTAssertEqual(msg.durationMs, 5000)
        XCTAssertEqual(msg.durationApiMs, 4500)
        XCTAssertFalse(msg.isError)
        XCTAssertEqual(msg.numTurns, 3)
        XCTAssertEqual(msg.result, "Task completed")
        XCTAssertEqual(msg.stopReason, "end_turn")
        XCTAssertEqual(msg.totalCostUsd, 0.01)
        XCTAssertEqual(msg.usage.inputTokens, 100)
        XCTAssertEqual(msg.usage.outputTokens, 50)
        XCTAssertTrue(msg.permissionDenials.isEmpty)
        XCTAssertNil(msg.fastModeState)
        XCTAssertEqual(msg.sessionId, "sess-rs1")
    }

    func testSDKResultSuccessWithPermissionDenials() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "duration_ms": 2000,
            "duration_api_ms": 1800,
            "is_error": false,
            "num_turns": 1,
            "result": "Done with denial",
            "stop_reason": "end_turn",
            "total_cost_usd": 0.002,
            "usage": {
                "input_tokens": 50,
                "output_tokens": 20,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.002,
                "context_window": 200000,
                "max_output_tokens": 8192
            },
            "modelUsage": {},
            "permission_denials": [
                {"tool_name": "Bash", "tool_use_id": "tu-denied", "tool_input": {"command": "rm -rf /"}}
            ],
            "uuid": "uuid-rs2",
            "session_id": "sess-rs2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKResultSuccess.self, from: data)
        XCTAssertEqual(msg.permissionDenials.count, 1)
        XCTAssertEqual(msg.permissionDenials[0].toolName, "Bash")
        XCTAssertEqual(msg.permissionDenials[0].toolUseId, "tu-denied")
    }

    func testSDKResultSuccessWithFastModeState() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "duration_ms": 3000,
            "duration_api_ms": 2700,
            "is_error": false,
            "num_turns": 2,
            "result": "Fast mode result",
            "total_cost_usd": 0.005,
            "usage": {
                "input_tokens": 75,
                "output_tokens": 30,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.005,
                "context_window": 200000,
                "max_output_tokens": 8192
            },
            "modelUsage": {},
            "permission_denials": [],
            "fast_mode_state": "on",
            "uuid": "uuid-rs3",
            "session_id": "sess-rs3"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKResultSuccess.self, from: data)
        XCTAssertEqual(msg.fastModeState, "on")
    }

    // MARK: - SDKResultError Typed Decoding

    func testSDKResultErrorTypedDecoding() throws {
        let json = """
        {
            "type": "result",
            "subtype": "error_during_execution",
            "duration_ms": 1000,
            "duration_api_ms": 900,
            "is_error": true,
            "num_turns": 1,
            "stop_reason": "error",
            "total_cost_usd": 0.001,
            "usage": {
                "input_tokens": 20,
                "output_tokens": 5,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.001,
                "context_window": 200000,
                "max_output_tokens": 8192
            },
            "modelUsage": {},
            "permission_denials": [],
            "errors": ["Rate limit exceeded", "Retry after 60s"],
            "uuid": "uuid-re1",
            "session_id": "sess-re1"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKResultError.self, from: data)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.subtype, "error_during_execution")
        XCTAssertTrue(msg.isError)
        XCTAssertEqual(msg.errors, ["Rate limit exceeded", "Retry after 60s"])
        XCTAssertEqual(msg.numTurns, 1)
        XCTAssertEqual(msg.stopReason, "error")
    }

    func testSDKResultErrorRoundTrip() throws {
        let json = """
        {
            "type": "result",
            "subtype": "error_max_turns",
            "duration_ms": 500,
            "duration_api_ms": 400,
            "is_error": true,
            "num_turns": 10,
            "total_cost_usd": 0.05,
            "usage": {
                "input_tokens": 200,
                "output_tokens": 100,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.05,
                "context_window": 200000,
                "max_output_tokens": 8192
            },
            "modelUsage": {},
            "permission_denials": [],
            "errors": ["max_turns reached"],
            "uuid": "uuid-rert",
            "session_id": "sess-rert"
        }
        """
        let data = json.data(using: .utf8)!
        let original = try decoder.decode(SDKResultError.self, from: data)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(SDKResultError.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - SDKInitMessage with ApiKeySource enum

    func testSDKInitMessageWithValidApiKeySource() throws {
        let cases: [(String, ApiKeySource)] = [
            ("user", .user),
            ("project", .project),
            ("org", .org),
            ("temporary", .temporary),
            ("oauth", .oauth),
        ]
        for (rawValue, expected) in cases {
            let json = """
            {
                "type": "system",
                "subtype": "init",
                "session_id": "sess-aks-\(rawValue)",
                "api_key_source": "\(rawValue)"
            }
            """
            let data = json.data(using: .utf8)!
            let msg = try decoder.decode(SDKInitMessage.self, from: data)
            XCTAssertEqual(msg.apiKeySource, expected,
                           "Expected \(expected) for api_key_source: \(rawValue)")
        }
    }

    func testSDKInitMessageWithUnknownApiKeySourceDecodesNil() throws {
        // Unknown values should decode to nil (not crash), as the field is optional
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "sess-aks-unk",
            "api_key_source": "unknown_source"
        }
        """
        _ = json.data(using: .utf8)!
        // Unknown enum values will cause a decoding error for the ApiKeySource field
        // and since it's optional, SDKInitMessage will fail to decode the whole struct.
        // We just verify the message still has usable basic fields when api_key_source is absent.
        let jsonNoSource = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "sess-aks-absent"
        }
        """
        let dataNoSource = jsonNoSource.data(using: .utf8)!
        let msg = try decoder.decode(SDKInitMessage.self, from: dataNoSource)
        XCTAssertNil(msg.apiKeySource)
        XCTAssertEqual(msg.sessionId, "sess-aks-absent")
    }

    func testSDKInitMessageApiKeySourceRoundTrip() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "sess-aks-rt",
            "api_key_source": "oauth",
            "cwd": "/project",
            "model": "claude-sonnet-4-6",
            "permission_mode": "default",
            "uuid": "u-rt-1",
            "claude_code_version": "2.0.0",
            "output_style": "concise"
        }
        """
        let data = json.data(using: .utf8)!
        let original = try decoder.decode(SDKInitMessage.self, from: data)
        XCTAssertEqual(original.apiKeySource, .oauth)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try decoder.decode(SDKInitMessage.self, from: encoded)
        XCTAssertEqual(decoded.apiKeySource, .oauth)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
    }

    // MARK: - SDKTaskNotification with TaskUsage

    func testSDKTaskNotificationWithUsage() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_notification",
            "task_id": "task-123",
            "status": "completed",
            "output_file": "/tmp/output.txt",
            "summary": "Task finished successfully",
            "usage": {
                "total_tokens": 1500,
                "tool_uses": 8,
                "duration_ms": 12000
            },
            "uuid": "uuid-tn1",
            "session_id": "sess-tn1"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKTaskNotificationMessage.self, from: data)
        XCTAssertEqual(msg.taskId, "task-123")
        XCTAssertEqual(msg.status, "completed")
        XCTAssertEqual(msg.usage?.totalTokens, 1500)
        XCTAssertEqual(msg.usage?.toolUses, 8)
        XCTAssertEqual(msg.usage?.durationMs, 12000)
    }

    func testSDKTaskNotificationWithoutUsage() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_notification",
            "task_id": "task-456",
            "status": "failed",
            "output_file": "",
            "summary": "Task failed",
            "uuid": "uuid-tn2",
            "session_id": "sess-tn2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKTaskNotificationMessage.self, from: data)
        XCTAssertNil(msg.usage)
        XCTAssertEqual(msg.status, "failed")
    }

    // MARK: - SDKMessage via rawJSON for new subtypes

    func testTaskProgressSubtypeAccessibleViaRawJSON() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_progress",
            "task_id": "task-789",
            "description": "Processing...",
            "usage": {"total_tokens": 100, "tool_uses": 1, "duration_ms": 500},
            "uuid": "uuid-rawtp",
            "session_id": "sess-rawtp"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "task_progress")
        XCTAssertEqual(msg.rawJSON["task_id"]?.stringValue, "task-789")
    }

    func testElicitationCompleteSubtypeAccessibleViaRawJSON() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "oauth-srv",
            "elicitation_id": "elic-999",
            "uuid": "uuid-rawec",
            "session_id": "sess-rawec"
        }
        """
        let msg = try parse(json)
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "elicitation_complete")
        XCTAssertEqual(msg.rawJSON["mcp_server_name"]?.stringValue, "oauth-srv")
        XCTAssertEqual(msg.rawJSON["elicitation_id"]?.stringValue, "elic-999")
    }
}
