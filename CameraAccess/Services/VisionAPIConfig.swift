/*
 * Vision API Configuration
 * Centralized configuration for Alibaba Cloud Dashscope API
 */

import Foundation

struct VisionAPIConfig {
    // API Key is now securely stored in Keychain
    // Get your API key from: https://help.aliyun.com/zh/model-studio/get-api-key
    static var apiKey: String {
        return APIKeyManager.shared.getAPIKey() ?? ""
    }

    // Base URL for Alibaba Cloud Dashscope API
    // Beijing region: https://dashscope.aliyuncs.com/compatible-mode/v1
    // Singapore region: https://dashscope-intl.aliyuncs.com/compatible-mode/v1
    static let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"

    // Model name
    static let model = "qwen3-vl-plus"
}
