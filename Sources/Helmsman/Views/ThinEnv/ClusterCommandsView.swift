// ClusterCommandsView.swift — grouped kubectl command launcher

import SwiftUI
import TerminalKit

struct ClusterCommandsView: View {
    let session: TerminalSession

    @AppStorage("gardicol.clusterCustomCommands")
    private var customCommandsBlob: String = ""
    @State private var customCommandInput = ""

    private let commandGroups: [(title: String, icon: String, commands: [String])] = [
        ("Quick Status", "bolt.fill", [
            "kubectl get nodes -o wide",
            "kubectl get pods -n guardicore -o wide",
            "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
        ]),
        ("Cluster Triage", "magnifyingglass", [
            "kubectl version --short 2>/dev/null || kubectl version",
            "kubectl get nodes -o wide",
            "kubectl get nodes --show-labels",
            "kubectl get pods -n kube-system -o wide",
            "kubectl get ns",
            "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
        ]),
        ("Guardicore System", "shield.lefthalf.filled", [
            "kubectl get pods -n guardicore -o wide",
            "kubectl get ds -n guardicore",
            "kubectl get deploy -n guardicore",
            "kubectl describe ds gc-agents-daemonset -n guardicore",
            "kubectl get events -n guardicore --sort-by='.lastTimestamp' | tail -30",
            "kubectl logs -n guardicore deploy/gc-kube-enforce --tail=80",
        ]),
        ("Policy / CNI", "network", [
            "kubectl get networkpolicies.networking.k8s.io -A",
            "kubectl get networkpolicies.crd.projectcalico.org -A",
        ]),
        ("Agent Debug", "ant.fill", [
            "for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; kubectl exec -n guardicore $pod -- sh -c \"grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -3\"; done",
            "for pod in $(kubectl get pods -n guardicore -o name | grep daemonset); do echo \"=== $pod ===\"; kubectl exec -n guardicore $pod -- sh -c \"grep -i 'enforcement policy' /var/log/gc-enforcement-agent.log 2>/dev/null | tail -2\"; done",
        ]),
        ("Quick Health", "heart.fill", [
            "kubectl get nodes -o wide",
            "kubectl get pods -A | grep -vE '^(NAMESPACE|.*Running|.*Completed)'",
            "kubectl get componentstatuses 2>/dev/null || kubectl get --raw /readyz?verbose",
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(commandGroups, id: \.title) { group in
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
        customCommandsBlob.split(separator: "\n").map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func addCustomCommand() {
        let cmd = customCommandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty, !customCommandsList.contains(cmd) else {
            customCommandInput = ""
            return
        }
        customCommandsBlob = (customCommandsList + [cmd]).joined(separator: "\n")
        customCommandInput = ""
    }

    private func removeCustomCommand(_ cmd: String) {
        customCommandsBlob = customCommandsList.filter { $0 != cmd }.joined(separator: "\n")
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
