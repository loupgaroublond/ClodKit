//
//  AgentOutput.swift
//  ClodKit
//
//  Output type for the agent/subagent tool.
//

import Foundation

// MARK: - Agent Output

/// Output from a subagent execution.
public enum AgentOutput: Sendable, Equatable, Codable {
    /// Agent completed successfully.
    case completed(AgentCompletedOutput)

    /// Agent launched in the background asynchronously.
    case asyncLaunched(AgentAsyncLaunchedOutput)

    /// A sub-agent was entered (control transferred).
    case subAgentEntered(AgentSubAgentEnteredOutput)

    enum CodingKeys: String, CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        switch status {
        case "completed":
            self = .completed(try AgentCompletedOutput(from: decoder))
        case "async_launched":
            self = .asyncLaunched(try AgentAsyncLaunchedOutput(from: decoder))
        case "sub_agent_entered":
            self = .subAgentEntered(try AgentSubAgentEnteredOutput(from: decoder))
        default:
            self = .completed(try AgentCompletedOutput(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .completed(let output): try output.encode(to: encoder)
        case .asyncLaunched(let output): try output.encode(to: encoder)
        case .subAgentEntered(let output): try output.encode(to: encoder)
        }
    }
}

// MARK: - Agent Completed Output

/// Output when an agent completes execution.
public struct AgentCompletedOutput: Sendable, Equatable, Codable {
    public let agentId: String
    public let content: [AgentTextContent]
    public let totalToolUseCount: Int
    public let totalDurationMs: Int
    public let totalTokens: Int
    public let usage: AgentUsage
    public let status: String
    public let prompt: String

    enum CodingKeys: String, CodingKey {
        case agentId = "agentId"
        case content
        case totalToolUseCount = "totalToolUseCount"
        case totalDurationMs = "totalDurationMs"
        case totalTokens = "totalTokens"
        case usage, status, prompt
    }

    public init(
        agentId: String,
        content: [AgentTextContent],
        totalToolUseCount: Int,
        totalDurationMs: Int,
        totalTokens: Int,
        usage: AgentUsage,
        prompt: String
    ) {
        self.agentId = agentId
        self.content = content
        self.totalToolUseCount = totalToolUseCount
        self.totalDurationMs = totalDurationMs
        self.totalTokens = totalTokens
        self.usage = usage
        self.status = "completed"
        self.prompt = prompt
    }
}

// MARK: - Agent Text Content

/// Text content item from an agent response.
public struct AgentTextContent: Sendable, Equatable, Codable {
    public let type: String
    public let text: String

    public init(type: String = "text", text: String) {
        self.type = type
        self.text = text
    }
}

// MARK: - Agent Usage

/// Token usage information for an agent execution.
public struct AgentUsage: Sendable, Equatable, Codable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let serverToolUse: AgentServerToolUse?
    public let serviceTier: String?
    public let cacheCreation: AgentCacheCreation?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case serverToolUse = "server_tool_use"
        case serviceTier = "service_tier"
        case cacheCreation = "cache_creation"
    }

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        serverToolUse: AgentServerToolUse? = nil,
        serviceTier: String? = nil,
        cacheCreation: AgentCacheCreation? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.serverToolUse = serverToolUse
        self.serviceTier = serviceTier
        self.cacheCreation = cacheCreation
    }
}

// MARK: - Agent Server Tool Use

/// Server-side tool use statistics.
public struct AgentServerToolUse: Sendable, Equatable, Codable {
    public let webSearchRequests: Int
    public let webFetchRequests: Int

    enum CodingKeys: String, CodingKey {
        case webSearchRequests = "web_search_requests"
        case webFetchRequests = "web_fetch_requests"
    }

    public init(webSearchRequests: Int, webFetchRequests: Int) {
        self.webSearchRequests = webSearchRequests
        self.webFetchRequests = webFetchRequests
    }
}

// MARK: - Agent Cache Creation

/// Cache creation statistics.
public struct AgentCacheCreation: Sendable, Equatable, Codable {
    public let ephemeral1hInputTokens: Int
    public let ephemeral5mInputTokens: Int

    enum CodingKeys: String, CodingKey {
        case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
        case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
    }

    public init(ephemeral1hInputTokens: Int, ephemeral5mInputTokens: Int) {
        self.ephemeral1hInputTokens = ephemeral1hInputTokens
        self.ephemeral5mInputTokens = ephemeral5mInputTokens
    }
}

// MARK: - Agent Async Launched Output

/// Output when an agent is launched asynchronously.
public struct AgentAsyncLaunchedOutput: Sendable, Equatable, Codable {
    public let status: String
    public let agentId: String
    public let description: String
    public let prompt: String
    public let outputFile: String
    public let canReadOutputFile: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case agentId = "agentId"
        case description, prompt
        case outputFile = "outputFile"
        case canReadOutputFile = "canReadOutputFile"
    }

    public init(
        agentId: String,
        description: String,
        prompt: String,
        outputFile: String,
        canReadOutputFile: Bool? = nil
    ) {
        self.status = "async_launched"
        self.agentId = agentId
        self.description = description
        self.prompt = prompt
        self.outputFile = outputFile
        self.canReadOutputFile = canReadOutputFile
    }
}

// MARK: - Agent Sub Agent Entered Output

/// Output when a sub-agent is entered (control transfer).
public struct AgentSubAgentEnteredOutput: Sendable, Equatable, Codable {
    public let status: String
    public let description: String
    public let message: String

    public init(description: String, message: String) {
        self.status = "sub_agent_entered"
        self.description = description
        self.message = message
    }
}
