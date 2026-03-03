//
//  SDKRateLimitInfo.swift
//  ClodKit
//
//  Rate limit information and event types from CLI.
//

import Foundation

// MARK: - SDK Rate Limit Info

/// Rate limit information for claude.ai subscription users.
public struct SDKRateLimitInfo: Sendable, Equatable, Codable {
    public let status: String
    public let resetsAt: Double?
    public let rateLimitType: String?
    public let utilization: Double?
    public let overageStatus: String?
    public let overageResetsAt: Double?
    public let overageDisabledReason: String?
    public let isUsingOverage: Bool?
    public let surpassedThreshold: Double?

    enum CodingKeys: String, CodingKey {
        case status
        case resetsAt = "resetsAt"
        case rateLimitType = "rateLimitType"
        case utilization
        case overageStatus = "overageStatus"
        case overageResetsAt = "overageResetsAt"
        case overageDisabledReason = "overageDisabledReason"
        case isUsingOverage = "isUsingOverage"
        case surpassedThreshold = "surpassedThreshold"
    }
}

// MARK: - SDK Rate Limit Event

/// Rate limit event emitted when rate limit info changes.
public struct SDKRateLimitEvent: Sendable, Equatable, Codable {
    public let type: String
    public let rateLimitInfo: SDKRateLimitInfo
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type
        case rateLimitInfo = "rate_limit_info"
        case uuid
        case sessionId = "session_id"
    }
}
