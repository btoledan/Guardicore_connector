// ClusterCustomCommandsStorage.swift — persisted user-defined kubectl shortcuts

import Foundation

enum ClusterCustomCommandsStorage {
    static let appStorageKey = "gardicol.clusterCustomCommands"

    static func parse(_ blob: String) -> [String] {
        blob.split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static func appending(_ command: String, to blob: String) -> String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return blob }
        var list = parse(blob)
        guard !list.contains(trimmed) else { return blob }
        list.append(trimmed)
        return list.joined(separator: "\n")
    }

    static func removing(_ command: String, from blob: String) -> String {
        parse(blob).filter { $0 != command }.joined(separator: "\n")
    }
}
