//
//  HookRegistry.swift
//  ClodKit
//
//  Actor managing hook registration and invocation.
//

import Foundation
import os.log

// MARK: - Hook Errors

/// Errors that can occur during hook operations.
public enum HookError: Error, Sendable, Equatable {
    /// The specified callback ID was not found in the registry.
    case callbackNotFound(String)

    /// The hook event type is not supported for callback invocation.
    case unsupportedHookEvent(HookEvent)

    /// The input data is invalid or missing required fields.
    case invalidInput(String)

    /// The callback invocation timed out.
    case timeout(String)
}

// MARK: - Type-Erased Callback Wrapper

/// Internal protocol for type-erased callback invocation.
private protocol AnyCallbackBox: Sendable {
    func invoke(input: HookInput) async throws -> HookOutput
    var eventType: HookEvent { get }
}

/// Type-erased wrapper for typed hook callbacks.
private struct CallbackBox<Input: Sendable>: AnyCallbackBox, Sendable {
    let callback: @Sendable (Input) async throws -> HookOutput
    let eventType: HookEvent
    let extractor: @Sendable (HookInput) -> Input?

    func invoke(input: HookInput) async throws -> HookOutput {
        guard let typedInput = extractor(input) else {
            throw HookError.invalidInput("Cannot extract input for event type \(eventType)")
        }
        return try await callback(typedInput)
    }
}

// MARK: - HookRegistry Actor

/// Actor managing hook registration and invocation.
/// Thread-safe storage and invocation of hook callbacks.
public actor HookRegistry {
    private var callbackIdCounter: Int = 0
    private var callbacks: [String: any AnyCallbackBox] = [:]
    private var hookConfig: [HookEvent: [HookMatcherConfig]] = [:]
    private let logger: Logger?

    /// Initialize a new hook registry.
    /// - Parameter logger: Optional logger for debugging.
    public init(logger: Logger? = nil) {
        self.logger = logger
    }

    // MARK: - PreToolUse Registration

    /// Register a callback for PreToolUse events.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onPreToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PreToolUseInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .preToolUse,
            extractor: { input in
                if case .preToolUse(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.preToolUse, default: []].append(
            HookMatcherConfig(matcher: pattern, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered PreToolUse hook: \(callbackId), pattern: \(pattern ?? "*")")
    }

    // MARK: - PostToolUse Registration

    /// Register a callback for PostToolUse events.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onPostToolUse(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PostToolUseInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .postToolUse,
            extractor: { input in
                if case .postToolUse(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.postToolUse, default: []].append(
            HookMatcherConfig(matcher: pattern, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered PostToolUse hook: \(callbackId), pattern: \(pattern ?? "*")")
    }

    // MARK: - PostToolUseFailure Registration

    /// Register a callback for PostToolUseFailure events.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onPostToolUseFailure(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PostToolUseFailureInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .postToolUseFailure,
            extractor: { input in
                if case .postToolUseFailure(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.postToolUseFailure, default: []].append(
            HookMatcherConfig(matcher: pattern, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered PostToolUseFailure hook: \(callbackId), pattern: \(pattern ?? "*")")
    }

    // MARK: - UserPromptSubmit Registration

    /// Register a callback for UserPromptSubmit events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onUserPromptSubmit(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (UserPromptSubmitInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .userPromptSubmit,
            extractor: { input in
                if case .userPromptSubmit(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.userPromptSubmit, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered UserPromptSubmit hook: \(callbackId)")
    }

    // MARK: - Stop Registration

    /// Register a callback for Stop events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onStop(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (StopInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .stop,
            extractor: { input in
                if case .stop(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.stop, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered Stop hook: \(callbackId)")
    }

    // MARK: - SubagentStart Registration

    /// Register a callback for SubagentStart events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onSubagentStart(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SubagentStartInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .subagentStart,
            extractor: { input in
                if case .subagentStart(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.subagentStart, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered SubagentStart hook: \(callbackId)")
    }

    // MARK: - SubagentStop Registration

    /// Register a callback for SubagentStop events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onSubagentStop(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SubagentStopInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .subagentStop,
            extractor: { input in
                if case .subagentStop(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.subagentStop, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered SubagentStop hook: \(callbackId)")
    }

    // MARK: - PreCompact Registration

    /// Register a callback for PreCompact events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onPreCompact(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PreCompactInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .preCompact,
            extractor: { input in
                if case .preCompact(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.preCompact, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered PreCompact hook: \(callbackId)")
    }

    // MARK: - PermissionRequest Registration

    /// Register a callback for PermissionRequest events.
    /// - Parameters:
    ///   - pattern: Optional regex pattern to match tool names.
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onPermissionRequest(
        matching pattern: String? = nil,
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (PermissionRequestInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .permissionRequest,
            extractor: { input in
                if case .permissionRequest(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.permissionRequest, default: []].append(
            HookMatcherConfig(matcher: pattern, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered PermissionRequest hook: \(callbackId), pattern: \(pattern ?? "*")")
    }

    // MARK: - SessionStart Registration

    /// Register a callback for SessionStart events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onSessionStart(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SessionStartInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .sessionStart,
            extractor: { input in
                if case .sessionStart(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.sessionStart, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered SessionStart hook: \(callbackId)")
    }

    // MARK: - SessionEnd Registration

    /// Register a callback for SessionEnd events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onSessionEnd(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (SessionEndInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .sessionEnd,
            extractor: { input in
                if case .sessionEnd(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.sessionEnd, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered SessionEnd hook: \(callbackId)")
    }

    // MARK: - Notification Registration

    /// Register a callback for Notification events.
    /// - Parameters:
    ///   - timeout: Timeout for callback execution (default 60 seconds).
    ///   - callback: The callback to invoke.
    public func onNotification(
        timeout: TimeInterval = 60.0,
        callback: @escaping @Sendable (NotificationInput) async throws -> HookOutput
    ) {
        let callbackId = generateCallbackId()
        let box = CallbackBox(
            callback: callback,
            eventType: .notification,
            extractor: { input in
                if case .notification(let typed) = input { return typed }
                return nil
            }
        )
        callbacks[callbackId] = box
        hookConfig[.notification, default: []].append(
            HookMatcherConfig(matcher: nil, hookCallbackIds: [callbackId], timeout: timeout)
        )
        logger?.debug("Registered Notification hook: \(callbackId)")
    }

    // MARK: - Configuration

    /// Get the hook configuration for the initialize request.
    /// - Returns: Dictionary of event names to matcher configs, or nil if no hooks registered.
    public func getHookConfig() -> [String: [HookMatcherConfig]]? {
        guard !hookConfig.isEmpty else { return nil }
        return Dictionary(uniqueKeysWithValues: hookConfig.map { ($0.key.rawValue, $0.value) })
    }

    /// Get the callback IDs for a specific callback ID prefix search.
    /// - Parameter callbackIdPrefix: Prefix to search for (e.g., "hook_1").
    /// - Returns: Matching callback ID if found.
    public func getCallbackId(forEvent event: HookEvent, atIndex index: Int = 0) -> String? {
        guard let configs = hookConfig[event], configs.indices.contains(index) else { return nil }
        return configs[index].hookCallbackIds.first
    }

    /// Whether any hooks are registered.
    public var hasHooks: Bool {
        !hookConfig.isEmpty
    }

    /// The number of registered callbacks.
    public var callbackCount: Int {
        callbacks.count
    }

    /// The registered hook events.
    public var registeredEvents: Set<HookEvent> {
        Set(hookConfig.keys)
    }

    // MARK: - Invocation

    /// Invoke a callback by its ID.
    /// - Parameters:
    ///   - callbackId: The callback ID to invoke.
    ///   - rawInput: The raw input dictionary from the CLI.
    /// - Returns: The hook output from the callback.
    /// - Throws: HookError if callback not found or input is invalid.
    public func invokeCallback(
        callbackId: String,
        rawInput: [String: JSONValue]
    ) async throws -> HookOutput {
        guard let box = callbacks[callbackId] else {
            logger?.error("Callback not found: \(callbackId)")
            throw HookError.callbackNotFound(callbackId)
        }

        let hookInput = try parseInput(from: rawInput, expectedEvent: box.eventType)
        logger?.debug("Invoking callback \(callbackId) for event \(box.eventType.rawValue)")

        return try await box.invoke(input: hookInput)
    }

    /// Invoke a callback with a pre-parsed HookInput.
    /// - Parameters:
    ///   - callbackId: The callback ID to invoke.
    ///   - input: The parsed hook input.
    /// - Returns: The hook output from the callback.
    /// - Throws: HookError if callback not found.
    public func invokeCallback(
        callbackId: String,
        input: HookInput
    ) async throws -> HookOutput {
        guard let box = callbacks[callbackId] else {
            logger?.error("Callback not found: \(callbackId)")
            throw HookError.callbackNotFound(callbackId)
        }

        logger?.debug("Invoking callback \(callbackId) for event \(box.eventType.rawValue)")
        return try await box.invoke(input: input)
    }

    // MARK: - Private Helpers

    private func generateCallbackId() -> String {
        callbackIdCounter += 1
        return "hook_\(callbackIdCounter)"
    }

    // MARK: - Input Parsing

    private func parseInput(from rawInput: [String: JSONValue], expectedEvent: HookEvent) throws -> HookInput {
        let base = parseBaseInput(from: rawInput)

        switch expectedEvent {
        case .preToolUse:
            return .preToolUse(parsePreToolUseInput(from: rawInput, base: base))

        case .postToolUse:
            return .postToolUse(parsePostToolUseInput(from: rawInput, base: base))

        case .postToolUseFailure:
            return .postToolUseFailure(parsePostToolUseFailureInput(from: rawInput, base: base))

        case .userPromptSubmit:
            return .userPromptSubmit(parseUserPromptSubmitInput(from: rawInput, base: base))

        case .stop:
            return .stop(parseStopInput(from: rawInput, base: base))

        case .subagentStart:
            return .subagentStart(parseSubagentStartInput(from: rawInput, base: base))

        case .subagentStop:
            return .subagentStop(parseSubagentStopInput(from: rawInput, base: base))

        case .preCompact:
            return .preCompact(parsePreCompactInput(from: rawInput, base: base))

        case .permissionRequest:
            return .permissionRequest(parsePermissionRequestInput(from: rawInput, base: base))

        case .sessionStart:
            return .sessionStart(parseSessionStartInput(from: rawInput, base: base))

        case .sessionEnd:
            return .sessionEnd(parseSessionEndInput(from: rawInput, base: base))

        case .notification:
            return .notification(parseNotificationInput(from: rawInput, base: base))
        }
    }

    private func parseBaseInput(from input: [String: JSONValue]) -> BaseHookInput {
        let eventName = input["hook_event_name"]?.stringValue ?? input["hookEventName"]?.stringValue ?? ""
        return BaseHookInput(
            sessionId: input["session_id"]?.stringValue ?? "",
            transcriptPath: input["transcript_path"]?.stringValue ?? "",
            cwd: input["cwd"]?.stringValue ?? "",
            permissionMode: input["permission_mode"]?.stringValue ?? "",
            hookEventName: HookEvent(rawValue: eventName) ?? .preToolUse
        )
    }

    private func parsePreToolUseInput(from input: [String: JSONValue], base: BaseHookInput) -> PreToolUseInput {
        PreToolUseInput(
            base: base,
            toolName: input["tool_name"]?.stringValue ?? "",
            toolInput: input["tool_input"]?.objectValue ?? [:],
            toolUseId: input["tool_use_id"]?.stringValue ?? ""
        )
    }

    private func parsePostToolUseInput(from input: [String: JSONValue], base: BaseHookInput) -> PostToolUseInput {
        PostToolUseInput(
            base: base,
            toolName: input["tool_name"]?.stringValue ?? "",
            toolInput: input["tool_input"]?.objectValue ?? [:],
            toolResponse: input["tool_response"] ?? .null,
            toolUseId: input["tool_use_id"]?.stringValue ?? ""
        )
    }

    private func parsePostToolUseFailureInput(from input: [String: JSONValue], base: BaseHookInput) -> PostToolUseFailureInput {
        PostToolUseFailureInput(
            base: base,
            toolName: input["tool_name"]?.stringValue ?? "",
            toolInput: input["tool_input"]?.objectValue ?? [:],
            error: input["error"]?.stringValue ?? "",
            isInterrupt: input["is_interrupt"]?.boolValue ?? false,
            toolUseId: input["tool_use_id"]?.stringValue ?? ""
        )
    }

    private func parseUserPromptSubmitInput(from input: [String: JSONValue], base: BaseHookInput) -> UserPromptSubmitInput {
        UserPromptSubmitInput(
            base: base,
            prompt: input["prompt"]?.stringValue ?? ""
        )
    }

    private func parseStopInput(from input: [String: JSONValue], base: BaseHookInput) -> StopInput {
        StopInput(
            base: base,
            stopHookActive: input["stop_hook_active"]?.boolValue ?? false
        )
    }

    private func parseSubagentStartInput(from input: [String: JSONValue], base: BaseHookInput) -> SubagentStartInput {
        SubagentStartInput(
            base: base,
            agentId: input["agent_id"]?.stringValue ?? "",
            agentType: input["agent_type"]?.stringValue ?? ""
        )
    }

    private func parseSubagentStopInput(from input: [String: JSONValue], base: BaseHookInput) -> SubagentStopInput {
        SubagentStopInput(
            base: base,
            stopHookActive: input["stop_hook_active"]?.boolValue ?? false,
            agentTranscriptPath: input["agent_transcript_path"]?.stringValue ?? ""
        )
    }

    private func parsePreCompactInput(from input: [String: JSONValue], base: BaseHookInput) -> PreCompactInput {
        PreCompactInput(
            base: base,
            trigger: input["trigger"]?.stringValue ?? "",
            customInstructions: input["custom_instructions"]?.stringValue
        )
    }

    private func parsePermissionRequestInput(from input: [String: JSONValue], base: BaseHookInput) -> PermissionRequestInput {
        let suggestions: [String]
        if case .array(let arr) = input["permission_suggestions"] {
            suggestions = arr.compactMap { $0.stringValue }
        } else {
            suggestions = []
        }
        return PermissionRequestInput(
            base: base,
            toolName: input["tool_name"]?.stringValue ?? "",
            toolInput: input["tool_input"]?.objectValue ?? [:],
            permissionSuggestions: suggestions
        )
    }

    private func parseSessionStartInput(from input: [String: JSONValue], base: BaseHookInput) -> SessionStartInput {
        SessionStartInput(
            base: base,
            source: input["source"]?.stringValue ?? ""
        )
    }

    private func parseSessionEndInput(from input: [String: JSONValue], base: BaseHookInput) -> SessionEndInput {
        SessionEndInput(
            base: base,
            reason: input["reason"]?.stringValue ?? ""
        )
    }

    private func parseNotificationInput(from input: [String: JSONValue], base: BaseHookInput) -> NotificationInput {
        NotificationInput(
            base: base,
            message: input["message"]?.stringValue ?? "",
            notificationType: input["notification_type"]?.stringValue ?? "",
            title: input["title"]?.stringValue
        )
    }
}

