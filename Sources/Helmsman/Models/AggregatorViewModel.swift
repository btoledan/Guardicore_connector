// AggregatorViewModel.swift — Gardicol Connector
// Background monicore-ctrl collection and snapshot assembly for aggregator terminal tabs.

import Foundation
import TerminalKit

struct AggregatorService: Identifiable, Hashable {
    let name: String
    let state: String

    var id: String { name }
    var isRunning: Bool { state.uppercased() == "RUNNING" }
}

struct AggregatorSystemResources: Hashable {
    let cpu: Double
    let memory: Double
    let swap: Double
    let disk: Double
}

struct AggregatorSnapshot {
    let services: [AggregatorService]
    let resources: AggregatorSystemResources?
    let fetchedAt: Date

    var runningCount: Int { services.filter(\.isRunning).count }
    var totalCount: Int { services.count }
    var stoppedServices: [AggregatorService] { services.filter { !$0.isRunning } }
    var allHealthy: Bool { !services.isEmpty && runningCount == totalCount }
}

@MainActor
final class AggregatorViewModel: ObservableObject {

    @Published private(set) var snapshot: AggregatorSnapshot?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    let session: TerminalSession

    private static var cache: [UUID: AggregatorSnapshot] = [:]
    private var activeRefreshID = UUID()

    init(session: TerminalSession) {
        self.session = session
        self.snapshot = Self.cache[session.id]
    }

    func refresh() async {
        guard let remoteBase = session.spec.metadata["guardicoreRemoteBase"] else {
            snapshot = nil
            errorMessage = nil
            return
        }
        guard !isRefreshing else { return }

        let refreshID = UUID()
        activeRefreshID = refreshID
        isRefreshing = true
        errorMessage = nil

        // Flat status is bulletproof for the service list; verbose adds system resources.
        async let statusTask = ClusterShellRunner.run(
            Self.remote(remoteBase, "monicore-ctrl status"),
            timeout: 30
        )
        async let verboseTask = ClusterShellRunner.run(
            Self.remote(remoteBase, "monicore-ctrl status all -v"),
            timeout: 45
        )

        let status = await statusTask
        let verbose = await verboseTask

        guard activeRefreshID == refreshID else { return }

        let services = Self.parseServices(status.output)
        let resources = Self.parseResources(verbose.output)

        if services.isEmpty {
            errorMessage = status.timedOut
                ? "monicore-ctrl status timed out."
                : "Could not read aggregator services. Check the connection."
        }

        let snap = AggregatorSnapshot(services: services, resources: resources, fetchedAt: Date())
        snapshot = snap
        Self.cache[session.id] = snap
        isRefreshing = false
    }

    // MARK: - Remote command assembly

    nonisolated private static func remote(_ base: String, _ command: String) -> String {
        let escaped = command
            // Survive the local double-quoted hop-1 command before reaching the tester.
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\"", with: "\\\"")
            // The final remote command is single-quoted by SSHDoubleHop.
            .replacingOccurrences(of: "'", with: "'\\''")
        return base.replacingOccurrences(of: "'__CMD_PLACEHOLDER__'", with: "'\(escaped)'")
    }

    // MARK: - Parsing

    /// Parses the flat `monicore-ctrl status` dict, e.g. `'gc-enforcement': RUNNING,`.
    nonisolated static func parseServices(_ output: String) -> [AggregatorService] {
        guard let regex = try? NSRegularExpression(
            pattern: "'([A-Za-z0-9_.-]+)'\\s*:\\s*([A-Z][A-Z_]+)"
        ) else { return [] }

        var services: [AggregatorService] = []
        var seen = Set<String>()

        output.enumerateLines { line, _ in
            let ns = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                let name = ns.substring(with: match.range(at: 1))
                let state = ns.substring(with: match.range(at: 2))
                // Skip the nested keys that only appear in verbose output.
                if name == "application-status" || name == "service-status" || name == "services-status" { continue }
                guard !seen.contains(name) else { continue }
                seen.insert(name)
                services.append(AggregatorService(name: name, state: state))
            }
        }
        return services.sorted { $0.name < $1.name }
    }

    /// Extracts the `system-resources` line from verbose output:
    /// `cpu:9.3% memory:46.5% swap:0.0% disk:36.3%`.
    nonisolated static func parseResources(_ output: String) -> AggregatorSystemResources? {
        guard let regex = try? NSRegularExpression(
            pattern: "cpu:([0-9.]+)%\\s*memory:([0-9.]+)%\\s*swap:([0-9.]+)%\\s*disk:([0-9.]+)%"
        ) else { return nil }

        let ns = output as NSString
        guard let match = regex.firstMatch(in: output, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        func value(_ index: Int) -> Double {
            Double(ns.substring(with: match.range(at: index))) ?? 0
        }
        return AggregatorSystemResources(cpu: value(1), memory: value(2), swap: value(3), disk: value(4))
    }
}
