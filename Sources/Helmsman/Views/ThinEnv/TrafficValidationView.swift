// TrafficValidationView.swift — probe builder for traffic + verdict stream proof

import SwiftUI
import TerminalKit

struct TrafficValidationView: View {
    let snapshot: ClusterSnapshot
    let session: TerminalSession

    @State private var sourceNS = ""
    @State private var sourcePod = ""
    @State private var destNS = ""
    @State private var destPod = ""
    @State private var destPort = "9001"
    @State private var protocol_ = "TCP"
    @State private var expected = "blocked"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build traffic validation probes. Commands run in the active cluster terminal.")
                .font(.caption2)
                .foregroundColor(.secondary)

            field("Source NS", $sourceNS)
            field("Source Pod", $sourcePod)
            field("Dest NS", $destNS)
            field("Dest Pod", $destPod)
            field("Dest Port", $destPort)
            field("Protocol", $protocol_)

            Picker("Expected", selection: $expected) {
                Text("blocked").tag("blocked")
                Text("allowed").tag("allowed")
            }
            .pickerStyle(.segmented)

            ClusterTerminalActionButton(
                label: "1. Locate source pod node",
                command: "kubectl get pod -n \(sourceNS) \(sourcePod) -o wide",
                session: session
            )
            .disabled(sourceNS.isEmpty || sourcePod.isEmpty)

            ClusterTerminalActionButton(
                label: "2. Find agent on source node",
                command: """
                NODE=$(kubectl get pod -n \(sourceNS) \(sourcePod) -o jsonpath='{.spec.nodeName}'); kubectl get pods -n guardicore -o wide | grep "$NODE"
                """,
                session: session
            )
            .disabled(sourceNS.isEmpty || sourcePod.isEmpty)

            ClusterTerminalActionButton(
                label: "3. nc probe from source pod",
                command: """
                kubectl exec -n \(sourceNS) \(sourcePod) -- sh -c "nc -zv \(destPod).\(destNS).svc.cluster.local \(destPort) 2>&1 || nc -zv \(destPod) \(destPort) 2>&1"
                """,
                session: session
            )
            .disabled(sourceNS.isEmpty || sourcePod.isEmpty || destPod.isEmpty)

            ClusterTerminalActionButton(
                label: "4. Verdict stream grep (source-node agent)",
                command: verdictGrepCommand,
                session: session
            )
            .disabled(sourceNS.isEmpty || sourcePod.isEmpty)

            Text("For blocked_by_source: check gc-verdict-stream.log on the source pod's node agent, not the destination.")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .frame(width: 72, alignment: .leading)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
        }
    }

    private var verdictGrepCommand: String {
        """
        SRC_IP=$(kubectl get pod -n \(sourceNS) \(sourcePod) -o jsonpath='{.status.podIP}'); NODE=$(kubectl get pod -n \(sourceNS) \(sourcePod) -o jsonpath='{.spec.nodeName}'); AGENT=$(kubectl get pods -n guardicore -o wide | grep "$NODE" | grep daemonset | awk '{print $1}'); kubectl exec -n guardicore $AGENT -- sh -c "grep 'SRC='$SRC_IP /var/log/gc-k8s-verdict-reporter.log | grep 'DPT=\(destPort)' | grep 'PROTO=\(protocol_)' | tail -10"
        """
    }
}
