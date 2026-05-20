// ScanResult.swift — NetScanKit

import Foundation

// MARK: - Well-known ports

public enum WellKnownPort: Int, CaseIterable, Sendable {
    case ssh      = 22
    case telnet   = 23
    case smtp     = 25
    case dns      = 53
    case http     = 80
    case pop3     = 110
    case imap     = 143
    case https    = 443
    case rdp      = 3389
    case vnc      = 5900
    case alt8080  = 8080
    case alt8443  = 8443
    case k8sApi   = 6443    // OpenShift / Kubernetes API

    public var label: String {
        switch self {
        case .ssh:     return "SSH"
        case .telnet:  return "Telnet"
        case .smtp:    return "SMTP"
        case .dns:     return "DNS"
        case .http:    return "HTTP"
        case .pop3:    return "POP3"
        case .imap:    return "IMAP"
        case .https:   return "HTTPS"
        case .rdp:     return "RDP"
        case .vnc:     return "VNC"
        case .alt8080: return "HTTP-Alt"
        case .alt8443: return "HTTPS-Alt"
        case .k8sApi:  return "Kube API"
        }
    }
}

// MARK: - Scan Result

public struct ScanResult: Identifiable, Hashable, Sendable {
    public var id: String { host }

    public let host: String
    public let openPorts: [Int]
    public let timestamp: Date

    public init(host: String, openPorts: [Int], timestamp: Date = .now) {
        self.host      = host
        self.openPorts = openPorts.sorted()
        self.timestamp = timestamp
    }

    // MARK: Derived

    public var hasSSH: Bool    { openPorts.contains(22) }
    public var hasTelnet: Bool { openPorts.contains(23) }
    public var hasHTTPS: Bool  { openPorts.contains(443) }
    public var isKubeAPI: Bool { openPorts.contains(6443) }

    /// Formatted open ports with known service labels.
    public var portSummary: String {
        openPorts.map { port in
            if let known = WellKnownPort(rawValue: port) {
                return "\(port)/\(known.label)"
            }
            return "\(port)"
        }.joined(separator: ", ")
    }
}

// MARK: - Scan State

public enum ScanState: Sendable {
    case idle
    case running(progress: Double)   // 0.0 – 1.0
    case finished([ScanResult])
    case cancelled
    case failed(String)
}
