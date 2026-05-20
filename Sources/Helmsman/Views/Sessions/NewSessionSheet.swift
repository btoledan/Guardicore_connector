// NewSessionSheet.swift — Gardicol Connector
// Quick-connect to a thin environment: number → XXX.thin.env

import SwiftUI
import SSHKit
import VaultKit

struct NewSessionSheet: View {
    @EnvironmentObject var sessionStore:    SessionStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore
    @Environment(\.dismiss) var dismiss

    var editing: Session? = nil

    @State private var host:     String = ""
    @State private var username: String = ThinEnvironment.user
    @State private var password: String = ThinEnvironment.password
    @FocusState private var focusedField: Field?

    private enum Field { case host, username, password }

    var isEditing: Bool { editing != nil }

    private var resolvedHost: String {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "" }
        if trimmed.hasSuffix(".thin.env") { return trimmed }
        return "\(trimmed).thin.env"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────────────
            VStack(spacing: 4) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)
                Text(isEditing ? "Edit Connection" : "Quick Connect")
                    .font(.title2.bold())
                if !isEditing {
                    Text("One-off connection — not saved to the sidebar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            // ── Fields ──────────────────────────────────────────────────────
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Thin Env")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("438", text: $host)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .host)
                        .onSubmit { focusedField = .username }
                    if !resolvedHost.isEmpty {
                        Text(resolvedHost)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }

                field(label: "Username", placeholder: ThinEnvironment.user,
                      text: $username, focus: .username)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("••••••••", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .onSubmit { connect() }
                }
            }
            .padding(.horizontal, 28)

            // ── Connect button ───────────────────────────────────────────────
            Button(action: connect) {
                Label(isEditing ? "Save" : "Connect", systemImage: isEditing ? "checkmark" : "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canConnect)
            .padding(.horizontal, 28)
            .padding(.top, 20)

            // ── Cancel ───────────────────────────────────────────────────────
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.top, 10)
                .padding(.bottom, 24)
        }
        .frame(width: 380)
        .onAppear {
            populate()
            focusedField = .host
        }
    }

    // MARK: - Reusable field builder

    private func field(label: String, placeholder: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: focus)
                .onSubmit {
                    switch focus {
                    case .host:     focusedField = .username
                    case .username: focusedField = .password
                    case .password: connect()
                    }
                }
        }
    }

    // MARK: - Logic

    private var canConnect: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func populate() {
        if let s = editing {
            host     = s.host.replacingOccurrences(of: ".thin.env", with: "")
            username = s.username
            if let stored = try? Keychain.get(KeychainItem(kind: .sshPassword, account: "\(s.username)@\(s.host)")) {
                password = stored
            }
            return
        }

        username = ThinEnvironment.user
        password = ThinEnvironment.password
    }

    private func connect() {
        guard canConnect else { return }

        let trimHost = resolvedHost
        let trimUser = username.trimmingCharacters(in: .whitespaces)
        let trimPass = password.isEmpty ? ThinEnvironment.password : password

        if isEditing {
            var session = editing ?? Session()
            session.name       = trimHost
            session.kind       = .ssh
            session.host       = trimHost
            session.port       = 22
            session.username   = trimUser
            session.authMethod = .password
            session.workspaceProfileID = WorkspaceProfile.defaultLab.id

            let item = KeychainItem(kind: .sshPassword, account: "\(trimUser)@\(trimHost)")
            try? Keychain.set(trimPass, for: item)
            sessionStore.update(session)
            sessionStore.indexForSpotlight()
            dismiss()
            return
        }

        let sshpass = SSHToolLocator.sshpass
        let ssh     = SSHToolLocator.ssh
        let command = "\(sshpass) -p '\(trimPass)' \(ssh) \(SSHDoubleHop.sshOptions) \(trimUser)@\(trimHost)"
        let tabName = host.trimmingCharacters(in: .whitespaces)
        activeTerminals.openCommand(command, name: "Thin \(tabName)")
        dismiss()
    }
}
