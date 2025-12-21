/*
 * Vision Recognition ViewModel
 * Manages image recognition state and API interaction
 */

import Foundation
import SwiftUI

@MainActor
class VisionRecognitionViewModel: ObservableObject {
    // Published properties for UI
    @Published var isAnalyzing = false
    @Published var recognitionResult: String?
    @Published var errorMessage: String?
    @Published var customPrompt: String = "图中描绘的是什么景象?"

    private let apiService: VisionAPIService
    private let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self.apiService = VisionAPIService(apiKey: apiKey)
    }

    // MARK: - Public Methods

    func analyzeImage(with prompt: String? = nil) async {
        isAnalyzing = true
        errorMessage = nil
        recognitionResult = nil

        do {
            let promptToUse = prompt ?? customPrompt
            let result = try await apiService.analyzeImage(photo, prompt: promptToUse)
            recognitionResult = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    func retryAnalysis() async {
        await analyzeImage()
    }

    func clearResult() {
        recognitionResult = nil
        errorMessage = nil
    }

    // MARK: - Quick Prompts

    static let quickPrompts = [
        "图中描绘的是什么景象?",
        "请详细描述这张图片的内容",
        "这张图片中有哪些物体?",
        "请用英文描述这张图片",
        "这是什么地方?",
        "图中的人在做什么?"
    ]
}
