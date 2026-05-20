// TerminalSession.swift — TerminalKit
// Observable model representing one live terminal session.
// Owns the transcript writer and exposes state that UI can bind to.

import Foundation
import Combine
import SwiftTerm

// MARK: - Session Status

public enum TerminalSessionStatus: Equatable, Sendable {
    case connecting
    case connected
    case disconnected(exitCode: Int32?)
    case reconnecting
}

// MARK: - TerminalSession

@MainActor
public final class TerminalSession: ObservableObject, Identifiable {

    // MARK: Public state

    public let id: UUID
    public let spec: AnySessionSpec   // holds the typed spec (SSH / Telnet / Serial / Local)

    @Published public private(set) var status: TerminalSessionStatus = .connecting
    @Published public private(set) var title: String
    @Published public private(set) var currentDirectory: String?
    @Published public private(set) var terminalSize: (cols: Int, rows: Int) = (80, 24)
    @Published public private(set) var reconnectAttempts: Int = 0

    // MARK: Transcript

    public let transcriptWriter: TranscriptWriter

    // MARK: Process handle (written by the view after launch)

    public weak var terminalView: LocalProcessTerminalView?

    // MARK: Init

    public init(id: UUID = .init(), spec: AnySessionSpec) {
        self.id    = id
        self.spec  = spec
        self.title = spec.name
        self.transcriptWriter = TranscriptWriter(sessionID: id, sessionName: spec.name)
    }

    // MARK: Process launch (called from NSViewRepresentable.makeNSView)

    /// Configures and starts the process inside a `LocalProcessTerminalView`.
    public func start(in view: LocalProcessTerminalView) {
        terminalView = view
        status = .connecting
        let args   = spec.args
        let exe    = spec.executableURL.path
        view.startProcess(executable: exe, args: args)
        status = .connected
        transcriptWriter.open()
        
        // Reset reconnect attempts if we stay connected for 5 seconds
        let currentAttempt = reconnectAttempts
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if self.status == .connected && self.reconnectAttempts == currentAttempt {
                self.reconnectAttempts = 0
            }
        }
    }

    // MARK: Multi-exec / send

    /// Sends `text` to the running process (as if typed).
    public func send(_ text: String) {
        terminalView?.send(txt: text)
    }

    /// Sends `text` followed by Enter (carriage return for TTY shells).
    public func run(_ command: String) {
        terminalView?.window?.makeFirstResponder(terminalView)
        send(command + "\r")
    }

    // MARK: Reconnect

    public func reconnect() {
        guard status != .connected && status != .connecting else { return }
        
        reconnectAttempts += 1
        status = .reconnecting
        guard let view = terminalView else { return }

        // Brief visual separator in the transcript
        let separator = "\r\n--- Reconnecting (attempt \(reconnectAttempts)) ---\r\n"
        transcriptWriter.writeRaw(separator)

        start(in: view)
    }

    // MARK: Callbacks (called by TerminalViewDelegate bridge)

    public func handleTermination(exitCode: Int32?) {
        transcriptWriter.flush()
        
        // Auto-reconnect up to 3 times for non-zero exit codes (unexpected disconnects)
        if exitCode != 0 && reconnectAttempts < 3 {
            status = .reconnecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.reconnect()
            }
        } else {
            status = .disconnected(exitCode: exitCode)
        }
    }

    public func updateTitle(_ newTitle: String) {
        guard !newTitle.isEmpty else { return }
        title = newTitle
    }

    public func updateSize(cols: Int, rows: Int) {
        terminalSize = (cols: cols, rows: rows)
    }

    public func updateCurrentDirectory(_ path: String?) {
        currentDirectory = path
    }

    public func appendTranscript(_ bytes: ArraySlice<UInt8>) {
        transcriptWriter.write(bytes)
    }
}

// MARK: - AnySessionSpec

/// Type-erased wrapper so TerminalSession can hold any SessionSpec without
/// importing SSHKit directly (keeps the dependency direction clean).
public struct AnySessionSpec: @unchecked Sendable {
    public let name:          String
    public let executableURL: URL
    public let args:          [String]
    public let metadata:      [String: String]

    public init(
        name: String,
        executableURL: URL,
        args: [String],
        metadata: [String: String] = [:]
    ) {
        self.name          = name
        self.executableURL = executableURL
        self.args          = args
        self.metadata      = metadata
    }
}
