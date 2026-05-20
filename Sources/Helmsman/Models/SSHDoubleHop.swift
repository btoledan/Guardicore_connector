// SSHDoubleHop.swift — Gardicol Connector
// Builds double-hop sshpass commands: local Mac → thin env → target host.

import Foundation

enum SSHDoubleHop {
    /// Options for interactive shells (forces pseudo-tty allocation).
    static let sshOptions =
        "-tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"

    /// Options for background commands (no pseudo-tty — keeps output clean for parsing).
    static let sshBgOptions =
        "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"

    /// Hop 1 uses full local paths; hop 2 uses plain sshpass/ssh on the remote tester.
    static func command(
        through env: ThinEnvironment,
        username: String,
        password: String,
        remoteHost: String
    ) -> String {
        let p = password.isEmpty ? env.password : password
        let u = username.isEmpty ? env.username : username
        let localSSHPass = SSHToolLocator.sshpass
        let localSSH     = SSHToolLocator.ssh
        let hop1 = "\(localSSHPass) -p '\(p)' \(localSSH) \(sshOptions) \(u)@\(env.host)"
        let hop2 = "sshpass -p '\(p)' ssh \(sshOptions) \(u)@\(remoteHost)"
        return "\(hop1) \"\(hop2)\""
    }

    /// Runs one remote command on the final machine instead of opening an interactive shell.
    /// Uses no-tty options so the output is clean text suitable for parsing.
    static func command(
        through env: ThinEnvironment,
        username: String,
        password: String,
        remoteHost: String,
        remoteCommand: String
    ) -> String {
        let p = password.isEmpty ? env.password : password
        let u = username.isEmpty ? env.username : username
        let localSSHPass = SSHToolLocator.sshpass
        let localSSH     = SSHToolLocator.ssh
        let hop1 = "\(localSSHPass) -p '\(p)' \(localSSH) \(sshBgOptions) \(u)@\(env.host)"
        let hop2 = "sshpass -p '\(p)' ssh \(sshBgOptions) \(u)@\(remoteHost) \(shellQuote(remoteCommand))"
        return "\(hop1) \"\(hop2)\""
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
