// KubeJSONParser.swift — Gardicol Connector
// Parses kubectl -o json output into ClusterSnapshot models.

import Foundation

enum KubeJSONParser {

    // MARK: - Public API

    static func parseNodesJSON(_ output: String) -> [ClusterNode] {
        guard let list: KubeNodeList = decode(output) else { return [] }
        return list.items.map { item in
            let ready = item.status?.conditions?
                .first { $0.type == "Ready" }?.status ?? "Unknown"
            let role = item.metadata.labels?
                .first { $0.key.contains("node-role") }?.value ?? "<none>"
            let internalIP = item.status?.addresses?
                .first { $0.type == "InternalIP" }?.address ?? ""
            return ClusterNode(
                name: item.metadata.name,
                role: role,
                internalIP: internalIP,
                status: ready == "True" ? "Ready" : "NotReady",
                age: age(from: item.metadata.creationTimestamp),
                version: item.status?.nodeInfo?.kubeletVersion,
                osImage: item.status?.nodeInfo?.osImage
            )
        }
    }

    static func parsePodsJSON(_ output: String, namespaceFilter: String? = nil) -> [ClusterPod] {
        guard let list: KubePodList = decode(output) else { return [] }
        return list.items
            .filter { namespaceFilter == nil || $0.metadata.namespace == namespaceFilter }
            .map { item in
                let ready = item.status?.containerStatuses?
                    .reduce((0, 0)) { acc, cs in
                        (acc.0 + (cs.ready ? 1 : 0), acc.1 + 1)
                    } ?? (0, 0)
                let readyStr = "\(ready.0)/\(ready.1)"
                let restarts = item.status?.containerStatuses?
                    .map(\.restartCount).reduce(0, +) ?? 0
                return ClusterPod(
                    namespace: item.metadata.namespace ?? "",
                    name: item.metadata.name,
                    ready: readyStr,
                    status: item.status?.phase ?? "Unknown",
                    restarts: restarts,
                    age: age(from: item.metadata.creationTimestamp),
                    ip: item.status?.podIP ?? "",
                    node: item.spec?.nodeName ?? ""
                )
            }
    }

    static func parseDaemonSetJSON(_ output: String) -> (desired: Int?, current: Int?, ready: Int?, available: Int?) {
        guard let list: KubeDaemonSetList = decode(output),
              let ds = list.items.first else { return (nil, nil, nil, nil) }
        return (
            ds.status?.desiredNumberScheduled,
            ds.status?.currentNumberScheduled,
            ds.status?.numberReady,
            ds.status?.numberAvailable
        )
    }

    static func parseDeploymentJSON(_ output: String) -> String? {
        guard let list: KubeDeploymentList = decode(output),
              let deploy = list.items.first else { return nil }
        let ready = deploy.status?.readyReplicas ?? 0
        let desired = deploy.status?.replicas ?? deploy.spec?.replicas ?? 0
        return "\(ready)/\(desired)"
    }

    static func parseCalicoPoliciesJSON(_ output: String) -> [CalicoPolicy] {
        guard let list: KubeCalicoPolicyList = decode(output) else { return [] }
        return list.items.map { item in
            let name = item.metadata.name
            let ns = item.metadata.namespace ?? ""
            let annotations = item.metadata.annotations ?? [:]
            let hasDeny = item.spec?.hasDenyAction ?? name.lowercased().contains("-block-")
            let uuid = extractRuleUUID(from: name)
            return CalicoPolicy(
                namespace: ns,
                name: name,
                action: name.lowercased().contains("-block-") ? "Block" : "Allow",
                ruleUUID: uuid,
                shortRuleID: uuid.map { "RUL-\($0.uppercased())" },
                direction: name.contains("--ingress") ? "ingress"
                    : name.contains("--egress") ? "egress" : nil,
                hasDeny: hasDeny,
                policyRevision: intAnnotation(annotations, matching: "policy-revision"),
                dcInventoryRevision: annotation(annotations, matching: "dc-inventory-revision"),
                sourceNamespace: inferNamespace(from: name, kind: "src"),
                destinationNamespace: inferNamespace(from: name, kind: "dst")
            )
        }
    }

    static func revisionAlignment(from snapshot: ClusterSnapshot) -> RevisionAlignment {
        let agentRevs = Set(snapshot.guardicore.agents.compactMap(\.policyRevision))
        let calicoRevs = Set(snapshot.policies.calicoPolicies.compactMap(\.policyRevision))
        let agentDC = Set(snapshot.guardicore.agents.compactMap(\.dcInventoryRevision))
        let calicoDC = Set(snapshot.policies.calicoPolicies.compactMap(\.dcInventoryRevision))

        let agentRev = agentRevs.count == 1 ? agentRevs.first : nil
        let calicoRev = calicoRevs.count == 1 ? calicoRevs.first : nil

        var chain: [RevisionChainStep] = []
        chain.append(RevisionChainStep(
            label: "Agent policy revision",
            value: agentRev.map(String.init) ?? (agentRevs.isEmpty ? "unknown" : "mixed (\(agentRevs.count))"),
            status: agentRevs.count <= 1 ? .ok : .warning,
            rawKey: "agentPolicyRevisionLogs"
        ))
        chain.append(RevisionChainStep(
            label: "Calico CRD revision",
            value: calicoRev.map(String.init) ?? (calicoRevs.isEmpty ? "unknown" : "mixed (\(calicoRevs.count))"),
            status: calicoRevs.isEmpty ? .unknown : (calicoRevs.count <= 1 ? .ok : .warning),
            rawKey: "calicoPoliciesJSON"
        ))
        if !agentDC.isEmpty || !calicoDC.isEmpty {
            chain.append(RevisionChainStep(
                label: "DC inventory revision",
                value: agentDC.count == 1 ? agentDC.first! : "mixed",
                status: agentDC == calicoDC && agentDC.count == 1 ? .ok : .warning,
                rawKey: "calicoPoliciesJSON"
            ))
        }

        let aligned = agentRev != nil && calicoRev != nil && agentRev == calicoRev
        return RevisionAlignment(steps: chain, isAligned: aligned, agentRevision: agentRev, calicoRevision: calicoRev)
    }

    // MARK: - Decode helper

    private static func decode<T: Decodable>(_ output: String) -> T? {
        guard let data = extractJSONData(from: output) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func extractJSONData(from output: String) -> Data? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{") ?? trimmed.firstIndex(of: "[") else { return nil }
        return String(trimmed[start...]).data(using: .utf8)
    }

    private static func age(from iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "?" }
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 3600 { return "\(secs / 60)m" }
        if secs < 86400 { return "\(secs / 3600)h" }
        return "\(secs / 86400)d"
    }

    private static func extractRuleUUID(from name: String) -> String? {
        let parts = name.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let candidate = String(parts[1])
        if candidate.count >= 8 { return String(candidate.prefix(8)) }
        return candidate.isEmpty ? nil : candidate
    }

    private static func annotation(_ annotations: [String: String], matching suffix: String) -> String? {
        annotations.first { key, _ in
            key == "guardicore/\(suffix)" || key.lowercased().contains(suffix.lowercased())
        }?.value.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
    }

    private static func intAnnotation(_ annotations: [String: String], matching suffix: String) -> Int? {
        guard let raw = annotation(annotations, matching: suffix) else { return nil }
        return raw.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
    }

    private static func inferNamespace(from name: String, kind: String) -> String? {
        // Names often embed namespace hints; best-effort from CRD naming patterns
        if name.contains("--ingress") || name.contains("--egress") { return nil }
        return nil
    }
}

// MARK: - Revision alignment

struct RevisionAlignment {
    var steps: [RevisionChainStep]
    var isAligned: Bool
    var agentRevision: Int?
    var calicoRevision: Int?
}

struct RevisionChainStep: Identifiable {
    enum Status { case ok, warning, error, unknown
        var symbol: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
    }
    var id: String { label }
    var label: String
    var value: String
    var status: Status
    var rawKey: String
}

// MARK: - Lightweight Kube JSON types

private struct KubeNodeList: Decodable { let items: [KubeNodeItem] }
private struct KubeNodeItem: Decodable {
    let metadata: KubeMeta
    let spec: KubeNodeSpec?
    let status: KubeNodeStatus?
}
private struct KubeNodeSpec: Decodable {}
private struct KubeNodeStatus: Decodable {
    let conditions: [KubeCondition]?
    let addresses: [KubeAddress]?
    let nodeInfo: KubeNodeInfo?
}
private struct KubeNodeInfo: Decodable {
    let kubeletVersion: String?
    let osImage: String?
}
private struct KubeAddress: Decodable { let type: String; let address: String }
private struct KubeCondition: Decodable { let type: String; let status: String }

private struct KubePodList: Decodable { let items: [KubePodItem] }
private struct KubePodItem: Decodable {
    let metadata: KubeMeta
    let spec: KubePodSpec?
    let status: KubePodStatus?
}
private struct KubePodSpec: Decodable { let nodeName: String? }
private struct KubePodStatus: Decodable {
    let phase: String?
    let podIP: String?
    let containerStatuses: [KubeContainerStatus]?
}
private struct KubeContainerStatus: Decodable {
    let ready: Bool
    let restartCount: Int
}

private struct KubeDaemonSetList: Decodable { let items: [KubeDaemonSetItem] }
private struct KubeDaemonSetItem: Decodable {
    let status: KubeDSStatus?
}
private struct KubeDSStatus: Decodable {
    let desiredNumberScheduled: Int?
    let currentNumberScheduled: Int?
    let numberReady: Int?
    let numberAvailable: Int?
}

private struct KubeDeploymentList: Decodable { let items: [KubeDeploymentItem] }
private struct KubeDeploymentItem: Decodable {
    let spec: KubeDeploySpec?
    let status: KubeDeployStatus?
}
private struct KubeDeploySpec: Decodable { let replicas: Int? }
private struct KubeDeployStatus: Decodable {
    let replicas: Int?
    let readyReplicas: Int?
}

private struct KubeCalicoPolicyList: Decodable { let items: [KubeCalicoPolicyItem] }
private struct KubeCalicoPolicyItem: Decodable {
    let metadata: KubeMeta
    let spec: KubeCalicoSpec?
}
private struct KubeCalicoSpec: Decodable {
    let ingress: [KubeCalicoRule]?
    let egress: [KubeCalicoRule]?

    var hasDenyAction: Bool {
        let rules = (ingress ?? []) + (egress ?? [])
        return rules.contains { $0.action?.lowercased() == "deny" }
    }
}
private struct KubeCalicoRule: Decodable { let action: String? }

private struct KubeMeta: Decodable {
    let name: String
    let namespace: String?
    let creationTimestamp: String?
    let labels: [String: String]?
    let annotations: [String: String]?
}
