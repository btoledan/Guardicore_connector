// SSHConfigParser.swift — SSHKit
// Round-trip-safe parser for ~/.ssh/config
// Preserves comments, blank lines, and original indentation.

import Foundation

// MARK: - Data Model

/// A fully parsed ~/.ssh/config file.
public struct SSHConfig: Sendable {

    // MARK: Block

    public struct Block: Sendable {
        public enum Kind: Sendable, Equatable {
            case host(pattern: String)    // "Host dev-server *.example.com"
            case match(criteria: String)  // "Match host *.example.com User admin"
        }

        public var kind: Kind
        /// Ordered key-value pairs within this block (excludes the Host/Match line itself).
        public var entries: [(key: String, value: String)]
        /// Raw source lines (includes the "Host …" opener, comments, blank lines).
        /// Used verbatim during serialisation for round-trip fidelity.
        internal var rawLines: [String]

        // MARK: Convenience

        public var hostPattern: String? {
            guard case .host(let p) = kind else { return nil }
            return p
        }

        /// Case-insensitive key lookup.
        public subscript(key: String) -> String? {
            entries.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
        }

        // MARK: Mutation (keeps rawLines in sync)

        /// Sets or adds a key, keeping `rawLines` in sync.
        public mutating func set(key: String, value: String) {
            if let idx = entries.firstIndex(where: {
                $0.key.caseInsensitiveCompare(key) == .orderedSame
            }) {
                entries[idx] = (key: key, value: value)
                // Update the corresponding raw line.
                if let lineIdx = rawLineIndex(forKey: key) {
                    rawLines[lineIdx] = "    \(key) \(value)"
                } else {
                    rawLines.append("    \(key) \(value)")
                }
            } else {
                entries.append((key: key, value: value))
                rawLines.append("    \(key) \(value)")
            }
        }

        /// Removes a key, keeping `rawLines` in sync.
        public mutating func remove(key: String) {
            entries.removeAll { $0.key.caseInsensitiveCompare(key) == .orderedSame }
            rawLines.removeAll { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty, !t.hasPrefix("#") else { return false }
                let k = t.split(separator: " ", maxSplits: 1,
                                omittingEmptySubsequences: true).first.map(String.init) ?? ""
                return k.caseInsensitiveCompare(key) == .orderedSame
            }
        }

        private func rawLineIndex(forKey key: String) -> Int? {
            rawLines.firstIndex { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty, !t.hasPrefix("#") else { return false }
                let k = t.split(separator: " ", maxSplits: 1,
                                omittingEmptySubsequences: true).first.map(String.init) ?? ""
                return k.caseInsensitiveCompare(key) == .orderedSame
            }
        }
    }

    // MARK: - SSHConfig properties

    /// Lines appearing before the first Host/Match block (global options, comments).
    public var preambleLines: [String]
    /// All Host/Match blocks, in file order.
    public var blocks: [Block]

    // MARK: Convenience

    /// Returns the first block whose Host pattern matches the given alias exactly.
    public func block(forAlias alias: String) -> Block? {
        blocks.first { $0.hostPattern?.lowercased() == alias.lowercased() }
    }

    /// Returns all blocks (including Match blocks) that apply to `hostname`.
    public func applicableBlocks(for hostname: String) -> [Block] {
        blocks.filter { block in
            switch block.kind {
            case .host(let pattern):
                return fnmatch(pattern, hostname, 0) == 0
            case .match:
                return false // Match blocks require full evaluation; skipped here
            }
        }
    }

    /// Adds a new Host block (or replaces if alias already exists).
    public mutating func upsert(block: Block) {
        guard case .host(let pattern) = block.kind else {
            blocks.append(block)
            return
        }
        if let idx = blocks.firstIndex(where: { $0.hostPattern?.lowercased() == pattern.lowercased() }) {
            blocks[idx] = block
        } else {
            blocks.append(block)
        }
    }
}

// MARK: - Parser

public enum SSHConfigParser {

    public enum Error: Swift.Error, LocalizedError {
        case readError(URL, Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .readError(let url, let inner):
                return "Could not read \(url.path): \(inner.localizedDescription)"
            }
        }
    }

    // MARK: Public API

    /// Parses the SSH config at `url`.  Returns an empty config if the file does not exist.
    public static func parse(at url: URL) throws -> SSHConfig {
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch let e as CocoaError where e.code == .fileReadNoSuchFile {
            return SSHConfig(preambleLines: [], blocks: [])
        } catch {
            throw Error.readError(url, error)
        }
        return parse(string: text)
    }

    /// Parses an SSH config string.
    public static func parse(string: String) -> SSHConfig {
        var preamble: [String] = []
        var blocks: [SSHConfig.Block] = []

        // Accumulator for current block being built
        var currentKind: SSHConfig.Block.Kind?
        var currentEntries: [(key: String, value: String)] = []
        var currentLines: [String] = []

        func commit() {
            guard let kind = currentKind else { return }
            blocks.append(SSHConfig.Block(kind: kind,
                                          entries: currentEntries,
                                          rawLines: currentLines))
            currentKind = nil
            currentEntries = []
            currentLines = []
        }

        // Normalise line endings
        let lines = string
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // Blank or comment line — keep in current context
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                if currentKind != nil {
                    currentLines.append(raw)
                } else {
                    preamble.append(raw)
                }
                continue
            }

            let parts = trimmed.split(separator: " ", maxSplits: 1,
                                       omittingEmptySubsequences: true)
            guard !parts.isEmpty else { continue }

            let keyword = String(parts[0])
            let value   = parts.count > 1 ? String(parts[1]) : ""

            switch keyword.lowercased() {
            case "host":
                commit()
                currentKind = .host(pattern: value)
                currentLines = [raw]
            case "match":
                commit()
                currentKind = .match(criteria: value)
                currentLines = [raw]
            default:
                if currentKind != nil {
                    currentEntries.append((key: keyword, value: value))
                    currentLines.append(raw)
                } else {
                    // Global option before any block
                    preamble.append(raw)
                }
            }
        }

        commit()
        return SSHConfig(preambleLines: preamble, blocks: blocks)
    }
}

// MARK: - Writer

public enum SSHConfigWriter {

    public enum Error: Swift.Error, LocalizedError {
        case writeError(URL, Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .writeError(let url, let inner):
                return "Could not write \(url.path): \(inner.localizedDescription)"
            }
        }
    }

    // MARK: Public API

    /// Serialises `config` back to a string using stored raw lines for fidelity.
    public static func serialize(_ config: SSHConfig) -> String {
        var lines: [String] = []
        lines.append(contentsOf: config.preambleLines)
        for block in config.blocks {
            lines.append(contentsOf: block.rawLines)
        }
        // Ensure single trailing newline
        var result = lines.joined(separator: "\n")
        if !result.hasSuffix("\n") { result += "\n" }
        return result
    }

    /// Writes `config` to `url` atomically.
    public static func write(_ config: SSHConfig, to url: URL) throws {
        do {
            try serialize(config).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw Error.writeError(url, error)
        }
    }

    /// Builds a new raw-line representation of `block` (used when creating blocks programmatically).
    public static func rawLines(for block: SSHConfig.Block) -> [String] {
        var lines: [String] = []
        switch block.kind {
        case .host(let pattern):
            lines.append("Host \(pattern)")
        case .match(let criteria):
            lines.append("Match \(criteria)")
        }
        for (key, value) in block.entries {
            lines.append("    \(key) \(value)")
        }
        return lines
    }

    /// Convenience: create a minimal Host block with the given options.
    public static func makeHostBlock(
        pattern: String,
        hostname: String,
        user: String,
        port: Int = 22,
        identityFile: String? = nil,
        proxyJump: String? = nil,
        extra: [(key: String, value: String)] = []
    ) -> SSHConfig.Block {
        var entries: [(key: String, value: String)] = [
            ("HostName", hostname),
            ("User", user)
        ]
        if port != 22 { entries.append(("Port", String(port))) }
        if let id = identityFile { entries.append(("IdentityFile", id)) }
        if let pj = proxyJump { entries.append(("ProxyJump", pj)) }
        entries.append(contentsOf: extra)

        let block = SSHConfig.Block(
            kind: .host(pattern: pattern),
            entries: entries,
            rawLines: []
        )
        // Build rawLines from entries
        let raw = rawLines(for: block)
        return SSHConfig.Block(kind: .host(pattern: pattern), entries: entries, rawLines: raw)
    }
}
