// ClusterViewModel.swift — Gardicol Connector
// Background kubectl collection and ClusterSnapshot assembly for cluster terminal tabs.

import Foundation
import TerminalKit

@MainActor
final class ClusterViewModel: ObservableObject {

    @Published private(set) var snapshot: ClusterSnapshot?
    @Published private(set) var refreshStage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isEnriching = false

    let session: TerminalSession

    private static var cache: [UUID: ClusterSnapshot] = [:]
    private var activeRefreshID = UUID()

    init(session: TerminalSession) {
        self.session = session
        self.snapshot = Self.cache[session.id]
    }

    func refresh() async {
        guard let remoteBase = session.spec.metadata["guardicoreRemoteBase"] else {
            snapshot = nil
            refreshStage = nil
            return
        }
        // Block if either phase is active — the 60-second timer must not interrupt Phase 2
        // enrichment, otherwise the new refreshID invalidates the in-flight Phase 2 guard.
        guard !isRefreshing && !isEnriching else { return }

        let cli = session.spec.metadata["guardicoreCLI"] ?? "kubectl"
        let isOpenShift = (session.spec.metadata["guardicoreClusterType"] == GuardicoreCluster.ClusterType.openshift.rawValue)

        let refreshID = UUID()
        activeRefreshID = refreshID
        isRefreshing = true
        refreshStage = "Starting…"

        var raw = RawClusterOutputs()
        var warnings: [String] = []

        // Phase 1 — minimal fast commands: create a snapshot quickly so tabs stop loading.
        refreshStage = "Fetching nodes & pods…"
        let coreResults = await fetchParallel(
            remoteBase: remoteBase,
            commands: [
                ("version", "\(cli) version --short 2>/dev/null || \(cli) version", 15),
                ("nodesJSON", "\(cli) get nodes -o json", 20),
                ("podsJSON", "\(cli) get pods -A -o json", 45),
            ]
        )

        guard activeRefreshID == refreshID else { return }

        applyResults(coreResults, to: &raw, warnings: &warnings)
        snapshot = buildSnapshot(raw: raw, warnings: warnings)
        Self.cache[session.id] = snapshot
        isRefreshing = false

        // Phase 2 — enrichment; UI already shows topology.
        isEnriching = true
        refreshStage = "Fetching Guardicore details…"

        let agentRevCmd = """
        for pod in $(\(cli) get pods -n guardicore -o name | grep daemonset); do echo "=== $pod ==="; \(cli) exec -n guardicore $pod -- sh -c "tail -200 /var/log/gc-enforcement-policy.log 2>/dev/null | grep -i 'Policy revision' | tail -1"; done
        """
        // Calico revision grep only applies to non-OpenShift clusters
        let calicoRevCmd = isOpenShift ? "echo 'OpenShift: no Calico'" : """
        (kubectl get networkpolicies -A -o yaml 2>/dev/null; kubectl get networkpolicies.crd.projectcalico.org -A -o yaml 2>/dev/null) | grep -E 'guardicore/policy-revision|guardicore/dc-inventory-revision|^  name:|^  namespace:' || true
        """

        var detailCommands: [(key: String, cmd: String, timeout: TimeInterval)] = [
            ("guardicorePodsJSON", "\(cli) get pods -n guardicore -o json", 20),
            ("daemonSetJSON", "\(cli) get ds -n guardicore -o json", 20),
            ("deploymentsJSON", "\(cli) get deploy -n guardicore -o json", 20),
            ("statefulSetsJSON", "\(cli) get sts -n guardicore -o json", 20),
            ("nodesLabels", "\(cli) get nodes --show-labels", 25),
            ("events", "\(cli) get events -n guardicore --sort-by='.lastTimestamp' | tail -30", 25),
            ("kubeEnforceLogs", "\(cli) logs -n guardicore deploy/gc-kube-enforce --tail=80", 30),
            ("standardNetworkPolicies", "\(cli) get networkpolicies.networking.k8s.io -A", 25),
            ("agentPolicyRevisionLogs", agentRevCmd, 90),
        ]

        if isOpenShift {
            // OpenShift: also fetch guardicore-orch namespace; skip Calico-specific commands
            detailCommands.append((key: "orchPodsJSON", cmd: "oc get pods -n guardicore-orch -o json", timeout: 20))
        } else {
            // Standard kubectl clusters: Calico + kube-inventory
            detailCommands.append(contentsOf: [
                (key: "calicoPoliciesJSON", cmd: "kubectl get networkpolicies.crd.projectcalico.org -A -o json", timeout: 25),
                (key: "calicoPoliciesList", cmd: "kubectl get networkpolicies.crd.projectcalico.org -A", timeout: 25),
                (key: "calicoRevisionGrep", cmd: calicoRevCmd, timeout: 45),
                (key: "kubeInventoryLogs", cmd: "POD=$(kubectl get pods -n guardicore -o name 2>/dev/null | grep gc-kube-inventory | head -1 | sed 's|pod/||'); [ -n \"$POD\" ] && kubectl logs -n guardicore \"$POD\" --tail=80 || true", timeout: 30),
            ])
        }

        let detailResults = await fetchParallel(remoteBase: remoteBase, commands: detailCommands)

        guard activeRefreshID == refreshID else { return }

        applyResults(detailResults, to: &raw, warnings: &warnings)
        snapshot = buildSnapshot(raw: raw, warnings: warnings)
        Self.cache[session.id] = snapshot
        isEnriching = false
        refreshStage = nil
    }

    func exportSnapshotMarkdown() -> String {
        ClusterSnapshotExport.markdown(snapshot)
    }

    func exportSnapshotJSON() -> String {
        ClusterSnapshotExport.json(snapshot)
    }

    // MARK: - Private

    private struct FetchResult {
        let key: String
        let exitCode: Int32
        let output: String
        let timedOut: Bool
    }

    private func fetchParallel(
        remoteBase: String,
        commands: [(key: String, cmd: String, timeout: TimeInterval)]
    ) async -> [FetchResult] {
        // Limit concurrency to avoid dropping SSH connections on the bastion host.
        // sshd MaxStartups is often 10, so 10 concurrent unauthenticated connections can fail.
        let maxConcurrent = 3
        
        return await withTaskGroup(of: FetchResult.self) { group in
            var results: [FetchResult] = []
            var index = 0
            
            // Add initial batch
            while index < min(maxConcurrent, commands.count) {
                let item = commands[index]
                group.addTask {
                    let escaped = Self.escapeCommandForRemoteBase(item.cmd)
                    let shell = remoteBase.replacingOccurrences(
                        of: "'__KUBECTL_PLACEHOLDER__'",
                        with: "'\(escaped)'"
                    )
                    let result = await ClusterShellRunner.run(shell, timeout: item.timeout)
                    return FetchResult(
                        key: item.key,
                        exitCode: result.exitCode,
                        output: result.output,
                        timedOut: result.timedOut
                    )
                }
                index += 1
            }
            
            // Add remaining as tasks complete
            for await r in group {
                results.append(r)
                if index < commands.count {
                    let item = commands[index]
                    group.addTask {
                        let escaped = Self.escapeCommandForRemoteBase(item.cmd)
                        let shell = remoteBase.replacingOccurrences(
                            of: "'__KUBECTL_PLACEHOLDER__'",
                            with: "'\(escaped)'"
                        )
                        let result = await ClusterShellRunner.run(shell, timeout: item.timeout)
                        return FetchResult(
                            key: item.key,
                            exitCode: result.exitCode,
                            output: result.output,
                            timedOut: result.timedOut
                        )
                    }
                    index += 1
                }
            }
            return results
        }
    }

    nonisolated private static func escapeCommandForRemoteBase(_ command: String) -> String {
        command
            // The inner ssh command is itself inside a local double-quoted hop command.
            // Keep these characters from being expanded by the local shell before hop 1.
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\"", with: "\\\"")
            // Final remote command is single-quoted by SSHDoubleHop.shellQuote.
            .replacingOccurrences(of: "'", with: "'\\''")
    }

    private func applyResults(
        _ results: [FetchResult],
        to raw: inout RawClusterOutputs,
        warnings: inout [String]
    ) {
        for r in results {
            switch r.key {
            case "version": raw.version = r.output
            case "nodesJSON": raw.nodesJSON = r.output
            case "podsJSON": raw.podsJSON = r.output
            case "guardicorePodsJSON": raw.guardicorePodsJSON = r.output
            case "daemonSetJSON": raw.daemonSetJSON = r.output
            case "deploymentsJSON": raw.deploymentsJSON = r.output
            case "statefulSetsJSON": raw.statefulSetsJSON = r.output
            case "calicoPoliciesJSON": raw.calicoPoliciesJSON = r.output
            case "nodesWide": raw.nodesWide = r.output
            case "nodesLabels": raw.nodesLabels = r.output
            case "podsAllWide": raw.podsAllWide = r.output
            case "guardicorePodsWide": raw.guardicorePodsWide = r.output
            case "daemonSet": raw.daemonSet = r.output
            case "deployments": raw.deployments = r.output
            case "events": raw.events = r.output
            case "kubeEnforceLogs": raw.kubeEnforceLogs = r.output
            case "kubeInventoryLogs": raw.kubeInventoryLogs = r.output
            case "standardNetworkPolicies": raw.standardNetworkPolicies = r.output
            case "calicoPoliciesList": raw.calicoPoliciesList = r.output
            case "calicoRevisionGrep": raw.calicoRevisionGrep = r.output
            case "agentPolicyRevisionLogs": raw.agentPolicyRevisionLogs = r.output
            default: break
            }

            if r.timedOut {
                let label = RawClusterOutputs.displayKeys.first { $0.key == r.key }?.label ?? r.key
                warnings.append("\(label) timed out")
            } else if r.exitCode != 0 && r.key != "version" {
                let label = RawClusterOutputs.displayKeys.first { $0.key == r.key }?.label ?? r.key
                warnings.append("\(label) failed (exit \(r.exitCode))")
            }
        }
        warnings = Array(Set(warnings)).sorted()
    }

    private func buildSnapshot(raw: RawClusterOutputs, warnings: [String]) -> ClusterSnapshot {
        // Prefer JSON parsing; fall back to text tables if JSON unavailable
        var nodes = KubeJSONParser.parseNodesJSON(raw.nodesJSON)
        if nodes.isEmpty { nodes = ClusterSnapshotParser.parseNodesWide(raw.nodesWide) }

        var pods = KubeJSONParser.parsePodsJSON(raw.podsJSON)
        if pods.isEmpty { pods = ClusterSnapshotParser.parsePodsWide(raw.podsAllWide) }

        var gcPods = KubeJSONParser.parsePodsJSON(raw.guardicorePodsJSON, namespaceFilter: "guardicore")
        if gcPods.isEmpty { gcPods = ClusterSnapshotParser.parsePodsWide(raw.guardicorePodsWide) }

        var allWarnings = warnings
        if nodes.isEmpty && (!raw.nodesJSON.isEmpty || !raw.nodesWide.isEmpty) {
            allWarnings.append("Could not parse nodes — check Raw tab.")
        }

        var ds = KubeJSONParser.parseDaemonSetJSON(raw.daemonSetJSON)
        if ds.desired == nil {
            ds = ClusterSnapshotParser.parseDaemonSet(raw.daemonSet)
        }

        var calico = KubeJSONParser.parseCalicoPoliciesJSON(raw.calicoPoliciesJSON)
        if calico.isEmpty {
            calico = ClusterSnapshotParser.parseCalicoPoliciesList(raw.calicoPoliciesList)
        }
        calico = ClusterSnapshotParser.enrichCalicoRevisions(calico, yamlGrep: raw.calicoRevisionGrep)

        let agents = ClusterSnapshotParser.parseGuardicoreAgents(
            pods: gcPods.isEmpty ? pods.filter(\.isGC) : gcPods,
            revisionLogs: raw.agentPolicyRevisionLogs
        )
        let inventoryPods = ClusterSnapshotParser.parseGuardicoreInventoryPods(
            pods: gcPods.isEmpty ? pods.filter(\.isGC) : gcPods
        )
        let kubeEnforce = (gcPods.isEmpty ? pods : gcPods).first(where: \.isKubeEnforce)

        var deployReady = KubeJSONParser.parseDeploymentJSON(raw.deploymentsJSON)
        if deployReady == nil {
            deployReady = ClusterSnapshotParser.parseDeploymentReady(raw.deployments)
        }

        var inventoryReady = KubeJSONParser.parseStatefulSetReady(raw.statefulSetsJSON)
        if inventoryReady == nil {
            inventoryReady = inventoryPods.first?.ready
        }

        return ClusterSnapshot(
            fetchedAt: Date(),
            version: ClusterSnapshotParser.parseVersion(raw.version),
            nodes: nodes,
            pods: pods,
            guardicore: GuardicoreSnapshot(
                daemonSetDesired: ds.desired,
                daemonSetCurrent: ds.current,
                daemonSetReady: ds.ready,
                daemonSetAvailable: ds.available,
                kubeEnforceReady: deployReady ?? kubeEnforce?.ready,
                kubeEnforceNode: kubeEnforce?.node,
                kubeInventoryReady: inventoryReady,
                inventoryPods: inventoryPods,
                agents: agents,
                eventsTail: raw.events,
                kubeEnforceLogTail: raw.kubeEnforceLogs,
                kubeInventoryLogTail: raw.kubeInventoryLogs
            ),
            policies: PolicySnapshot(
                standardNetworkPoliciesRaw: raw.standardNetworkPolicies,
                calicoPolicies: calico,
                revisions: ClusterSnapshotParser.parseRevisionGrep(raw.calicoRevisionGrep)
            ),
            raw: raw,
            warnings: allWarnings
        )
    }
}

// MARK: - Shell runner

enum ClusterShellRunner {
    static func run(
        _ command: String,
        timeout: TimeInterval = 30
    ) async -> (exitCode: Int32, output: String, timedOut: Bool) {
        guard !command.isEmpty else { return (1, "No remote command.", false) }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                // Use exec so the launched process is sshpass/ssh, not a parent bash that can
                // exit while child SSH processes keep the pipe open.
                process.arguments = ["-lc", "exec \(command)"]
                process.standardOutput = pipe
                process.standardError = pipe

                let lock = NSLock()
                var resumed = false
                var timedOut = false
                var collected = Data()

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    lock.lock()
                    collected.append(data)
                    lock.unlock()
                }

                func finish(_ code: Int32, _ output: String) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: (code, output, timedOut))
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    lock.lock()
                    let stillRunning = process.isRunning
                    lock.unlock()
                    if stillRunning {
                        timedOut = true
                        process.terminate()
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            if process.isRunning {
                                process.interrupt()
                            }
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    // Do not call readDataToEndOfFile here: SSH descendants can hold the pipe open.
                    lock.lock()
                    let data = collected
                    lock.unlock()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let code: Int32 = timedOut ? 124 : process.terminationStatus
                    let suffix = timedOut ? "\n\n(timed out after \(Int(timeout))s)" : ""
                    finish(code, output + suffix)
                } catch {
                    finish(1, error.localizedDescription)
                }
            }
        }
    }
}
