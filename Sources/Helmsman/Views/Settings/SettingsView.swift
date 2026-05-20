// SettingsView.swift — Helmsman

import SwiftUI
import CoreSpotlight
import VaultKit

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @EnvironmentObject var kubeStore:    KubeStore

    @AppStorage("helmsman.privacy.disableSpotlight")  private var disableSpotlight  = false
    @AppStorage("helmsman.terminal.scrollback")        private var scrollback         = 10000
    @AppStorage("helmsman.updates.autoCheck")          private var autoCheckUpdates   = true
    @AppStorage("helmsman.sftp.trackCwd")              private var trackCwd           = true

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General",   systemImage: "gear") }
            securityTab
                .tabItem { Label("Security",  systemImage: "lock.shield") }
            terminalTab
                .tabItem { Label("Terminal",  systemImage: "terminal") }
            profilesTab
                .tabItem { Label("Profiles",  systemImage: "person.2") }
            updatesTab
                .tabItem { Label("Updates",   systemImage: "arrow.down.circle") }
        }
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Spotlight") {
                Toggle("Disable Spotlight indexing of session names / hosts", isOn: $disableSpotlight)
                    .onChange(of: disableSpotlight) { _ in
                        if disableSpotlight {
                            CSSearchableIndex.default().deleteAllSearchableItems { _ in }
                        } else {
                            sessionStore.indexForSpotlight()
                        }
                    }
                Text("When disabled, no session data is sent to the Spotlight index.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("SFTP") {
                Toggle("Track terminal cwd in SFTP pane (requires OSC 7 in shell)", isOn: $trackCwd)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Security

    private var securityTab: some View {
        Form {
            Section("Touch ID") {
                LabeledContent("Status") {
                    Text(TouchIDAuth.isAvailable ? "Available ✓" : "Not available")
                        .foregroundColor(TouchIDAuth.isAvailable ? .green : .red)
                }
                Text("Touch ID is used to unlock the session vault and gate sudo proxy operations.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Keychain") {
                Text("Credentials are stored in separate Keychain items per secret class (identity passphrase, gateway password, vault unlock). No passwords are stored in plain-text files.")
                    .font(.caption).foregroundColor(.secondary)
                Button("Open Keychain Access") {
                    NSWorkspace.shared.open(
                        URL(fileURLWithPath: "/System/Applications/Utilities/Keychain Access.app")
                    )
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Terminal

    private var terminalTab: some View {
        Form {
            Section("Buffer") {
                LabeledContent("Scrollback lines") {
                    Stepper("\(scrollback)", value: $scrollback, in: 1000...100000, step: 1000)
                }
            }
            Section("Transcripts") {
                LabeledContent("Location") {
                    Button("Open Transcripts Folder") {
                        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                               in: .userDomainMask).first!
                        NSWorkspace.shared.open(support.appendingPathComponent("Helmsman/transcripts"))
                    }
                    .buttonStyle(.bordered)
                }
                Text("Per-session transcripts are stored in ~/Library/Application Support/Helmsman/transcripts/")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Profiles

    private var profilesTab: some View {
        VStack(alignment: .leading) {
            Text("Workspace Profiles").font(.headline)
            Table(sessionStore.profiles) {
                TableColumn("Name", value: \.name)
                TableColumn("Type") { p in Text(p.kind.rawValue) }
                TableColumn("Stored Passwords") { p in
                    Image(systemName: p.allowsStoredPasswords ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(p.allowsStoredPasswords ? .orange : .green)
                }
            }
            Text("Production profiles reject password-based Keychain entries and skip-host-key-checking. Lab profiles permit both.")
                .font(.caption).foregroundColor(.secondary).padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Updates

    private var updatesTab: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: $autoCheckUpdates)
                Button("Check Now") {
                    (NSApp.delegate as? AppDelegate)?.checkForUpdates(nil)
                }
                .buttonStyle(.bordered)
                Text("Updates are delivered via Sparkle with EdDSA signatures. You can hold a specific version by disabling automatic checks.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}


