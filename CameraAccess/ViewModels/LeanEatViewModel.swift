/*
 * LeanEat ViewModel
 * 食物营养分析视图模型
 */

import Foundation
import SwiftUI

@MainActor
class LeanEatViewModel: ObservableObject {
    // Published properties
    @Published var isAnalyzing = false
    @Published var nutritionData: FoodNutritionResponse?
    @Published var errorMessage: String?

    private let service: LeanEatService
    private let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self.service = LeanEatService(apiKey: apiKey)
    }

    // MARK: - Public Methods

    func analyzeFood() async {
        isAnalyzing = true
        errorMessage = nil
        nutritionData = nil

        do {
            print("🍎 [LeanEat] 开始分析食物营养...")
            let result = try await service.analyzeFood(photo)
            nutritionData = result
            print("✅ [LeanEat] 分析完成: \(result.foods.count) 种食物")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [LeanEat] 分析失败: \(error)")
        }

        isAnalyzing = false
    }

    func retry() async {
        await analyzeFood()
    }

    func clear() {
        nutritionData = nil
        errorMessage = nil
    }
}
