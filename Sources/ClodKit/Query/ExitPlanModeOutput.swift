//
//  ExitPlanModeOutput.swift
//  ClodKit
//
//  Output type for ExitPlanMode tool.
//

import Foundation

// MARK: - Exit Plan Mode Output

/// Output from the ExitPlanMode tool.
public struct ExitPlanModeOutput: Sendable, Equatable, Codable {
    /// The plan that was presented to the user.
    public let plan: String?

    /// Whether in agent context.
    public let isAgent: Bool

    /// The file path where the plan was saved.
    public let filePath: String?

    /// Whether the Agent tool is available in the current context.
    public let hasTaskTool: Bool?

    /// When true, the teammate has sent a plan approval request to the team leader.
    public let awaitingLeaderApproval: Bool?

    /// Unique identifier for the plan approval request.
    public let requestId: String?

    enum CodingKeys: String, CodingKey {
        case plan
        case isAgent = "isAgent"
        case filePath = "filePath"
        case hasTaskTool = "hasTaskTool"
        case awaitingLeaderApproval = "awaitingLeaderApproval"
        case requestId = "requestId"
    }

    public init(
        plan: String?,
        isAgent: Bool,
        filePath: String? = nil,
        hasTaskTool: Bool? = nil,
        awaitingLeaderApproval: Bool? = nil,
        requestId: String? = nil
    ) {
        self.plan = plan
        self.isAgent = isAgent
        self.filePath = filePath
        self.hasTaskTool = hasTaskTool
        self.awaitingLeaderApproval = awaitingLeaderApproval
        self.requestId = requestId
    }
}
