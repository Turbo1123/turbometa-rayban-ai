/*
 * API Key Manager
 * Secure storage and retrieval of API keys using Keychain
 */

import Foundation
import Security

class APIKeyManager {
    static let shared = APIKeyManager()

    private let service = "com.turbometa.apikey"
    private let legacyQwenAccount = "qwen-api-key"

    private init() {}

    // MARK: - Save API Key

    func saveAPIKey(_ key: String, provider: VisionAPIConfig.ModelProvider) -> Bool {
        guard !key.isEmpty else { return false }

        let data = key.data(using: .utf8)!

        // Delete existing key first
        deleteAPIKey(provider: provider)

        // Add new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Get API Key

    func getAPIKey(provider: VisionAPIConfig.ModelProvider) -> String? {
        if let key = readKey(account: provider.keychainAccount) {
            return key
        }

        // 兼容旧版本：通义千问使用旧账号名存储
        if provider == .qwen, let legacyKey = readKey(account: legacyQwenAccount) {
            _ = saveAPIKey(legacyKey, provider: .qwen)
            _ = deleteLegacyAPIKey()
            return legacyKey
        }

        return nil
    }

    // MARK: - Delete API Key

    func deleteAPIKey(provider: VisionAPIConfig.ModelProvider) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Has API Key

    func hasAPIKey(provider: VisionAPIConfig.ModelProvider) -> Bool {
        return getAPIKey(provider: provider) != nil
    }

    private func readKey(account: String) -> String? {
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

    private func deleteLegacyAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyQwenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
