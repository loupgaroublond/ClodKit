//
//  ApiKeySource.swift
//  ClodKit
//
//  Source of the API key used for authentication.
//

import Foundation

// MARK: - API Key Source

/// The source from which the API key was obtained.
public enum ApiKeySource: Codable, Sendable, Equatable {
    /// Key provided by the user directly.
    case user

    /// Key from a project-level configuration.
    case project

    /// Key from an organization-level configuration.
    case org

    /// Temporary key issued for a session.
    case temporary

    /// Key obtained via OAuth flow.
    case oauth

    /// An unrecognized source value from a newer CLI version.
    case unknown(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "user": self = .user
        case "project": self = .project
        case "org": self = .org
        case "temporary": self = .temporary
        case "oauth": self = .oauth
        default: self = .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .user: try container.encode("user")
        case .project: try container.encode("project")
        case .org: try container.encode("org")
        case .temporary: try container.encode("temporary")
        case .oauth: try container.encode("oauth")
        case .unknown(let value): try container.encode(value)
        }
    }
}
