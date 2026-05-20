// TranscriptWriter.swift — TerminalKit
// Writes terminal byte stream to a per-session log file.
// Stored under ~/Library/Application Support/Helmsman/transcripts/<date>/<session>.log

import Foundation

import AppKit

public final class TranscriptWriter: @unchecked Sendable {

    // MARK: - Properties

    private let fileURL:   URL
    private let queue:     DispatchQueue
    private var handle:    FileHandle?
    private var byteCount: Int = 0

    public let sessionID:   UUID
    public let sessionName: String

    // MARK: - Init

    public init(sessionID: UUID, sessionName: String) {
        self.sessionID   = sessionID
        self.sessionName = sessionName
        self.queue       = DispatchQueue(label: "com.helmsman.transcript.\(sessionID)", qos: .utility)
        self.fileURL     = TranscriptWriter.makeURL(sessionID: sessionID, name: sessionName)
    }

    // MARK: - Lifecycle

    public func open() {
        queue.async { [self] in
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                handle = try FileHandle(forWritingTo: fileURL)
            } catch {
                // Non-fatal: transcript is best-effort
            }
        }
    }

    // MARK: - Writing

    /// Appends raw bytes from the terminal output stream.
    public func write(_ bytes: ArraySlice<UInt8>) {
        let data = Data(bytes)
        queue.async { [self] in
            handle?.write(data)
            byteCount += data.count
        }
    }

    /// Appends a UTF-8 string directly (used for reconnect separators, etc.)
    public func writeRaw(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        queue.async { [self] in
            handle?.write(data)
        }
    }

    public func flush() {
        queue.async { [self] in
            try? handle?.synchronize()
        }
    }

    public func close() {
        queue.async { [self] in
            try? handle?.close()
            handle = nil
        }
    }

    // MARK: - Accessors

    /// The filesystem URL of the transcript log (shown in UI for Spotlight access).
    public var logFileURL: URL { fileURL }

    /// Opens the transcript's parent folder in Finder.
    public func revealInFinder() {
        let folder = fileURL.deletingLastPathComponent()
        NSWorkspace.shared.open(folder)
    }

    // MARK: - Path construction

    private static func makeURL(sessionID: UUID, name: String) -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base    = support.appendingPathComponent("Helmsman/transcripts")

        // Date folder: YYYY-MM-DD
        let dateStr = ISO8601DateFormatter().string(from: .now).prefix(10)
        let folder  = base.appendingPathComponent(String(dateStr))

        // Sanitise name for filesystem
        let safeName = name
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_. ")).inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")

        let filename = "\(safeName)_\(sessionID.uuidString.prefix(8)).log"
        return folder.appendingPathComponent(filename)
    }
}


