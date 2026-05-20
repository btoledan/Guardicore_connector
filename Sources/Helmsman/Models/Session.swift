// Session.swift — Helmsman (app layer)
// The primary data model. Pure Codable; no framework references stored directly.
// Passwords are kept in VaultKit.Keychain, not in this file.

import Foundation
import SSHKit
import TerminalKit

// MARK: - Session

public struct Session: Identifiable, Codable, Hashable {

    public var id:   UUID
    public var name: String
    public var kind: SessionKind

    // MARK: Target host
    public var host:     String
    public var port:     Int
    public var username: String

    // MARK: Auth
    public var authMethod:    AuthMethod
    /// Absolute or ~-expanded path to the identity file (key auth).
    public var identityFile:  String?

    // MARK: ProxyJump chain
    /// Ordered list of hops. The last hop connects to `host`.
    public var proxyJumpHops: [ProxyJumpHop]

    // MARK: Options
    public var x11Forwarding:       Bool
    public var agentForwarding:     Bool
    public var compression:         Bool
    public var serverAliveInterval: Int

    // MARK: Tunnels
    public var tunnels: [TunnelDescriptor]

    // MARK: SFTP
    public var sftpEnabled: Bool

    // MARK: Kube
    public var associatedKubeContext: String?   // context name from ~/.kube/config

    // MARK: Workspace profile
    public var workspaceProfileID: UUID

    // MARK: Metadata
    public var tags:   [String]
    public var notes:  String
    public var sortOrder: Int

    // MARK: Telnet / Serial specific
    /// For Telnet sessions
    public var telnetPort: Int
    /// For Serial sessions
    public var serialDevice: String
    public var serialBaudRate: Int

    // MARK: Init (SSH default)
    public init(
        id:   UUID   = .init(),
        name: String = "New Session",
        kind: SessionKind = .ssh,
        host: String = "",
        port: Int    = 22,
        username: String = "",
        authMethod: AuthMethod = .agent,
        identityFile: String?  = nil,
        proxyJumpHops: [ProxyJumpHop] = [],
        x11Forwarding:       Bool = false,
        agentForwarding:     Bool = false,
        compression:         Bool = false,
        serverAliveInterval: Int  = 60,
        tunnels: [TunnelDescriptor] = [],
        sftpEnabled: Bool = true,
        associatedKubeContext: String? = nil,
        workspaceProfileID: UUID = WorkspaceProfile.defaultProd.id,
        tags:  [String] = [],
        notes: String   = "",
        sortOrder: Int  = 0,
        telnetPort: Int = 23,
        serialDevice: String  = "",
        serialBaudRate: Int   = 115200
    ) {
        self.id                    = id
        self.name                  = name
        self.kind                  = kind
        self.host                  = host
        self.port                  = port
        self.username              = username
        self.authMethod            = authMethod
        self.identityFile          = identityFile
        self.proxyJumpHops         = proxyJumpHops
        self.x11Forwarding         = x11Forwarding
        self.agentForwarding       = agentForwarding
        self.compression           = compression
        self.serverAliveInterval   = serverAliveInterval
        self.tunnels               = tunnels
        self.sftpEnabled           = sftpEnabled
        self.associatedKubeContext = associatedKubeContext
        self.workspaceProfileID    = workspaceProfileID
        self.tags                  = tags
        self.notes                 = notes
        self.sortOrder             = sortOrder
        self.telnetPort            = telnetPort
        self.serialDevice          = serialDevice
        self.serialBaudRate        = serialBaudRate
    }

    // MARK: - Derived helpers

    /// Builds the SSHKit `SessionSpec` for this session.
    public func sessionSpec(skipHostKeyChecking: Bool = false) -> SessionSpec {
        switch kind {
        case .ssh:
            let desc = SSHSessionDescriptor(
                name:                name,
                host:                host,
                port:                port,
                username:            username,
                authMethod:          authMethod,
                identityFile:        identityFile,
                x11Forwarding:       x11Forwarding,
                agentForwarding:     agentForwarding,
                compression:         compression,
                serverAliveInterval: serverAliveInterval,
                skipHostKeyChecking: skipHostKeyChecking
            )
            let chain = ProxyJumpChain(hops: proxyJumpHops)
            return .ssh(desc, chain, tunnels)

        case .sftp:
            let desc = SSHSessionDescriptor(
                name: name, host: host, port: port, username: username,
                authMethod: authMethod, identityFile: identityFile
            )
            return .sftp(desc, ProxyJumpChain(hops: proxyJumpHops))

        case .telnet:
            return .telnet(TelnetSessionDescriptor(name: name, host: host, port: telnetPort))

        case .serial:
            guard let baud = SerialSessionDescriptor.BaudRate(rawValue: serialBaudRate) else {
                return .serial(SerialSessionDescriptor(name: name, device: serialDevice))
            }
            return .serial(SerialSessionDescriptor(name: name, device: serialDevice, baudRate: baud))

        case .tunnelOnly:
            let desc = SSHSessionDescriptor(
                name: name, host: host, port: port, username: username,
                authMethod: authMethod, identityFile: identityFile
            )
            let chain = ProxyJumpChain(hops: proxyJumpHops)
            return .ssh(desc, chain, tunnels)  // ssh -N with tunnels

        case .local:
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            return .local(shell: shell)
        }
    }

    /// Converts this session to an `AnySessionSpec` for TerminalKit.
    public func anySpec(profile: WorkspaceProfile) -> AnySessionSpec {
        let spec = sessionSpec(skipHostKeyChecking: profile.isLab)
        return AnySessionSpec(
            name:          spec.name,
            executableURL: spec.executableURL,
            args:          spec.args
        )
    }

    /// One-liner connection string for export / runbook.
    public func connectionOneLiner() -> String {
        let spec = sessionSpec()
        switch spec {
        case .ssh(let d, let chain, _):
            return d.sshOneLiner(chain: chain)
        case .sftp(let d, let chain):
            var args: [String] = []
            if let pj = chain.proxyJumpArgument { args += ["-J", pj] }
            if d.port != 22 { args += ["-P", String(d.port)] }
            args.append(d.sshTarget)
            return (["/usr/bin/sftp"] + args).joined(separator: " ")
        case .telnet(let d):
            return d.argv.joined(separator: " ")
        case .serial(let d):
            return d.argv.joined(separator: " ")
        case .local(let shell):
            return shell
        }
    }
}
