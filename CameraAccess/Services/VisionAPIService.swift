/*
 * Vision API Service
 * Provides image recognition using configurable providers
 * Supports Alibaba Cloud Dashscope and OpenRouter
 */

import Foundation
import UIKit

struct VisionAPIService {
    // API Configuration
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
    init() {
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
        let choices: [Choice]

        struct Choice: Codable {
            let message: Message

            struct Message: Codable {
                let content: String
            }
        }
    }

    // MARK: - Public Methods

    /// Analyze image and get description
    func analyzeImage(_ image: UIImage, prompt: String = "图中描绘的是什么景象?") async throws -> String {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw VisionAPIError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"

        // Create request
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
        let response = try await makeRequest(request)

        guard let firstChoice = response.choices.first else {
            throw VisionAPIError.emptyResponse
        }

        return firstChoice.message.content
    }

    // MARK: - Private Methods

    private func makeRequest(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let url = URL(string: "\(baseURL)/chat/completions")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        // Set headers based on provider
        let headers = VisionAPIConfig.headers(with: apiKey)
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VisionAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VisionAPIError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ChatCompletionResponse.self, from: data)
    }
}

// MARK: - Error Types

enum VisionAPIError: LocalizedError {
    case invalidImage
    case emptyResponse
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片"
        case .emptyResponse:
            return "API 返回空响应"
        case .invalidResponse:
            return "无效的响应格式"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        }
    }
}
