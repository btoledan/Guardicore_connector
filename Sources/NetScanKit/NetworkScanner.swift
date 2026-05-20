// NetworkScanner.swift — NetScanKit
// Async LAN host discovery: ICMP ping via ping(8) + TCP connect probing.
// Uses Network.framework (NWConnection) for TCP; no raw sockets required.

import Foundation
import Network

public final class NetworkScanner: ObservableObject, @unchecked Sendable {

    public static let shared = NetworkScanner()

    @MainActor @Published public private(set) var state: ScanState = .idle
    @MainActor @Published public private(set) var discovered: [ScanResult] = []

    private var scanTask: Task<Void, Never>?

    // MARK: - Public API

    /// Scans the given subnet (e.g., "192.168.1") for live hosts.
    /// - Parameters:
    ///   - subnet:        The /24 prefix without trailing dot.
    ///   - ports:         Which TCP ports to probe on each live host. Defaults to common services.
    ///   - maxConcurrent: Maximum simultaneous ping processes (default: 40).
    @MainActor
    public func scan(
        subnet: String,
        ports: [Int] = WellKnownPort.allCases.map(\.rawValue),
        maxConcurrent: Int = 40
    ) {
        cancel()
        discovered = []
        state = .running(progress: 0)

        scanTask = Task {
            await self.performScan(subnet: subnet, ports: ports, maxConcurrent: maxConcurrent)
        }
    }

    @MainActor
    public func cancel() {
        scanTask?.cancel()
        scanTask = nil
        if case .running = state { state = .cancelled }
    }

    // MARK: - Internal scan

    private func performScan(subnet: String, ports: [Int], maxConcurrent: Int) async {
        let total = 254
        var completed = 0
        var results: [ScanResult] = []

        await withTaskGroup(of: ScanResult?.self) { group in
            var activeCount = 0
            for i in 1...254 {
                if Task.isCancelled { break }

                if activeCount >= maxConcurrent {
                    if let result = await group.next() {
                        completed += 1
                        let pct = Double(completed) / Double(total)
                        await MainActor.run {
                            self.state = .running(progress: min(pct, 1.0))
                            if let r = result {
                                results.append(r)
                                self.discovered = (self.discovered + [r]).sorted { $0.host < $1.host }
                            }
                        }
                    }
                    activeCount -= 1
                }

                let host = "\(subnet).\(i)"
                let p = ports
                group.addTask { [weak self] in
                    await self?.probeHost(host: host, ports: p)
                }
                activeCount += 1
            }

            for await result in group {
                completed += 1
                let pct = Double(completed) / Double(total)
                await MainActor.run {
                    self.state = .running(progress: min(pct, 1.0))
                    if let r = result {
                        results.append(r)
                        self.discovered = (self.discovered + [r]).sorted { $0.host < $1.host }
                    }
                }
            }
        }

        if Task.isCancelled {
            await MainActor.run { self.state = .cancelled }
        } else {
            let sorted = results.sorted { $0.host < $1.host }
            await MainActor.run {
                self.discovered = sorted
                self.state = .finished(sorted)
            }
        }
    }

    // MARK: - Host probe

    private func probeHost(host: String, ports: [Int]) async -> ScanResult? {
        guard await pingHost(host) else { return nil }
        var open: [Int] = []
        for port in ports {
            if await tcpConnect(host: host, port: port) { open.append(port) }
        }
        return ScanResult(host: host, openPorts: open)
    }

    // MARK: - ping(8) reachability

    private func pingHost(_ host: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/sbin/ping")
            // -c 1: one packet, -W 500: 500ms timeout, -q: quiet
            p.arguments = ["-c", "1", "-W", "500", "-q", host]
            p.standardOutput = FileHandle.nullDevice
            p.standardError  = FileHandle.nullDevice
            p.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            do {
                try p.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - TCP connect probe (Network.framework)

    private func tcpConnect(host: String, port: Int) async -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return false }

        return await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: nwPort,
                using: .tcp
            )
            let queue = DispatchQueue(label: "netscan.\(host).\(port)", qos: .utility)
            var resolved = false

            let timeout = DispatchWorkItem {
                guard !resolved else { return }
                resolved = true
                conn.cancel()
                continuation.resume(returning: false)
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !resolved else { return }
                    resolved = true
                    timeout.cancel()
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .waiting:
                    guard !resolved else { return }
                    resolved = true
                    timeout.cancel()
                    conn.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }

            conn.start(queue: queue)
            // 1.5 s connect timeout per port
            queue.asyncAfter(deadline: .now() + 1.5, execute: timeout)
        }
    }
}
