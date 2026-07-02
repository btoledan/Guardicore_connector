// ClusterAutoSync.swift — Gardicol Connector
// Probes the well-known cluster IPs through a thin env's double-hop SSH and
// reports which cluster types are reachable, so they can be added automatically.

import Foundation

enum ClusterAutoSync {

    /// Cluster types that live on deterministic, type-specific IPs and can be
    /// auto-detected. `.custom` is excluded — those are added manually.
    static let probeableTypes: [GuardicoreCluster.ClusterType] = [
        .rancher, .rke2, .k3s, .openshift
    ]

    struct ProbeResult: Sendable {
        let type: GuardicoreCluster.ClusterType
        let ip: String
        let reachable: Bool
    }

    /// Probes every well-known cluster IP in parallel through the env's
    /// double-hop SSH and returns one result per candidate type.
    static func probe(
        env: ThinEnvironment,
        timeoutPerProbe: TimeInterval = 18
    ) async -> [ProbeResult] {
        await withTaskGroup(of: ProbeResult.self) { group in
            for type in probeableTypes {
                group.addTask {
                    await probeOne(type: type, env: env, timeout: timeoutPerProbe)
                }
            }
            var results: [ProbeResult] = []
            for await result in group {
                results.append(result)
            }
            // Keep a stable, predictable order for the UI.
            return results.sorted {
                (probeableTypes.firstIndex(of: $0.type) ?? 0)
                    < (probeableTypes.firstIndex(of: $1.type) ?? 0)
            }
        }
    }

    private static let probeToken = "gc-probe-ok"

    private static func probeOne(
        type: GuardicoreCluster.ClusterType,
        env: ThinEnvironment,
        timeout: TimeInterval
    ) async -> ProbeResult {
        let ip = type.defaultIP
        guard !ip.isEmpty else {
            return ProbeResult(type: type, ip: ip, reachable: false)
        }

        // A trivial remote command: it only runs once both SSH hops connect, so
        // a printed token confirms the cluster node is actually reachable.
        let probe = GuardicoreCluster(type: type)
        let command = probe.clusterRemoteCommand(
            "echo \(probeToken)",
            through: env
        )

        let result = await ClusterShellRunner.run(command, timeout: timeout)
        let reachable = !result.timedOut
            && result.exitCode == 0
            && result.output.contains(probeToken)
        return ProbeResult(type: type, ip: ip, reachable: reachable)
    }
}
