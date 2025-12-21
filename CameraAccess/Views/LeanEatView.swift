/*
 * LeanEat View
 * 食物营养分析界面
 */

import SwiftUI

struct LeanEatView: View {
    @StateObject private var viewModel: LeanEatViewModel
    @Environment(\.dismiss) private var dismiss

    let photo: UIImage

    init(photo: UIImage, apiKey: String) {
        self.photo = photo
        self._viewModel = StateObject(wrappedValue: LeanEatViewModel(photo: photo, apiKey: apiKey))
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.secondaryBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Photo section
                        photoSection

                        if viewModel.isAnalyzing {
                            analyzingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if let nutrition = viewModel.nutritionData {
                            nutritionResultView(nutrition)
                        } else {
                            analyzePromptView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("LeanEat 营养分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            // Auto-analyze on appear
            if viewModel.nutritionData == nil && viewModel.errorMessage == nil {
                await viewModel.analyzeFood()
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        Image(uiImage: photo)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 250)
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 8, x: 0, y: 4)
    }

    // MARK: - Analyzing View

    private var analyzingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.leanEat)

            Text("AI正在分析食物营养...")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("请稍候，这可能需要几秒钟")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("分析失败")
                .font(AppTypography.title2)
                .foregroundColor(AppColors.textPrimary)

            Text(error)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.retry()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                }
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.leanEat)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Analyze Prompt View

    private var analyzePromptView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.system(size: 60))
                .foregroundColor(AppColors.leanEat)

            Text("开始分析")
                .font(AppTypography.title2)
                .foregroundColor(AppColors.textPrimary)

            Text("点击下方按钮开始分析食物营养")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)

            Button {
                Task {
                    await viewModel.analyzeFood()
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("开始分析")
                }
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    LinearGradient(
                        colors: [AppColors.leanEat, AppColors.leanEat.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Nutrition Result View

    private func nutritionResultView(_ nutrition: FoodNutritionResponse) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Health Score Card
            healthScoreCard(nutrition)

            // Total Nutrition Summary
            totalNutritionCard(nutrition)

            // Food Items List
            foodItemsList(nutrition.foods)

            // Health Suggestions
            if !nutrition.suggestions.isEmpty {
                suggestionsCard(nutrition.suggestions)
            }
        }
    }

    // MARK: - Health Score Card

    private func healthScoreCard(_ nutrition: FoodNutritionResponse) -> some View {
        VStack(spacing: AppSpacing.md) {
            Text("健康评分")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            ZStack {
                Circle()
                    .stroke(
                        Color.gray.opacity(0.2),
                        lineWidth: 15
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: CGFloat(nutrition.healthScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(nutrition.healthScoreColor == "green" ? .green : nutrition.healthScoreColor == "yellow" ? .yellow : nutrition.healthScoreColor == "orange" ? .orange : .red),
                                Color(nutrition.healthScoreColor == "green" ? .green : nutrition.healthScoreColor == "yellow" ? .yellow : nutrition.healthScoreColor == "orange" ? .orange : .red).opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(nutrition.healthScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(nutrition.healthScoreText)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.tertiaryBackground)
        .cornerRadius(AppCornerRadius.xl)
        .shadow(color: AppShadow.small(), radius: 4, x: 0, y: 2)
    }

    // MARK: - Total Nutrition Card

    private func totalNutritionCard(_ nutrition: FoodNutritionResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("总营养成分")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                nutritionItem(
                    icon: "flame.fill",
                    title: "热量",
                    value: nutrition.formattedTotalCalories,
                    color: .orange
                )

                nutritionItem(
                    icon: "leaf.fill",
                    title: "蛋白质",
                    value: nutrition.formattedTotalProtein,
                    color: .green
                )

                nutritionItem(
                    icon: "drop.fill",
                    title: "脂肪",
                    value: nutrition.formattedTotalFat,
                    color: .yellow
                )

                nutritionItem(
                    icon: "sparkles",
                    title: "碳水",
                    value: nutrition.formattedTotalCarbs,
                    color: .blue
                )
            }
        }
        .padding()
        .background(AppColors.tertiaryBackground)
        .cornerRadius(AppCornerRadius.xl)
        .shadow(color: AppShadow.small(), radius: 4, x: 0, y: 2)
    }

    private func nutritionItem(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.secondaryBackground)
        .cornerRadius(AppCornerRadius.lg)
    }

    // MARK: - Food Items List

    private func foodItemsList(_ foods: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("食物明细")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal)

            ForEach(foods) { food in
                foodItemCard(food)
            }
        }
    }

    private func foodItemCard(_ food: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Food name and rating
            HStack {
                Text(food.healthRatingEmoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Text(food.portion)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(food.healthRating)
                    .font(AppTypography.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        food.healthRating == "优秀" ? Color.green :
                        food.healthRating == "良好" ? Color.yellow :
                        food.healthRating == "一般" ? Color.orange : Color.red
                    )
                    .cornerRadius(AppCornerRadius.sm)
            }

            Divider()

            // Nutrition details
            HStack(spacing: AppSpacing.lg) {
                miniNutritionItem(icon: "flame.fill", value: "\(food.calories)", unit: "千卡", color: .orange)
                miniNutritionItem(icon: "leaf.fill", value: String(format: "%.1f", food.protein), unit: "g", color: .green)
                miniNutritionItem(icon: "drop.fill", value: String(format: "%.1f", food.fat), unit: "g", color: .yellow)
                miniNutritionItem(icon: "sparkles", value: String(format: "%.1f", food.carbs), unit: "g", color: .blue)
            }
        }
        .padding()
        .background(AppColors.tertiaryBackground)
        .cornerRadius(AppCornerRadius.lg)
        .shadow(color: AppShadow.small(), radius: 4, x: 0, y: 2)
    }

    private func miniNutritionItem(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                Text(unit)
                    .font(.system(size: 10))
            }
            .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Suggestions Card

    private func suggestionsCard(_ suggestions: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.leanEat)
                Text("营养建议")
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)
            }

            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Text("\(index + 1).")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.leanEat)
                        .fontWeight(.bold)

                    Text(suggestion)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(AppColors.leanEat.opacity(0.1))
        .cornerRadius(AppCornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                .stroke(AppColors.leanEat.opacity(0.3), lineWidth: 1)
        )
    }
}
