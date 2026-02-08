//
//  TaskStopInput.swift
//  ClodKit
//
//  Input type for stopping a background task (renamed from KillBash).
//

import Foundation

// MARK: - Task Stop Input

/// Input for stopping a background task.
public struct TaskStopInput: Sendable, Equatable, Codable {
    /// The task ID to stop.
    public let taskId: String?

    /// Legacy shell ID (deprecated, use taskId instead).
    @available(*, deprecated, renamed: "taskId")
    public let shellId: String?

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id", shellId = "shell_id"
    }

    public init(taskId: String? = nil, shellId: String? = nil) {
        self.taskId = taskId
        self.shellId = shellId
    }
}
