//
//  TaskStopOutput.swift
//  ClodKit
//
//  Output type for the TaskStop tool.
//

import Foundation

// MARK: - Task Stop Output

/// Output from stopping a background task.
public struct TaskStopOutput: Sendable, Equatable, Codable {
    /// Status message about the operation.
    public let message: String

    /// The ID of the task that was stopped.
    public let taskId: String

    /// The type of the task that was stopped.
    public let taskType: String

    /// The command or description of the stopped task.
    public let command: String?

    enum CodingKeys: String, CodingKey {
        case message
        case taskId = "task_id"
        case taskType = "task_type"
        case command
    }

    public init(message: String, taskId: String, taskType: String, command: String? = nil) {
        self.message = message
        self.taskId = taskId
        self.taskType = taskType
        self.command = command
    }
}
