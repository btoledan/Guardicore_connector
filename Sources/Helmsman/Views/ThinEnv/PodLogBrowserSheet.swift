// PodLogBrowserSheet.swift — Gardicol Connector
// Lists the log files under /var/log inside a GC agent pod and opens a chosen log
// in the cluster terminal with a selectable tail size or a continuous follow (-f).

import SwiftUI
import TerminalKit

struct PodLogBrowserSheet: View {
    let podName: String
    let namespace: String
    let cli: String
    let session: TerminalSession
    /// The cluster's double-hop remote-command template (with '__KUBECTL_PLACEHOLDER__').
    /// Used to list files in the background; nil when a reconnect is required.
    let remoteBase: String?

    @Environment(\.dismiss) private var dismiss

    /// Pinned log file names, persisted across sessions (newline-separated).
    @AppStorage("gardicol.pinnedPodLogs") private var pinnedRaw: String = ""

    @State private var files: [String] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedFile: String = ""
    @State private var manualFile: String = ""
    @State private var tailLines = 200
    @State private var follow = false

    private let logDir = "/var/log"
    private let tailOptions = [100, 200, 300, 400, 500, 1000]

    /// Logs we always know exist for GC agents, shown if listing fails.
    private let knownLogs = [
        "gc-enforcement-policy.log",
        "gc-enforcement-agent.log",
        "gc-k8s-verdict-reporter.log",
    ]

    private var effectiveFile: String {
        let manual = manualFile.trimmingCharacters(in: .whitespaces)
        return manual.isEmpty ? selectedFile : manual
    }

    /// Ordered list of pinned file names.
    private var pinnedFiles: [String] {
        pinnedRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private func isPinned(_ file: String) -> Bool {
        pinnedFiles.contains(file)
    }

    private func togglePin(_ file: String) {
        var pins = pinnedFiles
        if let idx = pins.firstIndex(of: file) {
            pins.remove(at: idx)
        } else {
            pins.append(file)
        }
        pinnedRaw = pins.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            fileList
            Divider()
            options
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 460, height: 520)
        .task { await loadFiles() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("Pod Logs")
                    .font(.headline)
                Spacer()
                if isLoading { ProgressView().scaleEffect(0.6) }
                Button {
                    Task { await loadFiles() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Re-list \(logDir)")
            }
            Text(podName)
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text("\(logDir) · namespace \(namespace)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - File list

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LOG FILES")
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            if let loadError {
                Text(loadError)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(displayedFiles, id: \.self) { file in
                        logRow(file)
                    }
                }
            }
            .frame(maxHeight: 200)

            HStack(spacing: 6) {
                Text("Or path:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                TextField("custom-file.log", text: $manualFile)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
            }
        }
    }

    private func logRow(_ file: String) -> some View {
        let pinned = isPinned(file)
        return HStack(spacing: 6) {
            Button {
                selectedFile = file
                manualFile = ""
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: effectiveFile == file ? "largecircle.fill.circle" : "circle")
                        .font(.caption2)
                        .foregroundColor(effectiveFile == file ? .accentColor : .secondary)
                    Text(file)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button {
                togglePin(file)
            } label: {
                Image(systemName: pinned ? "pin.fill" : "pin")
                    .font(.caption2)
                    .foregroundColor(pinned ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(pinned ? "Unpin" : "Pin to top")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(effectiveFile == file ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(5)
    }

    private var displayedFiles: [String] {
        let base = files.isEmpty ? knownLogs : files
        let pins = pinnedFiles.filter { base.contains($0) }
        let rest = base.filter { !pins.contains($0) }
        return pins + rest
    }

    // MARK: - Options

    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $follow) {
                Text("Follow (tail -f, continuous)")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack(spacing: 6) {
                Text("Lines")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Picker("", selection: $tailLines) {
                    ForEach(tailOptions, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .opacity(follow ? 0.5 : 1)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(commandPreview)
                .font(.caption2.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer()
            Button("Cancel") { dismiss() }
                .controlSize(.small)
            Button("Open") {
                session.run(buildCommand())
                dismiss()
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .disabled(effectiveFile.isEmpty)
        }
    }

    // MARK: - Command building

    private var commandPreview: String {
        guard !effectiveFile.isEmpty else { return "Select a log file" }
        return buildCommand()
    }

    private func buildCommand() -> String {
        let path = effectiveFile.hasPrefix("/") ? effectiveFile : "\(logDir)/\(effectiveFile)"
        let tailArgs = follow ? "tail -f -n \(tailLines)" : "tail -n \(tailLines)"
        return "\(cli) exec -it \(podName) -n \(namespace) -- \(tailArgs) \(path)"
    }

    // MARK: - File listing

    private func loadFiles() async {
        guard let remoteBase else {
            loadError = "Reconnect required to list files; showing known logs."
            return
        }
        isLoading = true
        loadError = nil

        let listCmd = "\(cli) exec \(podName) -n \(namespace) -- sh -c 'ls -1 \(logDir) 2>/dev/null'"
        let full = Self.remoteCommand(base: remoteBase, listCmd)
        let result = await ClusterShellRunner.run(full, timeout: 25)

        let parsed = result.output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains(" ") && $0 != "total" }

        await MainActor.run {
            isLoading = false
            if parsed.isEmpty {
                loadError = result.timedOut
                    ? "Listing timed out; showing known logs."
                    : "Could not list \(logDir); showing known logs."
            } else {
                files = parsed.sorted()
                if selectedFile.isEmpty {
                    selectedFile = files.first { $0.hasSuffix(".log") } ?? files.first ?? ""
                }
            }
        }
    }

    private static func remoteCommand(base: String, _ command: String) -> String {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "'\\''")
        return base.replacingOccurrences(of: "'__KUBECTL_PLACEHOLDER__'", with: "'\(escaped)'")
    }
}
