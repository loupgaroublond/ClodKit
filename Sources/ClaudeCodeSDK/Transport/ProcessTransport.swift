//
//  ProcessTransport.swift
//  ClaudeCodeSDK
//
//  Real subprocess transport using Foundation.Process for CLI communication.
//

import Foundation

/// Transport implementation that spawns and communicates with the Claude CLI process.
/// Uses Foundation.Process with stdin/stdout pipes for bidirectional JSON-line communication.
///
/// Safety: `@unchecked Sendable` is correct because all mutable state is protected
/// by NSLock. The lock guards: `_process`, `_stdinPipe`, `_stdoutPipe`, `_stderrPipe`,
/// `_running`, `_readBuffer`, `_pendingMessages`, `_streamContinuation`, `_stderrBuffer`.
/// Immutable properties (`command`, `workingDirectory`, `additionalEnvironment`, `parser`)
/// are set once at init. The `_stderrHandler` is captured at init and never mutated.
public final class ProcessTransport: Transport, @unchecked Sendable {
    /// Lock protecting all mutable state.
    private let lock = NSLock()

    /// The subprocess.
    private var _process: Process?

    /// Pipe for writing to CLI stdin.
    private var _stdinPipe: Pipe?

    /// Pipe for reading from CLI stdout.
    private var _stdoutPipe: Pipe?

    /// Pipe for reading from CLI stderr.
    private var _stderrPipe: Pipe?

    /// JSON line parser for stdout.
    private let parser = JSONLineParser()

    /// Whether the process is running.
    private var _running: Bool = false

    /// Buffer for incomplete stdout data.
    private var _readBuffer = Data()

    /// Buffer for messages that arrive before a consumer connects.
    /// This prevents race conditions where control responses arrive before
    /// the message loop Task has started consuming the stream.
    private var _pendingMessages: [StdoutMessage] = []

    /// Stream continuation for message delivery.
    private var _streamContinuation: AsyncThrowingStream<StdoutMessage, Error>.Continuation?

    /// Accumulated stderr output.
    private var _stderrBuffer = Data()

    /// Callback for stderr output.
    private var _stderrHandler: ((String) -> Void)?

    /// The command to run.
    private let command: String

    /// Working directory for the process.
    private let workingDirectory: URL?

    /// Additional environment variables.
    private let additionalEnvironment: [String: String]

    /// Creates a new ProcessTransport.
    /// - Parameters:
    ///   - command: The command to run (default: "claude --input-format stream-json")
    ///   - workingDirectory: Working directory for the process.
    ///   - additionalEnvironment: Additional environment variables.
    ///   - stderrHandler: Optional callback invoked when stderr data is received.
    public init(
        command: String = "claude --input-format stream-json",
        workingDirectory: URL? = nil,
        additionalEnvironment: [String: String] = [:],
        stderrHandler: ((String) -> Void)? = nil
    ) {
        self.command = command
        self.workingDirectory = workingDirectory
        self.additionalEnvironment = additionalEnvironment
        self._stderrHandler = stderrHandler
    }

    /// Get accumulated stderr output.
    public var stderrOutput: String {
        lock.withLock {
            String(data: _stderrBuffer, encoding: .utf8) ?? ""
        }
    }

    // MARK: - Transport Protocol

    public var isConnected: Bool {
        lock.withLock { _running }
    }

    public func write(_ data: Data) async throws {
        let (running, stdinPipe) = lock.withLock { (_running, _stdinPipe) }

        guard running else {
            throw TransportError.notConnected
        }

        guard let stdinPipe = stdinPipe else {
            throw TransportError.notConnected
        }

        // Write data followed by newline
        var dataWithNewline = data
        if !data.hasSuffix(Data("\n".utf8)) {
            dataWithNewline.append(Data("\n".utf8))
        }

        do {
            try stdinPipe.fileHandleForWriting.write(contentsOf: dataWithNewline)
        } catch {
            throw TransportError.writeFailed(error.localizedDescription)
        }
    }

    public func readMessages() -> AsyncThrowingStream<StdoutMessage, Error> {
        // Check if stream already exists - calling readMessages() twice would orphan the first
        let alreadyHasStream = lock.withLock { _streamContinuation != nil }
        if alreadyHasStream {
            // Return a stream that immediately throws an error
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: TransportError.closed)
            }
        }

        return AsyncThrowingStream { [weak self] continuation in
            // Set continuation and drain any buffered messages
            let pending = self?.lock.withLock { () -> [StdoutMessage] in
                self?._streamContinuation = continuation
                let msgs = self?._pendingMessages ?? []
                self?._pendingMessages.removeAll()
                return msgs
            } ?? []

            // Yield buffered messages that arrived before consumer connected
            for message in pending {
                continuation.yield(message)
            }
        }
    }

    public func endInput() async {
        let stdinPipe = lock.withLock { _stdinPipe }
        stdinPipe?.fileHandleForWriting.closeFile()
    }

    public func close() {
        // Run close logic in background task
        Task { [weak self] in
            await self?.closeInternal()
        }
    }

    // MARK: - Lifecycle

    /// Start the process.
    /// - Throws: TransportError if the process fails to start.
    public func start() throws {
        try lock.withLock {
            guard !_running else { return }

            let process = Process()

            // Use zsh with login shell to get proper PATH
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]

            // Set working directory if provided
            if let workingDirectory = workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            // Configure environment
            var environment = ProcessInfo.processInfo.environment
            environment["CLAUDE_CODE_ENTRYPOINT"] = "sdk-swift"
            for (key, value) in additionalEnvironment {
                environment[key] = value
            }
            process.environment = environment

            // Set up pipes
            let stdinPipe = Pipe()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.standardInput = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            _process = process
            _stdinPipe = stdinPipe
            _stdoutPipe = stdoutPipe
            _stderrPipe = stderrPipe

            // Start reading stdout and stderr
            startReadingStdout(stdoutPipe: stdoutPipe)
            startReadingStderr(stderrPipe: stderrPipe)

            // Launch process
            do {
                try process.run()
                _running = true
            } catch {
                throw TransportError.launchFailed(error.localizedDescription)
            }

            // Handle process termination
            process.terminationHandler = { [weak self] process in
                self?.handleTermination(exitCode: process.terminationStatus)
            }
        }
    }

    // MARK: - Private Methods

    private func startReadingStdout(stdoutPipe: Pipe) {
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            if data.isEmpty {
                // EOF
                self?.handleStdoutEOF()
                return
            }

            self?.handleStdoutData(data)
        }
    }

    private func startReadingStderr(stderrPipe: Pipe) {
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            if data.isEmpty {
                // EOF - stop reading stderr
                self?.lock.withLock {
                    self?._stderrPipe?.fileHandleForReading.readabilityHandler = nil
                }
                return
            }

            self?.handleStderrData(data)
        }
    }

    private func handleStderrData(_ data: Data) {
        let handler = lock.withLock { () -> ((String) -> Void)? in
            _stderrBuffer.append(data)
            return _stderrHandler
        }

        // Invoke handler outside lock
        if let handler = handler, let text = String(data: data, encoding: .utf8) {
            handler(text)
        }
    }

    private func handleStdoutData(_ data: Data) {
        let (messages, continuation) = lock.withLock { () -> ([StdoutMessage], AsyncThrowingStream<StdoutMessage, Error>.Continuation?) in
            _readBuffer.append(data)

            // Parse all complete messages
            let (msgs, remaining) = parser.parseAllLines(from: _readBuffer)
            _readBuffer = remaining

            // If no consumer yet, buffer the messages to prevent loss
            if _streamContinuation == nil {
                _pendingMessages.append(contentsOf: msgs)
                return ([], nil)
            }

            return (msgs, _streamContinuation)
        }

        // Yield messages outside lock
        for message in messages {
            continuation?.yield(message)
        }
    }

    private func handleStdoutEOF() {
        let continuation = lock.withLock { () -> AsyncThrowingStream<StdoutMessage, Error>.Continuation? in
            _stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            _pendingMessages.removeAll()
            let cont = _streamContinuation
            _streamContinuation = nil
            return cont
        }

        continuation?.finish()
    }

    private func handleTermination(exitCode: Int32) {
        let continuation = lock.withLock { () -> AsyncThrowingStream<StdoutMessage, Error>.Continuation? in
            _running = false
            _pendingMessages.removeAll()
            let cont = _streamContinuation
            _streamContinuation = nil
            return cont
        }

        if exitCode != 0 {
            continuation?.finish(throwing: TransportError.processTerminated(exitCode))
        } else {
            continuation?.finish()
        }
    }

    private func closeInternal() async {
        let (running, stdinPipe, process) = lock.withLock { (_running, _stdinPipe, _process) }

        guard running else { return }

        // Close stdin to signal end of input
        stdinPipe?.fileHandleForWriting.closeFile()

        guard let process = process else { return }

        // Give process time to exit gracefully
        if process.isRunning {
            process.terminate() // Send SIGTERM

            // Wait up to 5 seconds for graceful exit
            let deadline = DispatchTime.now() + .seconds(5)

            while DispatchTime.now() < deadline && process.isRunning {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }

            // Force kill if still running
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }
        }

        // Clean up
        lock.withLock {
            _running = false
            _stdinPipe?.fileHandleForReading.closeFile()
            _stdoutPipe?.fileHandleForReading.closeFile()
            _stderrPipe?.fileHandleForReading.closeFile()

            let cont = _streamContinuation
            _streamContinuation = nil
            _pendingMessages.removeAll()

            cont?.finish()
        }
    }
}

// MARK: - Data Extension

private extension Data {
    func hasSuffix(_ suffix: Data) -> Bool {
        guard count >= suffix.count else { return false }
        return self[(count - suffix.count)...] == suffix
    }
}
