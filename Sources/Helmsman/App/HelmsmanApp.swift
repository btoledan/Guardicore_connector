// HelmsmanApp.swift — Gardicol Connector

import SwiftUI
import Sparkle

@main
struct HelmsmanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var sessionStore    = SessionStore.shared
    @StateObject private var thinEnvStore    = ThinEnvStore.shared
    @StateObject private var kubeStore       = KubeStore.shared
    @StateObject private var activeTerminals = ActiveTerminalsStore()

    var body: some Scene {
        WindowGroup("Gardicol Connector") {
            RootContentView()
                .environmentObject(sessionStore)
                .environmentObject(thinEnvStore)
                .environmentObject(kubeStore)
                .environmentObject(activeTerminals)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            AppCommands(
                sessionStore:    sessionStore,
                activeTerminals: activeTerminals
            )
        }

        Settings {
            SettingsView()
                .environmentObject(sessionStore)
                .environmentObject(kubeStore)
                .frame(width: 520, height: 420)
        }
    }
}
