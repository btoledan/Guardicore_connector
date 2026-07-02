// GuardicoreStatusView.swift — DaemonSet, agents, gc-kube-enforce, gc-kube-inventory

import SwiftUI
import TerminalKit

struct GuardicoreStatusView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    @State private var logBrowserAgent: GuardicoreAgent?
    @State private var pendingReset: PendingReset?

    /// CLI tool for this cluster (kubectl, or oc on OpenShift).
    private var cli: String { session.spec.metadata["guardicoreCLI"] ?? "kubectl" }
    private let namespace = "guardicore"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dsSection
            kubeEnforceSection
            kubeInventorySection
            agentsSection
            eventsSection
        }
        .sheet(item: $logBrowserAgent) { agent in
            PodLogBrowserSheet(
                podName: agent.podName,
                namespace: namespace,
                cli: cli,
                session: session,
                remoteBase: session.spec.metadata["guardicoreRemoteBase"]
            )
        }
        .alert(item: $pendingReset) { reset in
            Alert(
                title: Text(reset.title),
                message: Text(reset.detail + "\n\n" + reset.command),
                primaryButton: .destructive(Text(reset.confirmLabel)) {
                    session.run(reset.command)
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var dsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DaemonSet gc-agents-daemonset")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                dsMetric("Desired", snapshot.guardicore.daemonSetDesired)
                dsMetric("Current", snapshot.guardicore.daemonSetCurrent)
                dsMetric("Ready", snapshot.guardicore.daemonSetReady)
                dsMetric("Available", snapshot.guardicore.daemonSetAvailable)
            }
            ClusterTerminalActionButton(
                label: "kubectl get ds -n guardicore",
                command: "kubectl get ds -n guardicore",
                session: session
            )
            ClusterTerminalActionButton(
                label: "describe ds gc-agents-daemonset",
                command: "kubectl describe ds gc-agents-daemonset -n guardicore",
                session: session
            )
            Button(role: .destructive) {
                pendingReset = PendingReset(
                    title: "Reset Deployment?",
                    confirmLabel: "Restart All",
                    detail: "Rolling-restarts every GC agent pod in the DaemonSet.",
                    command: "\(cli) rollout restart ds/gc-agents-daemonset -n \(namespace)"
                )
            } label: {
                Label("Reset Deployment (rollout restart)", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.orange)
        }
        .padding(8)
        .background(Color.purple.opacity(0.06))
        .cornerRadius(8)
    }

    private func dsMetric(_ label: String, _ value: Int?) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value.map(String.init) ?? "—")
                .font(.caption.weight(.semibold))
        }
    }

    private var kubeEnforceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("gc-kube-enforce")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            HStack {
                Text("Ready: \(snapshot.guardicore.kubeEnforceReady ?? "—")")
                    .font(.caption)
                if let node = snapshot.guardicore.kubeEnforceNode {
                    Text("on \(node)")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            ClusterTerminalActionButton(
                label: "kubectl get deploy -n guardicore",
                command: "kubectl get deploy -n guardicore",
                session: session
            )
            ClusterTerminalActionButton(
                label: "logs deploy/gc-kube-enforce --tail=80",
                command: "kubectl logs -n guardicore deploy/gc-kube-enforce --tail=80",
                session: session
            )
        }
        .padding(8)
        .background(Color.indigo.opacity(0.06))
        .cornerRadius(8)
    }

    private var kubeInventorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("gc-kube-inventory")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            HStack {
                Text("Ready: \(snapshot.guardicore.kubeInventoryReady ?? "—")")
                    .font(.caption)
                if let pod = snapshot.guardicore.inventoryPods.first {
                    Text("on \(pod.node)")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            ClusterTerminalActionButton(
                label: "kubectl get sts -n guardicore",
                command: "kubectl get sts -n guardicore",
                session: session
            )
            ClusterTerminalActionButton(
                label: "kubectl get pods -n guardicore | grep inventory",
                command: "kubectl get pods -n guardicore -o wide | grep gc-kube-inventory",
                session: session
            )

            if snapshot.guardicore.inventoryPods.isEmpty {
                Text("No gc-kube-inventory pod found in guardicore namespace.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.guardicore.inventoryPods) { pod in
                    inventoryPodRow(pod)
                }
            }
        }
        .padding(8)
        .background(Color.teal.opacity(0.06))
        .cornerRadius(8)
    }

    private func inventoryPodRow(_ pod: GuardicoreInventoryPod) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(pod.status.lowercased() == "running" ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(pod.podName)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                Spacer()
                Text(pod.ready)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Text(pod.node).font(.caption2)
                Text(pod.ip).font(.caption2.monospaced())
                Text("↺ \(pod.restarts)").font(.caption2)
            }
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
                miniAction("shell", "kubectl exec -it \(pod.podName) -n guardicore -- /bin/sh")
                miniAction("logs", "kubectl logs -n guardicore \(pod.podName) --tail=80")
                miniAction("describe", "kubectl describe pod \(pod.podName) -n guardicore")
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Agents (\(snapshot.guardicore.agents.count))")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            if snapshot.guardicore.agents.isEmpty {
                Text("No agent pods found in guardicore namespace.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.guardicore.agents) { agent in
                    agentRow(agent)
                }
            }
        }
    }

    private func agentRow(_ agent: GuardicoreAgent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(agent.status.lowercased() == "running" ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(agent.podName)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                Spacer()
            }
            HStack(spacing: 8) {
                Text(agent.node).font(.caption2)
                Text("↺ \(agent.restarts)").font(.caption2)
                if let rev = agent.policyRevision {
                    Text("rev \(rev)").font(.caption2).foregroundColor(.purple)
                }
            }
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
                miniAction("shell", "\(cli) exec -it \(agent.podName) -n \(namespace) -- /bin/sh")
                miniAction("pod logs", "\(cli) logs -n \(namespace) \(agent.podName) --tail=200")
                Button {
                    logBrowserAgent = agent
                } label: {
                    Label("logs…", systemImage: "doc.text.magnifyingglass")
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            HStack(spacing: 4) {
                miniAction("policy log", """
                \(cli) exec -n \(namespace) \(agent.podName) -- sh -c "grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -10"
                """)
                miniAction("verdict", """
                \(cli) exec -n \(namespace) \(agent.podName) -- sh -c "tail -50 /var/log/gc-k8s-verdict-reporter.log"
                """)
                Button(role: .destructive) {
                    pendingReset = PendingReset(
                        title: "Restart Pod?",
                        confirmLabel: "Restart",
                        detail: "Deletes \(agent.podName); the DaemonSet recreates it automatically.",
                        command: "\(cli) delete pod \(agent.podName) -n \(namespace)"
                    )
                } label: {
                    Label("restart pod", systemImage: "arrow.clockwise")
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.orange)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private func miniAction(_ label: String, _ cmd: String) -> some View {
        Button(label) { session.run(cmd) }
            .font(.caption2)
            .buttonStyle(.bordered)
            .controlSize(.mini)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent events")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            if snapshot.guardicore.eventsTail.isEmpty {
                Text("No events captured.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    Text(snapshot.guardicore.eventsTail)
                        .font(.caption2.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
        }
    }
}

/// A disruptive action awaiting user confirmation before it runs in the terminal.
struct PendingReset: Identifiable {
    let id = UUID()
    let title: String
    let confirmLabel: String
    let detail: String
    let command: String
}
