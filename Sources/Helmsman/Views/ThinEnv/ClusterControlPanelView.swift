// ClusterControlPanelView.swift — Gardicol Connector
// Right-sidebar Cluster View for active cluster terminal tabs.

import SwiftUI
import TerminalKit
import AppKit

struct ClusterControlPanelView: View {
    @ObservedObject var session: TerminalSession
    @StateObject private var viewModel: ClusterViewModel
    @State private var selectedTab: ClusterPanelTab = .overview

    init(session: TerminalSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: ClusterViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            tabBar
            Divider()
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface.card)
        .task(id: session.id) { await viewModel.refresh() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task { await viewModel.refresh() }
        }
    }

    // MARK: Header

    private var panelHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .foregroundColor(AppTheme.accent.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Cluster View")
                    .font(.headline)
                    .foregroundColor(AppTheme.text.primary)
                if let snapshot = viewModel.snapshot {
                    HStack(spacing: 6) {
                        Text("Updated \(snapshot.fetchedAt, style: .relative) ago")
                        if viewModel.isEnriching, let stage = viewModel.refreshStage {
                            Text("· \(stage)")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(AppTheme.text.muted)
                } else if viewModel.isRefreshing, let stage = viewModel.refreshStage {
                    Text(stage)
                        .font(.caption2)
                        .foregroundColor(AppTheme.text.muted)
                }
            }
            Spacer()
            if viewModel.isRefreshing || viewModel.isEnriching {
                ProgressView().scaleEffect(0.6)
            } else {
                Button { Task { await viewModel.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh cluster state")
            }
            Menu {
                Button("Copy JSON") { copyExport(viewModel.exportSnapshotJSON()) }
                Button("Copy Markdown") { copyExport(viewModel.exportSnapshotMarkdown()) }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Export cluster snapshot")
            .disabled(viewModel.snapshot == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ClusterPanelTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.caption.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? AppTheme.accent.primary : AppTheme.text.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedTab == tab ? AppTheme.accent.primary.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if session.spec.metadata["guardicoreRemoteBase"] == nil {
            ScrollView {
                reconnectPrompt
                    .padding(12)
            }
        } else if let snapshot = viewModel.snapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    switch selectedTab {
                    case .overview:
                        ClusterOverviewView(
                            snapshot: snapshot,
                            session: session,
                            onQuickActionRun: {
                                // Debounce refresh ~1.5s after quick action runs
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    Task { await viewModel.refresh() }
                                }
                            }
                        )
                    case .topology:
                        ClusterTopologyView(snapshot: snapshot, session: session)
                    case .guardicore:
                        GuardicoreStatusView(snapshot: snapshot, session: session)
                    case .digestion:
                        PolicyDigestionView(snapshot: snapshot, session: session)
                    case .policies:
                        ClusterPoliciesView(snapshot: snapshot, session: session)
                    case .traffic:
                        TrafficValidationView(snapshot: snapshot, session: session)
                    case .commands:
                        ClusterCommandsView(session: session, clusterType: session.spec.metadata["guardicoreClusterType"])
                    case .raw:
                        ClusterRawView(snapshot: snapshot)
                    }
                    ClusterWarningList(warnings: snapshot.warnings)
                }
                .padding(10)
            }
        } else if viewModel.isRefreshing && viewModel.snapshot == nil {
            VStack {
                Spacer()
                ProgressView(viewModel.refreshStage ?? "Loading cluster…")
                Text("Fetching nodes and pods…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            }
        } else {
            ScrollView {
                ClusterEmptyState(
                    icon: "map",
                    title: "No cluster data yet",
                    subtitle: "Press ↻ to fetch cluster state"
                )
                .padding(12)
            }
        }
    }

    private var reconnectPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reconnect Required", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
            Text("Close this tab and use Connect to Cluster again so the app can run background kubectl commands.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }

    private func copyExport(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
