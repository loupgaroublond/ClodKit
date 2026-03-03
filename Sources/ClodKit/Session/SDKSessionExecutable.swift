//
//  SDKSessionExecutable.swift
//  ClodKit
//
//  Executable runtime options for V2 SDK sessions.
//
//  Note: The main Options uses cliPath: String (which can also be 'deno').
//  SDKSessionOptions only supports 'node' and 'bun' per the TypeScript SDK.
//

import Foundation

// MARK: - SDK Session Executable

/// Executable runtime for V2 SDK sessions.
/// Note: 'deno' is supported in the main Options but not in SDKSessionOptions.
@available(*, message: "V2 Session API is unstable and may change")
public enum SDKSessionExecutable: String, Sendable, Equatable, Codable {
    case node
    case bun
}
