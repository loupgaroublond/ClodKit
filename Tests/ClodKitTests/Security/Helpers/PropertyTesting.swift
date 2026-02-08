//
//  PropertyTesting.swift
//  ClodKit
//
//  Lightweight property testing framework with deterministic random generation.
//  Zero external dependencies — pure Swift.
//

import Foundation

// MARK: - Seeded Random Number Generator

/// Deterministic random number generator using xorshift64.
/// Given the same seed, produces the same sequence of values.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid zero state (xorshift64 fixpoint)
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Adversarial String Generator

/// Generates random strings weighted toward characters that are dangerous
/// in specific interpretation contexts (shell, JSON, filesystem).
struct AdversarialStringGenerator {
    enum Mode {
        /// Weight toward shell metacharacters
        case shellFocused
        /// Weight toward JSON metacharacters
        case jsonFocused
        /// Full Unicode range, uniform distribution
        case uniform
    }

    let mode: Mode
    let minLength: Int
    let maxLength: Int

    init(mode: Mode = .shellFocused, minLength: Int = 1, maxLength: Int = 64) {
        self.minLength = minLength
        self.maxLength = maxLength
        self.mode = mode
    }

    /// Shell metacharacters that have special meaning to shell interpreters.
    static let shellMetacharacters: [Character] = [
        "'", "\"", "`", "$", "(", ")", ";", "|", "&", "\\",
        "{", "}", "<", ">", "!", "~", "#", " ", "\t", "\n",
        "*", "?", "[", "]",
    ]

    /// JSON characters that have structural meaning in JSON.
    static let jsonMetacharacters: [Character] = [
        "\"", "\\", "/", "\n", "\r", "\t",
    ]

    /// Generate a random string using the given RNG.
    func generate(using rng: inout SeededRNG) -> String {
        let length = Int(rng.next() % UInt64(maxLength - minLength + 1)) + minLength
        var result = ""
        result.reserveCapacity(length)

        for _ in 0..<length {
            let char = nextCharacter(using: &rng)
            result.append(char)
        }

        return result
    }

    private func nextCharacter(using rng: inout SeededRNG) -> Character {
        let roll = rng.next() % 100

        switch mode {
        case .shellFocused:
            if roll < 40 {
                // 40% chance: pick from shell metacharacters
                let idx = Int(rng.next() % UInt64(Self.shellMetacharacters.count))
                return Self.shellMetacharacters[idx]
            } else if roll < 60 {
                // 20% chance: printable ASCII
                let scalar = UnicodeScalar(Int(rng.next() % 95) + 32)!
                return Character(scalar)
            } else if roll < 80 {
                // 20% chance: alphanumeric
                let alphanumeric = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                let idx = alphanumeric.index(alphanumeric.startIndex, offsetBy: Int(rng.next() % UInt64(alphanumeric.count)))
                return alphanumeric[idx]
            } else {
                // 20% chance: Unicode beyond ASCII
                let scalar = UnicodeScalar(Int(rng.next() % 0xD000) + 0x80)
                if let s = scalar {
                    return Character(s)
                }
                return "X"
            }

        case .jsonFocused:
            if roll < 40 {
                // 40% chance: pick from JSON metacharacters
                let idx = Int(rng.next() % UInt64(Self.jsonMetacharacters.count))
                return Self.jsonMetacharacters[idx]
            } else if roll < 70 {
                // 30% chance: printable ASCII
                let scalar = UnicodeScalar(Int(rng.next() % 95) + 32)!
                return Character(scalar)
            } else {
                // 30% chance: control characters and Unicode
                let controlChars: [Character] = ["\0", "\u{01}", "\u{02}", "\u{1F}", "\u{7F}"]
                if roll < 85 {
                    let idx = Int(rng.next() % UInt64(controlChars.count))
                    return controlChars[idx]
                } else {
                    let scalar = UnicodeScalar(Int(rng.next() % 0xD000) + 0x80)
                    if let s = scalar {
                        return Character(s)
                    }
                    return "X"
                }
            }

        case .uniform:
            // Full Unicode range (excluding surrogates)
            let codePoint = Int(rng.next() % 0x10FFFF)
            if codePoint >= 0xD800 && codePoint <= 0xDFFF {
                // Surrogate pair range — substitute with replacement character
                return "\u{FFFD}"
            }
            if let scalar = UnicodeScalar(codePoint) {
                return Character(scalar)
            }
            return "X"
        }
    }
}

// MARK: - Property Test Runner

/// Lightweight property test runner with seeded deterministic execution.
struct PropertyTest {
    /// A failure captured during property testing.
    struct Failure: CustomStringConvertible {
        let seed: UInt64
        let iteration: Int
        let input: String
        let message: String

        var description: String {
            "PropertyTest failure at iteration \(iteration) (seed: \(seed)): input=\(input.debugDescription) — \(message)"
        }
    }

    /// Run a property test over generated string values.
    ///
    /// - Parameters:
    ///   - iterations: Number of random inputs to test.
    ///   - seed: Seed for deterministic reproduction.
    ///   - generator: Closure that produces a test value from the RNG.
    ///   - property: Closure that asserts the property holds. Throw to indicate failure.
    /// - Returns: Array of failures (empty if all passed).
    @discardableResult
    static func forAll<T>(
        iterations: Int = 1000,
        seed: UInt64 = 42,
        generator: (inout SeededRNG) -> T,
        property: (T) throws -> Void
    ) -> [Failure] where T: CustomStringConvertible {
        var rng = SeededRNG(seed: seed)
        var failures: [Failure] = []

        for i in 0..<iterations {
            let value = generator(&rng)
            do {
                try property(value)
            } catch {
                failures.append(Failure(
                    seed: seed,
                    iteration: i,
                    input: String(describing: value),
                    message: error.localizedDescription
                ))
            }
        }

        return failures
    }

    /// Convenience for string properties using AdversarialStringGenerator.
    @discardableResult
    static func forAllStrings(
        iterations: Int = 1000,
        seed: UInt64 = 42,
        mode: AdversarialStringGenerator.Mode = .shellFocused,
        property: (String) throws -> Void
    ) -> [Failure] {
        let gen = AdversarialStringGenerator(mode: mode)
        return forAll(
            iterations: iterations,
            seed: seed,
            generator: { rng in gen.generate(using: &rng) },
            property: property
        )
    }
}

// MARK: - String: CustomStringConvertible already conforms
