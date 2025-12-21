/*
 * LeanEat Service
 * 食物营养分析AI服务
 */

import Foundation
import UIKit

class LeanEatService {
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

    // MARK: - Nutrition Analysis

    func analyzeFood(_ image: UIImage) async throws -> FoodNutritionResponse {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw LeanEatError.invalidImage
        }

        let base64String = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64String)"

        // Create specialized nutrition analysis prompt
        let nutritionPrompt = """
你是一位专业的营养师AI。请分析图片中的食物，并返回纯JSON格式的营养信息。

**严格要求：必须返回纯JSON格式，不要任何额外文字！**
**重要：所有文字内容（包括name字段）必须用中文！**

JSON格式如下：
{
  "foods": [
    {
      "name": "食物名称（中文）",
      "portion": "份量（如：1碗、100克等）",
      "calories": 热量数字（整数，单位：千卡）,
      "protein": 蛋白质（浮点数，单位：克）,
      "fat": 脂肪（浮点数，单位：克）,
      "carbs": 碳水化合物（浮点数，单位：克）,
      "fiber": 膳食纤维（浮点数，单位：克，可选）,
      "sugar": 糖分（浮点数，单位：克，可选）,
      "health_rating": "健康评级（优秀/良好/一般/较差）"
    }
  ],
  "total_calories": 总热量（整数）,
  "total_protein": 总蛋白质（浮点数）,
  "total_fat": 总脂肪（浮点数）,
  "total_carbs": 总碳水化合物（浮点数）,
  "health_score": 健康评分（0-100整数）,
  "suggestions": [
    "营养建议1",
    "营养建议2",
    "营养建议3"
  ]
}

请严格按照上述JSON格式返回，不要添加任何其他文字说明。
"""

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
                            text: nutritionPrompt,
                            imageUrl: nil
                        )
                    ]
                )
            ]
        )

        // Make API call
        let responseText = try await makeRequest(request)

        // Parse JSON response
        return try parseNutritionResponse(responseText)
    }

    // MARK: - Private Methods

    private func makeRequest(_ request: ChatCompletionRequest) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LeanEatError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LeanEatError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ChatCompletionResponse.self, from: data)

        guard let firstChoice = apiResponse.choices.first else {
            throw LeanEatError.emptyResponse
        }

        return firstChoice.message.content
    }

    private func parseNutritionResponse(_ text: String) throws -> FoodNutritionResponse {
        // Extract JSON from response (in case AI added extra text)
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to find JSON object in the response
        if let jsonStart = jsonText.range(of: "{"),
           let jsonEnd = jsonText.range(of: "}", options: .backwards) {
            jsonText = String(jsonText[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw LeanEatError.invalidJSON
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(FoodNutritionResponse.self, from: jsonData)
        } catch {
            print("❌ [LeanEat] JSON解析失败: \(error)")
            print("📝 [LeanEat] 原始响应: \(text)")
            throw LeanEatError.invalidJSON
        }
    }
}

// MARK: - Error Types

enum LeanEatError: LocalizedError {
    case invalidImage
    case emptyResponse
    case invalidResponse
    case invalidJSON
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片"
        case .emptyResponse:
            return "API 返回空响应"
        case .invalidResponse:
            return "无效的响应格式"
        case .invalidJSON:
            return "无法解析营养数据，请重试"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        }
    }
}
