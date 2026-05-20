// ProxyJumpComposerView.swift — Helmsman
// Visual editor for multi-hop ProxyJump chains.
// Each hop can be tested individually before saving.

import SwiftUI
import SSHKit

struct ProxyJumpComposerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var hops: [ProxyJumpHop]

    let targetHost: String
    let targetPort: Int

    @State private var draftHops: [ProxyJumpHop] = []
    @State private var testResults: [Int: HopTestResult] = [:]
    @State private var testingIdx: Int?

    enum HopTestResult { case success, failure(String), testing }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Chain visualizer ─────────────────────────────────────────
                chainDiagram

                Divider()

                // ── Hop list ─────────────────────────────────────────────────
                List {
                    ForEach(draftHops.indices, id: \.self) { i in
                        HopRowView(
                            hop:        $draftHops[i],
                            index:      i,
                            testResult: testResults[i],
                            isTesting:  testingIdx == i,
                            onTest:     { testHop(at: i) },
                            onDelete:   { draftHops.remove(at: i) }
                        )
                    }
                    .onMove { src, dst in draftHops.move(fromOffsets: src, toOffset: dst) }
                }
                .listStyle(.inset)

                Divider()

                // ── Toolbar ──────────────────────────────────────────────────
                HStack {
                    Button {
                        draftHops.append(ProxyJumpHop(user: "", host: "", port: 22))
                    } label: {
                        Label("Add Hop", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text(chainSummary)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding()
            }
            .navigationTitle("ProxyJump Composer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        hops = draftHops
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 560, height: 520)
        .onAppear { draftHops = hops }
    }

    // MARK: - Chain diagram

    private var chainDiagram: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Mac → hops → target
                ChainNodeView(label: "This Mac", icon: "laptopcomputer", isTarget: false)
                ForEach(draftHops.indices, id: \.self) { i in
                    Image(systemName: "arrow.right").foregroundColor(.secondary).padding(.horizontal, 4)
                    ChainNodeView(label: draftHops[i].jumpString, icon: "server.rack", isTarget: false)
                }
                Image(systemName: "arrow.right").foregroundColor(.secondary).padding(.horizontal, 4)
                ChainNodeView(label: "\(targetHost):\(targetPort)", icon: "desktopcomputer", isTarget: true)
            }
            .padding()
        }
        .frame(height: 80)
        .background(Color.secondary.opacity(0.05))
    }

    // MARK: - Computed

    private var chainSummary: String {
        let chain = ProxyJumpChain(hops: draftHops)
        if let pj = chain.proxyJumpArgument {
            return "ssh -J \(pj) \(targetHost)"
        }
        return "ssh \(targetHost)  (direct)"
    }

    // MARK: - Hop testing

    private func testHop(at idx: Int) {
        testingIdx = idx
        testResults[idx] = .testing
        let hop = draftHops[idx]
        let prevHops = Array(draftHops.prefix(idx))
        let chain = ProxyJumpChain(hops: [])
        let argv = chain.testArgv(through: prevHops, testing: hop)

        Task {
            let result = await runSSHTest(argv: argv)
            await MainActor.run {
                testResults[idx] = result
                testingIdx = nil
            }
        }
    }

    private func runSSHTest(argv: [String]) async -> HopTestResult {
        await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            p.arguments     = argv
            p.standardOutput = FileHandle.nullDevice
            p.standardError  = FileHandle.nullDevice
            p.terminationHandler = { proc in
                continuation.resume(returning:
                    proc.terminationStatus == 0
                    ? .success
                    : .failure("Exit code \(proc.terminationStatus)")
                )
            }
            do {
                try p.run()
            } catch {
                continuation.resume(returning: .failure(error.localizedDescription))
            }
        }
    }
}

// MARK: - Hop Row

private struct HopRowView: View {
    @Binding var hop: ProxyJumpHop
    let index:      Int
    let testResult: ProxyJumpComposerView.HopTestResult?
    let isTesting:  Bool
    let onTest:   () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hop \(index + 1)").font(.headline)
                Spacer()
                testStatusView
                Button(action: onTest) {
                    Label("Test", systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.bordered)
                .disabled(isTesting || hop.host.isEmpty)
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Alias").foregroundColor(.secondary).font(.caption)
                    TextField("ssh config alias (optional)", text: Binding(
                        get: { hop.sshConfigAlias ?? "" },
                        set: { hop.sshConfigAlias = $0.isEmpty ? nil : $0 }
                    ))
                    .font(.caption.monospaced())
                }
                GridRow {
                    Text("User").foregroundColor(.secondary).font(.caption)
                    TextField("admin", text: $hop.user).font(.caption.monospaced())
                }
                GridRow {
                    Text("Host").foregroundColor(.secondary).font(.caption)
                    TextField("bastion.example.com", text: $hop.host).font(.caption.monospaced())
                }
                GridRow {
                    Text("Port").foregroundColor(.secondary).font(.caption)
                    TextField("22", value: $hop.port, format: .number)
                        .frame(width: 60).font(.caption.monospaced())
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var testStatusView: some View {
        switch testResult {
        case .none:    EmptyView()
        case .success: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .failure(let msg):
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                .help(msg)
        case .testing:
            ProgressView().scaleEffect(0.7)
        }
    }
}

// MARK: - Chain Node

private struct ChainNodeView: View {
    let label:    String
    let icon:     String
    let isTarget: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isTarget ? .accentColor : .secondary)
            Text(label)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .frame(maxWidth: 100)
        }
    }
}
