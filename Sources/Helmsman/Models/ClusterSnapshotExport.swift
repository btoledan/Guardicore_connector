// ClusterSnapshotExport.swift — Markdown and JSON export for cluster snapshots

import Foundation

enum ClusterSnapshotExport {

    static func json(_ snapshot: ClusterSnapshot?) -> String {
        guard let snapshot else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        struct Export: Encodable {
            let fetchedAt: Date
            let health: String
            let version: String?
            let nodesReady: Int
            let nodeTotal: Int
            let unhealthyPods: Int
            let guardicoreAgentsReady: Int
            let guardicoreAgentsDesired: Int?
            let calicoPolicies: Int
            let blockWithDeny: Int
            let blockMissingDeny: Int
            let revisionAligned: Bool
            let agentRevision: Int?
            let calicoRevision: Int?
            let warnings: [String]
            let nodes: [ClusterNode]
            let agents: [GuardicoreAgent]
            let policies: [CalicoPolicy]
        }

        let alignment = snapshot.revisionAlignment
        let export = Export(
            fetchedAt: snapshot.fetchedAt,
            health: snapshot.health.rawValue,
            version: snapshot.version,
            nodesReady: snapshot.nodesReady,
            nodeTotal: snapshot.nodes.count,
            unhealthyPods: snapshot.unhealthyPodCount,
            guardicoreAgentsReady: snapshot.guardicore.agents.filter { $0.status.lowercased() == "running" }.count,
            guardicoreAgentsDesired: snapshot.guardicore.daemonSetDesired,
            calicoPolicies: snapshot.policies.calicoPolicies.count,
            blockWithDeny: snapshot.blockRulesWithDeny,
            blockMissingDeny: snapshot.blockRulesMissingDeny,
            revisionAligned: alignment.isAligned,
            agentRevision: alignment.agentRevision,
            calicoRevision: alignment.calicoRevision,
            warnings: snapshot.warnings,
            nodes: snapshot.nodes,
            agents: snapshot.guardicore.agents,
            policies: snapshot.policies.calicoPolicies
        )

        guard let data = try? encoder.encode(export),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    static func markdown(_ snapshot: ClusterSnapshot?) -> String {
        guard let s = snapshot else { return "# Cluster Snapshot\n\n(no data)" }
        let align = s.revisionAlignment
        var md = """
        # Guardicore Cluster Snapshot

        **Fetched:** \(s.fetchedAt.formatted())
        **Health:** \(s.health.rawValue)
        **Kubernetes:** \(s.version ?? "unknown")

        ## Summary

        | Metric | Value |
        |--------|-------|
        | Nodes ready | \(s.nodesReady)/\(s.nodes.count) |
        | GC agents ready | \(s.guardicore.daemonSetReady.map(String.init) ?? "?")/\(s.guardicore.daemonSetDesired.map(String.init) ?? "?") |
        | gc-kube-enforce | \(s.guardicore.kubeEnforceReady ?? "—") |
        | Unhealthy pods | \(s.unhealthyPodCount) |
        | Calico CRDs | \(s.policies.calicoPolicies.count) |
        | Block + Deny | \(s.blockRulesWithDeny) |
        | Block missing Deny | \(s.blockRulesMissingDeny) |
        | Revision aligned | \(align.isAligned ? "YES" : "NO") |

        ## Revision Chain

        """
        for step in align.steps {
            md += "- **\(step.label):** \(step.value)\n"
        }
        md += """

        ## Nodes

        | Node | Role | IP | Status |
        |------|------|----|--------|
        """
        for n in s.nodes {
            md += "\n| \(n.name) | \(n.roleShort) | \(n.internalIP) | \(n.status) |"
        }

        md += "\n\n## Guardicore Agents\n\n"
        md += "| Pod | Node | Status | Restarts | Policy Rev | DC Inv Rev |\n"
        md += "|-----|------|--------|----------|------------|------------|\n"
        for a in s.guardicore.agents {
            md += "| \(a.podName) | \(a.node) | \(a.status) | \(a.restarts) | \(a.policyRevision.map(String.init) ?? "—") | \(a.dcInventoryRevision ?? "—") |\n"
        }

        md += "\n## Calico Policies\n\n"
        md += "| Rule ID | Action | Namespace | CRD Name | Deny | Rev |\n"
        md += "|---------|--------|-----------|----------|------|-----|\n"
        for p in s.policies.calicoPolicies {
            md += "| \(p.shortRuleID ?? p.ruleUUID ?? "—") | \(p.action) | \(p.namespace) | \(p.name) | \(p.hasDeny ? "yes" : "no") | \(p.policyRevision.map(String.init) ?? "—") |\n"
        }

        if !s.warnings.isEmpty {
            md += "\n## Warnings\n\n"
            for w in s.warnings { md += "- \(w)\n" }
        }

        return md
    }
}
