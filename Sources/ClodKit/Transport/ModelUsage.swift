//
//  ModelUsage.swift
//  ClodKit
//
//  Token usage and cost information from a model response.
//

import Foundation

// MARK: - Model Usage

/// Token usage and cost information from a model response.
public struct ModelUsage: Sendable, Equatable, Codable {
    /// Number of input tokens consumed.
    public let inputTokens: Int

    /// Number of output tokens generated.
    public let outputTokens: Int

    /// Number of input tokens read from cache.
    public let cacheReadInputTokens: Int

    /// Number of input tokens written to cache.
    public let cacheCreationInputTokens: Int

    /// Number of web search requests made.
    public let webSearchRequests: Int

    /// Cost in USD.
    public let costUSD: Double

    /// Context window size.
    public let contextWindow: Int

    /// Maximum output tokens allowed.
    public let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens", outputTokens = "output_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case webSearchRequests = "web_search_requests"
        case costUSD = "cost_usd", contextWindow = "context_window"
        case maxOutputTokens = "max_output_tokens"
    }
}
