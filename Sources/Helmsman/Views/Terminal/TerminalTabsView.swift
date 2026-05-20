// TerminalTabsView.swift — Helmsman
// Custom tab bar + split terminal/SFTP pane layout.

import SwiftUI
import TerminalKit

struct TerminalTabsView: View {
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore
    @EnvironmentObject var kubeStore:       KubeStore
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // ── Tab bar ──────────────────────────────────────────────────────
            if !activeTerminals.tabs.isEmpty {
                tabBar
                Divider()
            }

            // ── Content ──────────────────────────────────────────────────────
            if activeTerminals.tabs.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ZStack {
                        // Keep every tab's terminal alive so each connection keeps its own shell.
                        ForEach(activeTerminals.tabs) { tab in
                            let isActive = activeTerminals.selectedTabID == tab.id
                            HStack(spacing: 0) {
                                TerminalPaneView(session: tab, colorScheme: colorScheme)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                if isActive && isClusterTab(tab) {
                                    Divider()
                                    ClusterControlPanelView(session: tab)
                                        .frame(width: 400)
                                        .transition(.move(edge: .trailing))
                                } else if isActive && activeTerminals.showSFTPPane {
                                    Divider()
                                    SFTPPaneView(session: tab)
                                        .frame(width: 260)
                                        .transition(.move(edge: .trailing))
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .opacity(isActive ? 1 : 0)
                            .allowsHitTesting(isActive)
                            .accessibilityHidden(!isActive)
                            .zIndex(isActive ? 1 : 0)
                            .id(tab.id)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if activeTerminals.showKubeDock {
                        Divider()
                        KubeContextDockView()
                            .frame(height: 200)
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeTerminals.showSFTPPane)
        .animation(.easeInOut(duration: 0.2), value: activeTerminals.showKubeDock)
    }

    // MARK: - Tab bar

    private func isClusterTab(_ tab: TerminalSession) -> Bool {
        if tab.spec.metadata["guardicoreTarget"] == "cluster" { return true }
        if tab.spec.metadata["guardicoreStatusCommand"] != nil { return true }

        let name = tab.spec.name.lowercased()
        return name.contains("rancher") ||
            name.contains("rke2") ||
            name.contains("cluster")
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(activeTerminals.tabs) { tab in
                    TabItemView(tab: tab,
                                isSelected: activeTerminals.selectedTabID == tab.id)
                        .onTapGesture {
                            activeTerminals.selectedTabID = tab.id
                        }
                }
            }
        }
        .frame(height: 36)
        .background(.bar)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No open sessions")
                .font(.title2)
                .foregroundColor(.secondary)
            Button("New Session…") {
                activeTerminals.showNewSession = true
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("n", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Item

private struct TabItemView: View {
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore
    @ObservedObject var tab: TerminalSession
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(tab.spec.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if tab.title != tab.spec.name && !tab.title.isEmpty {
                    Text(tab.title)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: 140, alignment: .leading)

            Button {
                activeTerminals.close(id: tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
            }
            .buttonStyle(.plain)
            .opacity(isSelected ? 1 : 0.5)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch tab.status {
        case .connected:     return .green
        case .connecting:    return .yellow
        case .reconnecting:  return .orange
        case .disconnected:  return .red
        }
    }
}
