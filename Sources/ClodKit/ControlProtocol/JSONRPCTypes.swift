//
//  JSONRPCTypes.swift
//  ClodKit
//
//  JSON-RPC wire format types for MCP communication.
//

import Foundation

// MARK: - JSONRPC Message

/// JSONRPC message for MCP communication.
public struct JSONRPCMessage: Codable, Sendable, Equatable {
    public let jsonrpc: String
    public let id: JSONValue?
    public let method: String?
    public let params: JSONValue?
    public let result: JSONValue?
    public let error: JSONRPCError?

    public init(
        jsonrpc: String = "2.0",
        id: JSONValue? = nil,
        method: String? = nil,
        params: JSONValue? = nil,
        result: JSONValue? = nil,
        error: JSONRPCError? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }

    /// Create a request message.
    public static func request(id: Int, method: String, params: JSONValue? = nil) -> JSONRPCMessage {
        JSONRPCMessage(id: .int(id), method: method, params: params)
    }

    /// Create a success response.
    public static func response(id: Int, result: JSONValue) -> JSONRPCMessage {
        JSONRPCMessage(id: .int(id), result: result)
    }

    /// Create an error response.
    public static func errorResponse(id: Int, error: JSONRPCError) -> JSONRPCMessage {
        JSONRPCMessage(id: .int(id), error: error)
    }

    /// Create a notification (request without id).
    public static func notification(method: String, params: JSONValue? = nil) -> JSONRPCMessage {
        JSONRPCMessage(method: method, params: params)
    }
}

// MARK: - JSONRPC Error

/// JSONRPC error object.
public struct JSONRPCError: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // Standard error codes
    public static let parseError = -32700
    public static let invalidRequest = -32600
    public static let methodNotFound = -32601
    public static let invalidParams = -32602
    public static let internalError = -32603
}
