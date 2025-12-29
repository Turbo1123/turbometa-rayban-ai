/*
 * API Key Manager
 * Secure storage and retrieval of API keys using Keychain
 */

import Foundation
import Security

class APIKeyManager {
    static let shared = APIKeyManager()

    private let service = "com.turbometa.apikey"
    private let account = "qwen-api-key"

    private init() {}

    // MARK: - Save API Key

    func saveAPIKey(_ key: String) -> Bool {
        guard !key.isEmpty else { return false }

        let data = key.data(using: .utf8)!

        // Delete existing key first
        deleteAPIKey()

        // Add new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Get API Key

    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    // MARK: - Delete API Key

    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Has API Key

    func hasAPIKey() -> Bool {
        return getAPIKey() != nil
    }
}
