//
//  MockTransport.swift
//  ClodKit
//
//  Mock implementation of Transport for unit testing.
//

import Foundation

/// Mock transport for testing components that depend on Transport protocol.
/// Provides methods to inject messages/errors and inspect written data.
///
/// Safety: `@unchecked Sendable` is correct because all mutable state is protected
/// by NSLock. The lock guards: `_writtenData`, `_pendingMessages`, `_pendingError`,
/// `_continuation`, `_connected`, `_inputEnded`. The `mockResponseHandler` property
/// is accessed outside the lock but only from write() which serializes through the lock.
public final class MockTransport: Transport, @unchecked Sendable {
    /// Lock protecting all mutable state.
    private let lock = NSLock()

    /// All data written via write().
    private var _writtenData: [Data] = []

    /// Messages to be yielded by readMessages().
    private var _pendingMessages: [StdoutMessage] = []

    /// Error to throw when reading messages.
    private var _pendingError: Error?

    /// Continuation for the message stream.
    private var _continuation: AsyncThrowingStream<StdoutMessage, Error>.Continuation?

    /// Whether the transport is connected.
    private var _connected: Bool = true

    /// Whether stdin has been closed.
    private var _inputEnded: Bool = false

    /// Optional handler called when data is written, for simulating responses.
    public var mockResponseHandler: ((Data) -> Void)?

    public init() {}

    // MARK: - Transport Protocol

    public var isConnected: Bool {
        lock.withLock { _connected }
    }

    public func write(_ data: Data) async throws {
        // Check state synchronously
        let (connected, inputEnded) = lock.withLock { (_connected, _inputEnded) }

        guard connected else {
            throw TransportError.notConnected
        }
        guard !inputEnded else {
            throw TransportError.closed
        }

        // Append synchronously
        lock.withLock {
            _writtenData.append(data)
        }

        // Call the mock response handler if set
        mockResponseHandler?(data)
    }

    public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
        // Check if stream already exists - calling readMessages() twice would orphan the first
        let alreadyHasStream = lock.withLock { _continuation != nil }
        if alreadyHasStream {
            // Return a stream that immediately throws an error
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: TransportError.closed)
            }
        }

        return AsyncThrowingStream { [weak self] continuation in
            guard let self = self else {
                continuation.finish()
                return
            }

            // Get pending state synchronously
            let (messages, error) = self.lock.withLock { () -> ([StdoutMessage], Error?) in
                self._continuation = continuation

                // Consume pending messages
                let msgs = self._pendingMessages
                self._pendingMessages.removeAll()

                // Get any pending error
                let err = self._pendingError
                self._pendingError = nil

                return (msgs, err)
            }

            for message in messages {
                continuation.yield(message)
            }

            // If there's a pending error, throw it
            if let error = error {
                continuation.finish(throwing: error)
            }
        }
    }

    public func endInput() async {
        lock.withLock {
            _inputEnded = true
        }
    }

    public func close() {
        let continuation = lock.withLock { () -> AsyncThrowingStream<StdoutMessage, Error>.Continuation? in
            _connected = false
            let cont = _continuation
            _continuation = nil
            return cont
        }

        continuation?.finish()
    }

    // MARK: - Test Helpers

    /// Inject a message to be yielded by readMessages().
    /// If a stream is active, yields immediately. Otherwise, queues for later.
    public func injectMessage(_ message: StdoutMessage) {
        let continuation = lock.withLock { () -> AsyncThrowingStream<StdoutMessage, Error>.Continuation? in
            if let cont = _continuation {
                return cont
            } else {
                _pendingMessages.append(message)
                return nil
            }
        }

        continuation?.yield(message)
    }

    /// Inject an error to be thrown by readMessages().
    /// If a stream is active, finishes with error immediately. Otherwise, queues for later.
    public func injectError(_ error: Error) {
        let continuation = lock.withLock { () -> AsyncThrowingStream<StdoutMessage, Error>.Continuation? in
            if let cont = _continuation {
                _continuation = nil
                return cont
            } else {
                _pendingError = error
                return nil
            }
        }

        continuation?.finish(throwing: error)
    }

    /// Get all data written via write().
    public func getWrittenData() -> [Data] {
        lock.withLock { _writtenData }
    }

    /// Clear written data for test isolation.
    public func clearWrittenData() {
        lock.withLock {
            _writtenData.removeAll()
        }
    }

    /// Check if input has been ended.
    public func isInputEnded() -> Bool {
        lock.withLock { _inputEnded }
    }

    /// Finish the message stream normally.
    public func finishStream() {
        let continuation = lock.withLock { () -> AsyncThrowingStream<StdoutMessage, Error>.Continuation? in
            let cont = _continuation
            _continuation = nil
            return cont
        }

        continuation?.finish()
    }

    /// Inject a raw JSON line to be parsed and handled.
    /// This simulates receiving a control response from the CLI.
    public func injectRawLine(_ jsonLine: String) {
        // Parse the JSON line to determine the message type
        guard let data = jsonLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        // Decode based on type
        if type == "control_response" {
            if let response = try? JSONDecoder().decode(ControlResponse.self, from: data) {
                injectMessage(.controlResponse(response))
            }
        } else if type == "control_request" {
            if let request = try? JSONDecoder().decode(ControlRequest.self, from: data) {
                injectMessage(.controlRequest(request))
            }
        }
    }
}
