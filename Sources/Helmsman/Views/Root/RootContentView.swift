// RootContentView.swift — Helmsman
// Top-level NavigationSplitView: sidebar + terminal tab container.

import SwiftUI
import TerminalKit

struct RootContentView: View {
    @EnvironmentObject var sessionStore:    SessionStore
    @EnvironmentObject var thinEnvStore:    ThinEnvStore
    @EnvironmentObject var kubeStore:       KubeStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .environmentObject(thinEnvStore)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            TerminalTabsView()
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .background(AppTheme.surface.base)
        // ── Sheets ──────────────────────────────────────────────────────────
        .sheet(isPresented: $activeTerminals.showNewSession) {
            NewSessionSheet()
                .environmentObject(sessionStore)
                .environmentObject(activeTerminals)
        }
        .sheet(isPresented: $activeTerminals.showMultiExec) {
            MultiExecView()
                .environmentObject(activeTerminals)
        }
        .sheet(isPresented: $activeTerminals.showExport) {
            if let tab = activeTerminals.activeTab,
               let session = sessionStore.sessions.first(where: {
                   $0.name == tab.spec.name
               }) {
                ExportConnectionView(session: session)
            }
        }
        // ── Spotlight open-session continuation ──────────────────────────────
        .onReceive(NotificationCenter.default.publisher(for: .openSessionByID)) { note in
            if let id = note.userInfo?["sessionID"] as? UUID,
               let session = sessionStore.sessions.first(where: { $0.id == id }) {
                activeTerminals.open(session: session, profile: sessionStore.activeProfile)
            }
        }
    }
}
