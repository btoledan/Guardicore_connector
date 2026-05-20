// SessionRowView.swift — Helmsman

import SwiftUI
import SSHKit

struct SessionRowView: View {
    @EnvironmentObject var sessionStore:    SessionStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore

    let session: Session
    @State private var showEditor = false

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(session.username)@\(session.host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    if !session.proxyJumpHops.isEmpty {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .help("\(session.proxyJumpHops.count) ProxyJump hop(s)")
                    }
                    if !session.tunnels.isEmpty {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .help("\(session.tunnels.count) tunnel(s)")
                    }
                }
            }
        } icon: {
            Image(systemName: session.kind.systemImage)
                .foregroundColor(session.kind.color)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            activeTerminals.open(session: session, profile: sessionStore.activeProfile)
        }
        .contextMenu {
            Button("Connect") {
                activeTerminals.open(session: session, profile: sessionStore.activeProfile)
            }
            Button("Edit Connection…") { showEditor = true }
            Divider()
            Button("Delete", role: .destructive) {
                sessionStore.delete(id: session.id)
            }
        }
        .sheet(isPresented: $showEditor) {
            NewSessionSheet(editing: session)
                .environmentObject(sessionStore)
                .environmentObject(activeTerminals)
        }
    }
}

// MARK: - SessionKind display helpers

extension SessionKind {
    var systemImage: String {
        switch self {
        case .ssh:        return "terminal.fill"
        case .sftp:       return "folder.fill.badge.plus"
        case .telnet:     return "network"
        case .serial:     return "cable.connector"
        case .tunnelOnly: return "arrow.left.arrow.right.circle.fill"
        case .local:      return "laptopcomputer"
        }
    }

    var color: Color {
        switch self {
        case .ssh:        return .green
        case .sftp:       return .blue
        case .telnet:     return .gray
        case .serial:     return .brown
        case .tunnelOnly: return .purple
        case .local:      return .primary
        }
    }
}
