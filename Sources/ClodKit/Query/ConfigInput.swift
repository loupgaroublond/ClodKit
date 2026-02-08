//
//  ConfigInput.swift
//  ClodKit
//
//  Input type for configuration tool.
//

import Foundation

// MARK: - Config Input

/// Input for the configuration tool.
public struct ConfigInput: Sendable, Equatable, Codable {
    /// The setting name to read or modify.
    public let setting: String

    /// The value to set, or nil to read the current value.
    public let value: JSONValue?

    public init(setting: String, value: JSONValue? = nil) {
        self.setting = setting
        self.value = value
    }
}
