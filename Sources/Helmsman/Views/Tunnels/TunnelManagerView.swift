// TunnelManagerView.swift — Helmsman
// Add / edit / delete labeled SSH tunnels. Exports one-liners for runbooks.

import SwiftUI
import SSHKit

struct TunnelManagerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tunnels: [TunnelDescriptor]
    let sessionName: String

    @State private var draft: [TunnelDescriptor]
    @State private var selected: UUID?
    @State private var copied: UUID?

    init(tunnels: Binding<[TunnelDescriptor]>, sessionName: String) {
        _tunnels     = tunnels
        self.sessionName = sessionName
        _draft = State(initialValue: tunnels.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // ── Tunnel list ──────────────────────────────────────────────
                List(selection: $selected) {
                    ForEach($draft) { $t in
                        tunnelRow(t)
                            .tag(t.id)
                    }
                    .onDelete { draft.remove(atOffsets: $0) }
                }
                .listStyle(.sidebar)
                .frame(width: 220)

                Divider()

                // ── Editor ───────────────────────────────────────────────────
                if let id = selected, let idx = draft.firstIndex(where: { $0.id == id }) {
                    TunnelEditorView(tunnel: $draft[idx], onCopyOneLiner: { str in
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(str, forType: .string)
                        copied = id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = nil }
                    }, sshTarget: sessionName)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text("Select a tunnel or add a new one.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("SSH Tunnels — \(sessionName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { tunnels = draft; dismiss() }
                }
                ToolbarItem {
                    Button {
                        let t = TunnelDescriptor(localPort: 8080, remoteHost: "localhost", remotePort: 80)
                        draft.append(t)
                        selected = t.id
                    } label: { Image(systemName: "plus") }
                }
            }
        }
        .frame(width: 620, height: 420)
    }

    private func tunnelRow(_ t: TunnelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t.label.isEmpty ? t.kind.rawValue : t.label)
                .font(.body)
            Text(t.sshFlags.joined(separator: " "))
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Tunnel Editor

private struct TunnelEditorView: View {
    @Binding var tunnel: TunnelDescriptor
    let onCopyOneLiner: (String) -> Void
    let sshTarget: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Label") {
                TextField("My Tunnel", text: $tunnel.label)
            }
            LabeledContent("Type") {
                Picker("", selection: $tunnel.kind) {
                    ForEach(TunnelDescriptor.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            LabeledContent("Local Bind") {
                TextField("127.0.0.1", text: $tunnel.localBindAddress)
                    .frame(width: 120)
                Text(":").foregroundColor(.secondary)
                TextField("8080", value: $tunnel.localPort, format: .number)
                    .frame(width: 60)
            }
            if tunnel.kind != .dynamic {
                LabeledContent("Remote Host") {
                    TextField("remote-host", text: $tunnel.remoteHost).frame(width: 180)
                    Text(":").foregroundColor(.secondary)
                    TextField("80", value: $tunnel.remotePort, format: .number).frame(width: 60)
                }
            }

            Divider()

            // Generated flags
            VStack(alignment: .leading, spacing: 6) {
                Text("Generated flags").font(.caption).foregroundColor(.secondary)
                HStack {
                    Text(tunnel.sshFlags.joined(separator: " "))
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        onCopyOneLiner(tunnel.oneLiner(sshTarget: sshTarget))
                    } label: {
                        Label("Copy one-liner", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("Copy full ssh -L/-R/-D one-liner")
                }
            }
        }
    }
}
