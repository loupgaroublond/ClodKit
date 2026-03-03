//
//  ConfigScope.swift
//  ClodKit
//
//  Enum representing the scope of a configuration setting.
//

import Foundation

// MARK: - Config Scope

/// The scope of a configuration setting.
public enum ConfigScope: String, Sendable, Equatable, Codable {
    case local
    case user
    case project
}
