// NetworkScannerView.swift — Helmsman
// LAN host discovery: subnet input, live results table, one-click SSH.

import SwiftUI
import NetScanKit
import SSHKit
import TerminalKit

struct NetworkScannerView: View {
    @EnvironmentObject var sessionStore:    SessionStore
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore
    @Environment(\.dismiss) var dismiss

    @StateObject private var scanner = NetworkScanner.shared
    @State private var subnet:  String = ""
    @State private var portsSelection: Set<Int> = Set(WellKnownPort.allCases.map(\.rawValue))

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scanControls
                Divider()
                resultsTable
            }
            .navigationTitle("Network Scanner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(width: 560, height: 480)
        .onAppear { guessSubnet() }
    }

    // MARK: - Controls

    private var scanControls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Subnet (e.g. 192.168.1)").font(.caption).foregroundColor(.secondary)
                TextField("192.168.1", text: $subnet)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
            }

            Spacer()

            if case .running(let pct) = scanner.state {
                ProgressView(value: pct)
                    .frame(width: 100)
                Button("Cancel", role: .cancel) { scanner.cancel() }
                    .buttonStyle(.bordered)
            } else {
                Button("Scan /24") {
                    let ports = Array(portsSelection)
                    scanner.scan(subnet: subnet, ports: ports)
                }
                .buttonStyle(.borderedProminent)
                .disabled(subnet.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    // MARK: - Results table

    @ViewBuilder
    private var resultsTable: some View {
        if scanner.discovered.isEmpty {
            if case .idle = scanner.state {
                Text("Enter a subnet and press Scan.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .running = scanner.state {
                Text("Scanning…")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            Table(scanner.discovered) {
                TableColumn("Host", value: \.host)
                TableColumn("Open Ports") { result in
                    Text(result.portSummary)
                        .font(.caption.monospaced())
                }
                TableColumn("Connect") { result in
                    if result.hasSSH {
                        Button("SSH") { quickSSH(result) }
                            .buttonStyle(.bordered)
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func guessSubnet() {
        // Attempt to read the default gateway subnet from route
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/sbin/route")
        p.arguments = ["-n", "get", "default"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        for line in out.components(separatedBy: .newlines) {
            if line.contains("gateway:") {
                let parts = line.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
                if let gw = parts.last {
                    let octets = gw.components(separatedBy: ".")
                    if octets.count == 4 {
                        subnet = octets.prefix(3).joined(separator: ".")
                    }
                }
            }
        }
    }

    private func quickSSH(_ result: ScanResult) {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let spec = AnySessionSpec(
            name:          result.host,
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            args:          [result.host]
        )
        let term = TerminalSession(spec: spec)
        activeTerminals.tabs.append(term)
        activeTerminals.selectedTabID = term.id
        dismiss()
    }
}
