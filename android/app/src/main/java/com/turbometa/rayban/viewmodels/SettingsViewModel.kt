package com.turbometa.rayban.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.turbometa.rayban.data.ConversationStorage
import com.turbometa.rayban.managers.AlibabaEndpoint
import com.turbometa.rayban.managers.AlibabaVisionModel
import com.turbometa.rayban.managers.APIProvider
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.managers.AppLanguage
import com.turbometa.rayban.managers.LanguageManager
import com.turbometa.rayban.managers.LiveAIProvider
import com.turbometa.rayban.managers.OpenRouterModel
import com.turbometa.rayban.utils.AIModel
import com.turbometa.rayban.utils.APIKeyManager
import com.turbometa.rayban.utils.OutputLanguage
import com.turbometa.rayban.utils.StreamQuality
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * SettingsViewModel
 * Supports multi-provider configuration (Alibaba/OpenRouter, Alibaba/Google for Live AI)
 * 1:1 port from iOS settings structure
 */
class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private val providerManager = APIProviderManager.getInstance(application)
    private val conversationStorage = ConversationStorage.getInstance(application)

    // Vision API Provider
    private val _visionProvider = MutableStateFlow(providerManager.currentProvider.value)
    val visionProvider: StateFlow<APIProvider> = _visionProvider.asStateFlow()

    // Alibaba Endpoint
    private val _alibabaEndpoint = MutableStateFlow(providerManager.alibabaEndpoint.value)
    val alibabaEndpoint: StateFlow<AlibabaEndpoint> = _alibabaEndpoint.asStateFlow()

    // Live AI Provider
    private val _liveAIProvider = MutableStateFlow(providerManager.liveAIProvider.value)
    val liveAIProvider: StateFlow<LiveAIProvider> = _liveAIProvider.asStateFlow()

    // API Keys status
    private val _hasAlibabaBeijingKey = MutableStateFlow(apiKeyManager.hasAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.BEIJING))
    val hasAlibabaBeijingKey: StateFlow<Boolean> = _hasAlibabaBeijingKey.asStateFlow()

    private val _hasAlibabaSingaporeKey = MutableStateFlow(apiKeyManager.hasAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE))
    val hasAlibabaSingaporeKey: StateFlow<Boolean> = _hasAlibabaSingaporeKey.asStateFlow()

    private val _hasOpenRouterKey = MutableStateFlow(apiKeyManager.hasAPIKey(APIProvider.OPENROUTER))
    val hasOpenRouterKey: StateFlow<Boolean> = _hasOpenRouterKey.asStateFlow()

    private val _hasGoogleKey = MutableStateFlow(apiKeyManager.hasGoogleAPIKey())
    val hasGoogleKey: StateFlow<Boolean> = _hasGoogleKey.asStateFlow()

    // Legacy hasApiKey for backward compatibility
    private val _hasApiKey = MutableStateFlow(apiKeyManager.hasAPIKey())
    val hasApiKey: StateFlow<Boolean> = _hasApiKey.asStateFlow()

    private val _apiKeyMasked = MutableStateFlow(getMaskedApiKey())
    val apiKeyMasked: StateFlow<String> = _apiKeyMasked.asStateFlow()

    // AI Model (for Live AI)
    private val _selectedModel = MutableStateFlow(providerManager.liveAIModel.value)
    val selectedModel: StateFlow<String> = _selectedModel.asStateFlow()

    // Vision Model
    private val _selectedVisionModel = MutableStateFlow(providerManager.selectedModel.value)
    val selectedVisionModel: StateFlow<String> = _selectedVisionModel.asStateFlow()

    // Output Language
    private val _selectedLanguage = MutableStateFlow(apiKeyManager.getOutputLanguage())
    val selectedLanguage: StateFlow<String> = _selectedLanguage.asStateFlow()

    // Video Quality
    private val _selectedQuality = MutableStateFlow(apiKeyManager.getVideoQuality())
    val selectedQuality: StateFlow<String> = _selectedQuality.asStateFlow()

    // Conversation count
    private val _conversationCount = MutableStateFlow(conversationStorage.getConversationCount())
    val conversationCount: StateFlow<Int> = _conversationCount.asStateFlow()

    // Error/Success messages
    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    // Dialog states
    private val _showApiKeyDialog = MutableStateFlow(false)
    val showApiKeyDialog: StateFlow<Boolean> = _showApiKeyDialog.asStateFlow()

    private val _showModelDialog = MutableStateFlow(false)
    val showModelDialog: StateFlow<Boolean> = _showModelDialog.asStateFlow()

    private val _showLanguageDialog = MutableStateFlow(false)
    val showLanguageDialog: StateFlow<Boolean> = _showLanguageDialog.asStateFlow()

    private val _showQualityDialog = MutableStateFlow(false)
    val showQualityDialog: StateFlow<Boolean> = _showQualityDialog.asStateFlow()

    private val _showDeleteConfirmDialog = MutableStateFlow(false)
    val showDeleteConfirmDialog: StateFlow<Boolean> = _showDeleteConfirmDialog.asStateFlow()

    private val _showVisionProviderDialog = MutableStateFlow(false)
    val showVisionProviderDialog: StateFlow<Boolean> = _showVisionProviderDialog.asStateFlow()

    private val _showEndpointDialog = MutableStateFlow(false)
    val showEndpointDialog: StateFlow<Boolean> = _showEndpointDialog.asStateFlow()

    private val _showLiveAIProviderDialog = MutableStateFlow(false)
    val showLiveAIProviderDialog: StateFlow<Boolean> = _showLiveAIProviderDialog.asStateFlow()

    // App Language
    private val _appLanguage = MutableStateFlow(LanguageManager.getCurrentLanguage())
    val appLanguage: StateFlow<AppLanguage> = _appLanguage.asStateFlow()

    private val _showAppLanguageDialog = MutableStateFlow(false)
    val showAppLanguageDialog: StateFlow<Boolean> = _showAppLanguageDialog.asStateFlow()

    private val _showVisionModelDialog = MutableStateFlow(false)
    val showVisionModelDialog: StateFlow<Boolean> = _showVisionModelDialog.asStateFlow()

    // Vision Model selection - expose provider manager states
    val openRouterModels: StateFlow<List<OpenRouterModel>> = providerManager.openRouterModels
    val isLoadingModels: StateFlow<Boolean> = providerManager.isLoadingModels
    val modelsError: StateFlow<String?> = providerManager.modelsError

    // Current editing key type
    private val _editingKeyType = MutableStateFlow<EditingKeyType?>(null)
    val editingKeyType: StateFlow<EditingKeyType?> = _editingKeyType.asStateFlow()

    enum class EditingKeyType {
        ALIBABA_BEIJING,
        ALIBABA_SINGAPORE,
        OPENROUTER,
        GOOGLE
    }

    init {
        observeProviderChanges()
    }

    private fun observeProviderChanges() {
        viewModelScope.launch {
            providerManager.currentProvider.collect { provider ->
                _visionProvider.value = provider
                refreshApiKeyStatus()
            }
        }
        viewModelScope.launch {
            providerManager.alibabaEndpoint.collect { endpoint ->
                _alibabaEndpoint.value = endpoint
                refreshApiKeyStatus()
            }
        }
        viewModelScope.launch {
            providerManager.liveAIProvider.collect { provider ->
                _liveAIProvider.value = provider
                _selectedModel.value = providerManager.liveAIModel.value
            }
        }
    }

    private fun refreshApiKeyStatus() {
        _hasAlibabaBeijingKey.value = apiKeyManager.hasAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.BEIJING)
        _hasAlibabaSingaporeKey.value = apiKeyManager.hasAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE)
        _hasOpenRouterKey.value = apiKeyManager.hasAPIKey(APIProvider.OPENROUTER)
        _hasGoogleKey.value = apiKeyManager.hasGoogleAPIKey()
        _hasApiKey.value = apiKeyManager.hasAPIKey()
        _apiKeyMasked.value = getMaskedApiKey()
    }

    // MARK: - Vision Provider

    fun showVisionProviderDialog() {
        _showVisionProviderDialog.value = true
    }

    fun hideVisionProviderDialog() {
        _showVisionProviderDialog.value = false
    }

    fun selectVisionProvider(provider: APIProvider) {
        providerManager.setCurrentProvider(provider)
        _visionProvider.value = provider
        _showVisionProviderDialog.value = false
        _message.value = "Vision API switched to ${provider.displayName}"
        refreshApiKeyStatus()
    }

    // MARK: - Alibaba Endpoint

    fun showEndpointDialog() {
        _showEndpointDialog.value = true
    }

    fun hideEndpointDialog() {
        _showEndpointDialog.value = false
    }

    fun selectEndpoint(endpoint: AlibabaEndpoint) {
        providerManager.setAlibabaEndpoint(endpoint)
        _alibabaEndpoint.value = endpoint
        _showEndpointDialog.value = false
        _message.value = "Endpoint switched to ${endpoint.displayName}"
        refreshApiKeyStatus()
    }

    // MARK: - Live AI Provider

    fun showLiveAIProviderDialog() {
        _showLiveAIProviderDialog.value = true
    }

    fun hideLiveAIProviderDialog() {
        _showLiveAIProviderDialog.value = false
    }

    fun selectLiveAIProvider(provider: LiveAIProvider) {
        providerManager.setLiveAIProvider(provider)
        _liveAIProvider.value = provider
        _selectedModel.value = provider.defaultModel
        _showLiveAIProviderDialog.value = false
        _message.value = "Live AI switched to ${provider.displayName}"
    }

    // MARK: - API Key Management

    fun showApiKeyDialog() {
        _showApiKeyDialog.value = true
    }

    fun hideApiKeyDialog() {
        _showApiKeyDialog.value = false
        _editingKeyType.value = null
    }

    fun showApiKeyDialogForType(type: EditingKeyType) {
        _editingKeyType.value = type
        _showApiKeyDialog.value = true
    }

    fun saveApiKey(apiKey: String): Boolean {
        val trimmedKey = apiKey.trim()
        if (trimmedKey.isBlank()) {
            _message.value = "API Key cannot be empty"
            return false
        }

        val success = when (_editingKeyType.value) {
            EditingKeyType.ALIBABA_BEIJING -> apiKeyManager.saveAPIKey(trimmedKey, APIProvider.ALIBABA, AlibabaEndpoint.BEIJING)
            EditingKeyType.ALIBABA_SINGAPORE -> apiKeyManager.saveAPIKey(trimmedKey, APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE)
            EditingKeyType.OPENROUTER -> apiKeyManager.saveAPIKey(trimmedKey, APIProvider.OPENROUTER)
            EditingKeyType.GOOGLE -> apiKeyManager.saveGoogleAPIKey(trimmedKey)
            null -> apiKeyManager.saveAPIKey(trimmedKey)
        }

        if (success) {
            refreshApiKeyStatus()
            _message.value = "API Key saved successfully"
            _showApiKeyDialog.value = false
            _editingKeyType.value = null
        } else {
            _message.value = "Failed to save API Key"
        }
        return success
    }

    fun deleteApiKey(): Boolean {
        val success = when (_editingKeyType.value) {
            EditingKeyType.ALIBABA_BEIJING -> apiKeyManager.deleteAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.BEIJING)
            EditingKeyType.ALIBABA_SINGAPORE -> apiKeyManager.deleteAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE)
            EditingKeyType.OPENROUTER -> apiKeyManager.deleteAPIKey(APIProvider.OPENROUTER)
            EditingKeyType.GOOGLE -> apiKeyManager.deleteGoogleAPIKey()
            null -> apiKeyManager.deleteAPIKey()
        }

        if (success) {
            refreshApiKeyStatus()
            _message.value = "API Key deleted"
        } else {
            _message.value = "Failed to delete API Key"
        }
        return success
    }

    fun getAvailableModels(): List<AIModel> = AIModel.entries

    fun getAvailableLanguages(): List<OutputLanguage> = OutputLanguage.entries

    private fun getMaskedApiKey(): String {
        val apiKey = apiKeyManager.getAPIKey() ?: return ""
        if (apiKey.length <= 8) return "****"
        return "${apiKey.take(4)}****${apiKey.takeLast(4)}"
    }

    fun getMaskedKeyForType(type: EditingKeyType): String {
        val key = when (type) {
            EditingKeyType.ALIBABA_BEIJING -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.BEIJING)
            EditingKeyType.ALIBABA_SINGAPORE -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE)
            EditingKeyType.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
            EditingKeyType.GOOGLE -> apiKeyManager.getGoogleAPIKey()
        } ?: return ""
        if (key.length <= 8) return "****"
        return "${key.take(4)}****${key.takeLast(4)}"
    }

    fun getCurrentKeyForType(type: EditingKeyType): String {
        return when (type) {
            EditingKeyType.ALIBABA_BEIJING -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.BEIJING)
            EditingKeyType.ALIBABA_SINGAPORE -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE)
            EditingKeyType.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
            EditingKeyType.GOOGLE -> apiKeyManager.getGoogleAPIKey()
        } ?: ""
    }

    // AI Model Management
    fun showModelDialog() {
        _showModelDialog.value = true
    }

    fun hideModelDialog() {
        _showModelDialog.value = false
    }

    fun selectModel(model: AIModel) {
        providerManager.setLiveAIModel(model.id)
        _selectedModel.value = model.id
        _showModelDialog.value = false
        _message.value = "Model changed to ${model.displayName}"
    }

    fun getSelectedModelDisplayName(): String {
        val modelId = _selectedModel.value
        return AIModel.entries.find { it.id == modelId }?.displayName ?: modelId
    }

    // Language Management
    fun showLanguageDialog() {
        _showLanguageDialog.value = true
    }

    fun hideLanguageDialog() {
        _showLanguageDialog.value = false
    }

    fun selectLanguage(language: OutputLanguage) {
        apiKeyManager.saveOutputLanguage(language.code)
        _selectedLanguage.value = language.code
        _showLanguageDialog.value = false
        _message.value = "Language changed to ${language.displayName}"
    }

    // App Language Functions
    fun showAppLanguageDialog() {
        _showAppLanguageDialog.value = true
    }

    fun hideAppLanguageDialog() {
        _showAppLanguageDialog.value = false
    }

    fun selectAppLanguage(language: AppLanguage) {
        LanguageManager.setLanguage(getApplication(), language)
        _appLanguage.value = language
        _showAppLanguageDialog.value = false

        // Auto-sync output language with app language
        val outputLangCode = when (language) {
            AppLanguage.CHINESE -> "zh-CN"
            AppLanguage.ENGLISH -> "en-US"
            AppLanguage.SYSTEM -> {
                // Detect system language
                val systemLocale = java.util.Locale.getDefault()
                if (systemLocale.language == "zh") "zh-CN" else "en-US"
            }
        }
        apiKeyManager.saveOutputLanguage(outputLangCode)
        _selectedLanguage.value = outputLangCode

        _message.value = "App language changed to ${language.displayName}"
    }

    fun getAppLanguageDisplayName(): String {
        return when (_appLanguage.value) {
            AppLanguage.SYSTEM -> "跟随系统 / System"
            AppLanguage.CHINESE -> "中文"
            AppLanguage.ENGLISH -> "English"
        }
    }

    fun getAvailableAppLanguages(): List<AppLanguage> = LanguageManager.getAvailableLanguages()

    // Vision Model Functions
    fun showVisionModelDialog() {
        _showVisionModelDialog.value = true
        // Auto-fetch OpenRouter models when dialog opens
        if (_visionProvider.value == APIProvider.OPENROUTER) {
            fetchOpenRouterModels()
        }
    }

    fun hideVisionModelDialog() {
        _showVisionModelDialog.value = false
    }

    fun selectVisionModel(modelId: String) {
        providerManager.setSelectedModel(modelId)
        _selectedVisionModel.value = modelId
        _showVisionModelDialog.value = false
        _message.value = "Model changed to $modelId"
    }

    fun fetchOpenRouterModels() {
        viewModelScope.launch {
            providerManager.fetchOpenRouterModels(apiKeyManager)
        }
    }

    fun searchOpenRouterModels(query: String): List<OpenRouterModel> {
        return providerManager.searchModels(query)
    }

    fun getAlibabaVisionModels(): List<AlibabaVisionModel> {
        return AlibabaVisionModel.availableModels
    }

    fun getSelectedVisionModelDisplayName(): String {
        val modelId = _selectedVisionModel.value
        // Check Alibaba models first
        AlibabaVisionModel.availableModels.find { it.id == modelId }?.let {
            return it.displayName
        }
        // Otherwise return the model ID (for OpenRouter models)
        return modelId
    }

    fun getSelectedLanguageDisplayName(): String {
        val langCode = _selectedLanguage.value
        return OutputLanguage.entries.find { it.code == langCode }?.let {
            "${it.nativeName} (${it.displayName})"
        } ?: langCode
    }

    // Video Quality Management
    fun getAvailableQualities(): List<StreamQuality> = StreamQuality.entries

    fun showQualityDialog() {
        _showQualityDialog.value = true
    }

    fun hideQualityDialog() {
        _showQualityDialog.value = false
    }

    fun selectQuality(quality: StreamQuality) {
        apiKeyManager.saveVideoQuality(quality.id)
        _selectedQuality.value = quality.id
        _showQualityDialog.value = false
        _message.value = "Video quality changed to ${quality.displayName}"
    }

    fun getSelectedQualityDisplayName(): String {
        val qualityId = _selectedQuality.value
        return StreamQuality.entries.find { it.id == qualityId }?.displayName ?: qualityId
    }

    // Conversation Management
    fun showDeleteConfirmDialog() {
        _showDeleteConfirmDialog.value = true
    }

    fun hideDeleteConfirmDialog() {
        _showDeleteConfirmDialog.value = false
    }

    fun deleteAllConversations() {
        viewModelScope.launch {
            val success = conversationStorage.deleteAllConversations()
            if (success) {
                _conversationCount.value = 0
                _message.value = "All conversations deleted"
            } else {
                _message.value = "Failed to delete conversations"
            }
            _showDeleteConfirmDialog.value = false
        }
    }

    fun refreshConversationCount() {
        _conversationCount.value = conversationStorage.getConversationCount()
    }

    // Message handling
    fun clearMessage() {
        _message.value = null
    }

    // Get current API key (for editing)
    fun getCurrentApiKey(): String {
        return when (_editingKeyType.value) {
            EditingKeyType.ALIBABA_BEIJING -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.BEIJING)
            EditingKeyType.ALIBABA_SINGAPORE -> apiKeyManager.getAPIKey(APIProvider.ALIBABA, AlibabaEndpoint.SINGAPORE)
            EditingKeyType.OPENROUTER -> apiKeyManager.getAPIKey(APIProvider.OPENROUTER)
            EditingKeyType.GOOGLE -> apiKeyManager.getGoogleAPIKey()
            null -> apiKeyManager.getAPIKey()
        } ?: ""
    }
}
