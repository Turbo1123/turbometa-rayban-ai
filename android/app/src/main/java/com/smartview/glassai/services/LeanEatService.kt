package com.smartview.glassai.services

import android.graphics.Bitmap
import android.util.Base64
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.smartview.glassai.models.FoodItem
import com.smartview.glassai.models.FoodNutritionResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

class LeanEatService(private val apiKey: String) {

    companion object {
        private const val BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        private const val MODEL = "qwen-vl-plus"

        private val NUTRITION_PROMPT = """
请分析这张图片中的食物，并以JSON格式返回营养分析结果。

请严格按照以下JSON格式返回（不要包含任何其他文字）：
{
  "foods": [
    {
      "name": "食物名称",
      "portion": "份量描述",
      "calories": 热量数值(整数),
      "protein": 蛋白质克数(小数),
      "fat": 脂肪克数(小数),
      "carbs": 碳水化合物克数(小数),
      "fiber": 膳食纤维克数(小数或null),
      "sugar": 糖克数(小数或null),
      "healthRating": "优秀/良好/一般/较差"
    }
  ],
  "totalCalories": 总热量(整数),
  "totalProtein": 总蛋白质(小数),
  "totalFat": 总脂肪(小数),
  "totalCarbs": 总碳水(小数),
  "healthScore": 0-100的健康评分(整数),
  "suggestions": ["建议1", "建议2", "建议3"]
}

健康评分标准：
- 80-100: 优秀（低脂、高蛋白、富含纤维）
- 60-79: 良好（营养较均衡）
- 40-59: 一般（可能高脂或高糖）
- 0-39: 较差（高热量、低营养）

请只返回JSON，不要有任何其他解释文字。
""".trimIndent()
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    suspend fun analyzeFood(image: Bitmap): Result<FoodNutritionResponse> = withContext(Dispatchers.IO) {
        try {
            val base64Image = encodeImageToBase64(image)
            val requestBody = buildRequestBody(base64Image)

            val request = Request.Builder()
                .url(BASE_URL)
                .addHeader("Authorization", "Bearer $apiKey")
                .addHeader("Content-Type", "application/json")
                .post(requestBody.toRequestBody("application/json".toMediaType()))
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()

            if (!response.isSuccessful) {
                return@withContext Result.failure(Exception("API Error: ${response.code} - $responseBody"))
            }

            if (responseBody.isNullOrEmpty()) {
                return@withContext Result.failure(Exception("Empty response from API"))
            }

            val nutritionResponse = parseNutritionResponse(responseBody)
            if (nutritionResponse == null) {
                return@withContext Result.failure(Exception("Failed to parse nutrition data"))
            }

            Result.success(nutritionResponse)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun encodeImageToBase64(bitmap: Bitmap): String {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
        val bytes = outputStream.toByteArray()
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun buildRequestBody(base64Image: String): String {
        val messages = listOf(
            mapOf(
                "role" to "user",
                "content" to listOf(
                    mapOf(
                        "type" to "image_url",
                        "image_url" to mapOf(
                            "url" to "data:image/jpeg;base64,$base64Image"
                        )
                    ),
                    mapOf(
                        "type" to "text",
                        "text" to NUTRITION_PROMPT
                    )
                )
            )
        )

        val request = mapOf(
            "model" to MODEL,
            "messages" to messages,
            "max_tokens" to 2000
        )

        return gson.toJson(request)
    }

    private fun parseNutritionResponse(responseBody: String): FoodNutritionResponse? {
        return try {
            val json = gson.fromJson(responseBody, JsonObject::class.java)
            val choices = json.getAsJsonArray("choices")
            if (choices == null || choices.size() == 0) return null

            val message = choices[0].asJsonObject.getAsJsonObject("message")
            val content = message?.get("content")?.asString ?: return null

            // Extract JSON from content (in case it has extra text)
            val jsonContent = extractJson(content) ?: return null

            // Parse the nutrition JSON
            parseNutritionJson(jsonContent)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun extractJson(content: String): String? {
        // Find JSON object in content
        val startIndex = content.indexOf('{')
        val endIndex = content.lastIndexOf('}')
        return if (startIndex >= 0 && endIndex > startIndex) {
            content.substring(startIndex, endIndex + 1)
        } else {
            null
        }
    }

    private fun parseNutritionJson(json: String): FoodNutritionResponse? {
        return try {
            val jsonObject = gson.fromJson(json, JsonObject::class.java)

            val foodsArray = jsonObject.getAsJsonArray("foods")
            val foods = mutableListOf<FoodItem>()

            foodsArray?.forEach { element ->
                val food = element.asJsonObject
                foods.add(
                    FoodItem(
                        name = food.get("name")?.asString ?: "",
                        portion = food.get("portion")?.asString ?: "",
                        calories = food.get("calories")?.asInt ?: 0,
                        protein = food.get("protein")?.asDouble ?: 0.0,
                        fat = food.get("fat")?.asDouble ?: 0.0,
                        carbs = food.get("carbs")?.asDouble ?: 0.0,
                        fiber = food.get("fiber")?.asDouble,
                        sugar = food.get("sugar")?.asDouble,
                        healthRating = food.get("healthRating")?.asString ?: "良好"
                    )
                )
            }

            val suggestionsArray = jsonObject.getAsJsonArray("suggestions")
            val suggestions = suggestionsArray?.map { it.asString } ?: emptyList()

            FoodNutritionResponse(
                foods = foods,
                totalCalories = jsonObject.get("totalCalories")?.asInt ?: 0,
                totalProtein = jsonObject.get("totalProtein")?.asDouble ?: 0.0,
                totalFat = jsonObject.get("totalFat")?.asDouble ?: 0.0,
                totalCarbs = jsonObject.get("totalCarbs")?.asDouble ?: 0.0,
                healthScore = jsonObject.get("healthScore")?.asInt ?: 50,
                suggestions = suggestions
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
