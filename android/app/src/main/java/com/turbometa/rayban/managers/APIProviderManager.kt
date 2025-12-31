package com.turbometa.rayban.managers

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/**
 * API Provider Manager
 * 管理不同的 API 提供商 (阿里云 Dashscope / OpenRouter / Google)
 * 1:1 port from iOS APIProviderManager.swift
 */

// MARK: - Alibaba Endpoint Enum

enum class AlibabaEndpoint(val id: String) {
    BEIJING("beijing"),
    SINGAPORE("singapore");

    val displayName: String
        get() = when (this) {
            BEIJING -> "北京 (中国大陆)"
            SINGAPORE -> "新加坡 (国际)"
        }

    val displayNameEn: String
        get() = when (this) {
            BEIJING -> "Beijing (China)"
            SINGAPORE -> "Singapore (International)"
        }

    val baseURL: String
        get() = when (this) {
            BEIJING -> "https://dashscope.aliyuncs.com/compatible-mode/v1"
            SINGAPORE -> "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
        }

    val websocketURL: String
        get() = when (this) {
            BEIJING -> "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
            SINGAPORE -> "wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime"
        }

    companion object {
        fun fromId(id: String): AlibabaEndpoint {
            return entries.find { it.id == id } ?: BEIJING
        }
    }
}

// MARK: - API Provider Enum (Vision API)

enum class APIProvider(val id: String) {
    ALIBABA("alibaba"),
    OPENROUTER("openrouter");

    val displayName: String
        get() = when (this) {
            ALIBABA -> "阿里云 Dashscope"
            OPENROUTER -> "OpenRouter"
        }

    val displayNameEn: String
        get() = when (this) {
            ALIBABA -> "Alibaba Dashscope"
            OPENROUTER -> "OpenRouter"
        }

    fun baseURL(endpoint: AlibabaEndpoint = AlibabaEndpoint.BEIJING): String {
        return when (this) {
            ALIBABA -> endpoint.baseURL
            OPENROUTER -> "https://openrouter.ai/api/v1"
        }
    }

    val defaultModel: String
        get() = when (this) {
            ALIBABA -> "qwen-vl-flash"
            OPENROUTER -> "google/gemini-2.0-flash-001"
        }

    val apiKeyHelpURL: String
        get() = when (this) {
            ALIBABA -> "https://help.aliyun.com/zh/model-studio/get-api-key"
            OPENROUTER -> "https://openrouter.ai/keys"
        }

    val supportsVision: Boolean
        get() = true

    companion object {
        fun fromId(id: String): APIProvider {
            return entries.find { it.id == id } ?: ALIBABA
        }
    }
}

// MARK: - Live AI Provider Enum

enum class LiveAIProvider(val id: String) {
    ALIBABA("alibaba"),
    GOOGLE("google");

    val displayName: String
        get() = when (this) {
            ALIBABA -> "阿里云 Qwen Omni"
            GOOGLE -> "Google Gemini Live"
        }

    val displayNameEn: String
        get() = when (this) {
            ALIBABA -> "Alibaba Qwen Omni"
            GOOGLE -> "Google Gemini Live"
        }

    val defaultModel: String
        get() = when (this) {
            ALIBABA -> "qwen3-omni-flash-realtime"
            GOOGLE -> "gemini-2.0-flash-exp"
        }

    val apiKeyHelpURL: String
        get() = when (this) {
            ALIBABA -> "https://help.aliyun.com/zh/model-studio/get-api-key"
            GOOGLE -> "https://aistudio.google.com/apikey"
        }

    fun websocketURL(endpoint: AlibabaEndpoint = AlibabaEndpoint.BEIJING): String {
        return when (this) {
            ALIBABA -> endpoint.websocketURL
            GOOGLE -> "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        }
    }

    companion object {
        fun fromId(id: String): LiveAIProvider {
            return entries.find { it.id == id } ?: ALIBABA
        }
    }
}

// MARK: - OpenRouter Model

data class OpenRouterModel(
    val id: String,
    val name: String,
    val description: String? = null,
    @SerializedName("context_length")
    val contextLength: Int? = null,
    val pricing: Pricing? = null,
    val architecture: Architecture? = null
) {
    val displayName: String
        get() = name.ifEmpty { id }

    val isVisionCapable: Boolean
        get() {
            // Check if model supports vision based on architecture or ID
            architecture?.let { arch ->
                if (arch.modality?.contains("image") == true ||
                    arch.modality?.contains("multimodal") == true) {
                    return true
                }
            }
            // Fallback: check common vision model patterns
            val visionPatterns = listOf("vision", "vl", "gpt-4o", "claude-3", "gemini")
            return visionPatterns.any { id.lowercase().contains(it) }
        }

    val priceDisplay: String
        get() {
            val p = pricing ?: return ""
            val promptPrice = (p.prompt.toDoubleOrNull() ?: 0.0) * 1_000_000
            val completionPrice = (p.completion.toDoubleOrNull() ?: 0.0) * 1_000_000
            return String.format("$%.2f / $%.2f per 1M tokens", promptPrice, completionPrice)
        }

    data class Pricing(
        val prompt: String,
        val completion: String
    )

    data class Architecture(
        val modality: String? = null,
        val tokenizer: String? = null,
        @SerializedName("instruct_type")
        val instructType: String? = null
    )
}

data class OpenRouterModelsResponse(
    val data: List<OpenRouterModel>
)

// MARK: - Alibaba Vision Model

data class AlibabaVisionModel(
    val id: String,
    val displayName: String,
    val description: String
) {
    companion object {
        val availableModels = listOf(
            AlibabaVisionModel(
                "qwen-vl-flash",
                "Qwen VL Flash",
                "快速响应，适合实时场景"
            ),
            AlibabaVisionModel(
                "qwen-vl-plus",
                "Qwen VL Plus",
                "均衡性能，推荐日常使用"
            ),
            AlibabaVisionModel(
                "qwen-vl-max",
                "Qwen VL Max",
                "最强性能，适合复杂任务"
            ),
            AlibabaVisionModel(
                "qwen2.5-vl-72b-instruct",
                "Qwen 2.5 VL 72B",
                "大参数模型，高精度分析"
            )
        )
    }
}

// MARK: - API Provider Manager

class APIProviderManager private constructor(context: Context) {

    companion object {
        private const val PREFS_NAME = "api_provider_prefs"
        private const val KEY_PROVIDER = "api_provider"
        private const val KEY_SELECTED_MODEL = "selected_vision_model"
        private const val KEY_ALIBABA_ENDPOINT = "alibaba_endpoint"
        private const val KEY_LIVE_AI_PROVIDER = "liveai_provider"
        private const val KEY_LIVE_AI_MODEL = "liveai_model"

        @Volatile
        private var instance: APIProviderManager? = null

        fun getInstance(context: Context): APIProviderManager {
            return instance ?: synchronized(this) {
                instance ?: APIProviderManager(context.applicationContext).also { instance = it }
            }
        }

        // Static accessors for non-context access
        private var prefs: SharedPreferences? = null

        val staticCurrentProvider: APIProvider
            get() {
                val id = prefs?.getString(KEY_PROVIDER, "alibaba") ?: "alibaba"
                return APIProvider.fromId(id)
            }

        val staticAlibabaEndpoint: AlibabaEndpoint
            get() {
                val id = prefs?.getString(KEY_ALIBABA_ENDPOINT, "beijing") ?: "beijing"
                return AlibabaEndpoint.fromId(id)
            }

        val staticLiveAIProvider: LiveAIProvider
            get() {
                val id = prefs?.getString(KEY_LIVE_AI_PROVIDER, "alibaba") ?: "alibaba"
                return LiveAIProvider.fromId(id)
            }

        val staticCurrentModel: String
            get() {
                return prefs?.getString(KEY_SELECTED_MODEL, null)
                    ?: staticCurrentProvider.defaultModel
            }

        val staticBaseURL: String
            get() = staticCurrentProvider.baseURL(staticAlibabaEndpoint)
    }

    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    init {
        // Set static prefs for non-context access
        Companion.prefs = this.prefs
    }

    // Vision API Provider
    private val _currentProvider = MutableStateFlow(
        APIProvider.fromId(prefs.getString(KEY_PROVIDER, "alibaba") ?: "alibaba")
    )
    val currentProvider: StateFlow<APIProvider> = _currentProvider

    private val _selectedModel = MutableStateFlow(
        prefs.getString(KEY_SELECTED_MODEL, null) ?: APIProvider.ALIBABA.defaultModel
    )
    val selectedModel: StateFlow<String> = _selectedModel

    // Alibaba Endpoint (Beijing/Singapore)
    private val _alibabaEndpoint = MutableStateFlow(
        AlibabaEndpoint.fromId(prefs.getString(KEY_ALIBABA_ENDPOINT, "beijing") ?: "beijing")
    )
    val alibabaEndpoint: StateFlow<AlibabaEndpoint> = _alibabaEndpoint

    // Live AI Provider
    private val _liveAIProvider = MutableStateFlow(
        LiveAIProvider.fromId(prefs.getString(KEY_LIVE_AI_PROVIDER, "alibaba") ?: "alibaba")
    )
    val liveAIProvider: StateFlow<LiveAIProvider> = _liveAIProvider

    private val _liveAIModel = MutableStateFlow(
        prefs.getString(KEY_LIVE_AI_MODEL, null) ?: LiveAIProvider.ALIBABA.defaultModel
    )
    val liveAIModel: StateFlow<String> = _liveAIModel

    // OpenRouter Models
    private val _openRouterModels = MutableStateFlow<List<OpenRouterModel>>(emptyList())
    val openRouterModels: StateFlow<List<OpenRouterModel>> = _openRouterModels

    private val _isLoadingModels = MutableStateFlow(false)
    val isLoadingModels: StateFlow<Boolean> = _isLoadingModels

    private val _modelsError = MutableStateFlow<String?>(null)
    val modelsError: StateFlow<String?> = _modelsError

    // MARK: - Setters

    fun setCurrentProvider(provider: APIProvider) {
        val oldValue = _currentProvider.value
        _currentProvider.value = provider
        prefs.edit().putString(KEY_PROVIDER, provider.id).apply()

        // Reset to default model when provider changes
        if (oldValue != provider) {
            setSelectedModel(provider.defaultModel)
        }
    }

    fun setSelectedModel(model: String) {
        _selectedModel.value = model
        prefs.edit().putString(KEY_SELECTED_MODEL, model).apply()
    }

    fun setAlibabaEndpoint(endpoint: AlibabaEndpoint) {
        _alibabaEndpoint.value = endpoint
        prefs.edit().putString(KEY_ALIBABA_ENDPOINT, endpoint.id).apply()
    }

    fun setLiveAIProvider(provider: LiveAIProvider) {
        val oldValue = _liveAIProvider.value
        _liveAIProvider.value = provider
        prefs.edit().putString(KEY_LIVE_AI_PROVIDER, provider.id).apply()

        if (oldValue != provider) {
            setLiveAIModel(provider.defaultModel)
        }
    }

    fun setLiveAIModel(model: String) {
        _liveAIModel.value = model
        prefs.edit().putString(KEY_LIVE_AI_MODEL, model).apply()
    }

    // MARK: - Live AI Configuration

    val liveAIWebSocketURL: String
        get() = _liveAIProvider.value.websocketURL(_alibabaEndpoint.value)

    fun getLiveAIAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): String {
        return when (_liveAIProvider.value) {
            LiveAIProvider.ALIBABA -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, _alibabaEndpoint.value) ?: ""
            LiveAIProvider.GOOGLE -> apiKeyManager.getGoogleAPIKey() ?: ""
        }
    }

    fun hasLiveAIAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): Boolean {
        return getLiveAIAPIKey(apiKeyManager).isNotEmpty()
    }

    // MARK: - Get Current Configuration

    val currentBaseURL: String
        get() = _currentProvider.value.baseURL(_alibabaEndpoint.value)

    fun getCurrentAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): String {
        return if (_currentProvider.value == APIProvider.ALIBABA) {
            apiKeyManager.getAPIKey(_currentProvider.value, _alibabaEndpoint.value) ?: ""
        } else {
            apiKeyManager.getAPIKey(_currentProvider.value) ?: ""
        }
    }

    val currentModel: String
        get() = _selectedModel.value

    fun hasAPIKey(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager): Boolean {
        return if (_currentProvider.value == APIProvider.ALIBABA) {
            apiKeyManager.hasAPIKey(_currentProvider.value, _alibabaEndpoint.value)
        } else {
            apiKeyManager.hasAPIKey(_currentProvider.value)
        }
    }

    // MARK: - OpenRouter Models

    suspend fun fetchOpenRouterModels(apiKeyManager: com.turbometa.rayban.utils.APIKeyManager) {
        if (_currentProvider.value != APIProvider.OPENROUTER) return

        val apiKey = apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
        if (apiKey.isNullOrEmpty()) {
            _modelsError.value = "请先配置 OpenRouter API Key"
            return
        }

        _isLoadingModels.value = true
        _modelsError.value = null

        withContext(Dispatchers.IO) {
            try {
                val request = Request.Builder()
                    .url("https://openrouter.ai/api/v1/models")
                    .addHeader("Authorization", "Bearer $apiKey")
                    .addHeader("X-Title", "TurboMeta")
                    .get()
                    .build()

                val response = httpClient.newCall(request).execute()

                if (!response.isSuccessful) {
                    _modelsError.value = "获取模型列表失败: ${response.code}"
                    return@withContext
                }

                val body = response.body?.string() ?: ""
                val modelsResponse = gson.fromJson(body, OpenRouterModelsResponse::class.java)

                // Sort models: vision-capable first, then by name
                _openRouterModels.value = modelsResponse.data.sortedWith(
                    compareByDescending<OpenRouterModel> { it.isVisionCapable }
                        .thenBy { it.displayName }
                )

                android.util.Log.d("APIProviderManager", "Loaded ${_openRouterModels.value.size} OpenRouter models")

            } catch (e: Exception) {
                _modelsError.value = e.message ?: "Unknown error"
                android.util.Log.e("APIProviderManager", "Failed to fetch OpenRouter models", e)
            }
        }

        _isLoadingModels.value = false
    }

    fun searchModels(query: String): List<OpenRouterModel> {
        if (query.isEmpty()) return _openRouterModels.value
        val lowercaseQuery = query.lowercase()
        return _openRouterModels.value.filter { model ->
            model.id.lowercase().contains(lowercaseQuery) ||
            model.displayName.lowercase().contains(lowercaseQuery) ||
            (model.description?.lowercase()?.contains(lowercaseQuery) == true)
        }
    }

    fun visionCapableModels(): List<OpenRouterModel> {
        return _openRouterModels.value.filter { it.isVisionCapable }
    }
}
