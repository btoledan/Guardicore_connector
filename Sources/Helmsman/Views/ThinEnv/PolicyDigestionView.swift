// PolicyDigestionView.swift — Did the rule reach the cluster dataplane?

import SwiftUI
import TerminalKit

struct PolicyDigestionView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            digestionCallout
            revisionChain
            policyTable
        }
    }

    private var digestionCallout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Policy Digestion")
                .font(.caption.bold())
            Text("Answers: did CM rules materialize as Calico CRDs with correct Deny actions and matching revisions?")
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                statPill("Allow", snapshot.policies.calicoPolicies.filter(\.isAllow).count, .green)
                statPill("Block", snapshot.policies.calicoPolicies.filter(\.isBlock).count, .red)
                statPill("Deny ✓", snapshot.blockRulesWithDeny, .green)
                statPill("Deny ?", snapshot.blockRulesMissingDeny, .orange)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(8)
    }

    private func statPill(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(count)").font(.caption.weight(.bold)).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }

    private var revisionChain: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Revision alignment")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            ForEach(snapshot.revisionAlignment.steps) { step in
                HStack(spacing: 6) {
                    Image(systemName: step.status.symbol)
                        .font(.caption2)
                        .foregroundColor(step.status == .ok ? .green : .orange)
                    Text(step.label).font(.caption2)
                    Spacer()
                    Text(step.value).font(.caption2.monospaced()).foregroundColor(.secondary)
                }
            }
            if snapshot.revisionAlignment.isAligned {
                Label("Agent and Calico revisions match — cluster digested", systemImage: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Label("Revision mismatch — policy sync may be pending", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private var policyTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calico CRD rules (\(snapshot.policies.calicoPolicies.count))")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            if snapshot.policies.calicoPolicies.isEmpty {
                Text("No Calico CRDs found. On Calico/KO, Guardicore rules appear under networkpolicies.crd.projectcalico.org — not standard v1 NetworkPolicy.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.policies.calicoPolicies) { policy in
                    policyCard(policy)
                }
            }
        }
    }

    private func policyCard(_ policy: CalicoPolicy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(policy.shortRuleID ?? policy.ruleUUID ?? "—")
                    .font(.caption2.weight(.bold).monospaced())
                Text(policy.isBlock ? "BLOCK" : "ALLOW")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(policy.isBlock ? .red : .green)
                Spacer()
                if policy.isBlock {
                    Text(policy.hasDeny ? "Deny ✓" : "Deny missing")
                        .font(.caption2)
                        .foregroundColor(policy.hasDeny ? .green : .red)
                }
            }
            Text(policy.name)
                .font(.caption2.monospaced())
                .lineLimit(2)
            HStack(spacing: 8) {
                Text("ns: \(policy.namespace)").font(.caption2)
                if let dir = policy.direction { Text(dir).font(.caption2) }
                if let rev = policy.policyRevision {
                    Text("rev \(rev)").font(.caption2).foregroundColor(.purple)
                }
            }
            .foregroundColor(.secondary)

            HStack(spacing: 4) {
                miniBtn("YAML actions") {
                    session.run("""
                    kubectl get networkpolicies.crd.projectcalico.org -n \(policy.namespace) \(policy.name) -o yaml | grep -E '^  - action:'
                    """)
                }
                miniBtn("Full YAML") {
                    session.run("kubectl get networkpolicies.crd.projectcalico.org -n \(policy.namespace) \(policy.name) -o yaml")
                }
            }
        }
        .padding(8)
        .background((policy.dataplaneProven ? Color.green : Color.orange).opacity(0.06))
        .cornerRadius(6)
    }

    private func miniBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .font(.caption2)
            .buttonStyle(.bordered)
            .controlSize(.mini)
    }
}
