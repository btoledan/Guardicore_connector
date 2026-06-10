// GuardicoreStatusView.swift — DaemonSet, agents, gc-kube-enforce, gc-kube-inventory

import SwiftUI
import TerminalKit

struct GuardicoreStatusView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dsSection
            kubeEnforceSection
            kubeInventorySection
            agentsSection
            eventsSection
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
                miniAction("shell", "kubectl exec -it \(agent.podName) -n guardicore -- /bin/sh")
                miniAction("policy log", """
                kubectl exec -n guardicore \(agent.podName) -- sh -c "grep -i 'Policy revision' /var/log/gc-enforcement-policy.log 2>/dev/null | tail -10"
                """)
                miniAction("verdict", """
                kubectl exec -n guardicore \(agent.podName) -- sh -c "tail -50 /var/log/gc-k8s-verdict-reporter.log"
                """)
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
