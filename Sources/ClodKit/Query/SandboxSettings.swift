//
//  SandboxSettings.swift
//  ClodKit
//
//  Sandbox configuration for CLI process execution.
//

import Foundation

// MARK: - Sandbox Settings

/// Sandbox configuration for CLI process execution.
public struct SandboxSettings: Sendable, Equatable, Codable {
    /// Whether sandboxing is enabled.
    public var enabled: Bool?

    /// Automatically allow Bash commands if sandboxed.
    public var autoAllowBashIfSandboxed: Bool?

    /// Allow unsandboxed commands.
    public var allowUnsandboxedCommands: Bool?

    /// Network configuration for the sandbox.
    public var network: SandboxNetworkConfig?

    /// Violations to ignore, keyed by category.
    public var ignoreViolations: [String: [String]]?

    /// Enable a weaker nested sandbox.
    public var enableWeakerNestedSandbox: Bool?

    /// Commands excluded from sandboxing.
    public var excludedCommands: [String]?

    /// Ripgrep configuration override.
    public var ripgrep: RipgrepConfig?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case enabled, autoAllowBashIfSandboxed = "auto_allow_bash_if_sandboxed"
        case allowUnsandboxedCommands = "allow_unsandboxed_commands"
        case network, ignoreViolations = "ignore_violations"
        case enableWeakerNestedSandbox = "enable_weaker_nested_sandbox"
        case excludedCommands = "excluded_commands", ripgrep
    }
}

// MARK: - Sandbox Network Config

/// Network configuration within a sandbox.
public struct SandboxNetworkConfig: Sendable, Equatable, Codable {
    /// Domains allowed for network access.
    public var allowedDomains: [String]?

    /// Only allow managed domains.
    public var allowManagedDomainsOnly: Bool?

    /// Unix sockets allowed for communication.
    public var allowUnixSockets: [String]?

    /// Allow all Unix sockets.
    public var allowAllUnixSockets: Bool?

    /// Allow binding to local ports.
    public var allowLocalBinding: Bool?

    /// HTTP proxy port.
    public var httpProxyPort: Int?

    /// SOCKS proxy port.
    public var socksProxyPort: Int?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case allowedDomains = "allowed_domains"
        case allowManagedDomainsOnly = "allow_managed_domains_only"
        case allowUnixSockets = "allow_unix_sockets"
        case allowAllUnixSockets = "allow_all_unix_sockets"
        case allowLocalBinding = "allow_local_binding"
        case httpProxyPort = "http_proxy_port"
        case socksProxyPort = "socks_proxy_port"
    }
}

// MARK: - Ripgrep Config

/// Configuration for the ripgrep command.
public struct RipgrepConfig: Sendable, Equatable, Codable {
    /// The ripgrep command path.
    public let command: String

    /// Additional arguments for ripgrep.
    public var args: [String]?

    public init(command: String, args: [String]? = nil) {
        self.command = command
        self.args = args
    }
}
