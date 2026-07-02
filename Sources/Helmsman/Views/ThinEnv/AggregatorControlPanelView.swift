// AggregatorControlPanelView.swift — Gardicol Connector
// Right-sidebar view for active aggregator terminal tabs: live monicore-ctrl
// service status plus one-tap command shortcuts.

import SwiftUI
import TerminalKit
import AppKit

struct AggregatorControlPanelView: View {
    @ObservedObject var session: TerminalSession
    @StateObject private var viewModel: AggregatorViewModel
    @State private var selectedTab: Tab = .services

    init(session: TerminalSession) {
        self.session = session
        _viewModel = StateObject(wrappedValue: AggregatorViewModel(session: session))
    }

    private enum Tab: String, CaseIterable, Identifiable {
        case services = "Services"
        case commands = "Commands"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface.card)
        .task(id: session.id) { await viewModel.refresh() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            Task { await viewModel.refresh() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .foregroundColor(AppTheme.accent.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Aggregator View")
                    .font(.headline)
                    .foregroundColor(AppTheme.text.primary)
                if let snapshot = viewModel.snapshot {
                    Text("Updated \(snapshot.fetchedAt, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(AppTheme.text.muted)
                } else if viewModel.isRefreshing {
                    Text("Loading…")
                        .font(.caption2)
                        .foregroundColor(AppTheme.text.muted)
                }
            }
            Spacer()
            if viewModel.isRefreshing {
                ProgressView().scaleEffect(0.6)
            } else {
                Button { Task { await viewModel.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh service status")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.caption.weight(selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? AppTheme.accent.primary : AppTheme.text.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedTab == tab ? AppTheme.accent.primary.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if session.spec.metadata["guardicoreRemoteBase"] == nil {
            ScrollView { reconnectPrompt.padding(12) }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch selectedTab {
                    case .services: servicesTab
                    case .commands: AggregatorCommandsView(session: session)
                    }
                }
                .padding(10)
            }
        }
    }

    // MARK: - Services tab

    @ViewBuilder
    private var servicesTab: some View {
        quickActionsCard

        if let snapshot = viewModel.snapshot {
            healthSummary(snapshot)
            if let resources = snapshot.resources {
                resourceCards(resources)
            }
            serviceList(snapshot)
        } else if viewModel.isRefreshing {
            HStack {
                Spacer()
                ProgressView("Reading service status…")
                    .font(.caption)
                Spacer()
            }
            .padding(.vertical, 24)
        } else {
            ClusterEmptyState(
                icon: "list.bullet.rectangle",
                title: "No status yet",
                subtitle: "Press ↻ to run monicore-ctrl status"
            )
        }
    }

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("QUICK ACTIONS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            ForEach(AggregatorCommands.quickActionBuiltIns, id: \.self) { cmd in
                ClusterTerminalActionButton(
                    label: cmd,
                    command: cmd,
                    session: session,
                    onRun: scheduleRefresh
                )
            }
        }
        .padding(10)
        .background(AppTheme.surface.elevated)
        .cornerRadius(8)
    }

    private func healthSummary(_ snapshot: AggregatorSnapshot) -> some View {
        let color: Color = snapshot.allHealthy
            ? AppTheme.semantic.success
            : (snapshot.runningCount == 0 ? AppTheme.semantic.error : AppTheme.semantic.warning)
        return HStack(spacing: 8) {
            Image(systemName: snapshot.allHealthy ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(color)
            Text("\(snapshot.runningCount)/\(snapshot.totalCount) services running")
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
            Spacer()
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(AppTheme.semantic.warning)
                    .lineLimit(2)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func resourceCards(_ resources: AggregatorSystemResources) -> some View {
        HStack(spacing: 6) {
            ClusterMetricCard(title: "CPU", value: percent(resources.cpu), color: AppTheme.accent.primary)
            ClusterMetricCard(title: "Memory", value: percent(resources.memory), color: usageColor(resources.memory))
            ClusterMetricCard(title: "Disk", value: percent(resources.disk), color: usageColor(resources.disk))
            ClusterMetricCard(title: "Swap", value: percent(resources.swap), color: usageColor(resources.swap))
        }
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func serviceList(_ snapshot: AggregatorSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SERVICES")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            ForEach(snapshot.services) { service in
                AggregatorServiceRow(service: service, session: session, onAction: scheduleRefresh)
            }
        }
    }

    private func usageColor(_ value: Double) -> Color {
        if value >= 90 { return AppTheme.semantic.error }
        if value >= 75 { return AppTheme.semantic.warning }
        return AppTheme.semantic.success
    }

    private var reconnectPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reconnect Required", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
            Text("Close this tab and use Connect to Aggregator again so the app can run background monicore-ctrl commands.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }

    private func scheduleRefresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Task { await viewModel.refresh() }
        }
    }
}

// MARK: - Service row

private struct AggregatorServiceRow: View {
    let service: AggregatorService
    let session: TerminalSession
    var onAction: (() -> Void)? = nil

    @State private var pendingAction: AggregatorCommands.ServiceAction?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(service.isRunning ? AppTheme.semantic.success : AppTheme.semantic.error)
                .frame(width: 8, height: 8)
            Text(service.name)
                .font(.caption.monospaced())
                .foregroundColor(AppTheme.text.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(service.state)
                .font(.caption2.weight(.semibold))
                .foregroundColor(service.isRunning ? AppTheme.semantic.success : AppTheme.semantic.error)
            Menu {
                ForEach(AggregatorCommands.serviceActions) { action in
                    Button {
                        if action.disruptive {
                            pendingAction = action
                        } else {
                            run(action)
                        }
                    } label: {
                        Label(action.title, systemImage: action.icon)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundColor(AppTheme.text.muted)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppTheme.surface.elevated)
        .cornerRadius(6)
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text("\(action.title) \(service.name)?"),
                message: Text("This runs `\(action.command(for: service.name))` on the aggregator."),
                primaryButton: .destructive(Text(action.title)) { run(action) },
                secondaryButton: .cancel()
            )
        }
    }

    private func run(_ action: AggregatorCommands.ServiceAction) {
        session.run(action.command(for: service.name))
        onAction?()
    }
}

// MARK: - Commands tab

private struct AggregatorCommandsView: View {
    let session: TerminalSession

    @AppStorage("gardicol.aggregatorCustomCommands")
    private var customCommandsBlob: String = ""
    @State private var customCommandInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(AggregatorCommands.commandGroups, id: \.title) { group in
                AggregatorCommandGroupView(
                    title: group.title,
                    icon: group.icon,
                    commands: group.commands,
                    session: session
                )
            }

            if !customCommandsList.isEmpty {
                AggregatorCommandGroupView(
                    title: "Custom",
                    icon: "star.fill",
                    commands: customCommandsList,
                    session: session,
                    onDelete: removeCustomCommand
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ADD COMMAND")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    TextField("monicore-ctrl …", text: $customCommandInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .onSubmit(addCustomCommand)
                    Button("Add", action: addCustomCommand)
                        .disabled(customCommandInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .controlSize(.small)
                }
            }
        }
    }

    private var customCommandsList: [String] {
        ClusterCustomCommandsStorage.parse(customCommandsBlob)
    }

    private func addCustomCommand() {
        let cmd = customCommandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else {
            customCommandInput = ""
            return
        }
        customCommandsBlob = ClusterCustomCommandsStorage.appending(cmd, to: customCommandsBlob)
        customCommandInput = ""
    }

    private func removeCustomCommand(_ cmd: String) {
        customCommandsBlob = ClusterCustomCommandsStorage.removing(cmd, from: customCommandsBlob)
    }
}

private struct AggregatorCommandGroupView: View {
    let title: String
    let icon: String
    let commands: [String]
    let session: TerminalSession
    var onDelete: ((String) -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.caption2).foregroundColor(.accentColor)
                    Text(title).font(.caption.bold())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(commands, id: \.self) { cmd in
                    HStack(spacing: 4) {
                        ClusterTerminalActionButton(label: cmd, command: cmd, session: session)
                        if let onDelete {
                            Button { onDelete(cmd) } label: {
                                Image(systemName: "trash").font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
