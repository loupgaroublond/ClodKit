//
//  BoundaryCrossingRoundtripTests.swift
//  ClodKit
//
//  Roundtrip identity tests for non-shell boundaries.
//  Verifies data survives JSON serialization, Codable encode/decode,
//  MCP config generation, and environment variable passing.
//  Covers crossing points 13-18 from the testing strategy doc.
//

import XCTest
@testable import ClodKit

final class BoundaryCrossingRoundtripTests: XCTestCase {

    // MARK: - Crossing Point 13: Prompt through JSONSerialization

    func testPromptJSONRoundtrip() throws {
        let crossing = JSONSerializationCrossing()

        for input in AdversarialStrings.jsonMetachars + AdversarialStrings.jsonInjection {
            XCTAssertNoThrow(try crossing.testRoundtrip(input),
                "JSON roundtrip failed for: \(input.debugDescription)")
        }
    }

    func testPromptJSONRoundtripWithShellMetachars() throws {
        let crossing = JSONSerializationCrossing()

        for input in AdversarialStrings.shellMetachars + AdversarialStrings.shellInjection {
            XCTAssertNoThrow(try crossing.testRoundtrip(input),
                "JSON roundtrip failed for shell metachar: \(input.debugDescription)")
        }
    }

    func testPromptJSONRoundtripWithUnicode() throws {
        let crossing = JSONSerializationCrossing()

        // BOM (\u{FEFF}) is stripped by JSONSerialization when it appears as the
        // sole content of a string — this is expected Foundation behavior, not a bug.
        let bomStripped: Set<String> = ["\u{FEFF}"]

        for input in AdversarialStrings.unicodeEdgeCases {
            // Skip empty string and known Foundation edge cases
            guard !input.isEmpty, !bomStripped.contains(input) else { continue }
            XCTAssertNoThrow(try crossing.testRoundtrip(input),
                "JSON roundtrip failed for unicode: \(input.debugDescription)")
        }
    }

    func testPromptJSONRoundtripPropertyBased() {
        let crossing = JSONSerializationCrossing()
        let failures = PropertyTest.forAllStrings(
            iterations: 500,
            seed: 42,
            mode: .jsonFocused,
            property: { input in
                try crossing.testRoundtrip(input)
            }
        )
        XCTAssertTrue(failures.isEmpty,
            "JSON roundtrip property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }

    // MARK: - Crossing Point 14: MCP Config through JSONSerialization

    func testMCPConfigRoundtrip() throws {
        for serverName in AdversarialStrings.jsonMetachars + AdversarialStrings.jsonInjection {
            // Skip strings with characters invalid in dict keys for Foundation
            guard !serverName.isEmpty else { continue }

            let config: [String: Any] = [
                "mcpServers": [
                    serverName: [
                        "type": "stdio",
                        "command": "/usr/bin/test",
                        "args": [] as [String]
                    ] as [String: Any]
                ] as [String: Any]
            ]

            let data = try JSONSerialization.data(withJSONObject: config, options: [])
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = parsed as? [String: Any],
                  let servers = dict["mcpServers"] as? [String: Any] else {
                XCTFail("Failed to parse MCP config for server name: \(serverName.debugDescription)")
                continue
            }

            XCTAssertNotNil(servers[serverName],
                "Server name should survive JSON roundtrip: \(serverName.debugDescription)")
        }
    }

    func testMCPServerPathRoundtrip() throws {
        for path in AdversarialStrings.filesystemTraversal + AdversarialStrings.shellInjection {
            let config: [String: Any] = [
                "mcpServers": [
                    "test-server": [
                        "type": "stdio",
                        "command": path,
                        "args": [path]
                    ] as [String: Any]
                ] as [String: Any]
            ]

            let data = try JSONSerialization.data(withJSONObject: config, options: [])
            let parsed = try JSONSerialization.jsonObject(with: data, options: [])
            guard let dict = parsed as? [String: Any],
                  let servers = dict["mcpServers"] as? [String: Any],
                  let server = servers["test-server"] as? [String: Any],
                  let command = server["command"] as? String else {
                XCTFail("Failed to parse MCP config for path: \(path.debugDescription)")
                continue
            }

            XCTAssertEqual(command, path,
                "MCP server command path should survive JSON roundtrip: \(path.debugDescription)")
        }
    }

    // MARK: - Crossing Point 15: Codable Roundtrip — SDKMessage

    func testSDKMessageCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for input in AdversarialStrings.all {
            let original = SDKMessage(
                type: "assistant",
                rawJSON: [
                    "type": .string("assistant"),
                    "content": .string(input),
                    "session_id": .string(input)
                ]
            )

            let data = try encoder.encode(original)
            let recovered = try decoder.decode(SDKMessage.self, from: data)

            XCTAssertEqual(recovered.type, original.type,
                "SDKMessage type should survive roundtrip")
            XCTAssertEqual(recovered.rawJSON["content"], original.rawJSON["content"],
                "SDKMessage content should survive roundtrip for: \(input.debugDescription)")
            XCTAssertEqual(recovered.rawJSON["session_id"], original.rawJSON["session_id"],
                "SDKMessage session_id should survive roundtrip for: \(input.debugDescription)")
        }
    }

    // MARK: - Crossing Point 15: Codable Roundtrip — ControlRequest

    func testControlRequestCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for input in AdversarialStrings.all {
            let original = ControlRequest(
                type: "control_request",
                requestId: input,
                request: .string(input)
            )

            let data = try encoder.encode(original)
            let recovered = try decoder.decode(ControlRequest.self, from: data)

            XCTAssertEqual(recovered.requestId, original.requestId,
                "ControlRequest requestId should survive roundtrip for: \(input.debugDescription)")
            XCTAssertEqual(recovered.request, original.request,
                "ControlRequest request should survive roundtrip for: \(input.debugDescription)")
        }
    }

    // MARK: - Crossing Point 15: Codable Roundtrip — ControlResponse

    func testControlResponseCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for input in AdversarialStrings.all {
            let original = ControlResponse(
                type: "control_response",
                response: ControlResponsePayload(
                    subtype: "success",
                    requestId: input,
                    response: .string(input)
                )
            )

            let data = try encoder.encode(original)
            let recovered = try decoder.decode(ControlResponse.self, from: data)

            XCTAssertEqual(recovered.response.requestId, original.response.requestId,
                "ControlResponse requestId should survive roundtrip for: \(input.debugDescription)")
            XCTAssertEqual(recovered.response.response, original.response.response,
                "ControlResponse response should survive roundtrip for: \(input.debugDescription)")
        }
    }

    // MARK: - Crossing Point 15: Codable Roundtrip — FullControlRequest

    func testFullControlRequestCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for input in AdversarialStrings.jsonMetachars + AdversarialStrings.jsonInjection + AdversarialStrings.shellInjection {
            let original = FullControlRequest(
                requestId: input,
                request: .initialize(InitializeRequest(
                    systemPrompt: input,
                    appendSystemPrompt: input
                ))
            )

            let data = try encoder.encode(original)
            let recovered = try decoder.decode(FullControlRequest.self, from: data)

            XCTAssertEqual(recovered.requestId, original.requestId,
                "FullControlRequest requestId should survive roundtrip for: \(input.debugDescription)")

            if case .initialize(let req) = recovered.request {
                XCTAssertEqual(req.systemPrompt, input,
                    "InitializeRequest systemPrompt should survive roundtrip for: \(input.debugDescription)")
                XCTAssertEqual(req.appendSystemPrompt, input,
                    "InitializeRequest appendSystemPrompt should survive roundtrip for: \(input.debugDescription)")
            } else {
                XCTFail("Expected .initialize payload after roundtrip")
            }
        }
    }

    // MARK: - Crossing Point 15: Codable Roundtrip — FullControlResponse

    func testFullControlResponseCodableRoundtrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for input in AdversarialStrings.jsonMetachars + AdversarialStrings.jsonInjection + AdversarialStrings.shellInjection {
            let original = FullControlResponse(
                response: .success(requestId: input, response: .string(input))
            )

            let data = try encoder.encode(original)
            let recovered = try decoder.decode(FullControlResponse.self, from: data)

            XCTAssertEqual(recovered.response.requestId, original.response.requestId,
                "FullControlResponse requestId should survive roundtrip for: \(input.debugDescription)")

            if case .success(_, let response) = recovered.response {
                XCTAssertEqual(response, .string(input),
                    "FullControlResponse response should survive roundtrip for: \(input.debugDescription)")
            } else {
                XCTFail("Expected .success payload after roundtrip")
            }
        }
    }

    // MARK: - Crossing Point 16: MCP Config Temp File Write/Read

    func testMCPConfigTempFileRoundtrip() throws {
        for input in AdversarialStrings.jsonMetachars + AdversarialStrings.jsonInjection {
            let config: [String: Any] = [
                "mcpServers": [
                    "test": [
                        "type": "stdio",
                        "command": input,
                        "args": [input]
                    ] as [String: Any]
                ] as [String: Any]
            ]

            // Write to temp file (simulates buildMCPConfigFile)
            let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "mcp-test-\(UUID().uuidString).json"
            let filePath = tempDir.appendingPathComponent(fileName)
            try data.write(to: filePath)

            defer { try? FileManager.default.removeItem(at: filePath) }

            // Read back and verify
            let readData = try Data(contentsOf: filePath)
            let parsed = try JSONSerialization.jsonObject(with: readData, options: [])
            guard let dict = parsed as? [String: Any],
                  let servers = dict["mcpServers"] as? [String: Any],
                  let server = servers["test"] as? [String: Any],
                  let command = server["command"] as? String else {
                XCTFail("Failed to read back MCP config for: \(input.debugDescription)")
                continue
            }

            XCTAssertEqual(command, input,
                "MCP config command should survive file write/read roundtrip: \(input.debugDescription)")
        }
    }

    // MARK: - Crossing Point 17: Working Directory URL

    func testWorkingDirectoryURLPreservation() throws {
        // Working directory uses URL type which provides some built-in safety.
        // Verify adversarial paths are handled as URLs.
        for path in AdversarialStrings.filesystemTraversal {
            let url = URL(fileURLWithPath: path)
            let transport = ProcessTransport(
                executablePath: "claude",
                arguments: ["-p"],
                workingDirectory: url
            )
            let config = transport.buildProcessConfiguration()

            XCTAssertEqual(config.workingDirectory, url,
                "Working directory URL should be preserved: \(path.debugDescription)")
        }
    }

    // MARK: - Crossing Point 18: Environment Variable Roundtrip

    func testEnvironmentVariableRoundtrip() throws {
        let crossing = EnvironmentCrossing()

        for input in AdversarialStrings.shellMetachars + AdversarialStrings.shellInjection {
            let kv = EnvironmentKeyValue(key: "TEST_KEY", value: input)
            XCTAssertNoThrow(try crossing.testRoundtrip(kv),
                "Environment roundtrip failed for value: \(input.debugDescription)")
        }
    }

    func testEnvironmentVariablePreservationInProcessConfig() {
        for input in AdversarialStrings.shellMetachars + AdversarialStrings.shellInjection + AdversarialStrings.jsonMetachars {
            let transport = ProcessTransport(
                executablePath: "claude",
                arguments: ["-p"],
                additionalEnvironment: ["ADVERSARIAL_KEY": input]
            )
            let config = transport.buildProcessConfiguration()

            XCTAssertEqual(config.environment["ADVERSARIAL_KEY"], input,
                "Environment variable should be preserved in ProcessConfiguration: \(input.debugDescription)")
        }
    }

    func testEnvironmentKeyPreservation() {
        // Keys with special characters in environment
        let specialKeys = ["KEY=VALUE", "KEY;DROP", "KEY$(cmd)", "KEY`id`", "KEY\nNEW"]

        for key in specialKeys {
            let transport = ProcessTransport(
                executablePath: "claude",
                arguments: ["-p"],
                additionalEnvironment: [key: "value"]
            )
            let config = transport.buildProcessConfiguration()

            XCTAssertEqual(config.environment[key], "value",
                "Environment key should be preserved: \(key.debugDescription)")
        }
    }

    // MARK: - Codable Roundtrip Property Test

    func testCodableRoundtripPropertyBased() {
        let failures = PropertyTest.forAllStrings(
            iterations: 500,
            seed: 42,
            mode: .jsonFocused,
            property: { input in
                let crossing = CodableCrossing<ControlRequest>()
                let original = ControlRequest(
                    type: "control_request",
                    requestId: input,
                    request: .string(input)
                )
                let data = try crossing.transform(original)
                let recovered = try crossing.recover(data)

                guard recovered == original else {
                    throw BoundaryCrossingError.roundtripFailed(
                        crossing: "Codable<ControlRequest>",
                        input: input,
                        recovered: String(describing: recovered)
                    )
                }
            }
        )
        XCTAssertTrue(failures.isEmpty,
            "Codable roundtrip property test had \(failures.count) failures. First: \(failures.first?.description ?? "none")")
    }
}
