// SSHToolLocator.swift — Gardicol Connector
// Resolves ssh/sshpass when GUI apps launch with a minimal PATH.

import Foundation

enum SSHToolLocator {
    private static let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ]

    static func path(for tool: String) -> String {
        for dir in searchPaths {
            let full = "\(dir)/\(tool)"
            if FileManager.default.isExecutableFile(atPath: full) {
                return full
            }
        }
        return tool
    }

    static var sshpass: String { path(for: "sshpass") }
    static var ssh:     String { path(for: "ssh") }

    static var sshpassAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: sshpass)
    }
}
