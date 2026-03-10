package com.smartview.glassai.models

import com.smartview.glassai.ui.theme.HealthExcellent
import com.smartview.glassai.ui.theme.HealthFair
import com.smartview.glassai.ui.theme.HealthGood
import com.smartview.glassai.ui.theme.HealthPoor
import androidx.compose.ui.graphics.Color

data class FoodNutritionResponse(
    val foods: List<FoodItem> = emptyList(),
    val totalCalories: Int = 0,
    val totalProtein: Double = 0.0,
    val totalFat: Double = 0.0,
    val totalCarbs: Double = 0.0,
    val healthScore: Int = 0,
    val suggestions: List<String> = emptyList()
) {
    val healthScoreColor: Color
        get() = when {
            healthScore >= 80 -> HealthExcellent
            healthScore >= 60 -> HealthGood
            healthScore >= 40 -> HealthFair
            else -> HealthPoor
        }

    val healthScoreText: String
        get() = when {
            healthScore >= 80 -> "优秀"
            healthScore >= 60 -> "良好"
            healthScore >= 40 -> "一般"
            else -> "较差"
        }
}

data class FoodItem(
    val name: String,
    val portion: String,
    val calories: Int,
    val protein: Double,
    val fat: Double,
    val carbs: Double,
    val fiber: Double? = null,
    val sugar: Double? = null,
    val healthRating: String = "良好"
) {
    val healthRatingEmoji: String
        get() = when (healthRating) {
            "优秀" -> "🟢"
            "良好" -> "🟡"
            "一般" -> "🟠"
            "较差" -> "🔴"
            else -> "🟡"
        }

    val healthRatingColor: Color
        get() = when (healthRating) {
            "优秀" -> HealthExcellent
            "良好" -> HealthGood
            "一般" -> HealthFair
            "较差" -> HealthPoor
            else -> HealthGood
        }
}
