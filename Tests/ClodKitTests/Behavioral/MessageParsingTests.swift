//
//  MessageParsingTests.swift
//  ClodKitTests
//
//  Behavioral tests for SDKMessage exhaustive parsing and type discrimination (Bead 1vb).
//

import XCTest
@testable import ClodKit

final class MessageParsingTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Helper

    private func parseMessage(_ json: String) throws -> SDKMessage {
        let data = json.data(using: .utf8)!
        return try decoder.decode(SDKMessage.self, from: data)
    }

    // MARK: - Assistant Message

    func testAssistantMessageParsing() throws {
        let json = """
        {
            "type": "assistant",
            "message": {
                "role": "assistant",
                "content": [{"type": "text", "text": "Hello!"}]
            },
            "session_id": "sess-123"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "assistant")
        XCTAssertEqual(msg.content, .string("Hello!"))
        XCTAssertEqual(msg.sessionId, "sess-123")
    }

    // MARK: - User Message

    func testUserMessageParsing() throws {
        let json = """
        {
            "type": "user",
            "content": "Write a function",
            "session_id": "sess-456"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "user")
        XCTAssertEqual(msg.sessionId, "sess-456")
    }

    func testUserMessageWithIsSynthetic() throws {
        let json = """
        {
            "type": "user",
            "content": "Synthetic prompt",
            "isSynthetic": true,
            "session_id": "sess-789"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "user")
        XCTAssertEqual(msg.isSynthetic, true)
    }

    func testUserMessageWithToolUseResult() throws {
        let json = """
        {
            "type": "user",
            "tool_use_result": {"output": "file contents"},
            "session_id": "sess-001"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "user")
        XCTAssertNotNil(msg.toolUseResult)
    }

    // MARK: - Result Success

    func testResultSuccessMessageParsing() throws {
        let json = """
        {
            "type": "result",
            "subtype": "success",
            "result": "The answer is 42",
            "stop_reason": "end_turn",
            "session_id": "sess-res1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.content, .string("The answer is 42"))
        XCTAssertEqual(msg.stopReason, "end_turn")
    }

    // MARK: - Result Error

    func testResultErrorMessageParsing() throws {
        let json = """
        {
            "type": "result",
            "subtype": "error_max_turns",
            "error": "Exceeded max turns",
            "session_id": "sess-res2"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "result")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "error_max_turns")
    }

    // MARK: - System Init

    func testSystemInitMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "sess-init1",
            "api_key_source": "env",
            "cwd": "/home/user",
            "model": "claude-sonnet-4-20250514",
            "permission_mode": "default",
            "uuid": "uuid-123",
            "agents": ["main", "task"],
            "betas": ["interleaved-thinking"],
            "claude_code_version": "2.1.34",
            "output_style": "concise",
            "skills": ["commit", "review-pr"],
            "plugins": [{"name": "test-plugin", "path": "/path/to/plugin"}]
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "init")
        XCTAssertEqual(msg.sessionId, "sess-init1")
    }

    // MARK: - System Status (NEW)

    func testSystemStatusMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "status",
            "status": "compacting",
            "permission_mode": "default",
            "uuid": "uuid-456",
            "session_id": "sess-stat1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "status")
    }

    // MARK: - System Hook Started (NEW)

    func testSystemHookStartedMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "hook_started",
            "hook_id": "h1",
            "hook_name": "pre-tool-hook",
            "hook_event": "PreToolUse",
            "uuid": "uuid-hs1",
            "session_id": "sess-hs1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "hook_started")
        XCTAssertEqual(msg.rawJSON["hook_id"]?.stringValue, "h1")
    }

    // MARK: - System Hook Progress (NEW)

    func testSystemHookProgressMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "hook_progress",
            "hook_id": "h1",
            "hook_name": "pre-tool-hook",
            "hook_event": "PreToolUse",
            "stdout": "running...",
            "stderr": "",
            "output": "running...",
            "uuid": "uuid-hp1",
            "session_id": "sess-hp1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "hook_progress")
    }

    // MARK: - System Hook Response (NEW)

    func testSystemHookResponseMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "hook_response",
            "hook_id": "h1",
            "hook_name": "pre-tool-hook",
            "hook_event": "PreToolUse",
            "output": "done",
            "stdout": "done",
            "stderr": "",
            "exit_code": 0,
            "outcome": "success",
            "uuid": "uuid-hr1",
            "session_id": "sess-hr1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "hook_response")
        XCTAssertEqual(msg.rawJSON["exit_code"]?.intValue, 0)
    }

    // MARK: - Tool Progress (NEW - top-level type)

    func testToolProgressMessageParsing() throws {
        let json = """
        {
            "type": "tool_progress",
            "tool_use_id": "tu-1",
            "tool_name": "Bash",
            "parent_tool_use_id": null,
            "elapsed_time_seconds": 3.5,
            "uuid": "uuid-tp1",
            "session_id": "sess-tp1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "tool_progress")
        XCTAssertEqual(msg.rawJSON["tool_use_id"]?.stringValue, "tu-1")
        XCTAssertEqual(msg.rawJSON["tool_name"]?.stringValue, "Bash")
    }

    // MARK: - Auth Status (NEW - top-level type)

    func testAuthStatusMessageParsing() throws {
        let json = """
        {
            "type": "auth_status",
            "is_authenticating": true,
            "output": ["Authenticating..."],
            "error": null,
            "uuid": "uuid-as1",
            "session_id": "sess-as1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "auth_status")
        XCTAssertEqual(msg.rawJSON["is_authenticating"]?.boolValue, true)
    }

    // MARK: - System Task Notification (NEW)

    func testSystemTaskNotificationMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "task_notification",
            "task_id": "task-42",
            "status": "completed",
            "output_file": "/tmp/output.txt",
            "summary": "Task completed successfully",
            "uuid": "uuid-tn1",
            "session_id": "sess-tn1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "task_notification")
        XCTAssertEqual(msg.rawJSON["task_id"]?.stringValue, "task-42")
    }

    // MARK: - System Files Persisted (NEW)

    func testSystemFilesPersistedMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "files_persisted",
            "files": [{"filename": "test.txt", "file_id": "f1"}],
            "failed": [{"filename": "bad.txt", "error": "too large"}],
            "processed_at": "2026-02-07T12:00:00Z",
            "uuid": "uuid-fp1",
            "session_id": "sess-fp1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "files_persisted")
    }

    // MARK: - Tool Use Summary (NEW - top-level type)

    func testToolUseSummaryMessageParsing() throws {
        let json = """
        {
            "type": "tool_use_summary",
            "summary": "Read 3 files, wrote 1 file",
            "preceding_tool_use_ids": ["tu-1", "tu-2", "tu-3"],
            "uuid": "uuid-tus1",
            "session_id": "sess-tus1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "tool_use_summary")
        XCTAssertEqual(msg.rawJSON["summary"]?.stringValue, "Read 3 files, wrote 1 file")
    }

    // MARK: - Stream Event

    func testStreamEventMessageParsing() throws {
        let json = """
        {
            "type": "stream_event",
            "event": "content_block_delta",
            "data": {"delta": {"text": "Hello"}}
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "stream_event")
    }

    // MARK: - Compact Boundary

    func testCompactBoundaryMessageParsing() throws {
        let json = """
        {
            "type": "system",
            "subtype": "compact_boundary",
            "session_id": "sess-cb1"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "system")
        XCTAssertEqual(msg.rawJSON["subtype"]?.stringValue, "compact_boundary")
    }

    // MARK: - Unknown Type Produces Graceful Degradation

    func testUnknownTypeStillParses() throws {
        let json = """
        {
            "type": "future_new_type",
            "data": {"something": "new"},
            "session_id": "sess-future"
        }
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.type, "future_new_type")
        XCTAssertEqual(msg.sessionId, "sess-future")
    }

    // MARK: - Missing Optional Fields Don't Crash

    func testMissingSessionIdIsNil() throws {
        let json = """
        {"type": "assistant"}
        """
        let msg = try parseMessage(json)
        XCTAssertNil(msg.sessionId)
    }

    func testMissingContentIsNil() throws {
        let json = """
        {"type": "user"}
        """
        let msg = try parseMessage(json)
        // user type with no "content" key
        XCTAssertNil(msg.content)
    }

    func testMissingStopReasonIsNil() throws {
        let json = """
        {"type": "result", "subtype": "success", "result": "answer"}
        """
        let msg = try parseMessage(json)
        XCTAssertNil(msg.stopReason)
    }

    // MARK: - Missing Type Field Throws

    func testMissingTypeFieldThrows() {
        let json = """
        {"content": "no type field"}
        """
        XCTAssertThrowsError(try parseMessage(json))
    }

    // MARK: - Convenience Accessors

    func testIsSyntheticAccessor() throws {
        let json = """
        {"type": "user", "isSynthetic": true}
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.isSynthetic, true)
    }

    func testIsSyntheticNilWhenAbsent() throws {
        let json = """
        {"type": "user"}
        """
        let msg = try parseMessage(json)
        XCTAssertNil(msg.isSynthetic)
    }

    func testToolUseResultAccessor() throws {
        let json = """
        {"type": "user", "tool_use_result": {"status": "success"}}
        """
        let msg = try parseMessage(json)
        XCTAssertNotNil(msg.toolUseResult)
    }

    func testErrorAccessorOnAssistantMessage() throws {
        let json = """
        {"type": "assistant", "error": "rate_limit"}
        """
        let msg = try parseMessage(json)
        XCTAssertEqual(msg.error, .rateLimit)
    }

    func testErrorAccessorOnNonAssistantReturnsNil() throws {
        let json = """
        {"type": "user", "error": "rate_limit"}
        """
        let msg = try parseMessage(json)
        XCTAssertNil(msg.error)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let json = """
        {
            "type": "assistant",
            "message": {
                "role": "assistant",
                "content": [{"type": "text", "text": "Hello"}]
            },
            "session_id": "sess-rt1"
        }
        """
        let original = try parseMessage(json)
        let data = try JSONEncoder().encode(original)
        let roundTripped = try decoder.decode(SDKMessage.self, from: data)
        XCTAssertEqual(roundTripped.type, original.type)
        XCTAssertEqual(roundTripped.sessionId, original.sessionId)
    }

    // MARK: - Typed Message Decoding

    func testSDKInitMessageDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "init",
            "session_id": "sess-init2",
            "api_key_source": "env",
            "cwd": "/home",
            "model": "claude-sonnet-4-20250514",
            "permission_mode": "default",
            "uuid": "u1",
            "agents": ["main"],
            "betas": ["beta1"],
            "claude_code_version": "2.1.34",
            "output_style": "concise",
            "skills": ["commit"],
            "plugins": [{"name": "p1", "path": "/p"}]
        }
        """
        let data = json.data(using: .utf8)!
        let init_msg = try decoder.decode(SDKInitMessage.self, from: data)
        XCTAssertEqual(init_msg.type, "system")
        XCTAssertEqual(init_msg.subtype, "init")
        XCTAssertEqual(init_msg.sessionId, "sess-init2")
        XCTAssertEqual(init_msg.agents, ["main"])
        XCTAssertEqual(init_msg.betas, ["beta1"])
        XCTAssertEqual(init_msg.claudeCodeVersion, "2.1.34")
        XCTAssertEqual(init_msg.outputStyle, "concise")
        XCTAssertEqual(init_msg.skills, ["commit"])
        XCTAssertEqual(init_msg.plugins?.count, 1)
        XCTAssertEqual(init_msg.plugins?.first?.name, "p1")
    }

    func testSDKStatusMessageDecoding() throws {
        let json = """
        {
            "type": "system",
            "subtype": "status",
            "status": "compacting",
            "permission_mode": "default",
            "uuid": "u2",
            "session_id": "sess-stat2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKStatusMessage.self, from: data)
        XCTAssertEqual(msg.subtype, "status")
        XCTAssertEqual(msg.status, "compacting")
    }

    func testSDKToolProgressMessageDecoding() throws {
        let json = """
        {
            "type": "tool_progress",
            "tool_use_id": "tu-1",
            "tool_name": "Bash",
            "elapsed_time_seconds": 5.0,
            "uuid": "u3",
            "session_id": "sess-tp2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKToolProgressMessage.self, from: data)
        XCTAssertEqual(msg.toolName, "Bash")
        XCTAssertEqual(msg.elapsedTimeSeconds, 5.0)
    }

    func testSDKAuthStatusMessageDecoding() throws {
        let json = """
        {
            "type": "auth_status",
            "is_authenticating": false,
            "output": ["Done"],
            "uuid": "u4",
            "session_id": "sess-as2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKAuthStatusMessage.self, from: data)
        XCTAssertFalse(msg.isAuthenticating)
        XCTAssertEqual(msg.output, ["Done"])
    }

    func testSDKToolUseSummaryMessageDecoding() throws {
        let json = """
        {
            "type": "tool_use_summary",
            "summary": "Read 2 files",
            "preceding_tool_use_ids": ["tu-a", "tu-b"],
            "uuid": "u5",
            "session_id": "sess-tus2"
        }
        """
        let data = json.data(using: .utf8)!
        let msg = try decoder.decode(SDKToolUseSummaryMessage.self, from: data)
        XCTAssertEqual(msg.summary, "Read 2 files")
        XCTAssertEqual(msg.precedingToolUseIds, ["tu-a", "tu-b"])
    }
}
