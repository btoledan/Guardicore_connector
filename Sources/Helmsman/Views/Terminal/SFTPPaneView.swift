// SFTPPaneView.swift — Helmsman
// Graphical file browser for the remote SFTP side of an SSH session.
// Tracks cwd via OSC 7 (session.currentDirectory).
//
// KNOWN LIMITS (documented per PRD):
//  • cwd tracking relies on the shell emitting OSC 7 (file://hostname/path).
//    Add `precmd() { printf '\033]7;file://%s%s\033\\' "$(hostname)" "$PWD" }` to ~/.zshrc.
//  • sudo shells, ForceCommand, and non-interactive shells won't emit OSC 7.
//  • Use the "Sync to Terminal Path" button to manually align.

import SwiftUI
import TerminalKit

struct SFTPPaneView: View {
    @ObservedObject var session: TerminalSession
    @EnvironmentObject var activeTerminals: ActiveTerminalsStore

    @State private var remotePath: String = "~"
    @State private var items: [RemoteItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var sftpProcess: Process?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .onChange(of: session.currentDirectory) { newDir in
            guard let dir = newDir else { return }
            // OSC 7 gives file://hostname/path — extract path
            if let url = URL(string: dir) { remotePath = url.path }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.caption)
            TextField("Remote path", text: $remotePath)
                .font(.caption.monospaced())
                .textFieldStyle(.plain)
                .onSubmit { loadDirectory(remotePath) }
            Spacer()
            Button {
                if let dir = session.currentDirectory,
                   let url = URL(string: dir) {
                    remotePath = url.path
                    loadDirectory(remotePath)
                }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Sync to terminal's current directory")

            Button {
                activeTerminals.showSFTPPane = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .help("Close SFTP pane")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = error {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text(err).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button("Retry") { loadDirectory(remotePath) }.font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            Text("No files or directory not loaded")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items) { item in
                RemoteItemRow(item: item, onNavigate: { loadDirectory(item.path) })
            }
            .listStyle(.plain)
        }
    }

    // MARK: - SFTP listing

    /// Loads directory listing via `sftp` subprocess (ls -la equivalent via sftp protocol).
    /// In v1, this runs `sftp -b -` (batch mode) with an `ls` command.
    private func loadDirectory(_ path: String) {
        isLoading = true
        error     = nil
        Task {
            // Build sftp target from the session spec
            let spec    = session.spec
            let target  = spec.name  // e.g., "user@host"
            let command = "ls -la \(path)\nbye\n"
            let result  = await runSFTPCommand(target: target, command: command)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let output):
                    items = parseLSOutput(output, basePath: path)
                    remotePath = path
                case .failure(let msg):
                    error = msg.message
                }
            }
        }
    }

    private func runSFTPCommand(target: String, command: String) async -> Result<String, SFTPCommandError> {
        await withCheckedContinuation { continuation in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/sftp")
            p.arguments = ["-b", "-", "-q", target]

            let inPipe  = Pipe()
            let outPipe = Pipe()
            let errPipe = Pipe()
            p.standardInput  = inPipe
            p.standardOutput = outPipe
            p.standardError  = errPipe

            do {
                try p.run()
                inPipe.fileHandleForWriting.write(command.data(using: .utf8)!)
                inPipe.fileHandleForWriting.closeFile()
                p.waitUntilExit()
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(),
                                 encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    continuation.resume(returning: .success(out))
                } else {
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                                     encoding: .utf8) ?? "Unknown error"
                    continuation.resume(
                        returning: .failure(
                            SFTPCommandError(message: err.trimmingCharacters(in: .whitespacesAndNewlines))
                        )
                    )
                }
            } catch {
                continuation.resume(returning: .failure(SFTPCommandError(message: error.localizedDescription)))
            }
        }
    }

    private func parseLSOutput(_ output: String, basePath: String) -> [RemoteItem] {
        // Parse `ls -la` style output from sftp
        output.components(separatedBy: .newlines)
            .filter { !$0.isEmpty && !$0.hasPrefix("sftp>") }
            .compactMap { line -> RemoteItem? in
                // drwxr-xr-x  2 user group 4096 May  4 12:00 dirname
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 9 else { return nil }
                let permissions = String(parts[0])
                let name        = parts[8...].joined(separator: " ")
                guard name != "." && name != ".." else { return nil }
                let isDir = permissions.hasPrefix("d") || permissions.hasPrefix("l")
                let fullPath = basePath.hasSuffix("/")
                    ? "\(basePath)\(name)"
                    : "\(basePath)/\(name)"
                return RemoteItem(name: name, path: fullPath,
                                  isDirectory: isDir, permissions: permissions)
            }
    }
}

// MARK: - Remote Item

struct RemoteItem: Identifiable {
    var id: String { path }
    let name:        String
    let path:        String
    let isDirectory: Bool
    let permissions: String
}

struct SFTPCommandError: Error {
    let message: String
}

struct RemoteItemRow: View {
    let item: RemoteItem
    let onNavigate: () -> Void

    var body: some View {
        HStack {
            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                .foregroundColor(item.isDirectory ? .blue : .primary)
                .font(.caption)
            Text(item.name)
                .font(.caption.monospaced())
                .lineLimit(1)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if item.isDirectory { onNavigate() }
        }
        .help(item.path)
    }
}
