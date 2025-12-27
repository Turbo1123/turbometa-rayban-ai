package com.turbometa.rayban.utils

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class APIKeyManager(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val sharedPreferences = EncryptedSharedPreferences.create(
        context,
        "turbometa_secure_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    companion object {
        private const val KEY_API_KEY = "qwen_api_key"
        private const val KEY_AI_MODEL = "ai_model"
        private const val KEY_OUTPUT_LANGUAGE = "output_language"
        private const val KEY_VIDEO_QUALITY = "video_quality"

        @Volatile
        private var instance: APIKeyManager? = null

        fun getInstance(context: Context): APIKeyManager {
            return instance ?: synchronized(this) {
                instance ?: APIKeyManager(context.applicationContext).also { instance = it }
            }
        }
    }

    fun saveAPIKey(key: String): Boolean {
        return try {
            if (key.isBlank()) return false
            sharedPreferences.edit().putString(KEY_API_KEY, key).apply()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun getAPIKey(): String? {
        return try {
            sharedPreferences.getString(KEY_API_KEY, null)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun deleteAPIKey(): Boolean {
        return try {
            sharedPreferences.edit().remove(KEY_API_KEY).apply()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun hasAPIKey(): Boolean {
        return !getAPIKey().isNullOrBlank()
    }

    // AI Model
    fun saveAIModel(model: String) {
        sharedPreferences.edit().putString(KEY_AI_MODEL, model).apply()
    }

    fun getAIModel(): String {
        return sharedPreferences.getString(KEY_AI_MODEL, "qwen3-omni-flash-realtime") ?: "qwen3-omni-flash-realtime"
    }

    // Output Language
    fun saveOutputLanguage(language: String) {
        sharedPreferences.edit().putString(KEY_OUTPUT_LANGUAGE, language).apply()
    }

    fun getOutputLanguage(): String {
        return sharedPreferences.getString(KEY_OUTPUT_LANGUAGE, "zh-CN") ?: "zh-CN"
    }

    // Video Quality
    fun saveVideoQuality(quality: String) {
        sharedPreferences.edit().putString(KEY_VIDEO_QUALITY, quality).apply()
    }

    fun getVideoQuality(): String {
        return sharedPreferences.getString(KEY_VIDEO_QUALITY, "MEDIUM") ?: "MEDIUM"
    }
}

// Available AI models
enum class AIModel(val id: String, val displayName: String) {
    FLASH_REALTIME("qwen3-omni-flash-realtime", "Qwen3 Omni Flash (Realtime)"),
    STANDARD_REALTIME("qwen3-omni-standard-realtime", "Qwen3 Omni Standard (Realtime)")
}

// Available output languages
enum class OutputLanguage(val code: String, val displayName: String, val nativeName: String) {
    CHINESE("zh-CN", "Chinese", "中文"),
    ENGLISH("en-US", "English", "English"),
    JAPANESE("ja-JP", "Japanese", "日本語"),
    KOREAN("ko-KR", "Korean", "한국어"),
    SPANISH("es-ES", "Spanish", "Español"),
    FRENCH("fr-FR", "French", "Français")
}

// Video quality options
enum class StreamQuality(val id: String, val displayName: String, val description: String) {
    LOW("LOW", "低画质", "省电模式，适合长时间使用"),
    MEDIUM("MEDIUM", "中画质", "平衡模式（推荐）"),
    HIGH("HIGH", "高画质", "最佳画质，耗电较快")
}
