/*
 * Quick Vision Service
 * 快速识图服务 - 支持多提供商 (阿里云/OpenRouter)
 * 返回简洁的描述，适合 TTS 播报
 */

import Foundation
import UIKit

class QuickVisionService {
    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let provider: APIProvider

    /// Initialize with explicit configuration
    init(apiKey: String, baseURL: String? = nil, model: String? = nil) {
        self.apiKey = apiKey
        self.provider = VisionAPIConfig.provider
        self.baseURL = baseURL ?? VisionAPIConfig.baseURL
        self.model = model ?? VisionAPIConfig.model
    }

    /// Initialize with current provider configuration
    convenience init() {
        self.init(
            apiKey: VisionAPIConfig.apiKey,
            baseURL: VisionAPIConfig.baseURL,
            model: VisionAPIConfig.model
        )
    }

    // MARK: - API Request/Response Models

    struct ChatCompletionRequest: Codable {
        let model: String
        let messages: [Message]

        struct Message: Codable {
            let role: String
            let content: [Content]

            struct Content: Codable {
                let type: String
                let text: String?
                let imageUrl: ImageURL?

                enum CodingKeys: String, CodingKey {
                    case type
                    case text
                    case imageUrl = "image_url"
                }

                struct ImageURL: Codable {
                    let url: String
                }
            }
        }
    }

    struct ChatCompletionResponse: Codable {
        let choices: [Choice]?
        let error: APIError?

        struct Choice: Codable {
            let message: Message?
            let delta: Delta?

            struct Message: Codable {
                let content: String?
            }

            struct Delta: Codable {
                let content: String?
            }
        }

        struct APIError: Codable {
            let message: String?
            let code: Int?
        }
    }

    // MARK: - Quick Vision Analysis

    /// 快速识图 - 返回简洁的语音描述
    /// - Parameters:
    ///   - image: 要识别的图片
    ///   - customPrompt: 自定义提示词（可选）
    /// - Returns: 简洁的描述文本，适合 TTS 播报
    func analyzeImage(_ image: UIImage, customPrompt: String? = nil) async throws -> String {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw QuickVisionError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"

        // 使用本地化的提示词
        let prompt = customPrompt ?? "prompt.quickvision".localized

        // Create API request
        let request = ChatCompletionRequest(
            model: model,
            messages: [
                ChatCompletionRequest.Message(
                    role: "user",
                    content: [
                        ChatCompletionRequest.Message.Content(
                            type: "image_url",
                            text: nil,
                            imageUrl: ChatCompletionRequest.Message.Content.ImageURL(url: dataURL)
                        ),
                        ChatCompletionRequest.Message.Content(
                            type: "text",
                            text: prompt,
                            imageUrl: nil
                        )
                    ]
                )
            ]
        )

        // Make API call
        return try await makeRequest(request)
    }

    // MARK: - Private Methods

    private func makeRequest(_ request: ChatCompletionRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // Set headers based on provider
        let headers = VisionAPIConfig.headers(with: apiKey)
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        urlRequest.timeoutInterval = 60 // 60秒超时（OpenRouter 可能需要更长时间）

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        print("📡 [QuickVision] Sending request to \(model) via \(provider.displayName)...")
        print("📡 [QuickVision] URL: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickVisionError.invalidResponse
        }

        // Log raw response for debugging
        let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to decode"
        print("📡 [QuickVision] HTTP Status: \(httpResponse.statusCode)")
        print("📡 [QuickVision] Raw response: \(rawResponse.prefix(500))")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [QuickVision] API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw QuickVisionError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let apiResponse: ChatCompletionResponse

        do {
            apiResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        } catch {
            print("❌ [QuickVision] JSON decode error: \(error)")
            throw QuickVisionError.invalidResponse
        }

        // Check for API error in response body
        if let apiError = apiResponse.error {
            let errorMsg = apiError.message ?? "Unknown API error"
            print("❌ [QuickVision] API returned error: \(errorMsg)")
            throw QuickVisionError.apiError(statusCode: apiError.code ?? -1, message: errorMsg)
        }

        // Get content from choices
        guard let choices = apiResponse.choices, let firstChoice = choices.first else {
            print("❌ [QuickVision] No choices in response")
            throw QuickVisionError.emptyResponse
        }

        // Try message.content first, then delta.content
        let content = firstChoice.message?.content ?? firstChoice.delta?.content

        guard let result = content, !result.isEmpty else {
            print("❌ [QuickVision] Empty content in response")
            throw QuickVisionError.emptyResponse
        }

        let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ [QuickVision] Result: \(trimmedResult)")

        return trimmedResult
    }
}

// MARK: - Error Types

enum QuickVisionError: LocalizedError {
    case noDevice
    case streamNotReady
    case frameTimeout
    case invalidImage
    case emptyResponse
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "眼镜未连接，请先在 Meta View 中配对眼镜"
        case .streamNotReady:
            return "视频流启动失败，请检查眼镜连接状态"
        case .frameTimeout:
            return "等待视频帧超时，请重试"
        case .invalidImage:
            return "无法处理图片"
        case .emptyResponse:
            return "AI返回空响应，请重试"
        case .invalidResponse:
            return "无效的响应格式"
        case .apiError(let statusCode, let message):
            return "API错误(\(statusCode)): \(message)"
        }
    }
}
