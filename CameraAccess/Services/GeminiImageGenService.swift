/*
 * Gemini Image Generation Service
 * Handles interaction with Gemini API for Image Generation
 */

import Foundation
import UIKit

struct GeminiImageGenService {
    // API Configuration
    private let apiKey: String
    private var baseURL: String {
        VisionAPIConfig.baseURL(for: VisionAPIConfig.activeImageGenProvider)
    }
    
    // Default model if not specified
    private let defaultModel = VisionAPIConfig.imageGenModel

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - API Request/Response Models

    // Request structure for Gemini API (GenerateContent)
    // Documentation: https://ai.google.dev/api/rest/v1beta/models/generateContent
    struct GenerateContentRequest: Codable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
        
        struct Content: Codable {
            let parts: [Part]
            
            struct Part: Codable {
                let text: String?
                let inlineData: InlineData?
                
                struct InlineData: Codable {
                    let mimeType: String
                    let data: String
                }
            }
        }
        
        struct GenerationConfig: Codable {
            let responseMimeType: String?
        }
    }

    // Response structure
    // We expect the response to contain the generated image data or a link
    // Note: Gemini API for Image Generation usually returns key "images" in some variations, 
    // but the unified generateContent model primarily returns "candidates".
    // If it returns an image, it might be in base64 within the parts.
    
    // However, depending on the exact model version and capability, the response format might differ.
    // For standard Gemini Image Gen (Imagen 3), it might return base64 images.
    
    struct GenerateContentResponse: Codable {
        let candidates: [Candidate]?
        
        struct Candidate: Codable {
            let content: Content
            
            struct Content: Codable {
                let parts: [Part]
                
                struct Part: Codable {
                    let text: String?
                    let inlineData: InlineData?
                    
                    struct InlineData: Codable {
                        let mimeType: String
                        let data: String
                    }
                }
            }
        }
    }

    struct OpenAIImageGenRequest: Codable {
        let model: String
        let prompt: String
        let size: String
        let response_format: String?
    }

    struct OpenAIImageGenResponse: Codable {
        let created: Int
        let data: [Item]
        
        struct Item: Codable {
            let url: String?
            let b64_json: String?
        }
    }

    // MARK: - Public Methods

    enum ImageStyle: String, CaseIterable, Identifiable {
        case realistic = "写实风格 (Realistic)"
        case anime = "动漫风格 (Anime)"
        case watercolor = "水彩风格 (Watercolor)"
        case cyberpunk = "赛博朋克 (Cyberpunk)"
        case sketch = "素描风格 (Sketch)"
        case oilPainting = "油画风格 (Oil Painting)"
        
        var id: String { rawValue }
        
        var promptModifier: String {
            switch self {
            case .realistic: return "photorealistic, 8k, highly detailed, realistic texture, cinematic lighting"
            case .anime: return "anime style, studio ghibli style, vibrant colors, clean lines"
            case .watercolor: return "watercolor painting style, soft edges, artistic, blending colors"
            case .cyberpunk: return "cyberpunk style, neon lights, futuristic, high contrast"
            case .sketch: return "pencil sketch, black and white, rough lines, artistic"
            case .oilPainting: return "oil painting style, textured, canvas strokes, classical art"
            }
        }
    }

    /// Generate image based on original image and style
    /// - Parameters:
    ///   - originalImage: The input image (e.g., photo taken by user)
    ///   - prompt: User's prompt describing what to do or just base description
    ///   - style: Selected style
    /// - Returns: Generated image as UIImage
    func generateImage(originalImage: UIImage, prompt: String, style: ImageStyle) async throws -> UIImage {
        let provider = VisionAPIConfig.activeImageGenProvider

        if provider == .doubao {
            // Doubao T2I Logic (OpenAI Compatible)
            // Note: Doubao Seedream is primarily T2I. We ignore originalImage for now,
            // or we could use it if they support I2I via specific endpoint, strictly following user request for "Seedream"
            return try await generateImageOpenAI(prompt: prompt, style: style)
        }

        // 1. Prepare Image Data - 使用 ImageProcessor 优化压缩
        guard let imageData = originalImage.compressed(maxFileSizeKB: 500) else {
            throw GeminiImageGenError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()

        // 2. Construct Prompt
        let fullPrompt = "Redraw this image in \(style.promptModifier). \(prompt)"

        // 3. Create Request
        let requestBody = GenerateContentRequest(
            contents: [
                GenerateContentRequest.Content(
                    parts: [
                        GenerateContentRequest.Content.Part(text: fullPrompt, inlineData: nil),
                        GenerateContentRequest.Content.Part(
                            text: nil,
                            inlineData: GenerateContentRequest.Content.Part.InlineData(
                                mimeType: "image/jpeg",
                                data: base64Image
                            )
                        )
                    ]
                )
            ],
            generationConfig: nil
        )

        // 4. Make Request
        return try await makeRequest(requestBody)
    }

    private func generateImageOpenAI(prompt: String, style: ImageStyle) async throws -> UIImage {
        let fullPrompt = "\(style.promptModifier). \(prompt)"
        
        let requestBody = OpenAIImageGenRequest(
            model: VisionAPIConfig.imageGenModel,
            prompt: fullPrompt,
            size: "1024x1024",
            response_format: "b64_json"
        )
        
        return try await makeOpenAIRequest(requestBody)
    }
    
    // Support for text modification
    func modifyImage(originalImage: UIImage, instruction: String) async throws -> UIImage {
        // 使用 ImageProcessor 优化压缩
        guard let imageData = originalImage.compressed(maxFileSizeKB: 500) else {
            throw GeminiImageGenError.invalidImage
        }
        let base64Image = imageData.base64EncodedString()

        let requestBody = GenerateContentRequest(
            contents: [
                GenerateContentRequest.Content(
                    parts: [
                        GenerateContentRequest.Content.Part(text: "Edit this image: \(instruction)", inlineData: nil),
                        GenerateContentRequest.Content.Part(
                            text: nil,
                            inlineData: GenerateContentRequest.Content.Part.InlineData(
                                mimeType: "image/jpeg",
                                data: base64Image
                            )
                        )
                    ]
                )
            ],
            generationConfig: nil
        )

        return try await makeRequest(requestBody)
    }

    // MARK: - Private Methods

    private func makeRequest(_ requestBody: GenerateContentRequest) async throws -> UIImage {
        // Construct URL: baseURL + /models/{model}:generateContent
        // Note: VisionAPIConfig.baseURL might be just the host or base path.
        // Standard Google Gemini path: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent

        let model = VisionAPIConfig.imageGenModel

        // Clean up base URL to ensure it doesn't end with slash
        var cleanBaseURL = baseURL
        if cleanBaseURL.hasSuffix("/") {
            cleanBaseURL.removeLast()
        }

        // Check if baseURL already contains "models" or full path (for proxies)
        // If it's the standard Google URL, we append /models/{model}:generateContent
        let endpoint: String
        if cleanBaseURL.contains("generativelanguage.googleapis.com") {
             endpoint = "\(cleanBaseURL)/models/\(model):generateContent?key=\(apiKey)"
        } else {
             // For custom proxies (e.g. OpenAI compatible or custom Gemini proxies), logic might vary.
             // Assuming direct Gemini API proxy structure for now.
             endpoint = "\(cleanBaseURL)/models/\(model):generateContent"
        }

        guard let url = URL(string: endpoint) else {
            throw GeminiImageGenError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120 // 增加超时时间到120秒，图片生成可能较慢

        // If not using query param for key (e.g. custom proxy), add header
        if !endpoint.contains("key=") {
             urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(requestBody)

        // 使用带重试的网络请求
        let (data, response) = try await URLSession.shared.dataWithRetry(for: urlRequest, retryCount: 2)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiImageGenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Gemini Image Gen Error: \(errorMessage)")
            throw GeminiImageGenError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse Response
        let decoder = JSONDecoder()
        let genResponse = try decoder.decode(GenerateContentResponse.self, from: data)

        // Extract Image
        // Check for inline data in the first candidate
        if let firstCandidate = genResponse.candidates?.first,
           let parts = firstCandidate.content.parts.first,
           let inlineData = parts.inlineData,
           let imageData = Data(base64Encoded: inlineData.data),
           let image = UIImage(data: imageData) {
            return image
        }

        throw GeminiImageGenError.noImageGenerated

    }

    private func makeOpenAIRequest(_ requestBody: OpenAIImageGenRequest) async throws -> UIImage {
        // Construct URL: baseURL + /images/generations
        var cleanBaseURL = baseURL
        if cleanBaseURL.hasSuffix("/") {
            cleanBaseURL.removeLast()
        }

        let endpoint = "\(cleanBaseURL)/images/generations"

        guard let url = URL(string: endpoint) else {
            throw GeminiImageGenError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 120 // 增加超时时间到120秒

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(requestBody)

        // 使用带重试的网络请求
        let (data, response) = try await URLSession.shared.dataWithRetry(for: urlRequest, retryCount: 2)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiImageGenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("OpenAI/Doubao Image Gen Error: \(errorMessage)")
            throw GeminiImageGenError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let genResponse = try decoder.decode(OpenAIImageGenResponse.self, from: data)

        if let firstItem = genResponse.data.first {
            if let b64 = firstItem.b64_json,
               let imageData = Data(base64Encoded: b64),
               let image = UIImage(data: imageData) {
                return image
            }

            if let urlString = firstItem.url,
               let imageURL = URL(string: urlString) {
                // Download image from URL with retry
                let (imageData, _) = try await URLSession.shared.dataWithRetry(from: imageURL, retryCount: 2)
                if let image = UIImage(data: imageData) {
                    return image
                }
            }
        }

        throw GeminiImageGenError.noImageGenerated
    }
}

// MARK: - Error Types

enum GeminiImageGenError: LocalizedError {
    case invalidImage
    case invalidURL
    case invalidResponse
    case noImageGenerated
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "无法处理图片"
        case .invalidURL:
            return "无效的 API 地址"
        case .invalidResponse:
            return "无效的响应格式"
        case .noImageGenerated:
            return "未生成有效的图片数据"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        }
    }
}
