//
//  FastModeState.swift
//  ClodKit
//
//  Enum representing the current fast mode state.
//

import Foundation

// MARK: - Fast Mode State

/// The current state of fast mode.
public enum FastModeState: String, Sendable, Equatable, Codable {
    case off
    case cooldown
    case on
}
