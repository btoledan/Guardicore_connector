// KubeContext.swift — KubeKit
// Data model for Kubernetes / OpenShift contexts, clusters, and namespace pins.

import Foundation

// MARK: - Kube Config structures

/// Raw representation matching the `~/.kube/config` JSON schema.
public struct RawKubeConfig: Decodable, Sendable {
    public let clusters:        [RawNamedCluster]
    public let contexts:        [RawNamedContext]
    public let users:           [RawNamedUser]
    public let currentContext:  String

    enum CodingKeys: String, CodingKey {
        case clusters, contexts, users
        case currentContext = "current-context"
    }
}

public struct RawNamedCluster: Decodable, Sendable {
    public let name:    String
    public let cluster: RawCluster
}

public struct RawCluster: Decodable, Sendable {
    public let server:                      String
    public let certificateAuthorityData:    String?
    public let insecureSkipTlsVerify:       Bool?

    enum CodingKeys: String, CodingKey {
        case server
        case certificateAuthorityData  = "certificate-authority-data"
        case insecureSkipTlsVerify     = "insecure-skip-tls-verify"
    }
}

public struct RawNamedContext: Decodable, Sendable {
    public let name:    String
    public let context: RawContext
}

public struct RawContext: Decodable, Sendable {
    public let cluster:   String
    public let user:      String
    public let namespace: String?
}

public struct RawNamedUser: Decodable, Sendable {
    public let name: String
    // User auth details intentionally omitted (not shown in UI)
}

// MARK: - KubeContext (app-level model)

/// A fully resolved context, combining its cluster and namespace.
public struct KubeContext: Identifiable, Hashable, Sendable {
    public var id: String { contextName }

    public let contextName:  String
    public let clusterName:  String
    public let serverURL:    String
    public let user:         String
    /// The namespace pinned for this context. Defaults to whatever is in the kube config ("default" if absent).
    public var pinnedNamespace: String
    public let isOpenShift:  Bool   // heuristic: server contains "api." and port 6443

    public init(
        contextName: String,
        clusterName: String,
        serverURL: String,
        user: String,
        pinnedNamespace: String,
        isOpenShift: Bool
    ) {
        self.contextName      = contextName
        self.clusterName      = clusterName
        self.serverURL        = serverURL
        self.user             = user
        self.pinnedNamespace  = pinnedNamespace
        self.isOpenShift      = isOpenShift
    }

    // MARK: Derived helpers

    /// Short display name: trims the "/<user>" suffix many tools append.
    public var displayName: String {
        if contextName.contains("/") {
            return String(contextName.split(separator: "/").first ?? Substring(contextName))
        }
        return contextName
    }

    /// Runs `oc` if OpenShift heuristic is true, else `kubectl`.
    public var cliTool: String { isOpenShift ? "oc" : "kubectl" }
}

// MARK: - Namespace Pin

/// A pinned (bookmarked) namespace for a context, persisted in app preferences.
public struct NamespacePin: Identifiable, Codable, Hashable, Sendable {
    public var id:          UUID
    public var contextName: String
    public var namespace:   String
    public var label:       String  // optional human-readable label

    public init(contextName: String, namespace: String, label: String = "") {
        self.id          = UUID()
        self.contextName = contextName
        self.namespace   = namespace.isEmpty ? "default" : namespace
        self.label       = label.isEmpty ? namespace : label
    }
}
