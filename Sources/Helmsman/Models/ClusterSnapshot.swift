// ClusterSnapshot.swift — Gardicol Connector
// Parsed cluster state for the Cluster View panel.

import Foundation
import SwiftUI

// MARK: - Health

enum ClusterHealthStatus: String, CaseIterable {
    case healthy           = "Healthy"
    case degraded          = "Degraded"
    case policySyncPending = "Policy Sync Pending"
    case agentProblem      = "Agent Problem"
    case cniProblem        = "CNI Problem"

    var color: Color {
        switch self {
        case .healthy:           return AppTheme.semantic.success
        case .degraded:          return AppTheme.semantic.warning
        case .policySyncPending: return AppTheme.semantic.warning
        case .agentProblem:      return AppTheme.semantic.error
        case .cniProblem:        return AppTheme.semantic.error
        }
    }

    var icon: String {
        switch self {
        case .healthy:           return "checkmark.circle.fill"
        case .degraded:          return "exclamationmark.triangle.fill"
        case .policySyncPending: return "arrow.triangle.2.circlepath"
        case .agentProblem:      return "shield.slash.fill"
        case .cniProblem:        return "network.slash"
        }
    }

    var description: String {
        switch self {
        case .healthy:
            return "All nodes ready, agents running, policies synced."
        case .degraded:
            return "One or more nodes are not ready or data could not be fetched. Check Raw tab for details."
        case .policySyncPending:
            return "Agent policy revision does not match the Calico CRD revision. Rules may not yet be enforced at the dataplane."
        case .agentProblem:
            return "One or more Guardicore agents are not running, gc-kube-enforce is down, or gc-kube-inventory is down."
        case .cniProblem:
            return "Block rules exist but are missing 'action: Deny' in Calico CRDs. Traffic may not be blocked."
        }
    }
}

// MARK: - Snapshot

struct ClusterSnapshot {
    var fetchedAt: Date
    var version: String?
    var nodes: [ClusterNode]
    var pods: [ClusterPod]
    var guardicore: GuardicoreSnapshot
    var policies: PolicySnapshot
    var raw: RawClusterOutputs
    var warnings: [String]

    var health: ClusterHealthStatus { ClusterSnapshot.computeHealth(self) }

    var nodesReady: Int { nodes.filter(\.isReady).count }
    var healthyPodCount: Int { pods.filter(\.isHealthyForOverview).count }
    var unhealthyPodCount: Int {
        pods.filter(\.isProblemForOverview).count
    }
    var podStatusBreakdown: [(status: String, count: Int)] {
        let grouped = Dictionary(grouping: pods, by: { $0.status.isEmpty ? "Unknown" : $0.status })
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.status < rhs.status }
                return lhs.count > rhs.count
            }
    }
    var healthFindings: [String] { ClusterSnapshot.computeHealthFindings(self) }

    var revisionAlignment: RevisionAlignment { KubeJSONParser.revisionAlignment(from: self) }

    var blockRulesWithDeny: Int { policies.calicoPolicies.filter { $0.isBlock && $0.hasDeny }.count }
    var blockRulesMissingDeny: Int { policies.calicoPolicies.filter { $0.isBlock && !$0.hasDeny }.count }

    static func computeHealth(_ s: ClusterSnapshot) -> ClusterHealthStatus {
        if s.nodes.isEmpty { return .degraded }

        let coreFetchFailed = s.warnings.contains { warning in
            warning.contains("kubectl get nodes -o json") ||
                warning.contains("kubectl get pods -A -o json") ||
                warning.contains("kubectl get pods -n guardicore -o json")
        }
        if coreFetchFailed { return .degraded }

        if s.nodes.contains(where: { !$0.isReady }) { return .degraded }

        let ds = s.guardicore
        if let desired = ds.daemonSetDesired, let ready = ds.daemonSetReady, ready < desired {
            return .agentProblem
        }
        if ds.agents.contains(where: { $0.status.lowercased() != "running" }) {
            return .agentProblem
        }
        if let ke = ds.kubeEnforceReady?.lowercased(), !ke.contains("running") && ke != "1/1" {
            return .agentProblem
        }
        if let inv = ds.kubeInventoryReady?.lowercased(), !inv.hasPrefix("1/1"), inv != "1/1" {
            return .agentProblem
        }
        if ds.inventoryPods.contains(where: { $0.status.lowercased() != "running" }) {
            return .agentProblem
        }

        let blockWithoutDeny = s.policies.calicoPolicies.filter {
            $0.isBlock && !$0.hasDeny
        }
        if !blockWithoutDeny.isEmpty { return .cniProblem }

        if !s.revisionAlignment.isAligned && s.revisionAlignment.agentRevision != nil {
            return .policySyncPending
        }

        if s.unhealthyPodCount > 0 { return .degraded }
        return .healthy
    }

    static func computeHealthFindings(_ s: ClusterSnapshot) -> [String] {
        var findings: [String] = []

        if s.nodes.isEmpty {
            findings.append("No nodes were parsed from kubectl output.")
        }

        let notReadyNodes = s.nodes.filter { !$0.isReady }
        if !notReadyNodes.isEmpty {
            findings.append("\(notReadyNodes.count) node(s) are not Ready: \(notReadyNodes.map(\.name).prefix(3).joined(separator: ", "))")
        }

        let ds = s.guardicore
        if let desired = ds.daemonSetDesired, let ready = ds.daemonSetReady, ready < desired {
            findings.append("Guardicore DaemonSet is not fully ready: \(ready)/\(desired) agents ready.")
        }
        let badAgents = ds.agents.filter { $0.status.lowercased() != "running" }
        if !badAgents.isEmpty {
            findings.append("\(badAgents.count) Guardicore agent pod(s) are not Running.")
        }
        if let ke = ds.kubeEnforceReady?.lowercased(), !ke.contains("running") && ke != "1/1" {
            findings.append("gc-kube-enforce is not ready: \(ds.kubeEnforceReady ?? "unknown").")
        }
        if let inv = ds.kubeInventoryReady?.lowercased(), !inv.hasPrefix("1/1"), inv != "1/1" {
            findings.append("gc-kube-inventory is not ready: \(ds.kubeInventoryReady ?? "unknown").")
        }
        let badInventory = ds.inventoryPods.filter { $0.status.lowercased() != "running" }
        if !badInventory.isEmpty {
            findings.append("\(badInventory.count) gc-kube-inventory pod(s) are not Running.")
        }

        if s.blockRulesMissingDeny > 0 {
            findings.append("\(s.blockRulesMissingDeny) block policy rule(s) are missing Calico action: Deny.")
        }

        let alignment = s.revisionAlignment
        if !alignment.isAligned {
            if alignment.agentRevision == nil {
                findings.append("Agent policy revision is unknown. Check agent policy revision log collection.")
            }
            if alignment.calicoRevision == nil {
                findings.append("Calico CRD policy revision is unknown. Check Calico CRD fetch/parsing.")
            }
            if let agent = alignment.agentRevision, let calico = alignment.calicoRevision, agent != calico {
                findings.append("Policy sync is pending: agent revision \(agent) does not match Calico revision \(calico).")
            }
        }

        let problemPods = s.pods.filter(\.isProblemForOverview)
        if !problemPods.isEmpty {
            let breakdown = Dictionary(grouping: problemPods, by: \.status)
                .map { "\($0.key): \($0.value.count)" }
                .sorted()
                .joined(separator: ", ")
            findings.append("Problem pod statuses: \(breakdown).")
        }

        findings.append(contentsOf: s.warnings.prefix(3))
        return Array(NSOrderedSet(array: findings)) as? [String] ?? findings
    }
}

// MARK: - Node / Pod

struct ClusterNode: Identifiable, Hashable, Codable {
    var id: String { name }
    var name: String
    var role: String
    var internalIP: String
    var status: String
    var age: String
    var version: String?
    var osImage: String?

    var isReady: Bool { status == "Ready" }
    var isControlPlane: Bool {
        let r = role.lowercased()
        return r.contains("control-plane") || r.contains("controlplane") || r.contains("master") || r.contains("etcd")
    }
    var roleShort: String { isControlPlane ? "control-plane" : "worker" }
}

struct ClusterPod: Identifiable, Hashable, Codable {
    var id: String { "\(namespace)/\(name)" }
    var namespace: String
    var name: String
    var ready: String
    var status: String
    var restarts: Int
    var age: String
    var ip: String
    var node: String

    var isGC: Bool { namespace == "guardicore" }
    var isSystem: Bool { namespace == "kube-system" }
    var isDaemonSetAgent: Bool { isGC && name.contains("gc-agents-daemonset") }
    var isKubeEnforce: Bool { isGC && name.contains("gc-kube-enforce") }
    var isKubeInventory: Bool { isGC && name.hasPrefix("gc-kube-inventory") }

    var isFullyReady: Bool {
        let p = ready.split(separator: "/")
        return p.count == 2 && p[0] == p[1]
    }

    var isHealthyForOverview: Bool {
        let s = status.lowercased()
        if s == "completed" || s == "succeeded" { return true }
        return s == "running" && isFullyReady
    }

    var isTransientForOverview: Bool {
        let s = status.lowercased()
        return s.hasPrefix("init:") ||
            s == "containercreating" ||
            s == "podinitializing" ||
            s == "terminating"
    }

    var isProblemForOverview: Bool {
        !isHealthyForOverview && !isTransientForOverview
    }

    var statusColor: Color {
        let s = status.lowercased()
        if s == "running" && isFullyReady { return AppTheme.semantic.success }
        if s.contains("crash") || s.contains("error") { return AppTheme.semantic.error }
        if s == "completed" || s == "succeeded" { return AppTheme.accent.secondary }
        if s == "pending" || s.hasPrefix("init:") || s == "containercreating" { return AppTheme.semantic.warning }
        if s == "terminating" { return AppTheme.text.muted }
        return AppTheme.semantic.warning
    }
}

// MARK: - Guardicore

struct GuardicoreSnapshot {
    var daemonSetDesired: Int?
    var daemonSetCurrent: Int?
    var daemonSetReady: Int?
    var daemonSetAvailable: Int?
    var kubeEnforceReady: String?
    var kubeEnforceNode: String?
    var kubeInventoryReady: String?
    var inventoryPods: [GuardicoreInventoryPod]
    var agents: [GuardicoreAgent]
    var eventsTail: String
    var kubeEnforceLogTail: String
    var kubeInventoryLogTail: String
}

struct GuardicoreInventoryPod: Identifiable, Hashable, Codable {
    var id: String { podName }
    var podName: String
    var node: String
    var ip: String
    var status: String
    var restarts: Int
    var ready: String
}

struct GuardicoreAgent: Identifiable, Hashable, Codable {
    var id: String { podName }
    var podName: String
    var node: String
    var ip: String
    var status: String
    var restarts: Int
    var policyRevision: Int?
    var dcInventoryRevision: String?
    var lastPolicyReceived: String?
}

// MARK: - Policies

struct PolicySnapshot {
    var standardNetworkPoliciesRaw: String
    var calicoPolicies: [CalicoPolicy]
    var revisions: Set<String>

    var revisionAligned: Bool {
        let agentRevs = Set(calicoPolicies.compactMap(\.policyRevision).map(String.init))
        let calicoRevs = revisions.compactMap { line -> String? in
            guard line.contains("guardicore/policy-revision") else { return nil }
            return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
        }
        if agentRevs.isEmpty || calicoRevs.isEmpty { return true }
        return agentRevs.count == 1 && calicoRevs.count <= 1
            && agentRevs.first.map { calicoRevs.contains($0) } == true
    }
}

struct CalicoPolicy: Identifiable, Hashable, Codable {
    var id: String { "\(namespace)/\(name)" }
    var namespace: String
    var name: String
    var action: String
    var ruleUUID: String?
    var shortRuleID: String?
    var direction: String?
    var hasDeny: Bool
    var policyRevision: Int?
    var dcInventoryRevision: String?
    var sourceNamespace: String?
    var destinationNamespace: String?

    var isBlock: Bool { name.lowercased().contains("-block-") || action.lowercased() == "block" }
    var isAllow: Bool { name.lowercased().contains("-allow-") || action.lowercased() == "allow" }
    var dataplaneProven: Bool { !isBlock || hasDeny }
}

// MARK: - Raw outputs

struct RawClusterOutputs {
    var version: String = ""
    var nodesJSON: String = ""
    var podsJSON: String = ""
    var guardicorePodsJSON: String = ""
    var daemonSetJSON: String = ""
    var deploymentsJSON: String = ""
    var statefulSetsJSON: String = ""
    var calicoPoliciesJSON: String = ""
    var nodesWide: String = ""
    var nodesLabels: String = ""
    var podsAllWide: String = ""
    var guardicorePodsWide: String = ""
    var daemonSet: String = ""
    var deployments: String = ""
    var events: String = ""
    var kubeEnforceLogs: String = ""
    var kubeInventoryLogs: String = ""
    var standardNetworkPolicies: String = ""
    var calicoPoliciesList: String = ""
    var calicoRevisionGrep: String = ""
    var agentPolicyRevisionLogs: String = ""

    func value(for key: String) -> String {
        switch key {
        case "version": return version
        case "nodesJSON": return nodesJSON
        case "podsJSON": return podsJSON
        case "guardicorePodsJSON": return guardicorePodsJSON
        case "daemonSetJSON": return daemonSetJSON
        case "deploymentsJSON": return deploymentsJSON
        case "statefulSetsJSON": return statefulSetsJSON
        case "calicoPoliciesJSON": return calicoPoliciesJSON
        case "nodesWide": return nodesWide
        case "nodesLabels": return nodesLabels
        case "podsAllWide": return podsAllWide
        case "guardicorePodsWide": return guardicorePodsWide
        case "daemonSet": return daemonSet
        case "deployments": return deployments
        case "events": return events
        case "kubeEnforceLogs": return kubeEnforceLogs
        case "kubeInventoryLogs": return kubeInventoryLogs
        case "standardNetworkPolicies": return standardNetworkPolicies
        case "calicoPoliciesList": return calicoPoliciesList
        case "calicoRevisionGrep": return calicoRevisionGrep
        case "agentPolicyRevisionLogs": return agentPolicyRevisionLogs
        default: return ""
        }
    }

    static let displayKeys: [(key: String, label: String)] = [
        ("version", "kubectl version"),
        ("nodesJSON", "kubectl get nodes -o json"),
        ("podsJSON", "kubectl get pods -A -o json"),
        ("guardicorePodsJSON", "kubectl get pods -n guardicore -o json"),
        ("daemonSetJSON", "kubectl get ds -n guardicore -o json"),
        ("deploymentsJSON", "kubectl get deploy -n guardicore -o json"),
        ("statefulSetsJSON", "kubectl get sts -n guardicore -o json"),
        ("calicoPoliciesJSON", "Calico CRDs -o json"),
        ("nodesWide", "kubectl get nodes -o wide (fallback)"),
        ("agentPolicyRevisionLogs", "Agent policy revision logs"),
        ("events", "kubectl get events -n guardicore"),
        ("kubeEnforceLogs", "gc-kube-enforce logs"),
        ("kubeInventoryLogs", "gc-kube-inventory logs"),
        ("standardNetworkPolicies", "networkpolicies.networking.k8s.io"),
        ("calicoPoliciesList", "networkpolicies.crd.projectcalico.org (text)"),
        ("calicoRevisionGrep", "Calico revision annotations (text)"),
    ]
}

// MARK: - Parsers

enum ClusterSnapshotParser {

    static func parseVersion(_ output: String) -> String? {
        let line = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.contains("Server Version") || $0.contains("GitVersion") || $0.hasPrefix("v") }
        return line?.isEmpty == false ? line : nil
    }

    static func parseNodesWide(_ output: String) -> [ClusterNode] {
        let lines = kubectlTableLines(output, headerPrefix: "NAME")
        return lines.compactMap { cols in
            guard cols.count >= 6 else { return nil }
            return ClusterNode(
                name: cols[0],
                role: cols[2],
                internalIP: cols[5],
                status: cols[1],
                age: cols[3],
                version: cols.count > 4 ? cols[4] : nil,
                osImage: cols.count > 7 ? cols[7] : nil
            )
        }
    }

    static func parsePodsWide(_ output: String) -> [ClusterPod] {
        let lines = kubectlTableLines(output, headerPrefix: "NAMESPACE")
        return lines.compactMap { cols in
            guard cols.count >= 8 else { return nil }
            let restarts = Int(cols[4].components(separatedBy: " ").first ?? "0") ?? 0
            return ClusterPod(
                namespace: cols[0],
                name: cols[1],
                ready: cols[2],
                status: cols[3],
                restarts: restarts,
                age: cols[5],
                ip: cols[6],
                node: cols[7]
            )
        }
    }

    static func parseDaemonSet(_ output: String) -> (desired: Int?, current: Int?, ready: Int?, available: Int?) {
        let lines = kubectlTableLines(output, headerPrefix: "NAME")
        guard let cols = lines.first, cols.count >= 5 else { return (nil, nil, nil, nil) }
        func int(_ s: String) -> Int? { Int(s) }
        return (int(cols[1]), int(cols[2]), int(cols[3]), cols.count > 4 ? int(cols[4]) : nil)
    }

    static func parseDeploymentReady(_ output: String) -> String? {
        let lines = kubectlTableLines(output, headerPrefix: "NAME")
        guard let cols = lines.first, cols.count >= 2 else { return nil }
        return cols[1]
    }

    static func parseGuardicoreAgents(
        pods: [ClusterPod],
        revisionLogs: String
    ) -> [GuardicoreAgent] {
        let revisions = parseAgentRevisionLogs(revisionLogs)
        return pods.filter(\.isDaemonSetAgent).map { pod in
            let rev = revisions[pod.name]
            return GuardicoreAgent(
                podName: pod.name,
                node: pod.node,
                ip: pod.ip,
                status: pod.status,
                restarts: pod.restarts,
                policyRevision: rev?.policyRevision,
                dcInventoryRevision: rev?.dcInventory,
                lastPolicyReceived: rev?.lastLine
            )
        }
    }

    static func parseGuardicoreInventoryPods(pods: [ClusterPod]) -> [GuardicoreInventoryPod] {
        pods.filter(\.isKubeInventory).map { pod in
            GuardicoreInventoryPod(
                podName: pod.name,
                node: pod.node,
                ip: pod.ip,
                status: pod.status,
                restarts: pod.restarts,
                ready: pod.ready
            )
        }
    }

    static func parseCalicoPoliciesList(_ output: String) -> [CalicoPolicy] {
        kubectlTableLines(output, headerPrefix: "NAMESPACE").compactMap { cols in
            guard cols.count >= 2 else { return nil }
            let name = cols[1]
            return CalicoPolicy(
                namespace: cols[0],
                name: name,
                action: name.lowercased().contains("-block-") ? "Block" : "Allow",
                ruleUUID: extractRuleUUID(from: name),
                shortRuleID: extractRuleUUID(from: name).map { "RUL-\($0.uppercased())" },
                direction: name.contains("--ingress") ? "ingress" : name.contains("--egress") ? "egress" : nil,
                hasDeny: name.lowercased().contains("-block-"),
                policyRevision: nil,
                dcInventoryRevision: nil,
                sourceNamespace: nil,
                destinationNamespace: nil
            )
        }
    }

    static func enrichCalicoRevisions(_ policies: [CalicoPolicy], yamlGrep: String) -> [CalicoPolicy] {
        var revByName: [String: (policy: Int?, dc: String?)] = [:]
        var currentName: String?
        for line in yamlGrep.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("name:") {
                currentName = t.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
            } else if t.contains("guardicore/policy-revision"), let n = currentName {
                let val = t.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                var entry = revByName[n] ?? (nil, nil)
                entry.policy = val.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
                revByName[n] = entry
            } else if t.contains("guardicore/dc-inventory-revision"), let n = currentName {
                let val = t.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                var entry = revByName[n] ?? (nil, nil)
                entry.dc = val.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
                revByName[n] = entry
            }
        }
        return policies.map { p in
            var copy = p
            if let r = revByName[p.name] {
                if let enrichedPolicy = r.policy,
                   copy.policyRevision == nil || copy.policyRevision == 0 || enrichedPolicy > (copy.policyRevision ?? 0) {
                    copy.policyRevision = enrichedPolicy
                }
                copy.dcInventoryRevision = copy.dcInventoryRevision ?? r.dc
            }
            return copy
        }
    }

    static func parseRevisionGrep(_ output: String) -> Set<String> {
        Set(output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    // MARK: Private helpers

    private static func kubectlTableLines(_ output: String, headerPrefix: String) -> [[String]] {
        let lines = output.components(separatedBy: .newlines)
        guard let headerIdx = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix(headerPrefix)
        }) else { return [] }

        return lines.dropFirst(headerIdx + 1).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let cols = trimmed.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
            return cols.isEmpty ? nil : cols
        }
    }

    private static func extractRuleUUID(from name: String) -> String? {
        let parts = name.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let candidate = String(parts[1])
        if candidate.count >= 8 { return String(candidate.prefix(8)) }
        return candidate.isEmpty ? nil : candidate
    }

    private struct AgentRevEntry {
        var policyRevision: Int?
        var dcInventory: String?
        var lastLine: String?
    }

    private static func parseAgentRevisionLogs(_ output: String) -> [String: AgentRevEntry] {
        var result: [String: AgentRevEntry] = [:]
        var currentPod: String?
        for line in output.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("=== pod/") || t.hasPrefix("=== gc-") {
                if t.hasPrefix("=== ") {
                    // Echo format: "=== pod/gc-agents-daemonset-xxxx ===" — strip leading "=== ",
                    // "pod/" prefix, trailing " ===" marker, and any leftover whitespace.
                    currentPod = t.replacingOccurrences(of: "=== ", with: "")
                        .replacingOccurrences(of: "pod/", with: "")
                        .replacingOccurrences(of: " ===", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            guard let pod = currentPod, !t.isEmpty else { continue }
            var entry = result[pod] ?? AgentRevEntry()
            entry.lastLine = t
            if t.lowercased().contains("dc-inventory") || t.lowercased().contains("inventory revision") {
                let num = t.split(whereSeparator: { !$0.isNumber && $0 != "." }).last.map(String.init)
                entry.dcInventory = num
            } else if let range = t.range(of: "Policy revision", options: .caseInsensitive) ?? t.range(of: "revision", options: .caseInsensitive) {
                let tail = t[range.upperBound...]
                let num = tail.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.first
                if let n = num, n > 0 || entry.policyRevision == nil {
                    entry.policyRevision = n
                }
            }
            result[pod] = entry
        }
        return result
    }
}
