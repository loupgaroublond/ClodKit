//
//  PermissionModeBehaviorTests.swift
//  ClodKitTests
//
//  Behavioral tests for PermissionMode semantics (Bead 9rn).
//

import XCTest
@testable import ClodKit

final class PermissionModeBehaviorTests: XCTestCase {

    // MARK: - All 6 Modes Are Representable

    func testAllSixModesExist() {
        let modes: [PermissionMode] = [
            .default, .acceptEdits, .bypassPermissions,
            .plan, .delegate, .dontAsk
        ]
        XCTAssertEqual(modes.count, 6)
    }

    // MARK: - CaseIterable Returns All 6

    func testCaseIterableReturnsAllSixCases() {
        let allCases = PermissionMode.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.default))
        XCTAssertTrue(allCases.contains(.acceptEdits))
        XCTAssertTrue(allCases.contains(.bypassPermissions))
        XCTAssertTrue(allCases.contains(.plan))
        XCTAssertTrue(allCases.contains(.delegate))
        XCTAssertTrue(allCases.contains(.dontAsk))
    }

    // MARK: - Raw Value Strings Match TS SDK

    func testDefaultRawValue() {
        XCTAssertEqual(PermissionMode.default.rawValue, "default")
    }

    func testAcceptEditsRawValue() {
        XCTAssertEqual(PermissionMode.acceptEdits.rawValue, "acceptEdits")
    }

    func testBypassPermissionsRawValue() {
        XCTAssertEqual(PermissionMode.bypassPermissions.rawValue, "bypassPermissions")
    }

    func testPlanRawValue() {
        XCTAssertEqual(PermissionMode.plan.rawValue, "plan")
    }

    func testDelegateRawValue() {
        XCTAssertEqual(PermissionMode.delegate.rawValue, "delegate")
    }

    func testDontAskRawValue() {
        XCTAssertEqual(PermissionMode.dontAsk.rawValue, "dontAsk")
    }

    // MARK: - JSON Encoding Produces Exact camelCase Strings

    func testJsonEncodingProducesCorrectStrings() throws {
        let encoder = JSONEncoder()
        for mode in PermissionMode.allCases {
            let data = try encoder.encode(mode)
            let jsonString = String(data: data, encoding: .utf8)!
            XCTAssertEqual(jsonString, "\"\(mode.rawValue)\"",
                           "Encoding \(mode) should produce \"\(mode.rawValue)\"")
        }
    }

    func testDelegateSerializesWithExactCamelCase() throws {
        let data = try JSONEncoder().encode(PermissionMode.delegate)
        let str = String(data: data, encoding: .utf8)!
        XCTAssertEqual(str, "\"delegate\"")
    }

    func testDontAskSerializesWithExactCamelCase() throws {
        let data = try JSONEncoder().encode(PermissionMode.dontAsk)
        let str = String(data: data, encoding: .utf8)!
        XCTAssertEqual(str, "\"dontAsk\"")
    }

    // MARK: - JSON Round-Trip for All Cases

    func testCodableRoundTripForAllCases() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for mode in PermissionMode.allCases {
            let data = try encoder.encode(mode)
            let decoded = try decoder.decode(PermissionMode.self, from: data)
            XCTAssertEqual(decoded, mode,
                           "Round-trip failed for \(mode)")
        }
    }

    // MARK: - Decoding from CLI JSON Strings

    func testDecodingFromRawJsonStrings() throws {
        let decoder = JSONDecoder()
        let testCases: [(String, PermissionMode)] = [
            ("\"default\"", .default),
            ("\"acceptEdits\"", .acceptEdits),
            ("\"bypassPermissions\"", .bypassPermissions),
            ("\"plan\"", .plan),
            ("\"delegate\"", .delegate),
            ("\"dontAsk\"", .dontAsk),
        ]
        for (jsonStr, expected) in testCases {
            let data = jsonStr.data(using: .utf8)!
            let decoded = try decoder.decode(PermissionMode.self, from: data)
            XCTAssertEqual(decoded, expected,
                           "Decoding \(jsonStr) should produce \(expected)")
        }
    }

    // MARK: - Unknown Future Modes Produce Graceful Error

    func testUnknownModeProducesDecodingError() {
        let decoder = JSONDecoder()
        let json = "\"superDuperMode\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(PermissionMode.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError,
                          "Unknown mode should produce DecodingError, got \(type(of: error))")
        }
    }

    func testEmptyStringProducesDecodingError() {
        let decoder = JSONDecoder()
        let json = "\"\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(PermissionMode.self, from: json))
    }

    // MARK: - PermissionMode Used in QueryOptions

    func testQueryOptionsAcceptsAllModes() {
        for mode in PermissionMode.allCases {
            var options = QueryOptions()
            options.permissionMode = mode
            XCTAssertEqual(options.permissionMode, mode)
        }
    }

    // MARK: - PermissionMode Used in PermissionUpdate.setMode

    func testPermissionUpdateSetModeAcceptsAllModes() {
        for mode in PermissionMode.allCases {
            let update = PermissionUpdate.setMode(mode)
            XCTAssertEqual(update.type, .setMode)
            XCTAssertEqual(update.mode, mode)
        }
    }

    // MARK: - Decoding from Object Context (Wrapped in Container)

    func testDecodingFromObjectContext() throws {
        let json = """
        {"mode": "delegate"}
        """.data(using: .utf8)!

        struct Wrapper: Codable {
            let mode: PermissionMode
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        XCTAssertEqual(decoded.mode, .delegate)
    }

    func testDecodingDontAskFromObjectContext() throws {
        let json = """
        {"mode": "dontAsk"}
        """.data(using: .utf8)!

        struct Wrapper: Codable {
            let mode: PermissionMode
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        XCTAssertEqual(decoded.mode, .dontAsk)
    }
}
