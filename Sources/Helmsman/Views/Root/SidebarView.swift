// SidebarView.swift — Gardicol Connector

import SwiftUI
import SSHKit

struct SidebarView: View {
    @EnvironmentObject var thinEnvStore:    ThinEnvStore
    @EnvironmentObject var sessionStore:    SessionStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore

    @State private var showAddThinEnv  = false
    @State private var showAddSaaS     = false
    @State private var showDeleteAlert = false
    @State private var pendingDelete:  Session?
    @State private var editingSession: Session?

    var body: some View {
        VStack(spacing: 0) {
            List {
                thinEnvSection
                saasClustersSection
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface.base)

            Divider()
            bottomBar
        }
        .alert("Delete Connection?", isPresented: $showDeleteAlert, presenting: pendingDelete) { s in
            Button("Delete", role: .destructive) { sessionStore.delete(id: s.id) }
            Button("Cancel", role: .cancel) {}
        } message: { s in
            Text("\"\(s.name)\" will be permanently removed.")
        }
        .sheet(isPresented: $showAddThinEnv) {
            AddThinEnvSheet().environmentObject(thinEnvStore)
        }
        .sheet(isPresented: $showAddSaaS) {
            NewSessionSheet()
                .environmentObject(sessionStore)
                .environmentObject(activeTerminals)
        }
        .sheet(item: $editingSession) { session in
            NewSessionSheet(editing: session)
                .environmentObject(sessionStore)
                .environmentObject(activeTerminals)
        }
    }

    // MARK: - Thin Environments section

    @ViewBuilder
    private var thinEnvSection: some View {
        Section {
            if thinEnvStore.environments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No thin environments yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button { showAddThinEnv = true } label: {
                        Label("Add Thin Environment", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }

            ForEach(thinEnvStore.environments) { env in
                ThinEnvRow(envID: env.id)
                    .environmentObject(thinEnvStore)
                    .environmentObject(activeTerminals)
            }
            .onDelete { offsets in
                for i in offsets {
                    thinEnvStore.delete(id: thinEnvStore.environments[i].id)
                }
            }
            .onMove { src, dst in
                thinEnvStore.move(fromOffsets: src, toOffset: dst)
            }

            if !thinEnvStore.environments.isEmpty {
                Button { showAddThinEnv = true } label: {
                    Label("Add Thin Environment", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        } header: {
            sectionHeader("Thin Environments", icon: "desktopcomputer") {
                showAddThinEnv = true
            }
        }
    }

    // MARK: - SaaS Clusters section

    @ViewBuilder
    private var saasClustersSection: some View {
        Section {
            ForEach(sessionStore.sessions) { session in
                SessionRowView(session: session)
                    .contextMenu { saasContextMenu(session) }
            }
            .onDelete { offsets in
                for i in offsets {
                    pendingDelete   = sessionStore.sessions[i]
                    showDeleteAlert = true
                }
            }
            .onMove { src, dst in
                sessionStore.move(fromOffsets: src, toOffset: dst)
            }
        } header: {
            sectionHeader("SaaS Clusters", icon: "cloud") {
                showAddSaaS = true
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { showAddThinEnv = true } label: {
                Label("Add Thin Env", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.text.secondary)
            .help("Add a new thin environment")

            Button { activeTerminals.openLocalShell() } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.plain)
            .foregroundColor(AppTheme.text.secondary)
            .help("New local shell")
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface.card)
    }

    // MARK: - Shared header builder

    private func sectionHeader(
        _ title: String,
        icon: String,
        onAdd: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Spacer()
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Add thin environment")
        }
    }

    // MARK: - SaaS context menu

    @ViewBuilder
    private func saasContextMenu(_ session: Session) -> some View {
        Button("Connect") {
            activeTerminals.open(session: session, profile: sessionStore.activeProfile)
        }
        Button("Edit Connection…") {
            editingSession = session
        }
        Divider()
        Button("Delete", role: .destructive) {
            pendingDelete   = session
            showDeleteAlert = true
        }
    }
}
