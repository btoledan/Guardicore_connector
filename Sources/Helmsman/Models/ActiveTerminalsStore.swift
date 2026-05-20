// ActiveTerminalsStore.swift — Helmsman
// Observable store managing open terminal tabs and their UI state.

import Foundation
import SwiftUI
import TerminalKit
import SSHKit
import KubeKit

@MainActor
public final class ActiveTerminalsStore: ObservableObject {

    // MARK: - Tabs

    @Published public var tabs: [TerminalSession] = []
    @Published public var selectedTabID: UUID?

    // MARK: - UI toggles

    @Published public var showNewSession:  Bool = false
    @Published public var showMultiExec:   Bool = false
    @Published public var showExport:      Bool = false
    @Published public var showSFTPPane:    Bool = true
    @Published public var showKubeDock:    Bool = false

    // MARK: - Active tab

    public var activeTab: TerminalSession? {
        guard let id = selectedTabID else { return tabs.first }
        return tabs.first { $0.id == id }
    }

    // MARK: - Tab management

    public func open(session: Session, profile: WorkspaceProfile) {
        let anySpec = session.anySpec(profile: profile)
        let term    = TerminalSession(spec: anySpec)
        tabs.append(term)
        selectedTabID = term.id
    }

    public func openLocalShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let spec = AnySessionSpec(
            name:          "Local Shell",
            executableURL: URL(fileURLWithPath: shell),
            args:          []
        )
        let term = TerminalSession(spec: spec)
        tabs.append(term)
        selectedTabID = term.id
    }

    public func closeActive() {
        guard let id = selectedTabID else { return }
        close(id: id)
    }

    public func close(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        // Select adjacent tab
        if tabs.isEmpty {
            selectedTabID = nil
        } else {
            let newIdx = min(idx, tabs.count - 1)
            selectedTabID = tabs[newIdx].id
        }
    }

    public func duplicateActive() {
        guard let active = activeTab else { return }
        let dup = TerminalSession(spec: active.spec)
        tabs.append(dup)
        selectedTabID = dup.id
    }

    public func selectNextTab() {
        guard let id = selectedTabID,
              let idx = tabs.firstIndex(where: { $0.id == id }),
              tabs.count > 1 else { return }
        selectedTabID = tabs[(idx + 1) % tabs.count].id
    }

    public func selectPreviousTab() {
        guard let id = selectedTabID,
              let idx = tabs.firstIndex(where: { $0.id == id }),
              tabs.count > 1 else { return }
        selectedTabID = tabs[(idx + tabs.count - 1) % tabs.count].id
    }

    public func reconnectActive() {
        activeTab?.reconnect()
    }

    // MARK: - Multi-exec

    /// Sends `command` to every tab in `targetIDs`. Returns list of tabs that received it.
    @discardableResult
    public func multiExec(command: String, targetIDs: Set<UUID>, dryRun: Bool) -> [String] {
        let targets = tabs.filter { targetIDs.contains($0.id) }
        guard !dryRun else {
            return targets.map { "[\($0.title)] $ \(command)" }
        }
        for tab in targets {
            tab.run(command)
        }
        return targets.map { $0.title }
    }

    // MARK: - UI helpers

    public func toggleSFTP() { showSFTPPane.toggle() }
    public func toggleKubeDock() { showKubeDock.toggle() }

    public func revealTranscript() {
        activeTab?.transcriptWriter.revealInFinder()
    }

    public func showExportSheet() { showExport = true }

    // MARK: - Quick-connect via raw shell command (thin envs / clusters)

    /// Launches `/bin/bash -c command` in a new terminal tab.
    /// Used for sshpass double-hop connections to thin environments and clusters.
    public func openCommand(
        _ command: String,
        name: String,
        metadata: [String: String] = [:]
    ) {
        let spec = AnySessionSpec(
            name:          name,
            executableURL: URL(fileURLWithPath: "/bin/bash"),
            args:          ["-c", command],
            metadata:      metadata
        )
        let term = TerminalSession(spec: spec)
        tabs.append(term)
        selectedTabID = term.id
    }
}

// MARK: - KubeStore

@MainActor
public final class KubeStore: ObservableObject {
    public static let shared = KubeStore()

    @Published public var contexts:      [KubeContext] = []
    @Published public var pinnedContext: KubeContext?
    @Published public var isLoading:     Bool = false
    @Published public var loadError:     String?

    private init() {}

    public func reload() {
        isLoading = true
        loadError = nil
        Task {
            do {
                contexts = try await KubeConfigParser.load()
                if pinnedContext == nil { pinnedContext = contexts.first }
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }

    public func pin(_ context: KubeContext) { pinnedContext = context }
}


