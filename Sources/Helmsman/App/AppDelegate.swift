// AppDelegate.swift — Helmsman
// Handles Sparkle updater, Spotlight continuation, and app-level macOS events.

import AppKit
import SwiftUI
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Sparkle

    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable native window tabbing for terminal tabs
        NSWindow.allowsAutomaticWindowTabbing = false  // we manage tabs ourselves

        // Sparkle automatic updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    // MARK: - Spotlight / NSUserActivity continuation

    func application(_ application: NSApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        guard userActivity.activityType == "com.helmsman.openSession",
              let idString = userActivity.userInfo?["sessionID"] as? String,
              let sessionID = UUID(uuidString: idString) else {
            return false
        }

        // Post notification; RootContentView observes and opens the session
        NotificationCenter.default.post(
            name: .openSessionByID,
            object: nil,
            userInfo: ["sessionID": sessionID]
        )
        return true
    }

    // MARK: - Menu actions

    func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    func checkForUpdates(_ sender: Any?) {
        updaterController?.updater.checkForUpdates()
    }

    // MARK: - Termination

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Flush all open transcript writers before quitting
        NotificationCenter.default.post(name: .applicationWillTerminate, object: nil)
        return .terminateNow
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let openSessionByID         = Notification.Name("com.helmsman.openSessionByID")
    static let applicationWillTerminate = Notification.Name("com.helmsman.willTerminate")
}
