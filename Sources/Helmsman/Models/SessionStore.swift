// SessionStore.swift — Helmsman (app layer)
// Observable store: loads/saves sessions and workspace profiles to disk.
// Passwords are NOT stored here — they live in VaultKit.Keychain.

import Foundation
import SwiftUI
import CoreSpotlight
import UniformTypeIdentifiers
import SSHKit

@MainActor
public final class SessionStore: ObservableObject {

    public static let shared = SessionStore()

    // MARK: - Published state

    @Published public var sessions:  [Session] = []
    @Published public var profiles:  [WorkspaceProfile] = [.defaultProd, .defaultLab]
    @Published public var activeProfileID: UUID = WorkspaceProfile.defaultProd.id

    // MARK: - Derived

    public var activeProfile: WorkspaceProfile {
        profiles.first { $0.id == activeProfileID } ?? .defaultProd
    }

    public var sessionsByProfile: [UUID: [Session]] {
        Dictionary(grouping: sessions) { $0.workspaceProfileID }
    }

    /// Sessions belonging to the currently active profile, sorted by `sortOrder`.
    public var activeSessions: [Session] {
        sessions
            .filter { $0.workspaceProfileID == activeProfileID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Persistence

    private let sessionsURL: URL
    private let profilesURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first!
        let base = support.appendingPathComponent("Helmsman")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        sessionsURL = base.appendingPathComponent("sessions.json")
        profilesURL = base.appendingPathComponent("profiles.json")
        load()
    }

    // MARK: - Load / Save

    public func load() {
        sessions = (try? JSONDecoder().decode([Session].self, from: Data(contentsOf: sessionsURL))) ?? []
        let stored = (try? JSONDecoder().decode([WorkspaceProfile].self, from: Data(contentsOf: profilesURL))) ?? []
        if !stored.isEmpty { profiles = stored }
    }

    public func save() {
        try? JSONEncoder().encode(sessions).write(to: sessionsURL, options: .atomic)
        try? JSONEncoder().encode(profiles).write(to: profilesURL, options: .atomic)
    }

    // MARK: - CRUD

    public func add(_ session: Session) {
        var s = session
        s.sortOrder = sessions.count
        sessions.append(s)
        save()
    }

    public func update(_ session: Session) {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[idx] = session
        save()
    }

    public func delete(id: UUID) {
        sessions.removeAll { $0.id == id }
        save()
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) {
        sessions.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (i, _) in sessions.enumerated() { sessions[i].sortOrder = i }
        save()
    }

    // MARK: - Profile management

    public func addProfile(_ profile: WorkspaceProfile) {
        profiles.append(profile)
        save()
    }

    public func deleteProfile(id: UUID) {
        guard id != WorkspaceProfile.defaultProd.id,
              id != WorkspaceProfile.defaultLab.id else { return } // protect defaults
        profiles.removeAll { $0.id == id }
        // Migrate orphaned sessions to Prod
        for i in sessions.indices where sessions[i].workspaceProfileID == id {
            sessions[i].workspaceProfileID = WorkspaceProfile.defaultProd.id
        }
        save()
    }

    // MARK: - Spotlight indexing

    public func indexForSpotlight() {
        // Core Spotlight indexing — see SpotlightIndexer.swift
        SpotlightIndexer.index(sessions: sessions)
    }
}

// MARK: - Spotlight Indexer

enum SpotlightIndexer {
    static let domainID = "com.helmsman.sessions"

    static func index(sessions: [Session]) {
        let items: [CSSearchableItem] = sessions.map { session in
            let attrs = CSSearchableItemAttributeSet(contentType: .data)
            attrs.title       = session.name
            attrs.contentDescription = "\(session.kind.rawValue) — \(session.username)@\(session.host)"
            attrs.keywords    = session.tags + [session.host, session.kind.rawValue]
            attrs.displayName = session.name

            let activity = NSUserActivity(activityType: "com.helmsman.openSession")
            activity.title = session.name
            activity.userInfo = ["sessionID": session.id.uuidString]

            return CSSearchableItem(
                uniqueIdentifier: session.id.uuidString,
                domainIdentifier: domainID,
                attributeSet:     attrs
            )
        }

        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    static func deindex(sessionID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [sessionID.uuidString]
        ) { _ in }
    }
}
