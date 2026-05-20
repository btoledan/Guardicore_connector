// SSHSessionDescriptor.swift — SSHKit
// Describes one SSH/SFTP/Telnet/Serial session and computes the launch argv.

import Foundation

// MARK: - Session Types

public enum SessionKind: String, Codable, CaseIterable, Sendable {
    case ssh        = "SSH"
    case sftp       = "SFTP"
    case telnet     = "Telnet"
    case serial     = "Serial"
    case tunnelOnly = "Tunnel"
    case local      = "Local Shell"
}

public enum AuthMethod: String, Codable, CaseIterable, Sendable {
    case key                = "Key / Certificate"
    case agent              = "SSH Agent"
    case password           = "Password"
    case keyboardInteractive = "Keyboard Interactive"
}

// MARK: - SSH Session Descriptor

/// Pure data describing one SSH session.  No I/O.
/// Compute the launch argv with `argv(chain:)`.
public struct SSHSessionDescriptor: Codable, Hashable, Sendable {

    // MARK: Identity
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var authMethod: AuthMethod

    // MARK: Key / Certificate
    /// Absolute or ~-expanded path to the identity file.
    public var identityFile: String?

    // MARK: Options
    public var x11Forwarding: Bool
    public var agentForwarding: Bool
    public var compression: Bool
    public var serverAliveInterval: Int
    /// Disable StrictHostKeyChecking — only permitted in Lab workspace profiles.
    public var skipHostKeyChecking: Bool

    // MARK: Init

    public init(
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        authMethod: AuthMethod = .agent,
        identityFile: String? = nil,
        x11Forwarding: Bool = false,
        agentForwarding: Bool = false,
        compression: Bool = false,
        serverAliveInterval: Int = 60,
        skipHostKeyChecking: Bool = false
    ) {
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.identityFile = identityFile
        self.x11Forwarding = x11Forwarding
        self.agentForwarding = agentForwarding
        self.compression = compression
        self.serverAliveInterval = serverAliveInterval
        self.skipHostKeyChecking = skipHostKeyChecking
    }

    // MARK: Computed strings

    public var sshTarget: String { "\(username)@\(host)" }

    // MARK: Export connection blocks

    /// Full `ssh …` one-liner for pasting into chats / runbooks.
    public func sshOneLiner(chain: ProxyJumpChain = .init()) -> String {
        let args = chain.sshArgv(for: self)
        return (["/usr/bin/ssh"] + args).joined(separator: " ")
    }

    /// `scp …` one-liner to copy a local file to the remote home directory.
    public func scpOneLiner(localPath: String, remotePath: String = "~/",
                            chain: ProxyJumpChain = .init()) -> String {
        var args: [String] = []
        if let pj = chain.proxyJumpArgument { args += ["-J", pj] }
        if port != 22 { args += ["-P", String(port)] }
        if let id = identityFile { args += ["-i", id] }
        args += [localPath, "\(sshTarget):\(remotePath)"]
        return (["/usr/bin/scp"] + args).joined(separator: " ")
    }

    /// `export KUBECONFIG=…` shell snippet (if a kubeconfig path is associated).
    public func kubeconfigExport(kubeconfigPath: String) -> String {
        "export KUBECONFIG=\(kubeconfigPath)"
    }
}

// MARK: - Telnet Descriptor

public struct TelnetSessionDescriptor: Codable, Hashable, Sendable {
    public var name: String
    public var host: String
    public var port: Int

    public var argv: [String] {
        ["/usr/bin/telnet", host, String(port)]
    }

    public init(name: String, host: String, port: Int = 23) {
        self.name = name
        self.host = host
        self.port = port
    }
}

// MARK: - Serial Descriptor

public struct SerialSessionDescriptor: Codable, Hashable, Sendable {
    public enum BaudRate: Int, Codable, CaseIterable, Sendable {
        case b9600   = 9600
        case b19200  = 19200
        case b38400  = 38400
        case b57600  = 57600
        case b115200 = 115200

        public var label: String { "\(rawValue)" }
    }

    public enum Parity: String, Codable, CaseIterable, Sendable {
        case none = "None"
        case even = "Even"
        case odd  = "Odd"
    }

    public var name: String
    public var device: String          // e.g., "/dev/tty.usbserial-0001"
    public var baudRate: BaudRate
    public var dataBits: Int           // 7 or 8
    public var parity: Parity
    public var stopBits: Int           // 1 or 2

    /// screen(1) is universally available on macOS and handles serial.
    public var argv: [String] {
        ["/usr/bin/screen", device, String(baudRate.rawValue)]
    }

    public init(
        name: String,
        device: String,
        baudRate: BaudRate = .b115200,
        dataBits: Int = 8,
        parity: Parity = .none,
        stopBits: Int = 1
    ) {
        self.name = name
        self.device = device
        self.baudRate = baudRate
        self.dataBits = dataBits
        self.parity = parity
        self.stopBits = stopBits
    }
}

// MARK: - Unified Session Spec (tagged union)

public enum SessionSpec: Codable, Hashable, Sendable {
    case ssh(SSHSessionDescriptor, ProxyJumpChain, [TunnelDescriptor])
    case sftp(SSHSessionDescriptor, ProxyJumpChain)
    case telnet(TelnetSessionDescriptor)
    case serial(SerialSessionDescriptor)
    case local(shell: String)

    public var name: String {
        switch self {
        case .ssh(let d, _, _):    return d.name
        case .sftp(let d, _):     return d.name
        case .telnet(let d):      return d.name
        case .serial(let d):      return d.name
        case .local:              return "Local Shell"
        }
    }

    public var kind: SessionKind {
        switch self {
        case .ssh:    return .ssh
        case .sftp:   return .sftp
        case .telnet: return .telnet
        case .serial: return .serial
        case .local:  return .local
        }
    }

    /// The argv used to launch the process in the PTY.
    public var launchArgv: [String] {
        switch self {
        case .ssh(let d, let chain, let tunnels):
            if tunnels.isEmpty {
                return ["/usr/bin/ssh"] + chain.sshArgv(for: d)
            } else {
                return ["/usr/bin/ssh"] + chain.tunnelArgv(for: d, tunnels: tunnels)
            }
        case .sftp(let d, let chain):
            var args: [String] = []
            if let pj = chain.proxyJumpArgument { args += ["-J", pj] }
            if d.port != 22 { args += ["-P", String(d.port)] }
            if let id = d.identityFile { args += ["-i", id] }
            args.append(d.sshTarget)
            return ["/usr/bin/sftp"] + args
        case .telnet(let d):
            return d.argv
        case .serial(let d):
            return d.argv
        case .local(let shell):
            return [shell]
        }
    }

    public var executableURL: URL {
        URL(fileURLWithPath: launchArgv[0])
    }

    public var args: [String] {
        Array(launchArgv.dropFirst())
    }
}
