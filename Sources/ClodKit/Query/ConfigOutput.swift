//
//  ConfigOutput.swift
//  ClodKit
//
//  Output type for the Config tool.
//

import Foundation

// MARK: - Config Output

/// Output from the Config tool.
public struct ConfigOutput: Sendable, Equatable, Codable {
    /// Whether the operation was successful.
    public let success: Bool

    /// The operation that was performed ("get" or "set").
    public let operation: String?

    /// The setting name.
    public let setting: String?

    /// The current value of the setting.
    public let value: JSONValue?

    /// The previous value of the setting (for set operations).
    public let previousValue: JSONValue?

    /// The new value after setting.
    public let newValue: JSONValue?

    /// Error message if the operation failed.
    public let error: String?

    public init(
        success: Bool,
        operation: String? = nil,
        setting: String? = nil,
        value: JSONValue? = nil,
        previousValue: JSONValue? = nil,
        newValue: JSONValue? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.operation = operation
        self.setting = setting
        self.value = value
        self.previousValue = previousValue
        self.newValue = newValue
        self.error = error
    }
}
