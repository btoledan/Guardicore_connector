// ThinEnvRow.swift — Gardicol Connector
// Tester, Management, Aggregators, and Clusters with explicit connect buttons.

import SwiftUI
import TerminalKit

private struct ClusterEditorContext: Identifiable {
    let envID: UUID
    let cluster: GuardicoreCluster
    var id: UUID { cluster.id }
}

private struct AggregatorEditorContext: Identifiable {
    let envID: UUID
    let aggregator: GuardicoreAggregator
    var id: UUID { aggregator.id }
}

struct ThinEnvRow: View {
    let envID: UUID

    @EnvironmentObject var thinEnvStore:    ThinEnvStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore

    @State private var isExpanded:                Bool = true
    @State private var showAddCluster               = false
    @State private var showAddAggregator            = false
    @State private var showEditFolder               = false
    @State private var showEditTesterConnection     = false
    @State private var showDeleteEnvAlert            = false
    @State private var clusterEditor:                ClusterEditorContext?
    @State private var aggregatorEditor:             AggregatorEditorContext?
    @State private var connectionTarget:            ConnectionTarget?
    @State private var pendingClusterDelete:        GuardicoreCluster?
    @State private var pendingAggregatorDelete:     GuardicoreAggregator?
    @State private var showDeleteClusterAlert        = false
    @State private var showDeleteAggregatorAlert     = false

    private var env: ThinEnvironment? { thinEnvStore.environment(id: envID) }

    var body: some View {
        Group {
            if let env {
                environmentCard(env)
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showAddCluster) {
            AddClusterSheet(envID: envID).environmentObject(thinEnvStore)
        }
        .sheet(isPresented: $showAddAggregator) {
            AddAggregatorSheet(envID: envID).environmentObject(thinEnvStore)
        }
        .sheet(isPresented: $showEditFolder) {
            if let env {
                AddThinEnvSheet(editing: env).environmentObject(thinEnvStore)
            }
        }
        .sheet(isPresented: $showEditTesterConnection) {
            if let env {
                ConnectionDetailsSheet(target: .thinEnv(env)).environmentObject(thinEnvStore)
            }
        }
        .sheet(item: $connectionTarget) { target in
            ConnectionDetailsSheet(target: target).environmentObject(thinEnvStore)
        }
        .sheet(item: $clusterEditor) { ctx in
            AddClusterSheet(envID: ctx.envID, editing: ctx.cluster).environmentObject(thinEnvStore)
        }
        .sheet(item: $aggregatorEditor) { ctx in
            AddAggregatorSheet(envID: ctx.envID, editing: ctx.aggregator).environmentObject(thinEnvStore)
        }
        .alert("Delete Environment?", isPresented: $showDeleteEnvAlert) {
            Button("Delete", role: .destructive) { thinEnvStore.delete(id: envID) }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let env { Text("\"\(env.displayName)\" and all its machines will be permanently removed.") }
        }
        .alert("Delete Cluster?", isPresented: $showDeleteClusterAlert, presenting: pendingClusterDelete) { cluster in
            Button("Delete", role: .destructive) { thinEnvStore.deleteCluster(id: cluster.id, fromEnvID: envID) }
            Button("Cancel", role: .cancel) {}
        } message: { cluster in Text("\"\(cluster.displayName)\" will be permanently removed.") }
        .alert("Delete Aggregator?", isPresented: $showDeleteAggregatorAlert, presenting: pendingAggregatorDelete) { aggr in
            Button("Delete", role: .destructive) { thinEnvStore.deleteAggregator(id: aggr.id, fromEnvID: envID) }
            Button("Cancel", role: .cancel) {}
        } message: { aggr in Text("\"\(aggr.displayName)\" will be permanently removed.") }
    }

    // MARK: - Environment Card

    private func environmentCard(_ env: ThinEnvironment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            environmentHeader(env)

            if isExpanded {
                Divider().opacity(0.45)
                machineRow(
                    kind: "Tester",
                    title: "Tester",
                    route: env.host,
                    color: .orange,
                    isCluster: false,
                    onOpen: { connectToTester(env) }
                )
                .contextMenu {
                    Button("Connection Details…") { showEditTesterConnection = true }
                }

                Divider().opacity(0.35)
                machineRow(
                    kind: "Mgmt",
                    title: "Mgmt Server",
                    route: "\(env.host) → mgmt",
                    color: .indigo,
                    isCluster: false,
                    onOpen: { connectToMgmt(env) }
                )
                .contextMenu {
                    Button("Connection Details…") { connectionTarget = .mgmt(env) }
                }

                if !env.aggregators.isEmpty {
                    Divider().opacity(0.35)
                    ForEach(env.aggregators) { aggr in
                        machineRow(
                            kind: "Aggr",
                            title: aggr.displayName,
                            route: "\(env.host) → \(aggr.address)",
                            color: .teal,
                            isCluster: false,
                            onOpen: { connectToAggregator(aggr, env: env) }
                        )
                        .contextMenu {
                            Button("Connection Details…") { connectionTarget = .aggregator(aggr, env: env) }
                            Button("Edit Address…") {
                                aggregatorEditor = AggregatorEditorContext(envID: envID, aggregator: aggr)
                            }
                            Divider()
                            Button("Delete Aggregator", role: .destructive) {
                                pendingAggregatorDelete = aggr
                                showDeleteAggregatorAlert = true
                            }
                        }
                        if aggr.id != env.aggregators.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }

                if !env.clusters.isEmpty {
                    Divider().opacity(0.35)
                    ForEach(env.clusters) { cluster in
                        machineRow(
                            kind: "Cluster",
                            title: cluster.displayName,
                            route: "\(env.host) → \(cluster.ip)",
                            color: clusterColor(cluster),
                            isCluster: true,
                            onOpen: { connectToCluster(cluster, env: env) }
                        )
                        .contextMenu {
                            Button("Connection Details…") { connectionTarget = .cluster(cluster, env: env) }
                            Button("Edit Cluster…") {
                                clusterEditor = ClusterEditorContext(envID: envID, cluster: cluster)
                            }
                            Divider()
                            Button("Delete Cluster", role: .destructive) {
                                pendingClusterDelete = cluster
                                showDeleteClusterAlert = true
                            }
                        }
                        if cluster.id != env.clusters.last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }

                Divider().opacity(0.35)
                addRows
            }
        }
        .background(AppTheme.surface.card)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(8)
        .contextMenu {
            Button("Edit Folder…") { showEditFolder = true }
            Button("Add Aggregator…") { showAddAggregator = true }
            Button("Add Cluster…") { showAddCluster = true }
            Divider()
            Button("Delete Environment", role: .destructive) { showDeleteEnvAlert = true }
        }
    }

    private func environmentHeader(_ env: ThinEnvironment) -> some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                Circle()
                    .fill(AppTheme.accent.primary)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(env.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.text.primary)
                        .lineLimit(1)
                    Text("\(env.host) · \(environmentSummary(env))")
                        .font(.caption2)
                        .foregroundColor(AppTheme.text.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                badge("Ready", color: .secondary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func machineRow(
        kind: String,
        title: String,
        route: String,
        color: Color,
        isCluster: Bool,
        onOpen: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            badge(kind, color: color)
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.text.primary)
                    .lineLimit(1)
                Text(route)
                    .font(.caption2.monospaced())
                    .foregroundColor(AppTheme.text.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button("Open", action: onOpen)
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(isCluster ? color : AppTheme.accent.primary)
                .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isCluster ? color.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
    }

    private var addRows: some View {
        HStack(spacing: 8) {
            Button { showAddAggregator = true } label: {
                Label("Add Aggr", systemImage: "plus")
                    .font(.caption2.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.text.secondary)

            Button { showAddCluster = true } label: {
                Label("Add Cluster", systemImage: "plus")
                    .font(.caption2.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.text.secondary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func environmentSummary(_ env: ThinEnvironment) -> String {
        let clusterText = "\(env.clusters.count) cluster\(env.clusters.count == 1 ? "" : "s")"
        let aggrText = "\(env.aggregators.count) aggregator\(env.aggregators.count == 1 ? "" : "s")"
        return "\(clusterText) · \(aggrText)"
    }

    // MARK: - Connect

    private func connectToTester(_ env: ThinEnvironment) {
        guard let live = thinEnvStore.environment(id: env.id) else { return }
        activeTerminals.openCommand(live.testerShellCommand, name: live.testerTabName)
    }

    private func connectToMgmt(_ env: ThinEnvironment) {
        guard let live = thinEnvStore.environment(id: env.id) else { return }
        activeTerminals.openCommand(live.mgmtShellCommand, name: live.mgmtTabName)
    }

    private func connectToAggregator(_ aggr: GuardicoreAggregator, env: ThinEnvironment) {
        guard
            let live = thinEnvStore.environment(id: env.id),
            let liveAggr = live.aggregators.first(where: { $0.id == aggr.id })
        else { return }
        activeTerminals.openCommand(liveAggr.shellCommand(through: live), name: liveAggr.tabName(in: live))
    }

    private func connectToCluster(_ cluster: GuardicoreCluster, env: ThinEnvironment) {
        guard
            let live = thinEnvStore.environment(id: env.id),
            let liveCluster = live.clusters.first(where: { $0.id == cluster.id })
        else { return }
        activeTerminals.openCommand(
            liveCluster.clusterShellCommand(through: live),
            name: liveCluster.clusterTabName(in: live),
            metadata: [
                "guardicoreTarget": "cluster",
                "guardicoreStatusCommand": liveCluster.clusterRemoteCommand(
                    "kubectl get pods -n guardicore",
                    through: live
                ),
                // Template for running any kubectl command in the background:
                // replace '__KUBECTL_PLACEHOLDER__' with the desired kubectl command.
                "guardicoreRemoteBase": liveCluster.clusterRemoteCommand(
                    "__KUBECTL_PLACEHOLDER__",
                    through: live
                )
            ]
        )
    }

    private func clusterIcon(_ cluster: GuardicoreCluster) -> String {
        switch cluster.type {
        case .rancher: return "server.rack"
        case .rke2:    return "cube.box"
        case .custom:  return "gearshape"
        }
    }

    private func clusterColor(_ cluster: GuardicoreCluster) -> Color {
        switch cluster.type {
        case .rancher: return AppTheme.semantic.success
        case .rke2:    return AppTheme.accent.secondary
        case .custom:  return AppTheme.accent.info
        }
    }
}
