// ClusterTopologyView.swift — Visual K8s cluster topology
// Redesigned May 2026: cluster summary header, grid layout, namespace color system, pod dot-matrix

import SwiftUI
import TerminalKit

// MARK: - Namespace colour palette

private let nsColorPalette: [Color] = [
    .purple, .orange, .teal, .pink, .indigo, .mint, .cyan, .brown
]

private func namespaceColor(_ ns: String) -> Color {
    switch ns {
    case "guardicore":       return .purple
    case "kube-system":      return Color(nsColor: .systemGray)
    case "calico-system", "calico-apiserver": return .orange
    case "ingress-nginx", "ingress-controller": return .teal
    case "metallb-system":   return .brown
    case "tigera-operator":  return .orange
    case "cert-manager":     return .cyan
    case "monitoring":       return .pink
    default:
        let hash = ns.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return nsColorPalette[abs(hash) % nsColorPalette.count]
    }
}

// MARK: - Main View

struct ClusterTopologyView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    private var controlPlaneNodes: [ClusterNode] { snapshot.nodes.filter(\.isControlPlane) }
    private var workerNodes: [ClusterNode]        { snapshot.nodes.filter { !$0.isControlPlane } }
    private var gcCoveredNodes: Int {
        snapshot.nodes.filter { node in snapshot.guardicore.agents.contains { $0.node == node.name } }.count
    }
    private var allNamespaces: [String] {
        Array(Set(snapshot.pods.map(\.namespace))).sorted()
    }
    private var unhealthyPods: Int { snapshot.unhealthyPodCount }

    // GC component placement (which node runs what)
    private var enforcePods: [ClusterPod]   { snapshot.pods.filter(\.isKubeEnforce) }
    private var inventoryClusterPods: [ClusterPod] { snapshot.pods.filter(\.isKubeInventory) }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {

                // ── Cluster summary strip ──────────────────────────
                ClusterTopologySummaryBar(
                    nodeCount:    snapshot.nodes.count,
                    readyNodes:   snapshot.nodesReady,
                    podCount:     snapshot.pods.count,
                    unhealthy:    unhealthyPods,
                    gcCovered:    gcCoveredNodes,
                    nsCount:      allNamespaces.count
                )

                // ── Guardicore component placement ─────────────────
                GuardicorePlacementCard(
                    agents: snapshot.guardicore.agents,
                    enforcePods: enforcePods,
                    inventoryClusterPods: inventoryClusterPods,
                    inventoryPods: snapshot.guardicore.inventoryPods,
                    kubeEnforceNode: snapshot.guardicore.kubeEnforceNode,
                    nodeCount: snapshot.nodes.count,
                    session: session
                )

                // ── Namespace colour legend ────────────────────────
                if !allNamespaces.isEmpty {
                    NamespaceLegend(namespaces: allNamespaces)
                }

                if snapshot.nodes.isEmpty {
                    ClusterEmptyState(
                        icon: "square.3.layers.3d",
                        title: "No nodes found",
                        subtitle: "Check Raw tab for kubectl output"
                    )
                } else {

                    // ── Control-plane nodes (full width) ──────────
                    if !controlPlaneNodes.isEmpty {
                        SectionLabel(text: "CONTROL PLANE", color: .blue)
                        VStack(spacing: 8) {
                            ForEach(controlPlaneNodes) { node in
                                TopoNodeCard(
                                    node: node,
                                    pods: snapshot.pods.filter { $0.node == node.name },
                                    agent: snapshot.guardicore.agents.first { $0.node == node.name },
                                    enforcePods: enforcePods.filter { $0.node == node.name },
                                    inventoryPods: inventoryClusterPods.filter { $0.node == node.name },
                                    session: session
                                )
                            }
                        }
                    }

                    // ── Worker nodes (adaptive 2-col grid) ────────
                    if !workerNodes.isEmpty {
                        SectionLabel(text: "WORKER NODES", color: .secondary)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(workerNodes) { node in
                                TopoNodeCard(
                                    node: node,
                                    pods: snapshot.pods.filter { $0.node == node.name },
                                    agent: snapshot.guardicore.agents.first { $0.node == node.name },
                                    enforcePods: enforcePods.filter { $0.node == node.name },
                                    inventoryPods: inventoryClusterPods.filter { $0.node == node.name },
                                    session: session
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Summary strip

private struct ClusterTopologySummaryBar: View {
    let nodeCount: Int
    let readyNodes: Int
    let podCount: Int
    let unhealthy: Int
    let gcCovered: Int
    let nsCount: Int

    var body: some View {
        HStack(spacing: 8) {
            SummaryStat(
                value: "\(readyNodes)/\(nodeCount)",
                label: "nodes",
                color: readyNodes == nodeCount ? .green : .red
            )
            Divider().frame(height: 30)
            SummaryStat(
                value: "\(podCount - unhealthy)/\(podCount)",
                label: "pods OK",
                color: unhealthy == 0 ? .green : .orange
            )
            Divider().frame(height: 30)
            SummaryStat(
                value: "\(gcCovered)/\(nodeCount)",
                label: "GC protected",
                color: gcCovered == nodeCount ? .purple : .red
            )
            Divider().frame(height: 30)
            SummaryStat(
                value: "\(nsCount)",
                label: "namespaces",
                color: .secondary
            )
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface.elevated, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 56, alignment: .leading)
    }
}

// MARK: - Namespace legend

private struct NamespaceLegend: View {
    let namespaces: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(namespaces, id: \.self) { ns in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(namespaceColor(ns))
                            .frame(width: 6, height: 6)
                        Text(ns)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(namespaceColor(ns).opacity(0.08))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - Section label

private struct SectionLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .kerning(0.8)
    }
}

// MARK: - Guardicore placement card

/// Shows, at a glance, which node runs each Guardicore control component:
/// the per-node enforcement DaemonSet agents, gc-kube-enforce, and gc-kube-inventory.
private struct GuardicorePlacementCard: View {
    let agents: [GuardicoreAgent]
    let enforcePods: [ClusterPod]
    let inventoryClusterPods: [ClusterPod]
    let inventoryPods: [GuardicoreInventoryPod]
    let kubeEnforceNode: String?
    let nodeCount: Int
    let session: TerminalSession

    /// Enforcement: prefer live pod placement, fall back to single node string.
    private var enforceRows: [(node: String, status: String, pod: String?)] {
        if !enforcePods.isEmpty {
            return enforcePods.map { ($0.node, $0.status, $0.name) }
        }
        if let n = kubeEnforceNode, !n.isEmpty {
            return [(n, "—", nil)]
        }
        return []
    }

    /// Inventory: prefer cluster pods (have node), fall back to parsed inventory pods.
    private var inventoryRows: [(node: String, status: String, pod: String?)] {
        if !inventoryClusterPods.isEmpty {
            return inventoryClusterPods.map { ($0.node, $0.status, $0.name) }
        }
        return inventoryPods.map { ($0.node, $0.status, $0.podName) }
    }

    private var coveredNodes: Int {
        Set(agents.map(\.node)).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundColor(.purple)
                Text("GUARDICORE PLACEMENT")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.purple)
                    .kerning(0.8)
                Spacer()
                Text("\(coveredNodes)/\(nodeCount) nodes protected")
                    .font(.caption2)
                    .foregroundColor(coveredNodes == nodeCount && nodeCount > 0 ? .green : .orange)
            }

            // Enforcement (DaemonSet agents) — node list
            PlacementSection(
                icon: "shield.lefthalf.filled",
                title: "Enforcement (DaemonSet)",
                color: .purple,
                rows: agents.map { ($0.node, $0.status, $0.podName) },
                emptyText: "No agents found",
                session: session,
                namespace: "guardicore"
            )

            Divider().opacity(0.3)

            // gc-kube-enforce
            PlacementSection(
                icon: "lock.shield.fill",
                title: "gc-kube-enforce",
                color: .blue,
                rows: enforceRows,
                emptyText: "Not detected",
                session: session,
                namespace: "guardicore"
            )

            Divider().opacity(0.3)

            // gc-kube-inventory
            PlacementSection(
                icon: "tray.full.fill",
                title: "gc-kube-inventory",
                color: .teal,
                rows: inventoryRows,
                emptyText: "Not detected",
                session: session,
                namespace: "guardicore"
            )
        }
        .padding(12)
        .background(AppTheme.surface.elevated, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.purple.opacity(0.25), lineWidth: 1))
    }
}

private struct PlacementSection: View {
    let icon: String
    let title: String
    let color: Color
    let rows: [(node: String, status: String, pod: String?)]
    let emptyText: String
    let session: TerminalSession
    let namespace: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color)
                Spacer()
                Text("\(rows.count)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }

            if rows.isEmpty {
                Text(emptyText)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 18)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        Circle()
                            .fill(row.status.lowercased() == "running" ? Color.green :
                                  row.status == "—" ? Color.secondary : Color.orange)
                            .frame(width: 6, height: 6)
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(row.node.isEmpty ? "unknown node" : row.node)
                            .font(.caption2.monospaced())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        if row.status != "—" {
                            Text(row.status)
                                .font(.caption2)
                                .foregroundColor(row.status.lowercased() == "running" ? .secondary : .orange)
                        }
                        Spacer()
                        if let pod = row.pod {
                            Button {
                                session.run("kubectl logs -n \(namespace) \(pod) --tail=200")
                            } label: {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 9))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("Tail logs for \(pod)")
                        }
                    }
                    .padding(.leading, 14)
                }
            }
        }
    }
}

// MARK: - GC component chip

private struct GCComponentChip: View {
    let icon: String
    let label: String
    let color: Color
    let running: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(label)
                .font(.system(size: 9, weight: .medium))
            Circle()
                .fill(running ? Color.green : Color.orange)
                .frame(width: 4, height: 4)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .cornerRadius(4)
    }
}

// MARK: - Node card

private struct TopoNodeCard: View {
    let node: ClusterNode
    let pods: [ClusterPod]
    let agent: GuardicoreAgent?
    var enforcePods: [ClusterPod] = []
    var inventoryPods: [ClusterPod] = []
    let session: TerminalSession

    @State private var expanded = true

    private var gcPods:    [ClusterPod] { pods.filter(\.isGC) }
    private var appPods:   [ClusterPod] { pods.filter { !$0.isSystem } }
    private var unhealthy: Int {
        pods.filter {
            let s = $0.status.lowercased()
            return s != "running" && s != "completed"
        }.count
    }
    private var podsByNS: [(ns: String, pods: [ClusterPod])] {
        let grouped = Dictionary(grouping: appPods, by: \.namespace)
        return grouped.keys.sorted().map { ns in (ns, grouped[ns]!) }
    }
    private var headerAccent: Color { node.isControlPlane ? .blue : Color(nsColor: .tertiaryLabelColor) }
    private var borderColor:  Color { node.isControlPlane ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.15) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Node header ───────────────────────────────────────
            HStack(alignment: .top, spacing: 8) {

                // Health dot
                Circle()
                    .fill(node.isReady ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .padding(.top, 3)

                // Name + IP
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(node.internalIP)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                    if let os = node.osImage {
                        Text(os)
                            .font(.caption2)
                            .foregroundColor(Color(nsColor: .quaternaryLabelColor))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    // Role badge
                    Text(node.roleShort)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(headerAccent.opacity(0.15))
                        .foregroundColor(headerAccent)
                        .cornerRadius(4)

                    // Pod health badge
                    HStack(spacing: 3) {
                        Circle()
                            .fill(unhealthy > 0 ? Color.red : Color.green)
                            .frame(width: 5, height: 5)
                        Text("\(pods.count) pods\(unhealthy > 0 ? " · \(unhealthy) !" : "")")
                            .font(.caption2)
                            .foregroundColor(unhealthy > 0 ? .red : .secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(node.isControlPlane ? Color.blue.opacity(0.05) : Color.clear)

            Divider().opacity(0.4)

            // ── GC agent row ─────────────────────────────────────
            if let agent {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.caption2)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(agent.podName)
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            StatusPill(text: agent.status,
                                       color: agent.status.lowercased() == "running" ? .green : .orange)
                            if agent.restarts > 0 {
                                Text("↺\(agent.restarts)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            if let rev = agent.policyRevision {
                                Text("rev \(rev)")
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    Spacer()
                    Button {
                        session.run("kubectl exec -it \(agent.podName) -n guardicore -- /bin/sh")
                    } label: {
                        Image(systemName: "terminal")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.purple.opacity(0.04))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "shield.slash")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("No Guardicore agent")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.05))
            }

            // ── GC control components on this node (enforce / inventory) ──
            if !enforcePods.isEmpty || !inventoryPods.isEmpty {
                Divider().opacity(0.4)
                HStack(spacing: 6) {
                    ForEach(enforcePods) { pod in
                        GCComponentChip(
                            icon: "lock.shield.fill",
                            label: "enforce",
                            color: .blue,
                            running: pod.status.lowercased() == "running"
                        )
                    }
                    ForEach(inventoryPods) { pod in
                        GCComponentChip(
                            icon: "tray.full.fill",
                            label: "inventory",
                            color: .teal,
                            running: pod.status.lowercased() == "running"
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.03))
            }

            // ── Pod namespaces (collapsible) ──────────────────────
            if !podsByNS.isEmpty {
                Divider().opacity(0.4)

                // Collapse toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Pods by namespace")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        // Mini dot summary (compact mode)
                        if !expanded {
                            PodDotMatrix(pods: pods, maxDots: 24)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(podsByNS, id: \.ns) { (ns, nsPods) in
                            NamespaceRow(ns: ns, pods: nsPods, session: session)
                            if ns != podsByNS.last?.ns {
                                Divider().padding(.leading, 10).opacity(0.3)
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .background(AppTheme.surface.card)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(borderColor, lineWidth: 1))
    }
}

// MARK: - Namespace row inside a node

private struct NamespaceRow: View {
    let ns: String
    let pods: [ClusterPod]
    let session: TerminalSession

    private var color: Color { namespaceColor(ns) }
    private var unhealthy: [ClusterPod] { pods.filter {
        let s = $0.status.lowercased()
        return s != "running" && s != "completed"
    }}

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Namespace label
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 30)
                Text(ns)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(color)
                    .lineLimit(2)
                    .frame(width: 60, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Pod dot matrix
                PodDotMatrix(pods: pods, maxDots: 30)

                // Unhealthy pods listed by name
                if !unhealthy.isEmpty {
                    ForEach(unhealthy) { pod in
                        Button {
                            session.run("kubectl describe pod \(pod.name) -n \(pod.namespace)")
                        } label: {
                            HStack(spacing: 4) {
                                Circle().fill(pod.statusColor).frame(width: 5, height: 5)
                                Text(pod.name)
                                    .font(.caption2.monospaced())
                                    .lineLimit(1)
                                Text(pod.status)
                                    .font(.caption2)
                                    .foregroundColor(pod.statusColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 0)
            Text("\(pods.count)")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Pod dot matrix

/// Renders pods as a grid of small coloured dots: green = running, red = error, orange = degraded, etc.
private struct PodDotMatrix: View {
    let pods: [ClusterPod]
    let maxDots: Int

    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 3
    private let columns = 10

    private var displayPods: [ClusterPod] { Array(pods.prefix(maxDots)) }
    private var overflow: Int { max(0, pods.count - maxDots) }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(stride(from: 0, to: displayPods.count, by: columns).map { $0 }, id: \.self) { i in
                HStack(spacing: spacing) {
                    ForEach(displayPods[i ..< min(i + columns, displayPods.count)]) { pod in
                        PodDot(pod: pod)
                    }
                    if i + columns >= displayPods.count && overflow > 0 {
                        Text("+\(overflow)")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

private struct PodDot: View {
    let pod: ClusterPod
    @State private var hovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(pod.statusColor)
            .frame(width: 8, height: 8)
            .opacity(hovered ? 0.7 : 1.0)
            .scaleEffect(hovered ? 1.4 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: hovered)
            .help("\(pod.name)\n\(pod.status) · \(pod.ready) ready · ↺\(pod.restarts)")
            .onHover { hovered = $0 }
    }
}

// MARK: - Status pill

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(3)
    }
}
