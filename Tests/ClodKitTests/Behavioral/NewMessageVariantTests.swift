//
//  NewMessageVariantTests.swift
//  ClodKitTests
//
//  Behavioral tests for new SDKMessage variants and updated types (Bead ClodeMonster-4mej).
//

import XCTest
@testable import ClodKit

final class NewMessageVariantTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - SDKElicitationCompleteMessage

    func testElicitationCompleteDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "my-mcp-server",
            "elicitation_id": "elicit-42",
            "uuid": "uuid-elicit-1",
            "session_id": "sess-elicit-1"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKElicitationCompleteMessage.self, from: json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.subtype, "elicitation_complete")
        XCTAssertEqual(msg.mcpServerName, "my-mcp-server")
        XCTAssertEqual(msg.elicitationId, "elicit-42")
        XCTAssertEqual(msg.uuid, "uuid-elicit-1")
        XCTAssertEqual(msg.sessionId, "sess-elicit-1")
    }

    func testElicitationCompleteRoundTrip() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "test-server",
            "elicitation_id": "elicit-99",
            "uuid": "uuid-rt-1",
            "session_id": "sess-rt-1"
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKElicitationCompleteMessage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKElicitationCompleteMessage.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.subtype, original.subtype)
        XCTAssertEqual(decoded.mcpServerName, original.mcpServerName)
        XCTAssertEqual(decoded.elicitationId, original.elicitationId)
        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
    }

    func testElicitationCompleteSnakeCaseCodingKeys() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "snake-test",
            "elicitation_id": "snake-id",
            "uuid": "u1",
            "session_id": "s1"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKElicitationCompleteMessage.self, from: json)
        XCTAssertEqual(msg.mcpServerName, "snake-test")
        XCTAssertEqual(msg.elicitationId, "snake-id")
        XCTAssertEqual(msg.sessionId, "s1")
    }

    func testElicitationCompleteViaSDKMessageRawJSON() throws {
        let json = """
        {
            "type": "system",
            "subtype": "elicitation_complete",
            "mcp_server_name": "via-sdk-msg",
            "elicitation_id": "e1",
            "uuid": "u2",
            "session_id": "s2"
        }
        """.data(using: .utf8)!

        let sdkMsg = try decoder.decode(SDKMessage.self, from: json)
        XCTAssertEqual(sdkMsg.type, "system")
        XCTAssertEqual(sdkMsg.rawJSON["subtype"]?.stringValue, "elicitation_complete")
        XCTAssertEqual(sdkMsg.rawJSON["mcp_server_name"]?.stringValue, "via-sdk-msg")
    }

    // MARK: - SDKPromptSuggestionMessage

    func testPromptSuggestionDecoding() throws {
        let json = """
        {
            "type": "prompt_suggestion",
            "suggestion": "What files are in the project?",
            "uuid": "uuid-ps-1",
            "session_id": "sess-ps-1"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKPromptSuggestionMessage.self, from: json)
        XCTAssertEqual(msg.type, "prompt_suggestion")
        XCTAssertEqual(msg.suggestion, "What files are in the project?")
        XCTAssertEqual(msg.uuid, "uuid-ps-1")
        XCTAssertEqual(msg.sessionId, "sess-ps-1")
    }

    func testPromptSuggestionRoundTrip() throws {
        let json = """
        {
            "type": "prompt_suggestion",
            "suggestion": "How many tests are there?",
            "uuid": "uuid-rt-ps",
            "session_id": "sess-rt-ps"
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKPromptSuggestionMessage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKPromptSuggestionMessage.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.suggestion, original.suggestion)
        XCTAssertEqual(decoded.uuid, original.uuid)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
    }

    func testPromptSuggestionViaSDKMessageRawJSON() throws {
        let json = """
        {
            "type": "prompt_suggestion",
            "suggestion": "Run the tests",
            "uuid": "u3",
            "session_id": "s3"
        }
        """.data(using: .utf8)!

        let sdkMsg = try decoder.decode(SDKMessage.self, from: json)
        XCTAssertEqual(sdkMsg.type, "prompt_suggestion")
        XCTAssertEqual(sdkMsg.rawJSON["suggestion"]?.stringValue, "Run the tests")
    }

    // MARK: - SDKAssistantMessageError - maxOutputTokens

    func testAssistantMessageErrorMaxOutputTokensCase() throws {
        let json = """
        {"type": "assistant", "error": "max_output_tokens"}
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKMessage.self, from: json)
        XCTAssertEqual(msg.error, .maxOutputTokens)
    }

    func testAssistantMessageErrorAllCases() {
        let allCases: [SDKAssistantMessageError] = [
            .authenticationFailed, .billingError, .rateLimit, .invalidRequest,
            .serverError, .maxOutputTokens, .unknown
        ]
        XCTAssertEqual(allCases.count, 7)
    }

    func testAssistantMessageErrorMaxOutputTokensRawValue() {
        XCTAssertEqual(SDKAssistantMessageError.maxOutputTokens.rawValue, "max_output_tokens")
    }

    // MARK: - SDKToolProgressMessage - taskId field

    func testToolProgressMessageWithTaskId() throws {
        let json = """
        {
            "type": "tool_progress",
            "tool_use_id": "tu-1",
            "tool_name": "Task",
            "elapsed_time_seconds": 2.0,
            "task_id": "task-abc",
            "uuid": "u4",
            "session_id": "s4"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKToolProgressMessage.self, from: json)
        XCTAssertEqual(msg.taskId, "task-abc")
        XCTAssertEqual(msg.toolName, "Task")
    }

    func testToolProgressMessageWithoutTaskIdIsNil() throws {
        let json = """
        {
            "type": "tool_progress",
            "tool_use_id": "tu-2",
            "tool_name": "Bash",
            "elapsed_time_seconds": 1.5,
            "uuid": "u5",
            "session_id": "s5"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKToolProgressMessage.self, from: json)
        XCTAssertNil(msg.taskId)
    }

    func testToolProgressMessageTaskIdRoundTrip() throws {
        let json = """
        {
            "type": "tool_progress",
            "tool_use_id": "tu-3",
            "tool_name": "Read",
            "elapsed_time_seconds": 0.5,
            "task_id": "task-rt",
            "uuid": "u6",
            "session_id": "s6"
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKToolProgressMessage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKToolProgressMessage.self, from: data)
        XCTAssertEqual(decoded.taskId, original.taskId)
    }

    // MARK: - SDKTaskNotificationMessage - toolUseId and usage fields

    func testTaskNotificationWithToolUseIdAndUsage() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_notification",
            "task_id": "task-1",
            "tool_use_id": "tu-notify",
            "status": "completed",
            "output_file": "/tmp/out.txt",
            "summary": "Done",
            "usage": {
                "total_tokens": 1000,
                "tool_uses": 5,
                "duration_ms": 3000
            },
            "uuid": "u7",
            "session_id": "s7"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKTaskNotificationMessage.self, from: json)
        XCTAssertEqual(msg.toolUseId, "tu-notify")
        XCTAssertEqual(msg.usage?.totalTokens, 1000)
        XCTAssertEqual(msg.usage?.toolUses, 5)
        XCTAssertEqual(msg.usage?.durationMs, 3000)
    }

    func testTaskNotificationOptionalFieldsNilWhenAbsent() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_notification",
            "task_id": "task-2",
            "status": "failed",
            "output_file": "/tmp/out2.txt",
            "summary": "Failed",
            "uuid": "u8",
            "session_id": "s8"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKTaskNotificationMessage.self, from: json)
        XCTAssertNil(msg.toolUseId)
        XCTAssertNil(msg.usage)
    }

    // MARK: - SDKTaskStartedMessage

    func testTaskStartedMessageDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-started-1",
            "tool_use_id": "tu-started",
            "description": "Running background analysis",
            "task_type": "analysis",
            "uuid": "u9",
            "session_id": "s9"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKTaskStartedMessage.self, from: json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.subtype, "task_started")
        XCTAssertEqual(msg.taskId, "task-started-1")
        XCTAssertEqual(msg.toolUseId, "tu-started")
        XCTAssertEqual(msg.description, "Running background analysis")
        XCTAssertEqual(msg.taskType, "analysis")
        XCTAssertEqual(msg.uuid, "u9")
        XCTAssertEqual(msg.sessionId, "s9")
    }

    func testTaskStartedMessageOptionalFieldsNilWhenAbsent() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-started-2",
            "description": "Simple task",
            "uuid": "u10",
            "session_id": "s10"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKTaskStartedMessage.self, from: json)
        XCTAssertNil(msg.toolUseId)
        XCTAssertNil(msg.taskType)
    }

    func testTaskStartedMessageRoundTrip() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_started",
            "task_id": "task-rt",
            "tool_use_id": "tu-rt",
            "description": "RT task",
            "task_type": "custom",
            "uuid": "u11",
            "session_id": "s11"
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKTaskStartedMessage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKTaskStartedMessage.self, from: data)

        XCTAssertEqual(decoded.taskId, original.taskId)
        XCTAssertEqual(decoded.toolUseId, original.toolUseId)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.taskType, original.taskType)
    }

    // MARK: - SDKTaskProgressMessage

    func testTaskProgressMessageDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_progress",
            "task_id": "task-prog-1",
            "tool_use_id": "tu-prog",
            "description": "Analyzing codebase",
            "usage": {
                "total_tokens": 500,
                "tool_uses": 3,
                "duration_ms": 1500
            },
            "last_tool_name": "Glob",
            "uuid": "u12",
            "session_id": "s12"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKTaskProgressMessage.self, from: json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.subtype, "task_progress")
        XCTAssertEqual(msg.taskId, "task-prog-1")
        XCTAssertEqual(msg.toolUseId, "tu-prog")
        XCTAssertEqual(msg.description, "Analyzing codebase")
        XCTAssertEqual(msg.usage.totalTokens, 500)
        XCTAssertEqual(msg.usage.toolUses, 3)
        XCTAssertEqual(msg.usage.durationMs, 1500)
        XCTAssertEqual(msg.lastToolName, "Glob")
    }

    func testTaskProgressMessageLastToolNameOptional() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_progress",
            "task_id": "task-prog-2",
            "description": "Running",
            "usage": {
                "total_tokens": 100,
                "tool_uses": 1,
                "duration_ms": 200
            },
            "uuid": "u13",
            "session_id": "s13"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKTaskProgressMessage.self, from: json)
        XCTAssertNil(msg.lastToolName)
        XCTAssertNil(msg.toolUseId)
    }

    func testTaskProgressMessageRoundTrip() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_progress",
            "task_id": "task-rt",
            "description": "RT",
            "usage": {
                "total_tokens": 200,
                "tool_uses": 2,
                "duration_ms": 800
            },
            "last_tool_name": "Read",
            "uuid": "u14",
            "session_id": "s14"
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKTaskProgressMessage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKTaskProgressMessage.self, from: data)

        XCTAssertEqual(decoded.taskId, original.taskId)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.usage.totalTokens, original.usage.totalTokens)
        XCTAssertEqual(decoded.lastToolName, original.lastToolName)
    }

    // MARK: - TaskUsage

    func testTaskUsageCodingKeys() throws {
        let json = """
        {
            "total_tokens": 1234,
            "tool_uses": 7,
            "duration_ms": 5000
        }
        """.data(using: .utf8)!

        let usage = try decoder.decode(TaskUsage.self, from: json)
        XCTAssertEqual(usage.totalTokens, 1234)
        XCTAssertEqual(usage.toolUses, 7)
        XCTAssertEqual(usage.durationMs, 5000)
    }

    func testTaskUsageRoundTrip() throws {
        let json = """
        {"total_tokens": 42, "tool_uses": 3, "duration_ms": 1000}
        """.data(using: .utf8)!

        let original = try decoder.decode(TaskUsage.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TaskUsage.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - SDKRateLimitInfo and SDKRateLimitEvent

    func testRateLimitInfoDecoding() throws {
        let json = """
        {
            "status": "allowed_warning",
            "resetsAt": 1709900000.0,
            "rateLimitType": "seven_day",
            "utilization": 0.85,
            "overageStatus": "allowed",
            "overageResetsAt": 1710000000.0,
            "overageDisabledReason": "no_limits_configured",
            "isUsingOverage": false,
            "surpassedThreshold": 0.8
        }
        """.data(using: .utf8)!

        let info = try decoder.decode(SDKRateLimitInfo.self, from: json)
        XCTAssertEqual(info.status, "allowed_warning")
        XCTAssertEqual(info.rateLimitType, "seven_day")
        XCTAssertEqual(info.utilization ?? 0, 0.85, accuracy: 0.001)
        XCTAssertEqual(info.overageStatus, "allowed")
        XCTAssertEqual(info.isUsingOverage, false)
        XCTAssertEqual(info.surpassedThreshold ?? 0, 0.8, accuracy: 0.001)
    }

    func testRateLimitInfoOptionalFieldsNilWhenAbsent() throws {
        let json = """
        {"status": "allowed"}
        """.data(using: .utf8)!

        let info = try decoder.decode(SDKRateLimitInfo.self, from: json)
        XCTAssertEqual(info.status, "allowed")
        XCTAssertNil(info.resetsAt)
        XCTAssertNil(info.rateLimitType)
        XCTAssertNil(info.utilization)
        XCTAssertNil(info.overageStatus)
        XCTAssertNil(info.overageResetsAt)
        XCTAssertNil(info.overageDisabledReason)
        XCTAssertNil(info.isUsingOverage)
        XCTAssertNil(info.surpassedThreshold)
    }

    func testRateLimitEventDecoding() throws {
        let json = """
        {
            "type": "rate_limit_event",
            "rate_limit_info": {
                "status": "rejected",
                "rateLimitType": "five_hour"
            },
            "uuid": "u15",
            "session_id": "s15"
        }
        """.data(using: .utf8)!

        let event = try decoder.decode(SDKRateLimitEvent.self, from: json)
        XCTAssertEqual(event.type, "rate_limit_event")
        XCTAssertEqual(event.rateLimitInfo.status, "rejected")
        XCTAssertEqual(event.rateLimitInfo.rateLimitType, "five_hour")
        XCTAssertEqual(event.uuid, "u15")
        XCTAssertEqual(event.sessionId, "s15")
    }

    func testRateLimitEventViaSDKMessageRawJSON() throws {
        let json = """
        {
            "type": "rate_limit_event",
            "rate_limit_info": {"status": "allowed"},
            "uuid": "u16",
            "session_id": "s16"
        }
        """.data(using: .utf8)!

        let sdkMsg = try decoder.decode(SDKMessage.self, from: json)
        XCTAssertEqual(sdkMsg.type, "rate_limit_event")
        XCTAssertNotNil(sdkMsg.rawJSON["rate_limit_info"])
    }

    func testRateLimitEventRoundTrip() throws {
        let json = """
        {
            "type": "rate_limit_event",
            "rate_limit_info": {
                "status": "allowed",
                "rateLimitType": "seven_day_opus",
                "utilization": 0.5
            },
            "uuid": "u-rt",
            "session_id": "s-rt"
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKRateLimitEvent.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKRateLimitEvent.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.rateLimitInfo.status, original.rateLimitInfo.status)
        XCTAssertEqual(decoded.rateLimitInfo.rateLimitType, original.rateLimitInfo.rateLimitType)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
    }

    // MARK: - SDKResultSuccess

    func testResultSuccessWithModelUsageAndFastModeState() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "duration_ms": 5000,
            "duration_api_ms": 4500,
            "is_error": false,
            "num_turns": 3,
            "result": "Done",
            "stop_reason": "end_turn",
            "total_cost_usd": 0.002,
            "usage": {
                "input_tokens": 100,
                "output_tokens": 200,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.001,
                "context_window": 200000,
                "max_output_tokens": 16000
            },
            "modelUsage": {
                "claude-sonnet-4": {
                    "input_tokens": 100,
                    "output_tokens": 200,
                    "cache_read_input_tokens": 0,
                    "cache_creation_input_tokens": 0,
                    "web_search_requests": 0,
                    "cost_usd": 0.001,
                    "context_window": 200000,
                    "max_output_tokens": 16000
                }
            },
            "permission_denials": [],
            "fast_mode_state": "on",
            "uuid": "u17",
            "session_id": "s17"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKResultSuccess.self, from: json)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.subtype, "success")
        XCTAssertEqual(msg.result, "Done")
        XCTAssertEqual(msg.fastModeState, "on")
        XCTAssertEqual(msg.modelUsage.count, 1)
        XCTAssertNotNil(msg.modelUsage["claude-sonnet-4"])
        XCTAssertEqual(msg.modelUsage["claude-sonnet-4"]?.inputTokens, 100)
        XCTAssertTrue(msg.permissionDenials.isEmpty)
    }

    func testResultSuccessFastModeStateNilWhenAbsent() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "duration_ms": 1000,
            "duration_api_ms": 900,
            "is_error": false,
            "num_turns": 1,
            "result": "OK",
            "stop_reason": "end_turn",
            "total_cost_usd": 0.001,
            "usage": {
                "input_tokens": 50,
                "output_tokens": 100,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.001,
                "context_window": 200000,
                "max_output_tokens": 16000
            },
            "modelUsage": {},
            "permission_denials": [],
            "uuid": "u18",
            "session_id": "s18"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKResultSuccess.self, from: json)
        XCTAssertNil(msg.fastModeState)
    }

    // MARK: - SDKResultError

    func testResultErrorWithModelUsageAndFastModeState() throws {
        let json = """
        {
            "type": "result",
            "subtype": "error_max_turns",
            "duration_ms": 3000,
            "duration_api_ms": 2800,
            "is_error": true,
            "num_turns": 10,
            "stop_reason": null,
            "total_cost_usd": 0.01,
            "usage": {
                "input_tokens": 500,
                "output_tokens": 1000,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
                "web_search_requests": 0,
                "cost_usd": 0.005,
                "context_window": 200000,
                "max_output_tokens": 16000
            },
            "modelUsage": {},
            "permission_denials": [],
            "errors": ["Max turns exceeded"],
            "fast_mode_state": "cooldown",
            "uuid": "u19",
            "session_id": "s19"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKResultError.self, from: json)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.subtype, "error_max_turns")
        XCTAssertEqual(msg.fastModeState, "cooldown")
        XCTAssertEqual(msg.errors, ["Max turns exceeded"])
        XCTAssertTrue(msg.isError)
    }

    // MARK: - SDKPermissionDenial

    func testPermissionDenialDecoding() throws {
        let json = """
        {
            "tool_name": "Bash",
            "tool_use_id": "tu-denied",
            "tool_input": {"command": "rm -rf /"}
        }
        """.data(using: .utf8)!

        let denial = try decoder.decode(SDKPermissionDenial.self, from: json)
        XCTAssertEqual(denial.toolName, "Bash")
        XCTAssertEqual(denial.toolUseId, "tu-denied")
        XCTAssertNotNil(denial.toolInput["command"])
    }

    func testPermissionDenialRoundTrip() throws {
        let json = """
        {
            "tool_name": "Write",
            "tool_use_id": "tu-rt-denial",
            "tool_input": {"path": "/etc/passwd", "content": "bad"}
        }
        """.data(using: .utf8)!

        let original = try decoder.decode(SDKPermissionDenial.self, from: json)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SDKPermissionDenial.self, from: data)

        XCTAssertEqual(decoded.toolName, original.toolName)
        XCTAssertEqual(decoded.toolUseId, original.toolUseId)
    }

    // MARK: - SDKInitMessage fastModeState

    func testInitMessageFastModeState() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "sess-fms",
            "fast_mode_state": "on"
        }
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(msg.fastModeState, "on")
    }

    func testInitMessageFastModeStateNilWhenAbsent() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "sess-no-fms"}
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKInitMessage.self, from: json)
        XCTAssertNil(msg.fastModeState)
    }

    // MARK: - ApiKeySource on SDKInitMessage

    func testInitMessageApiKeySourceUserCase() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "s", "api_key_source": "user"}
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(msg.apiKeySource, .user)
    }

    func testInitMessageApiKeySourceOauthCase() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "s", "api_key_source": "oauth"}
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKInitMessage.self, from: json)
        XCTAssertEqual(msg.apiKeySource, .oauth)
    }

    func testInitMessageApiKeySourceAbsentIsNil() throws {
        let json = """
        {"type": "system", "subtype": "init", "session_id": "s"}
        """.data(using: .utf8)!

        let msg = try decoder.decode(SDKInitMessage.self, from: json)
        XCTAssertNil(msg.apiKeySource)
    }
}
