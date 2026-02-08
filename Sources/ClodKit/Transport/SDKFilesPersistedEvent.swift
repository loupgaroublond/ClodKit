//
//  SDKFilesPersistedEvent.swift
//  ClodKit
//
//  Typed representation of file persistence events from CLI.
//

import Foundation

// MARK: - SDK Files Persisted Event

/// Notification that files have been persisted to storage.
public struct SDKFilesPersistedEvent: Sendable, Equatable, Codable {
    public let type: String
    public let subtype: String
    public let files: [PersistedFile]
    public let failed: [FailedFile]
    public let processedAt: String
    public let uuid: String
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case type, subtype, files, failed
        case processedAt = "processed_at"
        case uuid
        case sessionId = "session_id"
    }
}

// MARK: - Persisted File

/// A file that was successfully persisted.
public struct PersistedFile: Sendable, Equatable, Codable {
    public let filename: String
    public let fileId: String

    enum CodingKeys: String, CodingKey {
        case filename
        case fileId = "file_id"
    }
}

// MARK: - Failed File

/// A file that failed to persist.
public struct FailedFile: Sendable, Equatable, Codable {
    public let filename: String
    public let error: String
}
