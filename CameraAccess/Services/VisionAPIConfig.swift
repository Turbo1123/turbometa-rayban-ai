/*
 * Vision API Configuration
 * Centralized configuration for Alibaba Cloud Dashscope API
 */

import Foundation

struct VisionAPIConfig {
    enum ModelProvider: String, CaseIterable, Identifiable {
        case qwen
        case doubao
        case stepfun
        case openai
        case gemini
        case geminiCompatible

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .qwen: return "通义千问"
            case .doubao: return "豆包"
            case .stepfun: return "阶越星辰"
            case .openai: return "OpenAI 兼容"
            case .gemini: return "Gemini"
            case .geminiCompatible: return "Gemini 兼容"
            }
        }
        
        var isDoubao: Bool { self == .doubao }

        var defaultBaseURL: String {
            switch self {
            case .qwen:
                return "https://dashscope.aliyuncs.com/compatible-mode/v1"
            case .doubao:
                return "https://ark.cn-beijing.volces.com/api/v3"
            case .stepfun:
                return "https://api.stepfun.com/v1"
            case .openai:
                return ""
            case .gemini:
                return "https://generativelanguage.googleapis.com/v1beta"

            case .geminiCompatible:
                return ""
            }
        }

        var defaultRealtimeBaseURL: String {
            switch self {
            case .qwen:
                return "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
            case .doubao:
                return ""
            case .stepfun:
                return ""
            case .openai:
                return ""
            case .gemini:
                return ""
            case .geminiCompatible:
                return ""
            }
        }

        var keychainAccount: String {
            "api-key.\(rawValue)"
        }
    }

    static let defaultModel = "qwen3-vl-plus"
    static let defaultRealtimeModel = "qwen3-omni-flash-realtime"
    static let defaultRealtimeInputLanguage = "zh-CN"
    static let modelKey = "vision.api.model"
    static let realtimeModelKey = "realtime.api.model"
    static let realtimeInputLanguageKey = "realtime.input_language"
    static let providerKey = "vision.api.provider"

    // Image Generation Configuration
    static let defaultImageGenModel = "gemini-3-pro-image-preview"
    static let imageGenModelKey = "image.gen.model"
    static let imageGenProviderKey = "image.gen.provider"

    static var imageGenModel: String {
        get {
            UserDefaults.standard.string(forKey: imageGenModelKey) ?? defaultImageGenModel
        }
        set {
            UserDefaults.standard.setValue(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: imageGenModelKey)
        }
    }

    static var activeImageGenProvider: ModelProvider {
        // Defaults to Gemini for now as it's the only one implemented for this specific features set
        if let rawValue = UserDefaults.standard.string(forKey: imageGenProviderKey),
           let provider = ModelProvider(rawValue: rawValue) {
            return provider
        }
        return .gemini
    }

    static var preferredImageGenProvider: ModelProvider {
        get {
            activeImageGenProvider
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: imageGenProviderKey)
        }
    }

    // API Key is now securely stored in Keychain
    // Get your API key from: https://help.aliyun.com/zh/model-studio/get-api-key
    static var apiKey: String {
        return apiKey(for: activeProvider)
    }

    static var realtimeApiKey: String {
        return apiKey(for: activeRealtimeProvider)
    }

    // API Base URL (per provider)
    static var baseURL: String {
        return baseURL(for: activeProvider)
    }

    // Model name
    static var model: String {
        get {
            UserDefaults.standard.string(forKey: modelKey) ?? defaultModel
        }
        set {
            UserDefaults.standard.setValue(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelKey)
        }
    }

    static var realtimeModel: String {
        get {
            UserDefaults.standard.string(forKey: realtimeModelKey) ?? defaultRealtimeModel
        }
        set {
            UserDefaults.standard.setValue(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: realtimeModelKey)
        }
    }

    static var realtimeInputLanguage: String {
        get {
            UserDefaults.standard.string(forKey: realtimeInputLanguageKey) ?? defaultRealtimeInputLanguage
        }
        set {
            UserDefaults.standard.setValue(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: realtimeInputLanguageKey)
        }
    }

    static var preferredProvider: ModelProvider {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: providerKey),
               let provider = ModelProvider(rawValue: rawValue) {
                return provider
            }
            return .qwen
        }
        set {
            UserDefaults.standard.setValue(newValue.rawValue, forKey: providerKey)
        }
    }

    static var activeProvider: ModelProvider {
        provider(for: model) ?? preferredProvider
    }

    static var activeRealtimeProvider: ModelProvider {
        provider(for: realtimeModel) ?? preferredProvider
    }

    static func baseURL(for provider: ModelProvider) -> String {
        let key = baseURLKey(for: provider)
        let storedValue = UserDefaults.standard.string(forKey: key)
        let value = storedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? provider.defaultBaseURL : value
    }

    static func setBaseURL(_ url: String, for provider: ModelProvider) {
        let key = baseURLKey(for: provider)
        UserDefaults.standard.setValue(url.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key)
    }

    static func realtimeBaseURL(for provider: ModelProvider) -> String {
        let key = realtimeBaseURLKey(for: provider)
        let storedValue = UserDefaults.standard.string(forKey: key)
        let value = storedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? provider.defaultRealtimeBaseURL : value
    }

    static func setRealtimeBaseURL(_ url: String, for provider: ModelProvider) {
        let key = realtimeBaseURLKey(for: provider)
        UserDefaults.standard.setValue(url.trimmingCharacters(in: .whitespacesAndNewlines), forKey: key)
    }

    static func provider(for model: String) -> ModelProvider? {
        let lowercased = model.lowercased()
        if lowercased.contains("qwen") {
            return .qwen
        }
        if lowercased.contains("doubao") {
            return .doubao
        }
        if lowercased.contains("step") || lowercased.contains("stepfun") {
            return .stepfun
        }
        if lowercased.contains("gpt") || lowercased.contains("o1") || lowercased.contains("o3") {
            return .openai
        }
        if lowercased.contains("gemini") {
            return .gemini
        }
        return nil
    }

    static func provider(forBaseURL url: String) -> ModelProvider? {
        let lowercased = url.lowercased()
        if lowercased.contains("dashscope") {
            return .qwen
        }
        if lowercased.contains("volces") || lowercased.contains("ark") {
            return .doubao
        }
        if lowercased.contains("stepfun") {
            return .stepfun
        }
        if lowercased.contains("openai") {
            return .openai
        }
        if lowercased.contains("google") || lowercased.contains("googleapis") {
            return .gemini
        }
        return nil
    }

    private static func baseURLKey(for provider: ModelProvider) -> String {
        "vision.api.base_url.\(provider.rawValue)"
    }

    private static func realtimeBaseURLKey(for provider: ModelProvider) -> String {
        "realtime.api.base_url.\(provider.rawValue)"
    }

    static func apiKey(for provider: ModelProvider) -> String {
        APIKeyManager.shared.getAPIKey(provider: provider) ?? ""
    }
}
