// WorkspaceProfile.swift — Helmsman (app layer)
// Represents a security profile (Prod or Lab) that governs what auth methods
// are permitted and whether passwords may be stored in Keychain.

import Foundation
import SwiftUI

// MARK: - WorkspaceProfile

public struct WorkspaceProfile: Identifiable, Codable, Hashable {

    public var id:   UUID
    public var name: String
    public var kind: Kind
    public var sortOrder: Int

    public enum Kind: String, Codable, CaseIterable {
        case prod = "Production"
        case lab  = "Lab"

        public var systemImage: String {
            switch self {
            case .prod: return "lock.shield.fill"
            case .lab:  return "flask.fill"
            }
        }

        public var accentColor: Color {
            switch self {
            case .prod: return .blue
            case .lab:  return .orange
            }
        }
    }

    // MARK: Security rules

    /// In Lab profiles, password auth and stored passwords are permitted.
    public var isLab: Bool { kind == .lab }

    /// In Prod profiles, only key / agent / Touch-ID auth is allowed.
    public var isProd: Bool { kind == .prod }

    /// Whether password-based Keychain entries are permitted in this profile.
    public var allowsStoredPasswords: Bool { isLab }

    /// Whether `StrictHostKeyChecking=no` may be used in this profile.
    public var allowsSkipHostKeyChecking: Bool { isLab }

    /// Whether Touch ID is required for vault unlock in this profile.
    public var requiresTouchIDForVault: Bool { true } // always, regardless of profile

    // MARK: Defaults

    public static let defaultProd = WorkspaceProfile(
        id:        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name:      "Production",
        kind:      .prod,
        sortOrder: 0
    )

    public static let defaultLab = WorkspaceProfile(
        id:        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name:      "Lab",
        kind:      .lab,
        sortOrder: 1
    )

    public init(id: UUID = .init(), name: String, kind: Kind, sortOrder: Int = 0) {
        self.id        = id
        self.name      = name
        self.kind      = kind
        self.sortOrder = sortOrder
    }
}
