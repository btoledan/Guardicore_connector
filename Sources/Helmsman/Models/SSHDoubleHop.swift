// SSHDoubleHop.swift — Gardicol Connector
// Builds double-hop sshpass commands: local Mac → thin env → target host.

import Foundation

enum SSHDoubleHop {
    /// Keepalive + resiliency options shared by both hops.
    /// - ServerAliveInterval/CountMax: send a keepalive every 15s, tolerate 4 misses (60s grace)
    ///   before giving up. This is what stops "closed by remote host" idle drops.
    /// - TCPKeepAlive: also keep the TCP socket warm through NAT/firewalls on the path.
    /// - ServerAliveInterval on BOTH hops keeps the tester→target leg alive too, not just Mac→tester.
    static let keepAlive =
        "-o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o TCPKeepAlive=yes"

    /// Options for interactive shells (forces pseudo-tty allocation).
    static let sshOptions =
        "-tt -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \(keepAlive)"

    /// Options for background commands (no pseudo-tty — keeps output clean for parsing).
    static let sshBgOptions =
        "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null \(keepAlive)"

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

    /// Runs a command on the thin-env tester itself (single hop, no second SSH).
    /// Useful for probing the cluster network from inside the env (e.g. ping).
    static func testerCommand(
        through env: ThinEnvironment,
        username: String,
        password: String,
        remoteCommand: String
    ) -> String {
        let p = password.isEmpty ? env.password : password
        let u = username.isEmpty ? env.username : username
        let localSSHPass = SSHToolLocator.sshpass
        let localSSH     = SSHToolLocator.ssh
        return "\(localSSHPass) -p '\(p)' \(localSSH) \(sshBgOptions) \(u)@\(env.host) \(shellQuote(remoteCommand))"
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
