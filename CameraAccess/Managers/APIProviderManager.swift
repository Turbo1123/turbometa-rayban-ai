/*
 * API Provider Manager
 * 管理不同的 API 提供商 (阿里云 Dashscope / OpenRouter)
 */

import Foundation
import SwiftUI

// MARK: - Alibaba Endpoint Enum

enum AlibabaEndpoint: String, CaseIterable, Codable {
    case beijing = "beijing"
    case singapore = "singapore"

    var displayName: String {
        switch self {
        case .beijing: return "北京 (中国大陆)"
        case .singapore: return "新加坡 (国际)"
        }
    }

    var baseURL: String {
        switch self {
        case .beijing: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .singapore: return "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        }
    }

    var websocketURL: String {
        switch self {
        case .beijing: return "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
        case .singapore: return "wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime"
        }
    }
}

// MARK: - API Provider Enum (Vision API)

enum APIProvider: String, CaseIterable, Codable {
    case alibaba = "alibaba"
    case openrouter = "openrouter"

    var displayName: String {
        switch self {
        case .alibaba: return "阿里云 Dashscope"
        case .openrouter: return "OpenRouter"
        }
    }

    func baseURL(endpoint: AlibabaEndpoint = .beijing) -> String {
        switch self {
        case .alibaba: return endpoint.baseURL
        case .openrouter: return "https://openrouter.ai/api/v1"
        }
    }

    var baseURL: String {
        return baseURL(endpoint: .beijing)
    }

    var defaultModel: String {
        switch self {
        case .alibaba: return "qwen3-vl-plus"
        case .openrouter: return "google/gemini-3-flash-preview"
        }
    }

    var apiKeyHelpURL: String {
        switch self {
        case .alibaba: return "https://help.aliyun.com/zh/model-studio/get-api-key"
        case .openrouter: return "https://openrouter.ai/keys"
        }
    }

    var supportsVision: Bool {
        return true
    }
}

// MARK: - Live AI Provider Enum

enum LiveAIProvider: String, CaseIterable, Codable {
    case alibaba = "alibaba"
    case google = "google"

    var displayName: String {
        switch self {
        case .alibaba: return "阿里云 Qwen Omni"
        case .google: return "Google Gemini Live"
        }
    }

    var defaultModel: String {
        switch self {
        case .alibaba: return "qwen3-omni-flash-realtime"
        case .google: return "gemini-2.0-flash-exp"
        }
    }

    var apiKeyHelpURL: String {
        switch self {
        case .alibaba: return "https://help.aliyun.com/zh/model-studio/get-api-key"
        case .google: return "https://aistudio.google.com/apikey"
        }
    }

    func websocketURL(endpoint: AlibabaEndpoint = .beijing) -> String {
        switch self {
        case .alibaba: return endpoint.websocketURL
        case .google: return "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        }
    }
}

// MARK: - OpenRouter Model

struct OpenRouterModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int?
    let pricing: Pricing?
    let architecture: Architecture?

    var displayName: String {
        return name.isEmpty ? id : name
    }

    var isVisionCapable: Bool {
        // Check if model supports vision based on architecture or ID
        if let arch = architecture {
            return arch.modality?.contains("image") == true ||
                   arch.modality?.contains("multimodal") == true
        }
        // Fallback: check common vision model patterns
        let visionPatterns = ["vision", "vl", "gpt-4o", "claude-3", "gemini"]
        return visionPatterns.contains { id.lowercased().contains($0) }
    }

    var priceDisplay: String {
        guard let pricing = pricing else { return "" }
        let promptPrice = (Double(pricing.prompt) ?? 0) * 1_000_000
        let completionPrice = (Double(pricing.completion) ?? 0) * 1_000_000
        return String(format: "$%.2f / $%.2f per 1M tokens", promptPrice, completionPrice)
    }

    struct Pricing: Codable, Hashable {
        let prompt: String
        let completion: String
    }

    struct Architecture: Codable, Hashable {
        let modality: String?
        let tokenizer: String?
        let instructType: String?

        enum CodingKeys: String, CodingKey {
            case modality
            case tokenizer
            case instructType = "instruct_type"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case pricing
        case architecture
    }
}

struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
}

// MARK: - API Provider Manager

@MainActor
class APIProviderManager: ObservableObject {
    static let shared = APIProviderManager()

    // Vision API Provider
    private let providerKey = "api_provider"
    private let selectedModelKey = "selected_vision_model"
    private let alibabaEndpointKey = "alibaba_endpoint"

    // Live AI Provider
    private let liveAIProviderKey = "liveai_provider"
    private let liveAIModelKey = "liveai_model"

    @Published var currentProvider: APIProvider {
        didSet {
            UserDefaults.standard.set(currentProvider.rawValue, forKey: providerKey)
            // Reset to default model when provider changes
            if oldValue != currentProvider {
                selectedModel = currentProvider.defaultModel
            }
        }
    }

    @Published var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: selectedModelKey)
        }
    }

    // Alibaba Endpoint (Beijing/Singapore)
    @Published var alibabaEndpoint: AlibabaEndpoint {
        didSet {
            UserDefaults.standard.set(alibabaEndpoint.rawValue, forKey: alibabaEndpointKey)
        }
    }

    // Live AI Provider
    @Published var liveAIProvider: LiveAIProvider {
        didSet {
            UserDefaults.standard.set(liveAIProvider.rawValue, forKey: liveAIProviderKey)
            if oldValue != liveAIProvider {
                liveAIModel = liveAIProvider.defaultModel
            }
        }
    }

    @Published var liveAIModel: String {
        didSet {
            UserDefaults.standard.set(liveAIModel, forKey: liveAIModelKey)
        }
    }

    @Published var openRouterModels: [OpenRouterModel] = []
    @Published var isLoadingModels = false
    @Published var modelsError: String?

    private init() {
        // Alibaba Endpoint
        let savedEndpoint = UserDefaults.standard.string(forKey: alibabaEndpointKey) ?? "beijing"
        self.alibabaEndpoint = AlibabaEndpoint(rawValue: savedEndpoint) ?? .beijing

        // Vision API Provider
        let savedProvider = UserDefaults.standard.string(forKey: providerKey) ?? "alibaba"
        let provider = APIProvider(rawValue: savedProvider) ?? .alibaba
        self.currentProvider = provider

        let savedModel = UserDefaults.standard.string(forKey: selectedModelKey)
        self.selectedModel = savedModel ?? provider.defaultModel

        // Live AI Provider
        let savedLiveAIProvider = UserDefaults.standard.string(forKey: liveAIProviderKey) ?? "alibaba"
        let liveProvider = LiveAIProvider(rawValue: savedLiveAIProvider) ?? .alibaba
        self.liveAIProvider = liveProvider

        let savedLiveAIModel = UserDefaults.standard.string(forKey: liveAIModelKey)
        self.liveAIModel = savedLiveAIModel ?? liveProvider.defaultModel
    }

    // MARK: - Live AI Configuration

    var liveAIWebSocketURL: String {
        return liveAIProvider.websocketURL(endpoint: alibabaEndpoint)
    }

    var liveAIAPIKey: String {
        switch liveAIProvider {
        case .alibaba:
            return APIKeyManager.shared.getAPIKey(for: .alibaba, endpoint: alibabaEndpoint) ?? ""
        case .google:
            return APIKeyManager.shared.getGoogleAPIKey() ?? ""
        }
    }

    var hasLiveAIAPIKey: Bool {
        return !liveAIAPIKey.isEmpty
    }

    // MARK: - Get Current Configuration

    var currentBaseURL: String {
        return currentProvider.baseURL(endpoint: alibabaEndpoint)
    }

    var currentAPIKey: String {
        if currentProvider == .alibaba {
            return APIKeyManager.shared.getAPIKey(for: currentProvider, endpoint: alibabaEndpoint) ?? ""
        }
        return APIKeyManager.shared.getAPIKey(for: currentProvider) ?? ""
    }

    var currentModel: String {
        return selectedModel
    }

    var hasAPIKey: Bool {
        if currentProvider == .alibaba {
            return APIKeyManager.shared.hasAPIKey(for: currentProvider, endpoint: alibabaEndpoint)
        }
        return APIKeyManager.shared.hasAPIKey(for: currentProvider)
    }

    // MARK: - OpenRouter Models

    func fetchOpenRouterModels() async {
        guard currentProvider == .openrouter else { return }
        guard let apiKey = APIKeyManager.shared.getAPIKey(for: .openrouter), !apiKey.isEmpty else {
            modelsError = "请先配置 OpenRouter API Key"
            return
        }

        isLoadingModels = true
        modelsError = nil

        do {
            let url = URL(string: "https://openrouter.ai/api/v1/models")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("TurboMeta", forHTTPHeaderField: "X-Title")
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "OpenRouter", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取模型列表失败"])
            }

            let decoder = JSONDecoder()
            let modelsResponse = try decoder.decode(OpenRouterModelsResponse.self, from: data)

            // Sort models: vision-capable first, then by name
            openRouterModels = modelsResponse.data.sorted { m1, m2 in
                if m1.isVisionCapable != m2.isVisionCapable {
                    return m1.isVisionCapable
                }
                return m1.displayName < m2.displayName
            }

            print("✅ Loaded \(openRouterModels.count) OpenRouter models")

        } catch {
            modelsError = error.localizedDescription
            print("❌ Failed to fetch OpenRouter models: \(error)")
        }

        isLoadingModels = false
    }

    func searchModels(_ query: String) -> [OpenRouterModel] {
        guard !query.isEmpty else { return openRouterModels }
        let lowercaseQuery = query.lowercased()
        return openRouterModels.filter { model in
            model.id.lowercased().contains(lowercaseQuery) ||
            model.displayName.lowercased().contains(lowercaseQuery) ||
            (model.description?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }

    func visionCapableModels() -> [OpenRouterModel] {
        return openRouterModels.filter { $0.isVisionCapable }
    }
}

// MARK: - Static Helpers for Non-MainActor Access

extension APIProviderManager {
    nonisolated static var staticCurrentProvider: APIProvider {
        let savedProvider = UserDefaults.standard.string(forKey: "api_provider") ?? "alibaba"
        return APIProvider(rawValue: savedProvider) ?? .alibaba
    }

    nonisolated static var staticAlibabaEndpoint: AlibabaEndpoint {
        let savedEndpoint = UserDefaults.standard.string(forKey: "alibaba_endpoint") ?? "beijing"
        return AlibabaEndpoint(rawValue: savedEndpoint) ?? .beijing
    }

    nonisolated static var staticLiveAIProvider: LiveAIProvider {
        let savedProvider = UserDefaults.standard.string(forKey: "liveai_provider") ?? "alibaba"
        return LiveAIProvider(rawValue: savedProvider) ?? .alibaba
    }

    nonisolated static var staticLiveAIAPIKey: String {
        switch staticLiveAIProvider {
        case .alibaba:
            return APIKeyManager.shared.getAPIKey(for: .alibaba, endpoint: staticAlibabaEndpoint) ?? ""
        case .google:
            return APIKeyManager.shared.getGoogleAPIKey() ?? ""
        }
    }

    nonisolated static var staticCurrentModel: String {
        let savedModel = UserDefaults.standard.string(forKey: "selected_vision_model")
        return savedModel ?? staticCurrentProvider.defaultModel
    }

    nonisolated static var staticBaseURL: String {
        return staticCurrentProvider.baseURL(endpoint: staticAlibabaEndpoint)
    }

    nonisolated static var staticAPIKey: String {
        if staticCurrentProvider == .alibaba {
            return APIKeyManager.shared.getAPIKey(for: staticCurrentProvider, endpoint: staticAlibabaEndpoint) ?? ""
        }
        return APIKeyManager.shared.getAPIKey(for: staticCurrentProvider) ?? ""
    }

    nonisolated static var staticLiveAIWebsocketURL: String {
        return staticLiveAIProvider.websocketURL(endpoint: staticAlibabaEndpoint)
    }
}
