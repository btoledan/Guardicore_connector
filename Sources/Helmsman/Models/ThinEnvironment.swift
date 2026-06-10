// ThinEnvironment.swift — Gardicol Connector
// Models a Guardicore thin environment and the machines it contains.

import Foundation

// MARK: - ThinEnvironment

public struct ThinEnvironment: Identifiable, Codable, Hashable, Sendable {

    public var id:        UUID
    public var envNumber: Int
    public var label:     String
    public var username:  String
    public var password:  String
    public var mgmtUsername: String
    public var mgmtPassword: String
    public var aggregators:  [GuardicoreAggregator]
    public var clusters:     [GuardicoreCluster]
    public var sortOrder: Int

    public static let defaultPassword = "tisctmt1"
    public static let defaultUser     = "root"
    public static let mgmtHost        = "mgmt"
    static let password = defaultPassword
    static let user     = defaultUser

    public var host: String { "\(envNumber).thin.env" }

    public var displayName: String {
        label.isEmpty ? "\(envNumber)" : "\(envNumber)  —  \(label)"
    }

    public var testerShellCommand: String { shellCommand }
    public var testerTabName: String { "\(envNumber) › Tester" }

    public var mgmtShellCommand: String {
        SSHDoubleHop.command(
            through: self,
            username: mgmtUsername,
            password: mgmtPassword,
            remoteHost: Self.mgmtHost
        )
    }

    public var mgmtTabName: String { "\(envNumber) › Mgmt" }

    public var shellCommand: String {
        let sshpass = SSHToolLocator.sshpass
        let ssh     = SSHToolLocator.ssh
        return "\(sshpass) -p '\(password)' \(ssh) \(SSHDoubleHop.sshOptions) \(username)@\(host)"
    }

    public var hasMachinesBelowTester: Bool {
        true // mgmt is always present; aggregators/clusters may exist too
    }

    enum CodingKeys: String, CodingKey {
        case id, envNumber, label, username, password
        case mgmtUsername, mgmtPassword, aggregators, clusters, sortOrder
    }

    public init(
        id:            UUID = .init(),
        envNumber:     Int,
        label:         String = "",
        username:      String = ThinEnvironment.defaultUser,
        password:      String = ThinEnvironment.defaultPassword,
        mgmtUsername:  String = ThinEnvironment.defaultUser,
        mgmtPassword:  String = ThinEnvironment.defaultPassword,
        aggregators:   [GuardicoreAggregator]? = nil,
        clusters:      [GuardicoreCluster] = [],
        sortOrder:     Int = 0
    ) {
        self.id           = id
        self.envNumber    = envNumber
        self.label        = label
        self.username     = username
        self.password     = password
        self.mgmtUsername = mgmtUsername
        self.mgmtPassword = mgmtPassword
        self.aggregators  = aggregators ?? [GuardicoreAggregator()]
        self.clusters     = clusters
        self.sortOrder    = sortOrder
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decode(UUID.self, forKey: .id)
        envNumber    = try c.decode(Int.self, forKey: .envNumber)
        label        = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        username     = try c.decodeIfPresent(String.self, forKey: .username) ?? Self.defaultUser
        password     = try c.decodeIfPresent(String.self, forKey: .password) ?? Self.defaultPassword
        mgmtUsername = try c.decodeIfPresent(String.self, forKey: .mgmtUsername) ?? Self.defaultUser
        mgmtPassword = try c.decodeIfPresent(String.self, forKey: .mgmtPassword) ?? Self.defaultPassword
        aggregators  = try c.decodeIfPresent([GuardicoreAggregator].self, forKey: .aggregators)
            ?? [GuardicoreAggregator()]
        clusters     = try c.decodeIfPresent([GuardicoreCluster].self, forKey: .clusters) ?? []
        sortOrder    = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

// MARK: - GuardicoreAggregator

public struct GuardicoreAggregator: Identifiable, Codable, Hashable, Sendable {

    public var id:       UUID
    public var address:  String
    public var label:    String
    public var username: String
    public var password: String

    public static let defaultAddress = "172.16.100.50"

    public var displayName: String {
        label.isEmpty ? "Aggr \(address)" : label
    }

    public init(
        id:       UUID = .init(),
        address:  String = GuardicoreAggregator.defaultAddress,
        label:    String = "",
        username: String = "",
        password: String = ""
    ) {
        self.id       = id
        self.address  = address
        self.label    = label
        self.username = username
        self.password = password
    }

    public func shellCommand(through env: ThinEnvironment) -> String {
        let p = password.isEmpty ? env.password : password
        let u = username.isEmpty ? env.username : username
        return SSHDoubleHop.command(through: env, username: u, password: p, remoteHost: address)
    }

    public func tabName(in env: ThinEnvironment) -> String {
        "\(env.envNumber) › \(displayName)"
    }
}

// MARK: - GuardicoreCluster

public struct GuardicoreCluster: Identifiable, Codable, Hashable, Sendable {

    public var id:       UUID
    public var type:     ClusterType
    public var label:    String
    public var customIP: String
    public var username: String
    public var password: String

    public enum ClusterType: String, Codable, CaseIterable, Sendable {
        case rancher   = "Rancher"
        case rke2      = "RKE2"
        case k3s       = "k3s"
        case openshift = "OpenShift"
        case custom    = "Custom"

        public var defaultIP: String {
            switch self {
            case .rancher:   return "172.17.100.1"
            case .rke2:      return "172.17.50.1"
            case .k3s:       return "172.17.49.1"
            case .openshift: return "172.17.0.55"
            case .custom:    return ""
            }
        }

        /// CLI tool used to talk to this cluster type.
        public var cliTool: String {
            switch self {
            case .openshift: return "oc"
            default:         return "kubectl"
            }
        }
    }

    public var ip: String {
        switch type {
        case .rancher:   return "172.17.100.1"
        case .rke2:      return "172.17.50.1"
        case .k3s:       return "172.17.49.1"
        case .openshift: return "172.17.0.55"
        case .custom:    return customIP
        }
    }

    public var displayName: String {
        label.isEmpty ? type.rawValue : label
    }

    public init(
        id:       UUID = .init(),
        type:     ClusterType,
        label:    String = "",
        customIP: String = "",
        username: String = "",
        password: String = ""
    ) {
        self.id       = id
        self.type     = type
        self.label    = label
        self.customIP = customIP
        self.username = username
        self.password = password
    }

    public func clusterShellCommand(through env: ThinEnvironment) -> String {
        let p = password.isEmpty ? env.password : password
        let u = username.isEmpty ? env.username : username
        return SSHDoubleHop.command(through: env, username: u, password: p, remoteHost: ip)
    }

    public func clusterRemoteCommand(_ command: String, through env: ThinEnvironment) -> String {
        let p = password.isEmpty ? env.password : password
        let u = username.isEmpty ? env.username : username
        return SSHDoubleHop.command(
            through: env,
            username: u,
            password: p,
            remoteHost: ip,
            remoteCommand: command
        )
    }

    public func clusterTabName(in env: ThinEnvironment) -> String {
        "\(env.envNumber) › \(displayName)"
    }

    public func shellCommand(through env: ThinEnvironment) -> String {
        clusterShellCommand(through: env)
    }
}
