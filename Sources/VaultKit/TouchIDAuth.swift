// TouchIDAuth.swift — VaultKit
// Thin wrapper around LocalAuthentication's LAContext.
// Provides async Touch ID / device-passcode authentication.

import Foundation
import LocalAuthentication

// MARK: - Auth reason

public enum TouchIDReason: String, Sendable {
    case unlockVault = "Unlock Helmsman session vault"
    case sudoProxy   = "Authenticate sudo operation"
    case exportKey   = "Export SSH key or credential"
    case custom
}

// MARK: - TouchIDAuth

public enum TouchIDAuth {

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case notAvailable(String)
        case failed(String)
        case userCancelled

        public var errorDescription: String? {
            switch self {
            case .notAvailable(let msg): return "Biometrics not available: \(msg)"
            case .failed(let msg):       return "Authentication failed: \(msg)"
            case .userCancelled:         return "Authentication was cancelled."
            }
        }
    }

    // MARK: - Availability check

    /// Returns true if the device has Touch ID or Face ID enrolled and available.
    public static var isAvailable: Bool {
        let ctx = LAContext()
        var error: NSError?
        return ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    // MARK: - Authentication

    /// Evaluates biometric authentication (Touch ID or device passcode fallback).
    /// Async-safe: bridges LAContext's callback to Swift concurrency.
    ///
    /// - Parameters:
    ///   - reason: Predefined reason displayed in the Touch ID sheet.
    ///   - customReason: Used when reason == .custom.
    public static func authenticate(
        reason: TouchIDReason,
        customReason: String? = nil
    ) async throws {
        let localizedReason: String
        if reason == .custom, let custom = customReason {
            localizedReason = custom
        } else {
            localizedReason = reason.rawValue
        }

        let context = LAContext()
        // Prefer biometrics; fall back to device passcode
        let policy = LAPolicy.deviceOwnerAuthentication

        var canError: NSError?
        guard context.canEvaluatePolicy(policy, error: &canError) else {
            throw Error.notAvailable(canError?.localizedDescription ?? "Unknown")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            context.evaluatePolicy(policy, localizedReason: localizedReason) { success, error in
                if success {
                    continuation.resume()
                } else if let laError = error as? LAError, laError.code == .userCancel {
                    continuation.resume(throwing: Error.userCancelled)
                } else {
                    continuation.resume(throwing: Error.failed(error?.localizedDescription ?? "Unknown"))
                }
            }
        }
    }

    /// Convenience: authenticate and then execute `work` if successful.
    @discardableResult
    public static func authenticateThen<T: Sendable>(
        reason: TouchIDReason,
        work: @Sendable () async throws -> T
    ) async throws -> T {
        try await authenticate(reason: reason)
        return try await work()
    }
}
