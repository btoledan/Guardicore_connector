// ClusterOverviewView.swift — Cluster command-center dashboard
// Redesigned May 2026: health banner, metric blocks, GC section, revision chain, quick actions

import SwiftUI
import TerminalKit

struct ClusterOverviewView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {

                // ── Health banner ─────────────────────────────────
                HealthBanner(
                    status: snapshot.health,
                    findings: snapshot.healthFindings,
                    warnings: snapshot.warnings
                )

                // ── Key metrics row ───────────────────────────────
                HStack(spacing: 8) {
                    MetricBlock(
                        icon: "server.rack",
                        label: "Nodes",
                        value: "\(snapshot.nodesReady)/\(snapshot.nodes.count)",
                        subtitle: "ready",
                        color: snapshot.nodesReady == snapshot.nodes.count ? .green : .red
                    )
                    MetricBlock(
                        icon: "shield.lefthalf.filled",
                        label: "GC Agents",
                        value: agentValue,
                        subtitle: agentSubtitle,
                        color: agentColor
                    )
                    MetricBlock(
                        icon: snapshot.unhealthyPodCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        label: "Problem Pods",
                        value: snapshot.unhealthyPodCount == 0 ? "All OK" : "\(snapshot.unhealthyPodCount)",
                        subtitle: "\(snapshot.healthyPodCount)/\(snapshot.pods.count) healthy",
                        color: snapshot.unhealthyPodCount == 0 ? .green : .orange
                    )
                }

                PodStatusBreakdownCard(snapshot: snapshot)

                // ── Guardicore section ────────────────────────────
                GuardicoreSectionCard(snapshot: snapshot, session: session)

                // ── Revision chain ────────────────────────────────
                RevisionChainCard(alignment: snapshot.revisionAlignment)

                // ── Policy health ─────────────────────────────────
                if !snapshot.policies.calicoPolicies.isEmpty {
                    PolicyHealthCard(snapshot: snapshot)
                }

                // ── Quick actions ─────────────────────────────────
                QuickActionsCard(snapshot: snapshot, session: session)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    // MARK: Computed helpers

    private var agentValue: String {
        let ds = snapshot.guardicore
        if let r = ds.daemonSetReady, let d = ds.daemonSetDesired { return "\(r)/\(d)" }
        return "\(snapshot.guardicore.agents.count)"
    }
    private var agentSubtitle: String {
        let ds = snapshot.guardicore
        if let r = ds.daemonSetReady, let d = ds.daemonSetDesired {
            return r == d ? "all ready" : "\(d - r) missing"
        }
        return "agents"
    }
    private var agentColor: Color {
        let ds = snapshot.guardicore
        if let r = ds.daemonSetReady, let d = ds.daemonSetDesired, r < d { return .red }
        return snapshot.guardicore.agents.isEmpty ? .orange : .green
    }
}

// MARK: - Health banner

private struct HealthBanner: View {
    let status: ClusterHealthStatus
    let findings: [String]
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: status.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(status.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cluster Status")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(status.rawValue)
                        .font(.system(.body, design: .rounded).weight(.bold))
                        .foregroundColor(status.color)
                    Text(status.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }
                Spacer()
            }

            if !findings.isEmpty {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: 3) {
                    Text("What needs attention")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(findings.prefix(5), id: \.self) { finding in
                        HStack(spacing: 5) {
                            Image(systemName: findingIcon(finding))
                                .font(.caption2)
                                .foregroundColor(status.color)
                            Text(finding)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.color.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(status.color.opacity(0.35), lineWidth: 1.5)
        )
        .cornerRadius(10)
    }

    private func findingIcon(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("revision") || lower.contains("sync") { return "arrow.triangle.2.circlepath" }
        if lower.contains("pod") { return "shippingbox" }
        if lower.contains("agent") || lower.contains("guardicore") { return "shield" }
        return "exclamationmark.circle"
    }
}

// MARK: - Metric block

private struct MetricBlock: View {
    let icon: String
    let label: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Pod status breakdown

private struct PodStatusBreakdownCard: View {
    let snapshot: ClusterSnapshot

    private struct ProblemPodGroup: Identifiable {
        var status: String
        var namespace: String
        var pods: [ClusterPod]
        var id: String { "\(status)/\(namespace)" }
    }

    private var visibleBreakdown: [(status: String, count: Int)] {
        Array(snapshot.podStatusBreakdown.prefix(6))
    }
    private var problemGroups: [ProblemPodGroup] {
        let groups = Dictionary(grouping: snapshot.pods.filter(\.isProblemForOverview)) {
            "\($0.status)|\($0.namespace)"
        }
        return groups.compactMap { key, pods in
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return ProblemPodGroup(status: parts[0], namespace: parts[1], pods: pods.sorted { $0.name < $1.name })
        }
        .sorted { lhs, rhs in
            if lhs.pods.count == rhs.pods.count { return lhs.namespace < rhs.namespace }
            return lhs.pods.count > rhs.pods.count
        }
    }

    var body: some View {
        SectionCard(title: "Pod Status Breakdown", icon: "square.grid.3x3") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("\(snapshot.healthyPodCount)")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(.green)
                    Text("healthy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("\(snapshot.unhealthyPodCount)")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundColor(snapshot.unhealthyPodCount == 0 ? .green : .orange)
                    Text("need attention")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                ForEach(visibleBreakdown, id: \.status) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color(for: item.status))
                            .frame(width: 7, height: 7)
                        Text(item.status)
                            .font(.caption2)
                            .foregroundColor(.primary)
                        GeometryReader { proxy in
                            let width = max(2, proxy.size.width * CGFloat(item.count) / CGFloat(max(snapshot.pods.count, 1)))
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.08))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color(for: item.status).opacity(0.45))
                                    .frame(width: width)
                            }
                        }
                        .frame(height: 7)
                        Text("\(item.count)")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }

                if !problemGroups.isEmpty {
                    Divider().opacity(0.35)
                    Text("Which pods are counted")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)

                    ForEach(problemGroups.prefix(5)) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(color(for: group.status))
                                    .frame(width: 6, height: 6)
                                Text("\(group.status) in \(group.namespace)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(group.pods.count)")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                            }
                            Text(group.pods.prefix(4).map(\.name).joined(separator: ", "))
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            if group.pods.count > 4 {
                                Text("+ \(group.pods.count - 4) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func color(for status: String) -> Color {
        let s = status.lowercased()
        if s == "running" || s == "completed" || s == "succeeded" { return .green }
        if s.contains("crash") || s.contains("error") || s == "failed" { return .red }
        if s == "pending" || s.hasPrefix("init:") || s == "containercreating" { return .orange }
        return .secondary
    }
}

// MARK: - Guardicore section card

private struct GuardicoreSectionCard: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    private var ds: GuardicoreSnapshot { snapshot.guardicore }
    private var enforceColor: Color {
        guard let k = ds.kubeEnforceReady?.lowercased() else { return .secondary }
        return k.contains("1/1") || k.contains("running") ? .green : .orange
    }

    var body: some View {
        SectionCard(title: "Guardicore", icon: "shield.checkered") {
            VStack(spacing: 0) {
                // DaemonSet row
                CheckRow(
                    label: "gc-agents-daemonset",
                    value: daemonSetValue,
                    ok: daemonSetOK,
                    action: { session.run("kubectl get ds -n guardicore") }
                )
                Divider().padding(.leading, 10).opacity(0.3)
                // gc-kube-enforce row
                CheckRow(
                    label: "gc-kube-enforce",
                    value: ds.kubeEnforceReady ?? "—",
                    ok: enforceColor == .green,
                    action: { session.run("kubectl get deploy -n guardicore") }
                )
                // Agent policy revisions
                if !ds.agents.isEmpty {
                    Divider().padding(.leading, 10).opacity(0.3)
                    AgentRevRow(agents: ds.agents)
                }
            }
        }
    }

    private var daemonSetValue: String {
        if let r = ds.daemonSetReady, let d = ds.daemonSetDesired { return "\(r)/\(d) ready" }
        return "\(ds.agents.count) agents"
    }
    private var daemonSetOK: Bool {
        if let r = ds.daemonSetReady, let d = ds.daemonSetDesired { return r == d }
        return !ds.agents.isEmpty
    }
}

private struct AgentRevRow: View {
    let agents: [GuardicoreAgent]
    private var revisions: [Int] { agents.compactMap(\.policyRevision) }
    private var aligned: Bool { Set(revisions).count <= 1 }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: aligned ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(aligned ? .green : .orange)
            Text("Policy revisions")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            if revisions.isEmpty {
                Text("unknown")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            } else if aligned {
                Text("rev \(revisions[0])")
                    .font(.caption2.monospaced())
                    .foregroundColor(.green)
            } else {
                Text("mixed: \(Set(revisions).sorted().map(String.init).joined(separator: ", "))")
                    .font(.caption2.monospaced())
                    .foregroundColor(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

// MARK: - Revision chain card

private struct RevisionChainCard: View {
    let alignment: RevisionAlignment

    var body: some View {
        SectionCard(title: "Revision Chain", icon: "arrow.triangle.2.circlepath") {
            VStack(spacing: 0) {
                // Visual chain: CM → agent → Calico
                HStack(spacing: 0) {
                    ChainNode(
                        label: "CM publish",
                        value: "source",
                        status: .ok
                    )
                    ChainArrow()
                    ChainNode(
                        label: "Agent rev",
                        value: alignment.agentRevision.map(String.init) ?? "—",
                        status: alignment.agentRevision != nil ? .ok : .unknown
                    )
                    ChainArrow()
                    ChainNode(
                        label: "Calico CRD",
                        value: alignment.calicoRevision.map(String.init) ?? "—",
                        status: alignment.calicoRevision != nil
                            ? (alignment.isAligned ? .ok : .warning)
                            : .unknown
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                if !alignment.steps.isEmpty {
                    Divider().padding(.leading, 10).opacity(0.3)
                    ForEach(alignment.steps) { step in
                        CheckRow(
                            label: step.label,
                            value: step.value,
                            ok: step.status == .ok,
                            unknown: step.status == .unknown,
                            action: nil
                        )
                        if step.id != alignment.steps.last?.id {
                            Divider().padding(.leading, 10).opacity(0.3)
                        }
                    }
                }
            }
        }
    }
}

private struct ChainNode: View {
    let label: String
    let value: String
    let status: RevisionChainStep.Status

    private var color: Color {
        switch status {
        case .ok:      return .green
        case .warning: return .orange
        case .error:   return .red
        case .unknown: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: status.symbol)
                    .font(.caption2)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ChainArrow: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.caption2)
            .foregroundColor(Color.secondary.opacity(0.4))
            .padding(.bottom, 18)
    }
}

// MARK: - Policy health card

private struct PolicyHealthCard: View {
    let snapshot: ClusterSnapshot

    private var blockPolicies: [CalicoPolicy] { snapshot.policies.calicoPolicies.filter(\.isBlock) }
    private var missingDeny: [CalicoPolicy]   { blockPolicies.filter { !$0.hasDeny } }

    var body: some View {
        SectionCard(title: "Policy Health", icon: "checkmark.shield") {
            VStack(spacing: 0) {
                CheckRow(
                    label: "Block rules",
                    value: "\(blockPolicies.count) total",
                    ok: true,
                    action: nil
                )
                Divider().padding(.leading, 10).opacity(0.3)
                CheckRow(
                    label: "Block rules with Deny",
                    value: "\(snapshot.blockRulesWithDeny)/\(blockPolicies.count)",
                    ok: missingDeny.isEmpty,
                    action: nil
                )
                if !missingDeny.isEmpty {
                    Divider().padding(.leading, 10).opacity(0.3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Missing action: Deny on \(missingDeny.count) block rule(s)")
                            .font(.caption2)
                            .foregroundColor(.red)
                        ForEach(missingDeny.prefix(3)) { p in
                            Text("• \(p.namespace)/\(p.name)")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if missingDeny.count > 3 {
                            Text("  + \(missingDeny.count - 3) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
            }
        }
    }
}

// MARK: - Quick actions card

private struct QuickActionsCard: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    var body: some View {
        SectionCard(title: "Quick Actions", icon: "terminal") {
            VStack(spacing: 4) {
                ClusterTerminalActionButton(
                    label: "kubectl get nodes -o wide",
                    command: "kubectl get nodes -o wide",
                    session: session
                )
                ClusterTerminalActionButton(
                    label: "kubectl get pods -n guardicore -o wide",
                    command: "kubectl get pods -n guardicore -o wide",
                    session: session
                )
                ClusterTerminalActionButton(
                    label: "Calico NetworkPolicies -A",
                    command: "kubectl get networkpolicies.crd.projectcalico.org -A",
                    session: session
                )
                ClusterTerminalActionButton(
                    label: "kubectl get events -n guardicore",
                    command: "kubectl get events -n guardicore --sort-by=.lastTimestamp",
                    session: session
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }

        if let version = snapshot.version {
            Text(version)
                .font(.caption2.monospaced())
                .foregroundColor(Color(nsColor: .quaternaryLabelColor))
                .padding(.top, 2)
        }
    }
}

// MARK: - Shared sub-components

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .kerning(0.5)
            }
            .padding(.horizontal, 10)
            .padding(.top, 9)
            .padding(.bottom, 7)

            Divider().opacity(0.4)
            content()
        }
        .background(AppTheme.surface.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}

private struct CheckRow: View {
    let label: String
    let value: String
    let ok: Bool
    var unknown: Bool = false
    let action: (() -> Void)?

    private var icon: String  { unknown ? "questionmark.circle" : (ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill") }
    private var color: Color  { unknown ? .secondary : (ok ? .green : .orange) }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                if action != nil {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 8))
                        .foregroundColor(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}
