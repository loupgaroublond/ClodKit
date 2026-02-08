//
//  TaskOutputInput.swift
//  ClodKit
//
//  Input type for retrieving task output (renamed from BashOutput).
//

import Foundation

// MARK: - Task Output Input

/// Input for retrieving output from a background task.
public struct TaskOutputInput: Sendable, Equatable, Codable {
    /// The task ID to retrieve output from.
    public let taskId: String

    /// Whether to block until output is available.
    public let block: Bool

    /// Timeout in milliseconds.
    public let timeout: Int

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id", block, timeout
    }

    public init(taskId: String, block: Bool = true, timeout: Int = 30000) {
        self.taskId = taskId
        self.block = block
        self.timeout = timeout
    }
}
