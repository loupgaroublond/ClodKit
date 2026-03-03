//
//  SettingSource.swift
//  ClodKit
//
//  Enum representing the source of a setting.
//

import Foundation

// MARK: - Setting Source

/// Source for loading filesystem-based settings.
public enum SettingSource: String, Sendable, Equatable, Codable {
    /// Global user settings (~/.claude/settings.json).
    case user
    /// Project settings (.claude/settings.json).
    case project
    /// Local settings (.claude/settings.local.json).
    case local
}
