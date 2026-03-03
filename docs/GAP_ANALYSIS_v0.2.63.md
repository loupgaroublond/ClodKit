# Gap Analysis: Claude Agent SDK v0.2.63

Comparison of the current API spec (`CLAUDE_AGENT_SDK_API_SPEC.md`, dated 2026-02-08) and ClodKit Swift implementation against the actual TypeScript type definitions shipped in `@anthropic-ai/claude-agent-sdk@0.2.63` (Claude Code v2.1.63).

**Source files analyzed:**
- `sdk.d.ts` — Primary type declarations (2436 lines, up from 1835 in v0.2.34)
- `sdk-tools.d.ts` — Tool input JSON schemas (2367 lines, up from 1570 in v0.2.34)
- `package.json` — Package metadata

**Previous version analyzed:** v0.2.34 (2026-02-07)
**Analysis date:** 2026-03-01

---

## Table of Contents

1. [Hook System — 5 New Events (15 → 20)](#1-hook-system--5-new-events-15--20)
2. [New SDKMessage Variants](#2-new-sdkmessage-variants)
3. [Updated SDKMessage Variants](#3-updated-sdkmessage-variants)
4. [Options — New Fields](#4-options--new-fields)
5. [Query Interface — New Methods](#5-query-interface--new-methods)
6. [New Standalone Functions](#6-new-standalone-functions)
7. [New Supporting Types](#7-new-supporting-types)
8. [Updated Existing Types](#8-updated-existing-types)
9. [Permission System — New Update Variants](#9-permission-system--new-update-variants)
10. [MCP — New Config Types](#10-mcp--new-config-types)
11. [Control Protocol — New Request Types](#11-control-protocol--new-request-types)
12. [Tool Input/Output Schemas — New Tools and Updated Fields](#12-tool-inputoutput-schemas--new-tools-and-updated-fields)
13. [V2 Session API — Updated Types](#13-v2-session-api--updated-types)
14. [Sandbox Configuration — Changes](#14-sandbox-configuration--changes)
15. [Unchanged Areas](#15-unchanged-areas)
16. [ClodKit Impact Assessment](#16-clodkit-impact-assessment)

---

## 1. Hook System — 5 New Events (15 → 20)

### 1.1 New Hook Events

The `HOOK_EVENTS` array grew from 15 to 20 entries:

```typescript
export declare const HOOK_EVENTS: readonly [
  "PreToolUse", "PostToolUse", "PostToolUseFailure", "Notification",
  "UserPromptSubmit", "SessionStart", "SessionEnd", "Stop",
  "SubagentStart", "SubagentStop", "PreCompact", "PermissionRequest",
  "Setup", "TeammateIdle", "TaskCompleted",
  // NEW in v0.2.63:
  "Elicitation", "ElicitationResult", "ConfigChange",
  "WorktreeCreate", "WorktreeRemove"
];
```

### 1.2 New Hook Input Types

**ElicitationHookInput:**
```typescript
export declare type ElicitationHookInput = BaseHookInput & {
    hook_event_name: 'Elicitation';
    mcp_server_name: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitation_id?: string;
    requested_schema?: Record<string, unknown>;
};
```

**ElicitationResultHookInput:**
```typescript
export declare type ElicitationResultHookInput = BaseHookInput & {
    hook_event_name: 'ElicitationResult';
    mcp_server_name: string;
    elicitation_id?: string;
    mode?: 'form' | 'url';
    action: 'accept' | 'decline' | 'cancel';
    content?: Record<string, unknown>;
};
```

**ConfigChangeHookInput:**
```typescript
export declare type ConfigChangeHookInput = BaseHookInput & {
    hook_event_name: 'ConfigChange';
    source: 'user_settings' | 'project_settings' | 'local_settings' | 'policy_settings' | 'skills';
    file_path?: string;
};
```

**WorktreeCreateHookInput:**
```typescript
export declare type WorktreeCreateHookInput = BaseHookInput & {
    hook_event_name: 'WorktreeCreate';
    name: string;
};
```

**WorktreeRemoveHookInput:**
```typescript
export declare type WorktreeRemoveHookInput = BaseHookInput & {
    hook_event_name: 'WorktreeRemove';
    worktree_path: string;
};
```

### 1.3 New Hook-Specific Output Types

```typescript
export declare type ElicitationHookSpecificOutput = {
    hookEventName: 'Elicitation';
    action?: 'accept' | 'decline' | 'cancel';
    content?: Record<string, unknown>;
};

export declare type ElicitationResultHookSpecificOutput = {
    hookEventName: 'ElicitationResult';
    action?: 'accept' | 'decline' | 'cancel';
    content?: Record<string, unknown>;
};
```

### 1.4 Updated SyncHookJSONOutput

The `hookSpecificOutput` union now includes elicitation types:

```typescript
export declare type SyncHookJSONOutput = {
    // ... existing fields ...
    hookSpecificOutput?: PreToolUseHookSpecificOutput
      | UserPromptSubmitHookSpecificOutput
      | SessionStartHookSpecificOutput
      | SetupHookSpecificOutput
      | SubagentStartHookSpecificOutput
      | PostToolUseHookSpecificOutput
      | PostToolUseFailureHookSpecificOutput
      | NotificationHookSpecificOutput
      | PermissionRequestHookSpecificOutput
      // NEW:
      | ElicitationHookSpecificOutput
      | ElicitationResultHookSpecificOutput;
};
```

### 1.5 Updated HookInput Union

```typescript
export declare type HookInput = PreToolUseHookInput | PostToolUseHookInput | ...
    // NEW:
    | ElicitationHookInput | ElicitationResultHookInput
    | ConfigChangeHookInput | WorktreeCreateHookInput | WorktreeRemoveHookInput;
```

**ClodKit files affected:**
- `Sources/ClodKit/Hooks/HookEvent.swift` — Add 5 new cases
- `Sources/ClodKit/Hooks/HookInput.swift` — Add 5 new associated value types
- `Sources/ClodKit/Hooks/HookOutput.swift` — Add 2 new hook-specific output types, update union
- New files for each hook input type (following one-type-per-file pattern)

---

## 2. New SDKMessage Variants

### 2.1 SDKElicitationCompleteMessage

```typescript
export declare type SDKElicitationCompleteMessage = {
    type: 'system';
    subtype: 'elicitation_complete';
    mcp_server_name: string;
    elicitation_id: string;
    uuid: UUID;
    session_id: string;
};
```

### 2.2 SDKPromptSuggestionMessage

```typescript
export declare type SDKPromptSuggestionMessage = {
    type: 'prompt_suggestion';
    suggestion: string;
    uuid: UUID;
    session_id: string;
};
```

### 2.3 Updated SDKMessage Union

```typescript
export declare type SDKMessage = SDKAssistantMessage | SDKUserMessage | SDKUserMessageReplay
    | SDKResultMessage | SDKSystemMessage | SDKPartialAssistantMessage
    | SDKCompactBoundaryMessage | SDKStatusMessage | SDKLocalCommandOutputMessage
    | SDKHookStartedMessage | SDKHookProgressMessage | SDKHookResponseMessage
    | SDKToolProgressMessage | SDKAuthStatusMessage | SDKTaskNotificationMessage
    | SDKTaskStartedMessage | SDKTaskProgressMessage | SDKFilesPersistedEvent
    | SDKToolUseSummaryMessage | SDKRateLimitEvent
    // NEW:
    | SDKElicitationCompleteMessage | SDKPromptSuggestionMessage;
```

**ClodKit files affected:**
- `Sources/ClodKit/Session/SDKMessage.swift` — Add 2 new cases
- New files: `SDKElicitationCompleteMessage.swift`, `SDKPromptSuggestionMessage.swift`

---

## 3. Updated SDKMessage Variants

### 3.1 SDKResultSuccess / SDKResultError — New Fields

Both result types gained:
```typescript
modelUsage: Record<string, ModelUsage>;  // NEW
fast_mode_state?: FastModeState;          // NEW
```

### 3.2 SDKSystemMessage — New Fields

```typescript
export declare type SDKSystemMessage = {
    // ... existing fields ...
    skills: string[];           // NEW
    plugins: {                  // NEW
        name: string;
        path: string;
    }[];
    fast_mode_state?: FastModeState;  // NEW
};
```

### 3.3 SDKStatusMessage — New Field

```typescript
permissionMode?: PermissionMode;  // NEW
```

### 3.4 SDKTaskProgressMessage — New Field

```typescript
last_tool_name?: string;  // NEW
```

### 3.5 SDKTaskStartedMessage — New Field

```typescript
task_type?: string;  // NEW
```

### 3.6 SDKToolProgressMessage — New Field

```typescript
task_id?: string;  // NEW
```

### 3.7 SDKHookResponseMessage — New Field

```typescript
exit_code?: number;  // NEW
```

### 3.8 SDKAssistantMessageError — New Value

```typescript
export declare type SDKAssistantMessageError = 'authentication_failed' | 'billing_error'
    | 'rate_limit' | 'invalid_request' | 'server_error' | 'unknown'
    | 'max_output_tokens';  // NEW
```

### 3.9 SDKRateLimitInfo — Expanded

```typescript
export declare type SDKRateLimitInfo = {
    status: 'allowed' | 'allowed_warning' | 'rejected';
    resetsAt?: number;
    rateLimitType?: 'five_hour' | 'seven_day' | 'seven_day_opus'
        | 'seven_day_sonnet' | 'overage';  // EXPANDED (was just 'five_hour' | 'seven_day')
    utilization?: number;
    overageStatus?: 'allowed' | 'allowed_warning' | 'rejected';  // NEW
    overageResetsAt?: number;                                      // NEW
    overageDisabledReason?: 'overage_not_provisioned' | 'org_level_disabled'
        | 'org_level_disabled_until' | 'out_of_credits' | 'seat_tier_level_disabled'
        | 'member_level_disabled' | 'seat_tier_zero_credit_limit'
        | 'group_zero_credit_limit' | 'member_zero_credit_limit'
        | 'org_service_level_disabled' | 'org_service_zero_credit_limit'
        | 'no_limits_configured' | 'unknown';                     // NEW
    isUsingOverage?: boolean;                                      // NEW
    surpassedThreshold?: number;                                   // NEW
};
```

**ClodKit files affected:**
- `Sources/ClodKit/Session/SDKResultSuccess.swift`
- `Sources/ClodKit/Session/SDKResultError.swift`
- `Sources/ClodKit/Session/SDKSystemMessage.swift`
- `Sources/ClodKit/Session/SDKStatusMessage.swift`
- `Sources/ClodKit/Session/SDKTaskProgressMessage.swift`
- `Sources/ClodKit/Session/SDKTaskStartedMessage.swift`
- `Sources/ClodKit/Session/SDKToolProgressMessage.swift`
- `Sources/ClodKit/Session/SDKHookResponseMessage.swift`
- `Sources/ClodKit/Session/SDKAssistantMessageError.swift`
- `Sources/ClodKit/Session/SDKRateLimitInfo.swift`

---

## 4. Options — New Fields

The `Options` type gained many new fields:

```typescript
export declare type Options = {
    // ... existing fields ...

    // NEW fields:
    agent?: string;                                    // Main thread agent name
    executableArgs?: string[];                         // Additional runtime args
    extraArgs?: Record<string, string | null>;         // Additional CLI args
    fallbackModel?: string;                            // Fallback model
    enableFileCheckpointing?: boolean;                 // File change tracking
    forkSession?: boolean;                             // Fork on resume
    betas?: SdkBeta[];                                 // Beta features
    onElicitation?: OnElicitation;                     // Elicitation callback
    persistSession?: boolean;                          // Disable session persistence
    includePartialMessages?: boolean;                  // Stream partial messages
    thinking?: ThinkingConfig;                         // Thinking/reasoning config
    effort?: 'low' | 'medium' | 'high' | 'max';       // Effort level
    maxBudgetUsd?: number;                             // Budget limit
    plugins?: SdkPluginConfig[];                       // Plugin configs
    promptSuggestions?: boolean;                        // Prompt suggestions
    sessionId?: string;                                // Custom session ID
    resumeSessionAt?: string;                          // Resume at specific message
    settingSources?: SettingSource[];                   // Settings source control
    debug?: boolean;                                   // Debug mode
    debugFile?: string;                                // Debug log file
    stderr?: (data: string) => void;                   // Stderr callback
    strictMcpConfig?: boolean;                         // Strict MCP validation
    spawnClaudeCodeProcess?: (options: SpawnOptions) => SpawnedProcess;  // Custom spawn
};
```

**Note:** Several of these are callback-based and will need Swift-appropriate equivalents (closures/protocols).

**ClodKit files affected:**
- `Sources/ClodKit/Query/QueryOptions.swift` — Add all new fields

---

## 5. Query Interface — New Methods

The `Query` interface gained many new methods:

```typescript
export declare interface Query extends AsyncGenerator<SDKMessage, void> {
    // EXISTING:
    interrupt(): Promise<void>;
    setPermissionMode(mode: PermissionMode): Promise<void>;
    setModel(model?: string): Promise<void>;
    setMaxThinkingTokens(maxThinkingTokens: number | null): Promise<void>;

    // NEW:
    initializationResult(): Promise<SDKControlInitializeResponse>;
    supportedCommands(): Promise<SlashCommand[]>;
    supportedModels(): Promise<ModelInfo[]>;
    supportedAgents(): Promise<AgentInfo[]>;
    mcpServerStatus(): Promise<McpServerStatus[]>;
    accountInfo(): Promise<AccountInfo>;
    rewindFiles(userMessageId: string, options?: { dryRun?: boolean }): Promise<RewindFilesResult>;
    reconnectMcpServer(serverName: string): Promise<void>;
    toggleMcpServer(serverName: string, enabled: boolean): Promise<void>;
    setMcpServers(servers: Record<string, McpServerConfig>): Promise<McpSetServersResult>;
    streamInput(stream: AsyncIterable<SDKUserMessage>): Promise<void>;
    stopTask(taskId: string): Promise<void>;
    close(): void;
}
```

**ClodKit files affected:**
- `Sources/ClodKit/Query/ClaudeQuery.swift` — Add all new methods

---

## 6. New Standalone Functions

### 6.1 getSessionMessages

```typescript
export declare function getSessionMessages(
    _sessionId: string,
    _options?: GetSessionMessagesOptions
): Promise<SessionMessage[]>;

export declare type GetSessionMessagesOptions = {
    dir?: string;
    limit?: number;
    offset?: number;
};

export declare type SessionMessage = {
    type: 'user' | 'assistant';
    uuid: string;
    session_id: string;
    message: unknown;
    parent_tool_use_id: null;
};
```

### 6.2 listSessions

```typescript
export declare function listSessions(
    _options?: ListSessionsOptions
): Promise<SDKSessionInfo[]>;

export declare type ListSessionsOptions = {
    dir?: string;
    limit?: number;
};
```

### 6.3 createSdkMcpServer

```typescript
export declare function createSdkMcpServer(
    _options: CreateSdkMcpServerOptions
): McpSdkServerConfigWithInstance;

declare type CreateSdkMcpServerOptions = {
    name: string;
    version?: string;
    tools?: Array<SdkMcpToolDefinition<any>>;
};
```

**ClodKit files affected:**
- New file: `Sources/ClodKit/Session/SessionMessage.swift`
- New file: `Sources/ClodKit/Session/GetSessionMessagesOptions.swift`
- New file: `Sources/ClodKit/Session/ListSessionsOptions.swift`
- Top-level API functions in `Sources/ClodKit/Query/` or `Sources/ClodKit/Session/`

---

## 7. New Supporting Types

### 7.1 AccountInfo

```typescript
export declare type AccountInfo = {
    email?: string;
    organization?: string;
    subscriptionType?: string;
    tokenSource?: string;
    apiKeySource?: string;
};
```

### 7.2 AgentInfo

```typescript
export declare type AgentInfo = {
    name: string;
    description: string;
    model?: string;
};
```

### 7.3 ModelInfo

```typescript
export declare type ModelInfo = {
    value: string;
    displayName: string;
    description: string;
    supportsEffort?: boolean;
    supportedEffortLevels?: ('low' | 'medium' | 'high' | 'max')[];
    supportsAdaptiveThinking?: boolean;
};
```

### 7.4 ModelUsage

```typescript
export declare type ModelUsage = {
    inputTokens: number;
    outputTokens: number;
    cacheReadInputTokens: number;
    cacheCreationInputTokens: number;
    webSearchRequests: number;
    costUSD: number;
    contextWindow: number;
    maxOutputTokens: number;
};
```

### 7.5 FastModeState

```typescript
export declare type FastModeState = 'off' | 'cooldown' | 'on';
```

### 7.6 ThinkingConfig Types

```typescript
export declare type ThinkingConfig = ThinkingAdaptive | ThinkingEnabled | ThinkingDisabled;

export declare type ThinkingAdaptive = { type: 'adaptive'; };
export declare type ThinkingEnabled = { type: 'enabled'; budgetTokens?: number; };
export declare type ThinkingDisabled = { type: 'disabled'; };
```

### 7.7 RewindFilesResult

```typescript
export declare type RewindFilesResult = {
    canRewind: boolean;
    error?: string;
    filesChanged?: string[];
    insertions?: number;
    deletions?: number;
};
```

### 7.8 McpSetServersResult

```typescript
export declare type McpSetServersResult = {
    added: string[];
    removed: string[];
    errors: Record<string, string>;
};
```

### 7.9 SDKControlInitializeResponse

```typescript
declare type SDKControlInitializeResponse = {
    commands: SlashCommand[];
    agents: AgentInfo[];
    output_style: string;
    available_output_styles: string[];
    models: ModelInfo[];
    account: AccountInfo;
    fast_mode_state?: FastModeState;
};
```

### 7.10 SdkBeta

```typescript
export declare type SdkBeta = 'context-1m-2025-08-07';
```

### 7.11 SdkPluginConfig

```typescript
export declare type SdkPluginConfig = {
    type: 'local';
    path: string;
};
```

### 7.12 ElicitationRequest / OnElicitation

```typescript
export declare type ElicitationRequest = {
    serverName: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitationId?: string;
    requestedSchema?: Record<string, unknown>;
};

export declare type OnElicitation = (
    request: ElicitationRequest,
    options: { signal: AbortSignal }
) => Promise<ElicitationResult>;
```

### 7.13 ConfigScope

```typescript
export declare type ConfigScope = 'local' | 'user' | 'project';
```

### 7.14 SettingSource

```typescript
export declare type SettingSource = 'user' | 'project' | 'local';
```

### 7.15 PromptRequest / PromptRequestOption / PromptResponse

```typescript
export declare type PromptRequest = {
    prompt: string;
    message: string;
    options: PromptRequestOption[];
};

export declare type PromptRequestOption = {
    key: string;
    label: string;
    description?: string;
};

export declare type PromptResponse = {
    prompt_response: string;
    selected: string;
};
```

### 7.16 SDKSessionInfo

```typescript
export declare type SDKSessionInfo = {
    sessionId: string;
    summary: string;
    lastModified: number;
    fileSize: number;
    customTitle?: string;
    firstPrompt?: string;
    gitBranch?: string;
    cwd?: string;
};
```

### 7.17 AsyncHookJSONOutput / BaseOutputFormat

```typescript
export declare type AsyncHookJSONOutput = {
    async: true;
    asyncTimeout?: number;
};

export declare type BaseOutputFormat = {
    type: OutputFormatType;
};
```

### 7.18 SlashCommand

```typescript
export declare type SlashCommand = {
    name: string;
    description: string;
    argumentHint: string;
};
```

### 7.19 HookCallback / HookCallbackMatcher

```typescript
export declare type HookCallback = (
    input: HookInput,
    toolUseID: string | undefined,
    options: { signal: AbortSignal }
) => Promise<HookJSONOutput>;

export declare interface HookCallbackMatcher {
    matcher?: string;
    hooks: HookCallback[];
    timeout?: number;
}
```

**ClodKit files affected:**
- New files in `Sources/ClodKit/` for each type (following one-type-per-file convention)

---

## 8. Updated Existing Types

### 8.1 AgentDefinition — New Fields

```typescript
export declare type AgentDefinition = {
    // EXISTING: description, tools, disallowedTools, prompt, model, mcpServers

    // NEW:
    criticalSystemReminder_EXPERIMENTAL?: string;
    skills?: string[];
    maxTurns?: number;
};
```

### 8.2 StopHookInput — New Field

```typescript
last_assistant_message?: string;  // NEW
```

### 8.3 SubagentStopHookInput — New Field

```typescript
last_assistant_message?: string;  // NEW
```

### 8.4 SessionStartHookInput — New Fields

```typescript
agent_type?: string;  // NEW
model?: string;       // NEW
```

### 8.5 EXIT_REASONS — New Value

```typescript
export declare const EXIT_REASONS: readonly [
    "clear", "logout", "prompt_input_exit", "other",
    "bypass_permissions_disabled"  // NEW
];
```

### 8.6 McpServerStatus.tools — Expanded

```typescript
tools?: {
    name: string;
    description?: string;
    annotations?: {        // NEW
        readOnly?: boolean;
        destructive?: boolean;
        openWorld?: boolean;
    };
}[];
```

**ClodKit files affected:**
- `Sources/ClodKit/Agents/AgentDefinition.swift`
- `Sources/ClodKit/Hooks/StopHookInput.swift`
- `Sources/ClodKit/Hooks/SubagentStopHookInput.swift`
- `Sources/ClodKit/Hooks/SessionStartHookInput.swift`
- `Sources/ClodKit/Session/ExitReason.swift`
- `Sources/ClodKit/MCP/McpServerStatus.swift`

---

## 9. Permission System — New Update Variants

`PermissionUpdate` gained two new variants:

```typescript
export declare type PermissionUpdate =
    | { type: 'addRules'; ... }
    | { type: 'replaceRules'; ... }
    | { type: 'removeRules'; ... }
    | { type: 'setMode'; ... }
    // NEW:
    | { type: 'addDirectories'; directories: string[]; destination: PermissionUpdateDestination; }
    | { type: 'removeDirectories'; directories: string[]; destination: PermissionUpdateDestination; };
```

**ClodKit files affected:**
- `Sources/ClodKit/Permissions/PermissionUpdate.swift`

---

## 10. MCP — New Config Types

### 10.1 McpHttpServerConfig

```typescript
export declare type McpHttpServerConfig = {
    type: 'http';
    url: string;
    headers?: Record<string, string>;
};
```

### 10.2 McpClaudeAIProxyServerConfig (Already in ClodKit)

```typescript
export declare type McpClaudeAIProxyServerConfig = {
    type: 'claudeai-proxy';
    url: string;
    id: string;
};
```

### 10.3 Updated McpServerConfig Union

```typescript
export declare type McpServerConfig = McpStdioServerConfig | McpSSEServerConfig
    | McpHttpServerConfig | McpSdkServerConfigWithInstance;

export declare type McpServerConfigForProcessTransport = McpStdioServerConfig
    | McpSSEServerConfig | McpHttpServerConfig | McpSdkServerConfig;

export declare type McpServerStatusConfig = McpServerConfigForProcessTransport
    | McpClaudeAIProxyServerConfig;
```

**ClodKit files affected:**
- `Sources/ClodKit/MCP/McpHttpServerConfig.swift` (new)
- `Sources/ClodKit/MCP/McpServerConfig.swift` — Update unions

---

## 11. Control Protocol — New Request Types

Several new control request types were added to `SDKControlRequestInner`:

```typescript
declare type SDKControlRequestInner =
    | SDKControlInterruptRequest
    | SDKControlPermissionRequest
    | SDKControlInitializeRequest
    | SDKControlSetPermissionModeRequest
    | SDKControlSetModelRequest
    | SDKControlSetMaxThinkingTokensRequest
    | SDKControlMcpStatusRequest
    | SDKHookCallbackRequest
    | SDKControlMcpMessageRequest
    | SDKControlRewindFilesRequest
    | SDKControlMcpSetServersRequest
    | SDKControlMcpReconnectRequest
    | SDKControlMcpToggleRequest
    // NEW:
    | SDKControlMcpAuthenticateRequest
    | SDKControlMcpClearAuthRequest
    | SDKControlMcpOAuthCallbackUrlRequest
    | SDKControlRemoteControlRequest
    | SDKControlStopTaskRequest
    | SDKControlApplyFlagSettingsRequest
    | SDKControlElicitationRequest;
```

Note: `SDKControlMcpAuthenticateRequest`, `SDKControlMcpClearAuthRequest`, `SDKControlMcpOAuthCallbackUrlRequest`, and `SDKControlRemoteControlRequest` are referenced in the union but their type definitions are not exported in sdk.d.ts — they are internal types.

**New exported control types:**

```typescript
declare type SDKControlStopTaskRequest = {
    subtype: 'stop_task';
    task_id: string;
};

declare type SDKControlApplyFlagSettingsRequest = {
    subtype: 'apply_flag_settings';
    settings: Record<string, unknown>;
};

declare type SDKControlElicitationRequest = {
    subtype: 'elicitation';
    mcp_server_name: string;
    message: string;
    mode?: 'form' | 'url';
    url?: string;
    elicitation_id?: string;
    requested_schema?: Record<string, unknown>;
};

declare type SDKControlCancelRequest = {
    type: 'control_cancel_request';
    request_id: string;
};
```

Also, `SDKControlPermissionRequest` gained new fields:
```typescript
blocked_path?: string;     // NEW
decision_reason?: string;  // NEW
description?: string;      // NEW
```

And `SDKControlInitializeRequest` gained:
```typescript
promptSuggestions?: boolean;  // NEW
```

**ClodKit files affected:**
- `Sources/ClodKit/ControlProtocol/` — Add new control request types, update request inner union

---

## 12. Tool Input/Output Schemas — New Tools and Updated Fields

### 12.1 New Tool Types

**ConfigInput / ConfigOutput:**
```typescript
export interface ConfigInput {
    setting: string;
    value?: string | boolean | number;
}

export interface ConfigOutput {
    success: boolean;
    operation?: 'get' | 'set';
    setting?: string;
    value?: unknown;
    previousValue?: unknown;
    newValue?: unknown;
    error?: string;
}
```

**EnterWorktreeInput / EnterWorktreeOutput:**
```typescript
export interface EnterWorktreeInput {
    name?: string;
}

export interface EnterWorktreeOutput {
    worktreePath: string;
    worktreeBranch?: string;
    message: string;
}
```

**SubscribePollingInput / SubscribePollingOutput:**
```typescript
export interface SubscribePollingInput {
    type: 'tool' | 'resource';
    server: string;
    toolName?: string;
    arguments?: Record<string, unknown>;
    uri?: string;
    intervalMs: number;
    reason?: string;
}

export interface SubscribePollingOutput {
    subscribed: boolean;
    subscriptionId: string;
}
```

**UnsubscribePollingInput / UnsubscribePollingOutput:**
```typescript
export interface UnsubscribePollingInput {
    subscriptionId?: string;
    server?: string;
    target?: string;
}

export interface UnsubscribePollingOutput {
    unsubscribed: boolean;
}
```

### 12.2 Updated Tool Types

**AgentInput — New Fields:**
```typescript
name?: string;
team_name?: string;
mode?: 'acceptEdits' | 'bypassPermissions' | 'default' | 'dontAsk' | 'plan';
isolation?: 'worktree';
```

**AgentOutput — New Variant:**
```typescript
| {
    status: 'sub_agent_entered';
    description: string;
    message: string;
}
```

**BashOutput — Many New Fields:**
```typescript
rawOutputPath?: string;
isImage?: boolean;
backgroundTaskId?: string;
backgroundedByUser?: boolean;
dangerouslyDisableSandbox?: boolean;
returnCodeInterpretation?: string;
noOutputExpected?: boolean;
structuredContent?: unknown[];
persistedOutputPath?: string;
persistedOutputSize?: number;
```

**ExitPlanModeOutput — New Fields:**
```typescript
awaitingLeaderApproval?: boolean;
requestId?: string;
```

**FileEditOutput — New Field:**
```typescript
gitDiff?: {
    filename: string;
    status: 'modified' | 'added';
    additions: number;
    deletions: number;
    changes: number;
    patch: string;
};
```

**FileWriteOutput — New Field:**
```typescript
gitDiff?: { /* same structure as FileEditOutput.gitDiff */ };
```

**FileReadOutput — New Variant:**
```typescript
| {
    type: 'parts';
    file: {
        filePath: string;
        originalSize: number;
        count: number;
        outputDir: string;
    };
}
```

**TaskStopOutput — Restructured:**
```typescript
export interface TaskStopOutput {
    message: string;
    task_id: string;
    task_type: string;
    command?: string;
}
```

**AskUserQuestionInput — New Fields:**
```typescript
answers?: Record<string, string>;
metadata?: { source?: string; };
```

**ClodKit files affected:**
- `Sources/ClodKit/ControlProtocol/Tools/` — Add new tool types, update existing

---

## 13. V2 Session API — Updated Types

### 13.1 SDKSessionOptions — New Fields

```typescript
export declare type SDKSessionOptions = {
    model: string;
    pathToClaudeCodeExecutable?: string;
    executable?: 'node' | 'bun';
    executableArgs?: string[];
    env?: Record<string, string | undefined>;
    // NEW:
    allowedTools?: string[];
    disallowedTools?: string[];
    canUseTool?: CanUseTool;
    hooks?: Partial<Record<HookEvent, HookCallbackMatcher[]>>;
    permissionMode?: PermissionMode;
};
```

### 13.2 SDKSessionInfo (New Type — see Section 7.16)

### 13.3 New Session Functions (see Section 6)

**ClodKit files affected:**
- `Sources/ClodKit/Session/SDKSessionOptions.swift`

---

## 14. Sandbox Configuration — Changes

### 14.1 SandboxSettings — New Fields

```typescript
enableWeakerNestedSandbox?: boolean;  // NEW
excludedCommands?: string[];          // NEW
```

### 14.2 SandboxNetworkConfig — New Fields

```typescript
allowAllUnixSockets?: boolean;  // NEW
httpProxyPort?: number;         // NEW
socksProxyPort?: number;        // NEW
```

### 14.3 SandboxFilesystemConfig (New Sub-type)

```typescript
export declare type SandboxFilesystemConfig = {
    allowWrite?: string[];
    denyWrite?: string[];
    denyRead?: string[];
};
```

**ClodKit files affected:**
- `Sources/ClodKit/Sandbox/SandboxSettings.swift`
- `Sources/ClodKit/Sandbox/SandboxNetworkConfig.swift`
- New file: `Sources/ClodKit/Sandbox/SandboxFilesystemConfig.swift`

---

## 15. Unchanged Areas

The following areas remain unchanged from v0.2.34:

- **Core `query()` function signature** — Same `{ prompt, options }` shape
- **`tool()` function** — Same signature with optional annotations
- **PermissionMode values** — Same 5 modes
- **PermissionBehavior** — Same `'allow' | 'deny' | 'ask'`
- **PermissionResult** — Same structure (with allow/deny variants)
- **SDKUserMessage / SDKUserMessageReplay** — Same structure
- **SDKAssistantMessage** — Same structure (error enum updated separately)
- **SDKCompactBoundaryMessage** — Same structure
- **SDKLocalCommandOutputMessage** — Same structure
- **SDKAuthStatusMessage** — Same structure
- **SDKFilesPersistedEvent** — Same structure
- **SDKToolUseSummaryMessage** — Same structure
- **Most hook input base structure** — `BaseHookInput` unchanged
- **Pre/PostToolUseHookInput** — Same structure
- **NotificationHookInput** — Same structure
- **UserPromptSubmitHookInput** — Same structure
- **PermissionRequestHookInput** — Same structure (added `permission_suggestions`)
- **McpStdioServerConfig / McpSSEServerConfig** — Same structure

---

## 16. ClodKit Impact Assessment

### HIGH Priority — Core API Gaps

1. **Hook system expansion (15 → 20 events)** — 5 new hook events with input types, 2 new specific output types. This is the most structurally complex change. Multiple files affected across Hooks/.

2. **Options expansion** — ~25 new fields. Many are simple optional fields, but some require new supporting types (ThinkingConfig, SdkPluginConfig, etc.).

3. **Query interface expansion** — 13 new methods. These require corresponding control request handling in the transport layer.

4. **New SDKMessage variants** — 2 new message types plus fields added to 9 existing message types.

### MEDIUM Priority — Type Additions

5. **New supporting types** — ~20 new types (AccountInfo, AgentInfo, ModelInfo, ModelUsage, FastModeState, ThinkingConfig, etc.). All straightforward Codable structs/enums.

6. **Tool schema updates** — 4 new tool types (Config, EnterWorktree, SubscribePolling, UnsubscribePolling), plus expanded fields on 8 existing tool types.

7. **Permission system expansion** — 2 new PermissionUpdate variants (addDirectories, removeDirectories).

8. **MCP config expansion** — McpHttpServerConfig type, updated union types.

9. **Control protocol expansion** — 7 new control request types.

### LOW Priority — Minor Updates

10. **Sandbox config fields** — 5 new optional fields across SandboxSettings, SandboxNetworkConfig, new SandboxFilesystemConfig.

11. **V2 Session API updates** — SDKSessionOptions expansion, new session functions.

12. **Standalone functions** — getSessionMessages, listSessions (session reading utilities).

13. **SDKRateLimitInfo expansion** — 5 new optional fields.

14. **ExitReason new value** — `bypass_permissions_disabled`.

### Summary

| Category | New Types | Updated Types | New Fields | New Methods |
|----------|-----------|---------------|------------|-------------|
| Hooks | 7 | 3 | - | - |
| Messages | 2 | 9 | ~15 | - |
| Options | - | 1 | ~25 | - |
| Query | - | 1 | - | 13 |
| Supporting Types | ~20 | - | - | - |
| Tool Schemas | 8 | 8 | ~20 | - |
| Permissions | - | 1 | - | - |
| MCP | 1 | 2 | - | - |
| Control Protocol | 7 | 2 | - | - |
| Sandbox | 1 | 2 | 5 | - |
| V2 Session | 2 | 1 | 5 | - |
| Standalone Functions | - | - | - | 3 |
| **Total** | **~48** | **~30** | **~70** | **16** |
