// ClusterPoliciesView.swift — Calico CRDs and revision alignment

import SwiftUI
import TerminalKit

struct ClusterPoliciesView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            revisionCallout
            calicoSection
            standardSection
        }
    }

    private var revisionCallout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: snapshot.policies.revisionAligned ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(snapshot.policies.revisionAligned ? .green : .yellow)
                Text(snapshot.policies.revisionAligned ? "Revision aligned" : "Revision mismatch possible")
                    .font(.caption.weight(.bold))
            }
            if !snapshot.policies.revisions.isEmpty {
                ForEach(Array(snapshot.policies.revisions).sorted().prefix(4), id: \.self) { line in
                    Text(line)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(8)
        .background((snapshot.policies.revisionAligned ? Color.green : Color.yellow).opacity(0.08))
        .cornerRadius(8)
    }

    private var calicoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calico CRDs (\(snapshot.policies.calicoPolicies.count))")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Text("Guardicore rules materialize here on Calico/KO — empty v1 NetworkPolicy list is expected.")
                .font(.caption2)
                .foregroundColor(.secondary)

            if snapshot.policies.calicoPolicies.isEmpty {
                Text("No Calico CRDs found.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.policies.calicoPolicies) { policy in
                    policyRow(policy)
                }
            }

            ClusterTerminalActionButton(
                label: "kubectl get networkpolicies.crd.projectcalico.org -A",
                command: "kubectl get networkpolicies.crd.projectcalico.org -A",
                session: session
            )
        }
    }

    private func policyRow(_ policy: CalicoPolicy) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(policy.isBlock ? "BLOCK" : "ALLOW")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background((policy.isBlock ? Color.red : Color.green).opacity(0.15))
                    .foregroundColor(policy.isBlock ? .red : .green)
                    .cornerRadius(3)
                Text(policy.name)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text(policy.namespace).font(.caption2)
                if let uuid = policy.ruleUUID {
                    Text("uuid \(uuid)").font(.caption2).foregroundColor(.secondary)
                }
                if policy.isBlock {
                    Text(policy.hasDeny ? "Deny ✓" : "Deny ?")
                        .font(.caption2)
                        .foregroundColor(policy.hasDeny ? .green : .orange)
                }
                if let rev = policy.policyRevision {
                    Text("rev \(rev)").font(.caption2).foregroundColor(.purple)
                }
            }
            Button("Show YAML action lines") {
                session.run("""
                kubectl get networkpolicies.crd.projectcalico.org -n \(policy.namespace) \(policy.name) -o yaml | grep -E '^  - action:'
                """)
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }

    private var standardSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Standard NetworkPolicies")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            if snapshot.policies.standardNetworkPoliciesRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("(empty — normal for Guardicore on Calico)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text(snapshot.policies.standardNetworkPoliciesRaw)
                    .font(.caption2.monospaced())
                    .lineLimit(6)
            }
        }
    }
}
