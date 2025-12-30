/*
 * API Key Manager
 * Secure storage and retrieval of API keys using Keychain
 * Supports multiple API providers (Alibaba Dashscope, OpenRouter, Google)
 */

import Foundation
import Security

class APIKeyManager {
    static let shared = APIKeyManager()

    private let service = "com.smartview.glassai.apikey"

    // Account names for different providers
    private let alibabaBeijingAccount = "alibaba-beijing-api-key"
    private let alibabaSingaporeAccount = "alibaba-singapore-api-key"
    private let openrouterAccount = "openrouter-api-key"
    private let googleAccount = "google-api-key"
    private let legacyAccount = "qwen-api-key" // For backward compatibility (migrates to Beijing)
    private let legacyAlibabaAccount = "alibaba-api-key" // Old format (migrates to Beijing)

    private init() {
        // Migrate legacy key to new format if needed
        migrateLegacyKey()
    }

    // MARK: - Migration

    private func migrateLegacyKey() {
        // Migrate very old qwen key format
        if let legacyKey = getKey(for: legacyAccount),
           getKey(for: alibabaBeijingAccount) == nil {
            _ = saveKey(legacyKey, for: alibabaBeijingAccount)
            _ = deleteKey(for: legacyAccount)
            print("✅ Migrated legacy qwen API key to Alibaba Beijing")
        }

        // Migrate old alibaba key format (without endpoint)
        if let oldAlibabaKey = getKey(for: legacyAlibabaAccount),
           getKey(for: alibabaBeijingAccount) == nil {
            _ = saveKey(oldAlibabaKey, for: alibabaBeijingAccount)
            _ = deleteKey(for: legacyAlibabaAccount)
            print("✅ Migrated old Alibaba API key to Beijing endpoint")
        }
    }

    // MARK: - Provider-specific API Key Management

    func saveAPIKey(_ key: String, for provider: APIProvider, endpoint: AlibabaEndpoint? = nil) -> Bool {
        let account = accountName(for: provider, endpoint: endpoint)
        return saveKey(key, for: account)
    }

    func getAPIKey(for provider: APIProvider, endpoint: AlibabaEndpoint? = nil) -> String? {
        let account = accountName(for: provider, endpoint: endpoint)
        return getKey(for: account)
    }

    func deleteAPIKey(for provider: APIProvider, endpoint: AlibabaEndpoint? = nil) -> Bool {
        let account = accountName(for: provider, endpoint: endpoint)
        return deleteKey(for: account)
    }

    func hasAPIKey(for provider: APIProvider, endpoint: AlibabaEndpoint? = nil) -> Bool {
        return getAPIKey(for: provider, endpoint: endpoint) != nil
    }

    // MARK: - Google API Key (for Live AI)

    func saveGoogleAPIKey(_ key: String) -> Bool {
        return saveKey(key, for: googleAccount)
    }

    func getGoogleAPIKey() -> String? {
        return getKey(for: googleAccount)
    }

    func deleteGoogleAPIKey() -> Bool {
        return deleteKey(for: googleAccount)
    }

    func hasGoogleAPIKey() -> Bool {
        return getGoogleAPIKey() != nil
    }

    // MARK: - Backward Compatible Methods (defaults to current provider)

    func saveAPIKey(_ key: String) -> Bool {
        return saveAPIKey(key, for: APIProviderManager.staticCurrentProvider)
    }

    func getAPIKey() -> String? {
        return getAPIKey(for: APIProviderManager.staticCurrentProvider)
    }

    @discardableResult
    func deleteAPIKey() -> Bool {
        return deleteAPIKey(for: APIProviderManager.staticCurrentProvider)
    }

    func hasAPIKey() -> Bool {
        return hasAPIKey(for: APIProviderManager.staticCurrentProvider)
    }

    // MARK: - Private Helpers

    private func accountName(for provider: APIProvider, endpoint: AlibabaEndpoint? = nil) -> String {
        switch provider {
        case .alibaba:
            // Use current endpoint from settings if not specified
            let effectiveEndpoint = endpoint ?? APIProviderManager.staticAlibabaEndpoint
            switch effectiveEndpoint {
            case .beijing:
                return alibabaBeijingAccount
            case .singapore:
                return alibabaSingaporeAccount
            }
        case .openrouter:
            return openrouterAccount
        }
    }

    private func saveKey(_ key: String, for account: String) -> Bool {
        guard !key.isEmpty else { return false }

        let data = key.data(using: .utf8)!

        // Delete existing key first
        _ = deleteKey(for: account)

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

    private func getKey(for account: String) -> String? {
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

    private func deleteKey(for account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
