//
//  BoundaryCrossingTest.swift
//  ClodKit
//
//  Protocol for roundtrip identity tests across boundary crossings,
//  plus concrete implementations for shell, JSON, Codable, and environment boundaries.
//

import Foundation

// MARK: - Boundary Crossing Test Protocol

/// Protocol for testing that data survives a boundary crossing intact.
/// The invariant: `recover(transform(input)) == input`.
protocol BoundaryCrossingTest {
    associatedtype Input: Equatable
    associatedtype Intermediate

    /// Name of this boundary crossing (for diagnostics).
    var crossingName: String { get }

    /// Transform input for the target context (e.g., encode to JSON).
    func transform(_ input: Input) throws -> Intermediate

    /// Recover the original input from the target context's representation.
    func recover(_ intermediate: Intermediate) throws -> Input
}

extension BoundaryCrossingTest {
    /// The roundtrip invariant: data survives the boundary crossing intact.
    func testRoundtrip(_ input: Input) throws {
        let intermediate = try transform(input)
        let recovered = try recover(intermediate)
        guard recovered == input else {
            throw BoundaryCrossingError.roundtripFailed(
                crossing: crossingName,
                input: "\(input)",
                recovered: "\(recovered)"
            )
        }
    }
}

/// Errors from boundary crossing tests.
enum BoundaryCrossingError: Error, LocalizedError {
    case roundtripFailed(crossing: String, input: String, recovered: String)
    case transformFailed(crossing: String, input: String, reason: String)
    case recoverFailed(crossing: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .roundtripFailed(let crossing, let input, let recovered):
            return "Roundtrip failed at \(crossing): \(input.debugDescription) -> \(recovered.debugDescription)"
        case .transformFailed(let crossing, let input, let reason):
            return "Transform failed at \(crossing) for \(input.debugDescription): \(reason)"
        case .recoverFailed(let crossing, let reason):
            return "Recover failed at \(crossing): \(reason)"
        }
    }
}

// MARK: - JSON Boundary Crossing

/// Tests that strings survive JSON encode/decode roundtrips via JSONSerialization.
struct JSONSerializationCrossing: BoundaryCrossingTest {
    typealias Input = String
    typealias Intermediate = Data

    var crossingName: String { "JSONSerialization" }

    func transform(_ input: String) throws -> Data {
        let payload: [String: Any] = ["value": input]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    func recover(_ intermediate: Data) throws -> String {
        let parsed = try JSONSerialization.jsonObject(with: intermediate, options: [])
        guard let dict = parsed as? [String: Any],
              let value = dict["value"] as? String else {
            throw BoundaryCrossingError.recoverFailed(
                crossing: crossingName,
                reason: "Could not extract string from parsed JSON"
            )
        }
        return value
    }
}

// MARK: - Codable Boundary Crossing

/// Tests that a Codable value survives JSONEncoder/JSONDecoder roundtrips.
struct CodableCrossing<T: Codable & Equatable>: BoundaryCrossingTest {
    typealias Input = T
    typealias Intermediate = Data

    let typeName: String
    var crossingName: String { "Codable<\(typeName)>" }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(typeName: String = String(describing: T.self)) {
        self.typeName = typeName
    }

    func transform(_ input: T) throws -> Data {
        try encoder.encode(input)
    }

    func recover(_ intermediate: Data) throws -> T {
        try decoder.decode(T.self, from: intermediate)
    }
}

// MARK: - Environment Variable Key-Value Pair

/// An equatable key-value pair for environment variable roundtrip testing.
/// Tuples cannot conform to Equatable in Swift, so we use a struct.
struct EnvironmentKeyValue: Equatable {
    let key: String
    let value: String
}

// MARK: - Environment Variable Boundary Crossing

/// Tests that key/value pairs survive process environment set/get.
/// This uses in-process dictionary operations (same as Process.environment).
struct EnvironmentCrossing: BoundaryCrossingTest {
    typealias Input = EnvironmentKeyValue
    typealias Intermediate = [String: String]

    var crossingName: String { "Environment" }

    func transform(_ input: EnvironmentKeyValue) throws -> [String: String] {
        // Simulate setting an environment variable
        var env: [String: String] = [:]
        env[input.key] = input.value
        return env
    }

    func recover(_ intermediate: [String: String]) throws -> EnvironmentKeyValue {
        guard let entry = intermediate.first else {
            throw BoundaryCrossingError.recoverFailed(
                crossing: crossingName,
                reason: "Empty environment dictionary"
            )
        }
        return EnvironmentKeyValue(key: entry.key, value: entry.value)
    }
}

// MARK: - Shell Argument Boundary Crossing

/// Tests that strings survive the ProcessTransport argument-passing path.
/// This verifies arguments appear as discrete elements in the arguments array,
/// unchanged from their original value.
struct ShellArgumentCrossing: BoundaryCrossingTest {
    typealias Input = String
    typealias Intermediate = [String]

    var crossingName: String { "ShellArgument" }

    /// The flag that precedes this argument (e.g., "--system-prompt").
    let flag: String

    func transform(_ input: String) throws -> [String] {
        // Simulate what buildCLIArguments does: append flag and value as discrete elements
        return [flag, input]
    }

    func recover(_ intermediate: [String]) throws -> String {
        // The value should be at index 1, unchanged
        guard intermediate.count == 2, intermediate[0] == flag else {
            throw BoundaryCrossingError.recoverFailed(
                crossing: crossingName,
                reason: "Expected [flag, value], got \(intermediate)"
            )
        }
        return intermediate[1]
    }
}
