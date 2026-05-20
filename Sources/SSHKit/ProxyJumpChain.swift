// ProxyJumpChain.swift — SSHKit
// Models a multi-hop ProxyJump chain and builds the SSH argv.

import Foundation

// MARK: - ProxyJump Hop

/// One hop in a ProxyJump chain (bastion or intermediate).
public struct ProxyJumpHop: Codable, Hashable, Sendable {
    /// Optional reference to a Host alias in ~/.ssh/config.
    /// When set, all other fields can be omitted and the alias is used as-is.
    public var sshConfigAlias: String?

    public var user: String
    public var host: String
    public var port: Int

    /// Path to an identity file, if different from the default agent / global config.
    public var identityFile: String?

    public init(
        sshConfigAlias: String? = nil,
        user: String,
        host: String,
        port: Int = 22,
        identityFile: String? = nil
    ) {
        self.sshConfigAlias = sshConfigAlias
        self.user = user
        self.host = host
        self.port = port
        self.identityFile = identityFile
    }

    /// The string used in the -J argument: "user@host:port" (or just the alias).
    public var jumpString: String {
        if let alias = sshConfigAlias, !alias.isEmpty {
            return alias
        }
        let base = "\(user)@\(host)"
        return port == 22 ? base : "\(base):\(port)"
    }
}

// MARK: - ProxyJump Chain

/// An ordered list of hops. The final target is NOT included here;
/// it is specified separately in `SSHSessionDescriptor`.
public struct ProxyJumpChain: Codable, Hashable, Sendable {
    public var hops: [ProxyJumpHop]

    public init(hops: [ProxyJumpHop] = []) {
        self.hops = hops
    }

    public var isEmpty: Bool { hops.isEmpty }

    // MARK: -J argument

    /// The value for `ssh -J …`: comma-separated jump strings.
    /// Returns nil if the chain is empty.
    public var proxyJumpArgument: String? {
        guard !hops.isEmpty else { return nil }
        return hops.map(\.jumpString).joined(separator: ",")
    }

    // MARK: SSH argv

    /// Builds the complete argv for `/usr/bin/ssh` given a target.
    ///
    /// - Parameters:
    ///   - descriptor: The final target session descriptor.
    ///   - extraArgs:  Any caller-supplied extra flags (e.g., `-N` for tunnel-only sessions).
    public func sshArgv(for descriptor: SSHSessionDescriptor,
                        extraArgs: [String] = []) -> [String] {
        var args: [String] = []

        // Identity file for the target hop
        if let id = descriptor.identityFile {
            args += ["-i", (id as NSString).expandingTildeInPath]
        }

        // ProxyJump chain
        if let pj = proxyJumpArgument {
            args += ["-J", pj]
        }

        // Port
        if descriptor.port != 22 {
            args += ["-p", String(descriptor.port)]
        }

        // X11 forwarding
        if descriptor.x11Forwarding { args.append("-X") }

        // Agent forwarding
        if descriptor.agentForwarding { args.append("-A") }

        // Compression
        if descriptor.compression { args.append("-C") }

        // ServerAliveInterval
        args += ["-o", "ServerAliveInterval=\(descriptor.serverAliveInterval)"]
        args += ["-o", "ServerAliveCountMax=3"]

        // Disable strict host key checking only if explicitly requested (Lab mode)
        if descriptor.skipHostKeyChecking {
            args += ["-o", "StrictHostKeyChecking=no"]
            args += ["-o", "UserKnownHostsFile=/dev/null"]
        }

        // Extra caller args (e.g., -N, -L, -R, -D)
        args.append(contentsOf: extraArgs)

        // Target: user@host
        let target = "\(descriptor.username)@\(descriptor.host)"
        args.append(target)

        return args
    }

    // MARK: Tunnel argv

    /// Builds argv for a port-forwarding (tunnel) invocation.
    public func tunnelArgv(for descriptor: SSHSessionDescriptor,
                           tunnels: [TunnelDescriptor]) -> [String] {
        var tunnelFlags: [String] = ["-N"] // no remote command
        for t in tunnels {
            tunnelFlags += t.sshFlags
        }
        return sshArgv(for: descriptor, extraArgs: tunnelFlags)
    }

    // MARK: Hop testing

    /// argv to test reachability of a single hop via `ssh -W %h:%p`.
    /// Used by the ProxyJump Composer's per-hop "Test" button.
    public func testArgv(through previousHops: [ProxyJumpHop],
                         testing hop: ProxyJumpHop,
                         testPort: Int = 22) -> [String] {
        var args: [String] = ["-W", "\(hop.host):\(hop.port)", "-o", "ConnectTimeout=5"]
        let chain = ProxyJumpChain(hops: previousHops)
        if let pj = chain.proxyJumpArgument {
            args += ["-J", pj]
        }
        if let id = hop.identityFile {
            args += ["-i", (id as NSString).expandingTildeInPath]
        }
        args += ["\(hop.user)@\(hop.host)"]
        return args
    }
}

// MARK: - Tunnel Descriptor

/// One SSH tunnel (local, remote, or dynamic).
public struct TunnelDescriptor: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case local   = "Local (-L)"
        case remote  = "Remote (-R)"
        case dynamic = "Dynamic (-D)"
    }

    public var id: UUID
    public var label: String
    public var kind: Kind
    /// Local bind address (default: 127.0.0.1)
    public var localBindAddress: String
    public var localPort: Int
    /// Remote host (unused for dynamic)
    public var remoteHost: String
    /// Remote port (unused for dynamic)
    public var remotePort: Int

    public init(
        id: UUID = .init(),
        label: String = "",
        kind: Kind = .local,
        localBindAddress: String = "127.0.0.1",
        localPort: Int,
        remoteHost: String = "",
        remotePort: Int = 0
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.localBindAddress = localBindAddress
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
    }

    /// The flags appended to the ssh command (e.g., ["-L", "8080:remote:80"]).
    public var sshFlags: [String] {
        switch kind {
        case .local:
            return ["-L", "\(localBindAddress):\(localPort):\(remoteHost):\(remotePort)"]
        case .remote:
            return ["-R", "\(remotePort):\(localBindAddress):\(localPort)"]
        case .dynamic:
            return ["-D", "\(localBindAddress):\(localPort)"]
        }
    }

    /// The one-liner string suitable for pasting into a runbook.
    public func oneLiner(sshTarget: String) -> String {
        let flags = sshFlags.joined(separator: " ")
        return "ssh \(flags) -N \(sshTarget)"
    }
}
