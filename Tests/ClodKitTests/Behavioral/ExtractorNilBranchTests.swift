//
//  ExtractorNilBranchTests.swift
//  ClodKitTests
//
//  Tests for HookRegistry extractor `return nil` branches.
//  Each test registers a callback for one event type, then invokes it
//  with a mismatched HookInput to trigger the extractor's nil path.
//

import XCTest
@testable import ClodKit

final class ExtractorNilBranchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 10
    }

    // MARK: - Helpers

    /// A `.preToolUse(...)` input used as the "wrong type" for non-preToolUse extractors.
    private var wrongPreToolUseInput: HookInput {
        let base = BaseHookInput(sessionId: "", transcriptPath: "", cwd: "", permissionMode: "", hookEventName: .preToolUse)
        return .preToolUse(PreToolUseInput(base: base, toolName: "T", toolInput: [:], toolUseId: "tu"))
    }

    /// A `.stop(...)` input used as the "wrong type" for non-stop extractors.
    private var wrongStopInput: HookInput {
        let base = BaseHookInput(sessionId: "", transcriptPath: "", cwd: "", permissionMode: "", hookEventName: .stop)
        return .stop(StopInput(base: base, stopHookActive: false))
    }

    private func assertExtractorNilBranch(
        register: (HookRegistry) async -> Void,
        event: HookEvent,
        wrongInput: HookInput
    ) async throws {
        let registry = HookRegistry()
        await register(registry)
        let id = await registry.getCallbackId(forEvent: event)!
        do {
            _ = try await registry.invokeCallback(callbackId: id, input: wrongInput)
            XCTFail("Expected HookError.invalidInput for \(event)")
        } catch let error as HookError {
            if case .invalidInput(let msg) = error {
                XCTAssertTrue(msg.contains("Cannot extract input"), "Unexpected message: \(msg)")
            } else {
                XCTFail("Expected invalidInput, got \(error)")
            }
        }
    }

    // MARK: - Tests (one per event type except preToolUse which is already covered)

    func testExtractorNil_PostToolUse() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onPostToolUse { _ in .continue() } },
            event: .postToolUse,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_PostToolUseFailure() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onPostToolUseFailure { _ in .continue() } },
            event: .postToolUseFailure,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_UserPromptSubmit() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onUserPromptSubmit { _ in .continue() } },
            event: .userPromptSubmit,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_Stop() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onStop { _ in .continue() } },
            event: .stop,
            wrongInput: wrongPreToolUseInput
        )
    }

    func testExtractorNil_SubagentStart() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onSubagentStart { _ in .continue() } },
            event: .subagentStart,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_SubagentStop() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onSubagentStop { _ in .continue() } },
            event: .subagentStop,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_PreCompact() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onPreCompact { _ in .continue() } },
            event: .preCompact,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_PermissionRequest() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onPermissionRequest { _ in .continue() } },
            event: .permissionRequest,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_SessionStart() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onSessionStart { _ in .continue() } },
            event: .sessionStart,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_SessionEnd() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onSessionEnd { _ in .continue() } },
            event: .sessionEnd,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_Notification() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onNotification { _ in .continue() } },
            event: .notification,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_Setup() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onSetup { _ in .continue() } },
            event: .setup,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_TeammateIdle() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onTeammateIdle { _ in .continue() } },
            event: .teammateIdle,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_TaskCompleted() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onTaskCompleted { _ in .continue() } },
            event: .taskCompleted,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_Elicitation() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onElicitation { _ in .continue() } },
            event: .elicitation,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_ElicitationResult() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onElicitationResult { _ in .continue() } },
            event: .elicitationResult,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_ConfigChange() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onConfigChange { _ in .continue() } },
            event: .configChange,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_WorktreeCreate() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onWorktreeCreate { _ in .continue() } },
            event: .worktreeCreate,
            wrongInput: wrongStopInput
        )
    }

    func testExtractorNil_WorktreeRemove() async throws {
        try await assertExtractorNilBranch(
            register: { await $0.onWorktreeRemove { _ in .continue() } },
            event: .worktreeRemove,
            wrongInput: wrongStopInput
        )
    }
}
