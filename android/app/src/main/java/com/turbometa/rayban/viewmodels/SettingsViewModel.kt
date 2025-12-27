package com.turbometa.rayban.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.turbometa.rayban.data.ConversationStorage
import com.turbometa.rayban.utils.AIModel
import com.turbometa.rayban.utils.APIKeyManager
import com.turbometa.rayban.utils.OutputLanguage
import com.turbometa.rayban.utils.StreamQuality
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SettingsViewModel(application: Application) : AndroidViewModel(application) {

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private val conversationStorage = ConversationStorage.getInstance(application)

    // API Key
    private val _hasApiKey = MutableStateFlow(apiKeyManager.hasAPIKey())
    val hasApiKey: StateFlow<Boolean> = _hasApiKey.asStateFlow()

    private val _apiKeyMasked = MutableStateFlow(getMaskedApiKey())
    val apiKeyMasked: StateFlow<String> = _apiKeyMasked.asStateFlow()

    // AI Model
    private val _selectedModel = MutableStateFlow(apiKeyManager.getAIModel())
    val selectedModel: StateFlow<String> = _selectedModel.asStateFlow()

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

    fun getAvailableModels(): List<AIModel> = AIModel.entries

    fun getAvailableLanguages(): List<OutputLanguage> = OutputLanguage.entries

    private fun getMaskedApiKey(): String {
        val apiKey = apiKeyManager.getAPIKey() ?: return ""
        if (apiKey.length <= 8) return "****"
        return "${apiKey.take(4)}****${apiKey.takeLast(4)}"
    }

    // API Key Management
    fun showApiKeyDialog() {
        _showApiKeyDialog.value = true
    }

    fun hideApiKeyDialog() {
        _showApiKeyDialog.value = false
    }

    fun saveApiKey(apiKey: String): Boolean {
        val trimmedKey = apiKey.trim()
        if (trimmedKey.isBlank()) {
            _message.value = "API Key cannot be empty"
            return false
        }

        val success = apiKeyManager.saveAPIKey(trimmedKey)
        if (success) {
            _hasApiKey.value = true
            _apiKeyMasked.value = getMaskedApiKey()
            _message.value = "API Key saved successfully"
            _showApiKeyDialog.value = false
        } else {
            _message.value = "Failed to save API Key"
        }
        return success
    }

    fun deleteApiKey(): Boolean {
        val success = apiKeyManager.deleteAPIKey()
        if (success) {
            _hasApiKey.value = false
            _apiKeyMasked.value = ""
            _message.value = "API Key deleted"
        } else {
            _message.value = "Failed to delete API Key"
        }
        return success
    }

    // AI Model Management
    fun showModelDialog() {
        _showModelDialog.value = true
    }

    fun hideModelDialog() {
        _showModelDialog.value = false
    }

    fun selectModel(model: AIModel) {
        apiKeyManager.saveAIModel(model.id)
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
        _message.value = "画质已切换为${quality.displayName}"
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
        return apiKeyManager.getAPIKey() ?: ""
    }
}
