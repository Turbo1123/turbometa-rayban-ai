/*
 * Quick Vision Service
 * 快速识图服务 - 使用 qwen3-vl-plus 模型进行图像识别
 * 返回简洁的描述，适合 TTS 播报
 */

import Foundation
import UIKit

class QuickVisionService {
    private let apiKey: String
    private let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    private let model = "qwen3-vl-plus"

    init(apiKey: String) {
        self.apiKey = apiKey
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
        let choices: [Choice]

        struct Choice: Codable {
            let message: Message

            struct Message: Codable {
                let content: String
            }
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
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30 // 30秒超时

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        print("📡 [QuickVision] Sending request to qwen3-vl-plus...")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuickVisionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [QuickVision] API error: \(httpResponse.statusCode) - \(errorMessage)")
            throw QuickVisionError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ChatCompletionResponse.self, from: data)

        guard let firstChoice = apiResponse.choices.first else {
            throw QuickVisionError.emptyResponse
        }

        let result = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("✅ [QuickVision] Result: \(result)")

        return result
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
