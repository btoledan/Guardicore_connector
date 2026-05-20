// ExportConnectionView.swift — Helmsman
// Exports connection strings (ssh, scp, KUBECONFIG) for runbooks / chat pastes.
// Template mode adds {{NAMESPACE}} etc. placeholders; off by default.

import SwiftUI
import SSHKit

struct ExportConnectionView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss

    let session: Session

    @State private var templateMode = false
    @State private var copied: String?

    private var profile: WorkspaceProfile {
        sessionStore.profiles.first { $0.id == session.workspaceProfileID } ?? .defaultProd
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Toggle("Template mode (adds {{PLACEHOLDER}} tokens)", isOn: $templateMode)
                    .padding()
                    .help("Enable to generate reusable templates with placeholder tokens")

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        exportBlock(
                            title: "SSH Connection",
                            icon:  "terminal.fill",
                            text:  sshOneLiner
                        )
                        exportBlock(
                            title: "SCP (copy to home dir)",
                            icon:  "arrow.up.doc",
                            text:  scpOneLiner
                        )
                        if !session.tunnels.isEmpty {
                            exportBlock(
                                title: "Tunnels only (ssh -N)",
                                icon:  "arrow.left.arrow.right.circle",
                                text:  tunnelOneLiner
                            )
                        }
                        if let kubeCtx = session.associatedKubeContext {
                            exportBlock(
                                title: "KUBECONFIG export",
                                icon:  "cloud",
                                text:  "export KUBECONFIG=~/.kube/config\nexport KUBE_CONTEXT=\(kubeCtx)"
                            )
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Export Connection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 560, height: 480)
    }

    // MARK: - Computed strings

    private var spec: SessionSpec { session.sessionSpec() }

    private var sshOneLiner: String {
        guard case .ssh(let d, let chain, _) = spec else {
            return session.connectionOneLiner()
        }
        if templateMode {
            return "ssh -J {{JUMP_HOST}} {{USER}}@{{TARGET_HOST}}"
        }
        return d.sshOneLiner(chain: chain)
    }

    private var scpOneLiner: String {
        guard case .ssh(let d, let chain, _) = spec else { return "" }
        if templateMode {
            return "scp {{LOCAL_FILE}} {{USER}}@{{TARGET_HOST}}:{{REMOTE_PATH}}"
        }
        return d.scpOneLiner(localPath: "{{LOCAL_FILE}}", remotePath: "~/")
    }

    private var tunnelOneLiner: String {
        guard case .ssh(let d, let chain, let tunnels) = spec, !tunnels.isEmpty else { return "" }
        let argv = chain.tunnelArgv(for: d, tunnels: tunnels)
        return (["/usr/bin/ssh"] + argv).joined(separator: " ")
    }

    // MARK: - Export block

    @ViewBuilder
    private func exportBlock(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)

            HStack(alignment: .top) {
                Text(text)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = nil }
                } label: {
                    Image(systemName: copied == title ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copied == title ? .green : .accentColor)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
        }
    }
}
