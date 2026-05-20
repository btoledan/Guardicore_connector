// AppCommands.swift — Helmsman
// SwiftUI menu bar commands.

import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var activeTerminals: ActiveTerminalsStore

    var body: some Commands {
        // ── Session menu ────────────────────────────────────────────────────
        CommandMenu("Session") {
            Button("New SSH Session…") {
                activeTerminals.showNewSession = true
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("New Local Shell") {
                activeTerminals.openLocalShell()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Duplicate Tab") {
                activeTerminals.duplicateActive()
            }
            .keyboardShortcut("d", modifiers: [.command])

            Button("Close Tab") {
                activeTerminals.closeActive()
            }
            .keyboardShortcut("w", modifiers: [.command])

            Divider()

            Button("Export Connection String…") {
                activeTerminals.showExport = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        // ── Terminal menu ───────────────────────────────────────────────────
        CommandMenu("Terminal") {
            Button("Next Tab") {
                activeTerminals.selectNextTab()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("Previous Tab") {
                activeTerminals.selectPreviousTab()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Divider()

            Button("Multi-Exec…") {
                activeTerminals.showMultiExec = true
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Button("Reveal Transcript in Finder") {
                activeTerminals.revealTranscript()
            }

            Divider()

            Button("Reconnect") {
                activeTerminals.reconnectActive()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // ── View menu additions ─────────────────────────────────────────────
        CommandGroup(after: .toolbar) {
            Button("Toggle SFTP Pane") {
                activeTerminals.toggleSFTP()
            }
            .keyboardShortcut("\\", modifiers: [.command])

            Button("Toggle Kube Context Dock") {
                activeTerminals.toggleKubeDock()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        // ── Help additions ──────────────────────────────────────────────────
        CommandGroup(replacing: .help) {
            Button("Helmsman Help") {
                NSWorkspace.shared.open(URL(string: "https://helmsman.app/docs")!)
            }
            Button("Open Transcript Folder") {
                let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                       in: .userDomainMask).first!
                NSWorkspace.shared.open(support.appendingPathComponent("Helmsman/transcripts"))
            }
        }
    }
}
