// Keychain.swift — VaultKit
// Thread-safe Keychain wrapper with per-class credential items.
// Uses SecItem* APIs (no deprecated convenience wrappers).

import Foundation
import Security

// MARK: - KeychainItem

/// Uniquely identifies one credential in the Keychain.
public struct KeychainItem: Sendable {
    public let kind: CredentialKind
    /// e.g., "admin@bastion.example.com" or path to an identity file.
    public let account: String

    public init(kind: CredentialKind, account: String) {
        self.kind = kind
        self.account = account
    }

    fileprivate var service: String { kind.rawValue }
}

// MARK: - Keychain Error

public enum KeychainError: Error, LocalizedError, Sendable {
    case unexpectedData
    case unhandledStatus(OSStatus)
    case itemNotFound
    case duplicateItem
    case biometryNotAvailable
    case userCancelled

    public var errorDescription: String? {
        switch self {
        case .unexpectedData:            return "Keychain returned unexpected data format."
        case .unhandledStatus(let s):    return "Keychain error (OSStatus \(s))."
        case .itemNotFound:              return "Credential not found in Keychain."
        case .duplicateItem:             return "A credential with that identity already exists."
        case .biometryNotAvailable:      return "Touch ID / Face ID is not available on this device."
        case .userCancelled:             return "Authentication was cancelled."
        }
    }

    static func from(_ status: OSStatus) -> KeychainError {
        switch status {
        case errSecItemNotFound:         return .itemNotFound
        case errSecDuplicateItem:        return .duplicateItem
        case errSecUserCanceled:         return .userCancelled
        default:                         return .unhandledStatus(status)
        }
    }
}

// MARK: - Keychain

/// Primary Keychain interface for Helmsman.
/// All methods are synchronous and should be called off the main thread.
public enum Keychain {

    // MARK: Write

    /// Stores `secret` for `item`, creating or updating as needed.
    /// - Parameter requireBiometry: If `true`, adds a biometric access-control
    ///   policy so Touch ID is required on retrieval.
    public static func set(
        _ secret: String,
        for item: KeychainItem,
        requireBiometry: Bool = false
    ) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        // Build base query
        var query = baseQuery(for: item)

        // Access control
        if requireBiometry {
            var cfError: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryCurrentSet, .or, .devicePasscode],
                &cfError
            ), cfError == nil else {
                throw KeychainError.biometryNotAvailable
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        }

        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = item.kind.keychainLabel

        // Try to add; update if it already exists
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            var updateAttrs: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrLabel as String: item.kind.keychainLabel
            ]
            if requireBiometry {
                var cfError: Unmanaged<CFError>?
                if let access = SecAccessControlCreateWithFlags(
                    kCFAllocatorDefault,
                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    [.biometryCurrentSet, .or, .devicePasscode],
                    &cfError
                ), cfError == nil {
                    updateAttrs[kSecAttrAccessControl as String] = access
                }
            }
            let updateQuery = baseQuery(for: item)
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.from(updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw KeychainError.from(addStatus)
        }
    }

    // MARK: Read

    /// Retrieves the secret for `item`.
    /// - Parameter prompt: Shown to the user in the Touch ID dialog (when applicable).
    public static func get(
        _ item: KeychainItem,
        prompt: String = "Helmsman needs your credential"
    ) throws -> String {
        var query = baseQuery(for: item)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseOperationPrompt as String] = prompt

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw KeychainError.from(status)
        }
        guard let data = result as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return secret
    }

    /// Returns `true` if an item exists in the Keychain (does not retrieve the secret).
    public static func exists(_ item: KeychainItem) -> Bool {
        var query = baseQuery(for: item)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: Delete

    /// Removes the item from the Keychain.
    public static func delete(_ item: KeychainItem) throws {
        let query = baseQuery(for: item)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status)
        }
    }

    // MARK: - Private helpers

    private static func baseQuery(for item: KeychainItem) -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: item.service,
            kSecAttrAccount as String: item.account
        ]
    }
}
