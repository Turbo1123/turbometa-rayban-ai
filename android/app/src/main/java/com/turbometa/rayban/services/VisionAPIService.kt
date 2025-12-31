package com.turbometa.rayban.services

import android.graphics.Bitmap
import android.util.Base64
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonObject
import com.turbometa.rayban.managers.AlibabaEndpoint
import com.turbometa.rayban.managers.APIProvider
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.utils.APIKeyManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

/**
 * Vision API Service
 * Supports multiple providers: Alibaba Cloud Dashscope (Beijing/Singapore), OpenRouter
 * 1:1 port from iOS VisionAPIConfig + QuickVisionService
 */
class VisionAPIService(
    private val apiKeyManager: APIKeyManager,
    private val providerManager: APIProviderManager
) {
    companion object {
        private const val TAG = "VisionAPIService"

        // Provider-specific URLs
        const val ALIBABA_BEIJING_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
        const val ALIBABA_SINGAPORE_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        const val OPENROUTER_URL = "https://openrouter.ai/api/v1"

        // Default Models
        const val DEFAULT_ALIBABA_MODEL = "qwen3-vl-plus"
        const val DEFAULT_OPENROUTER_MODEL = "google/gemini-3-flash-preview"
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val gson = Gson()

    // MARK: - Configuration

    private val currentProvider: APIProvider
        get() = providerManager.currentProvider.value

    private val alibabaEndpoint: AlibabaEndpoint
        get() = providerManager.alibabaEndpoint.value

    private val baseURL: String
        get() = when (currentProvider) {
            APIProvider.ALIBABA -> when (alibabaEndpoint) {
                AlibabaEndpoint.BEIJING -> ALIBABA_BEIJING_URL
                AlibabaEndpoint.SINGAPORE -> ALIBABA_SINGAPORE_URL
            }
            APIProvider.OPENROUTER -> OPENROUTER_URL
        }

    private val apiKey: String?
        get() = when (currentProvider) {
            APIProvider.ALIBABA -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, alibabaEndpoint)
            APIProvider.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
        }

    private val model: String
        get() = providerManager.selectedModel.value

    // MARK: - Analyze Image

    suspend fun analyzeImage(image: Bitmap, prompt: String): Result<String> = withContext(Dispatchers.IO) {
        try {
            val key = apiKey
            if (key.isNullOrBlank()) {
                return@withContext Result.failure(VisionAPIError.NoAPIKey)
            }

            Log.d(TAG, "Analyzing image with provider: $currentProvider, model: $model")

            val base64Image = encodeImageToBase64(image)
            val requestBody = buildRequestBody(base64Image, prompt)
            val url = "$baseURL/chat/completions"

            val requestBuilder = Request.Builder()
                .url(url)
                .addHeader("Authorization", "Bearer $key")
                .addHeader("Content-Type", "application/json")

            // Add OpenRouter-specific headers
            if (currentProvider == APIProvider.OPENROUTER) {
                requestBuilder.addHeader("HTTP-Referer", "https://turbometa.app")
                requestBuilder.addHeader("X-Title", "TurboMeta")
            }

            val request = requestBuilder
                .post(requestBody.toRequestBody("application/json".toMediaType()))
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string()

            if (!response.isSuccessful) {
                Log.e(TAG, "API Error: ${response.code} - $responseBody")
                return@withContext Result.failure(VisionAPIError.APIError("API Error: ${response.code} - $responseBody"))
            }

            if (responseBody.isNullOrEmpty()) {
                return@withContext Result.failure(VisionAPIError.EmptyResponse)
            }

            val result = parseResponse(responseBody)
            if (result.isNullOrEmpty()) {
                return@withContext Result.failure(VisionAPIError.InvalidResponse)
            }

            Log.d(TAG, "Analysis successful")
            Result.success(result)
        } catch (e: Exception) {
            Log.e(TAG, "Error analyzing image: ${e.message}")
            Result.failure(e)
        }
    }

    // MARK: - Quick Vision (for background recognition)
    // Matching iOS QuickVision prompts exactly

    suspend fun quickVision(image: Bitmap, language: String = "zh-CN"): Result<String> {
        val prompt = getQuickVisionPrompt(language)
        return analyzeImage(image, prompt)
    }

    /**
     * Get localized Quick Vision prompt matching iOS implementation
     */
    private fun getQuickVisionPrompt(language: String): String {
        return when (language) {
            "zh-CN" -> """
                你是一个智能眼镜AI助手。请用简洁的中文描述图片内容，适合语音播报。

                要求：
                1. 用1-2句话描述主要内容
                2. 语言自然、口语化
                3. 不要使用标点符号过多
                4. 总字数控制在50字以内
                5. 直接描述，不要说"图片中"或"我看到"
            """.trimIndent()
            "en-US" -> """
                You are a smart glasses AI assistant. Please describe the image content concisely, suitable for voice announcement.

                Requirements:
                1. Describe the main content in 1-2 sentences
                2. Use natural, conversational language
                3. Don't use too many punctuation marks
                4. Keep the total under 50 words
                5. Describe directly, don't say "in the image" or "I see"
            """.trimIndent()
            "ja-JP" -> """
                あなたはスマートグラスのAIアシスタントです。画像の内容を簡潔に日本語で説明してください。音声読み上げに適した形式で。

                要件：
                1. 1-2文で主要な内容を説明
                2. 自然で会話的な言葉を使用
                3. 句読点を多用しない
                4. 合計50文字以内
                5. 直接説明し、「画像には」や「見えます」とは言わない
            """.trimIndent()
            "ko-KR" -> """
                당신은 스마트 안경 AI 어시스턴트입니다. 이미지 내용을 간결한 한국어로 설명해 주세요. 음성 안내에 적합하게.

                요구사항:
                1. 1-2문장으로 주요 내용 설명
                2. 자연스럽고 대화체로
                3. 구두점을 많이 사용하지 않음
                4. 총 50자 이내
                5. 직접 설명하고, "이미지에는"이나 "보입니다"라고 말하지 않음
            """.trimIndent()
            else -> getQuickVisionPrompt("en-US")
        }
    }

    // MARK: - Private Helpers

    private fun encodeImageToBase64(bitmap: Bitmap): String {
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
        val bytes = outputStream.toByteArray()
        return Base64.encodeToString(bytes, Base64.NO_WRAP)
    }

    private fun buildRequestBody(base64Image: String, prompt: String): String {
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
                        "text" to prompt
                    )
                )
            )
        )

        val request = mapOf(
            "model" to model,
            "messages" to messages,
            "max_tokens" to 2000
        )

        return gson.toJson(request)
    }

    private fun parseResponse(responseBody: String): String? {
        return try {
            val json = gson.fromJson(responseBody, JsonObject::class.java)
            val choices = json.getAsJsonArray("choices")
            if (choices != null && choices.size() > 0) {
                val message = choices[0].asJsonObject.getAsJsonObject("message")
                message?.get("content")?.asString
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing response: ${e.message}")
            null
        }
    }
}

sealed class VisionAPIError : Exception() {
    object InvalidImage : VisionAPIError()
    object EmptyResponse : VisionAPIError()
    object InvalidResponse : VisionAPIError()
    object NoAPIKey : VisionAPIError()
    data class APIError(override val message: String) : VisionAPIError()
}
