/*
 * Vision API Configuration
 * Centralized configuration for Vision API
 * Supports multiple providers: Alibaba Cloud Dashscope, OpenRouter
 */

import Foundation

struct VisionAPIConfig {
    // MARK: - Dynamic Configuration (based on current provider)

    /// Current API Key based on selected provider
    static var apiKey: String {
        return APIProviderManager.staticAPIKey
    }

    /// Current Base URL based on selected provider
    static var baseURL: String {
        return APIProviderManager.staticBaseURL
    }

    /// Current Model based on selected provider
    static var model: String {
        return APIProviderManager.staticCurrentModel
    }

    /// Current Provider
    static var provider: APIProvider {
        return APIProviderManager.staticCurrentProvider
    }

    // MARK: - Provider-specific URLs

    /// Alibaba Cloud Dashscope API URLs
    static let alibabaBeijingURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    static let alibabaSingaporeURL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"

    /// OpenRouter API URL
    static let openRouterURL = "https://openrouter.ai/api/v1"

    // MARK: - Default Models

    static let defaultAlibabaModel = "qwen3-vl-plus"
    static let defaultOpenRouterModel = "google/gemini-3-flash-preview"

    // MARK: - Request Headers

    /// Get headers for the current provider
    static func headers(with apiKey: String) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]

        // Add OpenRouter-specific headers
        if provider == .openrouter {
            headers["HTTP-Referer"] = "https://turbometa.app"
            headers["X-Title"] = "TurboMeta"
        }

        return headers
    }
}
