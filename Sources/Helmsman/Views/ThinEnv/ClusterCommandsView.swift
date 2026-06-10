// ClusterCommandsView.swift — grouped kubectl command launcher

import SwiftUI
import TerminalKit

struct ClusterCommandsView: View {
    let session: TerminalSession
    var clusterType: String? = nil

    @AppStorage(ClusterCustomCommandsStorage.appStorageKey)
    private var customCommandsBlob: String = ""
    @State private var customCommandInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ClusterCommands.groups(forClusterType: clusterType), id: \.title) { group in
                ClusterCommandGroupView(
                    title: group.title,
                    icon: group.icon,
                    commands: group.commands,
                    session: session
                )
            }

            if !customCommandsList.isEmpty {
                ClusterCommandGroupView(
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
                    TextField("kubectl …", text: $customCommandInput)
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

private struct ClusterCommandGroupView: View {
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
