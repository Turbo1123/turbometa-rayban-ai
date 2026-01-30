package com.turbometa.rayban.viewmodels

import android.app.Application
import android.graphics.Bitmap
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.turbometa.rayban.data.ConversationStorage
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.managers.BluetoothAudioManager
import com.turbometa.rayban.managers.LiveAIProvider
import com.turbometa.rayban.models.ConversationMessage
import com.turbometa.rayban.models.ConversationRecord
import com.turbometa.rayban.models.MessageRole
import com.turbometa.rayban.services.GeminiLiveService
import com.turbometa.rayban.services.OmniRealtimeService
import com.turbometa.rayban.utils.APIKeyManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * OmniRealtimeViewModel
 * Supports multiple Live AI providers: Alibaba Qwen Omni, Google Gemini
 * 1:1 port from iOS OmniRealtimeViewModel
 */
class OmniRealtimeViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "OmniRealtimeViewModel"
    }

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private val providerManager = APIProviderManager.getInstance(application)
    private val conversationStorage = ConversationStorage.getInstance(application)

    // Bluetooth Audio Manager
    private val bluetoothAudioManager = BluetoothAudioManager(application)

    // Services
    private var omniService: OmniRealtimeService? = null
    private var geminiService: GeminiLiveService? = null

    // Current provider
    private val _currentProvider = MutableStateFlow(providerManager.liveAIProvider.value)
    val currentProvider: StateFlow<LiveAIProvider> = _currentProvider.asStateFlow()

    // State
    sealed class ViewState {
        object Idle : ViewState()
        object Connecting : ViewState()
        object Connected : ViewState()
        object Recording : ViewState()
        object Processing : ViewState()
        object Speaking : ViewState()
        data class Error(val message: String) : ViewState()
    }

    private val _viewState = MutableStateFlow<ViewState>(ViewState.Idle)
    val viewState: StateFlow<ViewState> = _viewState.asStateFlow()

    private val _messages = MutableStateFlow<List<ConversationMessage>>(emptyList())
    val messages: StateFlow<List<ConversationMessage>> = _messages.asStateFlow()

    private val _currentTranscript = MutableStateFlow("")
    val currentTranscript: StateFlow<String> = _currentTranscript.asStateFlow()

    private val _userTranscript = MutableStateFlow("")
    val userTranscript: StateFlow<String> = _userTranscript.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording.asStateFlow()

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    // Audio source state
    val currentAudioSource: StateFlow<BluetoothAudioManager.AudioSource> = bluetoothAudioManager.currentAudioSource
    val isBluetoothScoConnected: StateFlow<Boolean> = bluetoothAudioManager.isBluetoothScoConnected
    val isBluetoothScoAvailable: StateFlow<Boolean> = bluetoothAudioManager.isBluetoothScoAvailable

    private var currentSessionId: String = UUID.randomUUID().toString()
    private var pendingVideoFrame: Bitmap? = null

    init {
        // Observe provider changes
        viewModelScope.launch {
            providerManager.liveAIProvider.collect { provider ->
                if (_currentProvider.value != provider) {
                    _currentProvider.value = provider
                    Log.d(TAG, "Live AI provider changed to: ${provider.displayName}")
                    // Refresh service if connected
                    if (_isConnected.value) {
                        disconnect()
                    }
                    initializeService()
                }
            }
        }
        initializeService()
    }

    private fun initializeService() {
        val provider = providerManager.liveAIProvider.value
        val apiKey = providerManager.getLiveAIAPIKey(apiKeyManager)
        val language = apiKeyManager.getOutputLanguage()

        if (apiKey.isBlank()) {
            _errorMessage.value = "API Key not configured for ${provider.displayName}"
            Log.e(TAG, "API Key not configured for ${provider.displayName}")
            return
        }

        Log.d(TAG, "Initializing service for provider: ${provider.displayName}")

        when (provider) {
            LiveAIProvider.ALIBABA -> initializeOmniService(apiKey, language)
            LiveAIProvider.GOOGLE -> initializeGeminiService(apiKey, language)
        }
    }

    private fun initializeOmniService(apiKey: String, language: String) {
        // Clean up Gemini service if exists
        geminiService?.disconnect()
        geminiService = null

        val model = providerManager.liveAIModel.value
        val endpoint = providerManager.alibabaEndpoint.value

        omniService = OmniRealtimeService(apiKey, model, language, endpoint, getApplication()).apply {
            onTranscriptDelta = { delta ->
                _currentTranscript.value += delta
            }

            onTranscriptDone = { transcript ->
                if (transcript.isNotBlank()) {
                    addAssistantMessage(transcript)
                }
                _currentTranscript.value = ""
                _viewState.value = ViewState.Connected
            }

            onUserTranscript = { transcript ->
                if (transcript.isNotBlank()) {
                    _userTranscript.value = transcript
                    addUserMessage(transcript)
                }
            }

            onSpeechStarted = {
                _viewState.value = ViewState.Recording
            }

            onSpeechStopped = {
                _viewState.value = ViewState.Processing
            }

            onError = { error ->
                _errorMessage.value = error
                _viewState.value = ViewState.Error(error)
            }
        }

        observeOmniServiceStates()
    }

    private fun initializeGeminiService(apiKey: String, language: String) {
        // Clean up Omni service if exists
        omniService?.disconnect()
        omniService = null

        val model = providerManager.liveAIModel.value

        geminiService = GeminiLiveService(apiKey, model, language).apply {
            onTranscriptDelta = { delta ->
                _currentTranscript.value += delta
            }

            onTranscriptDone = { transcript ->
                if (transcript.isNotBlank()) {
                    addAssistantMessage(_currentTranscript.value.ifBlank { transcript })
                }
                _currentTranscript.value = ""
                _viewState.value = ViewState.Connected
            }

            onUserTranscript = { transcript ->
                if (transcript.isNotBlank()) {
                    _userTranscript.value = transcript
                    addUserMessage(transcript)
                }
            }

            onSpeechStarted = {
                _viewState.value = ViewState.Recording
            }

            onSpeechStopped = {
                _viewState.value = ViewState.Processing
            }

            onError = { error ->
                _errorMessage.value = error
                _viewState.value = ViewState.Error(error)
            }

            onConnected = {
                _isConnected.value = true
                _viewState.value = ViewState.Connected
            }
        }

        observeGeminiServiceStates()
    }

    private fun observeOmniServiceStates() {
        viewModelScope.launch {
            omniService?.isConnected?.collect { connected ->
                _isConnected.value = connected
                if (connected && _viewState.value == ViewState.Connecting) {
                    _viewState.value = ViewState.Connected
                } else if (!connected && _viewState.value != ViewState.Idle) {
                    _viewState.value = ViewState.Idle
                }
            }
        }

        viewModelScope.launch {
            omniService?.isRecording?.collect { recording ->
                _isRecording.value = recording
            }
        }

        viewModelScope.launch {
            omniService?.isSpeaking?.collect { speaking ->
                _isSpeaking.value = speaking
                if (speaking) {
                    _viewState.value = ViewState.Speaking
                }
            }
        }
    }

    private fun observeGeminiServiceStates() {
        viewModelScope.launch {
            geminiService?.isConnected?.collect { connected ->
                _isConnected.value = connected
                if (connected && _viewState.value == ViewState.Connecting) {
                    _viewState.value = ViewState.Connected
                } else if (!connected && _viewState.value != ViewState.Idle) {
                    _viewState.value = ViewState.Idle
                }
            }
        }

        viewModelScope.launch {
            geminiService?.isRecording?.collect { recording ->
                _isRecording.value = recording
            }
        }

        viewModelScope.launch {
            geminiService?.isSpeaking?.collect { speaking ->
                _isSpeaking.value = speaking
                if (speaking) {
                    _viewState.value = ViewState.Speaking
                }
            }
        }
    }

    fun connect() {
        viewModelScope.launch {
            if (_isConnected.value) return@launch

            _viewState.value = ViewState.Connecting
            _messages.value = emptyList()
            currentSessionId = UUID.randomUUID().toString()

            when (_currentProvider.value) {
                LiveAIProvider.ALIBABA -> omniService?.connect()
                LiveAIProvider.GOOGLE -> geminiService?.connect()
            }
        }
    }

    fun disconnect() {
        viewModelScope.launch {
            saveCurrentConversation()
            omniService?.disconnect()
            geminiService?.disconnect()
            _viewState.value = ViewState.Idle
            _isConnected.value = false
            _messages.value = emptyList()
            _currentTranscript.value = ""
            _userTranscript.value = ""
        }
    }

    fun startRecording() {
        if (!_isConnected.value) {
            _errorMessage.value = "Not connected"
            return
        }

        // Update video frame if available
        pendingVideoFrame?.let { frame ->
            when (_currentProvider.value) {
                LiveAIProvider.ALIBABA -> omniService?.updateVideoFrame(frame)
                LiveAIProvider.GOOGLE -> geminiService?.updateVideoFrame(frame)
            }
        }

        when (_currentProvider.value) {
            LiveAIProvider.ALIBABA -> omniService?.startRecording()
            LiveAIProvider.GOOGLE -> geminiService?.startRecording()
        }
        _viewState.value = ViewState.Recording
    }

    fun stopRecording() {
        when (_currentProvider.value) {
            LiveAIProvider.ALIBABA -> omniService?.stopRecording()
            LiveAIProvider.GOOGLE -> geminiService?.stopRecording()
        }
        if (_viewState.value == ViewState.Recording) {
            _viewState.value = ViewState.Processing
        }
    }

    /**
     * 切换音频源（手机麦克风 / 眼镜麦克风）
     */
    fun switchAudioSource(source: BluetoothAudioManager.AudioSource) {
        Log.d(TAG, "切换音频源到: $source")

        // 切换蓝牙音频管理器的音频源
        bluetoothAudioManager.switchAudioSource(source)

        // 通知当前活动的Service切换音频源
        when (_currentProvider.value) {
            LiveAIProvider.ALIBABA -> omniService?.switchAudioSource(source)
            LiveAIProvider.GOOGLE -> geminiService?.switchAudioSource(source)
        }
    }

    fun updateVideoFrame(frame: Bitmap) {
        pendingVideoFrame = frame
        when (_currentProvider.value) {
            LiveAIProvider.ALIBABA -> omniService?.updateVideoFrame(frame)
            LiveAIProvider.GOOGLE -> geminiService?.updateVideoFrame(frame)
        }
    }

    fun sendImage(image: Bitmap) {
        when (_currentProvider.value) {
            LiveAIProvider.ALIBABA -> omniService?.updateVideoFrame(image)
            LiveAIProvider.GOOGLE -> geminiService?.sendImageInput(image)
        }
    }

    private fun addUserMessage(text: String) {
        val message = ConversationMessage(
            id = UUID.randomUUID().toString(),
            role = MessageRole.USER,
            content = text,
            timestamp = System.currentTimeMillis()
        )
        _messages.value = _messages.value + message
    }

    private fun addAssistantMessage(text: String) {
        val message = ConversationMessage(
            id = UUID.randomUUID().toString(),
            role = MessageRole.ASSISTANT,
            content = text,
            timestamp = System.currentTimeMillis()
        )
        _messages.value = _messages.value + message
    }

    private fun saveCurrentConversation() {
        if (_messages.value.isEmpty()) return

        val record = ConversationRecord(
            id = currentSessionId,
            timestamp = System.currentTimeMillis(),
            messages = _messages.value,
            aiModel = providerManager.liveAIModel.value,
            language = apiKeyManager.getOutputLanguage()
        )

        conversationStorage.saveConversation(record)
    }

    fun clearError() {
        _errorMessage.value = null
        omniService?.clearError()
        geminiService?.clearError()
        if (_viewState.value is ViewState.Error) {
            _viewState.value = if (_isConnected.value) ViewState.Connected else ViewState.Idle
        }
    }

    fun refreshService() {
        disconnect()
        omniService = null
        geminiService = null
        initializeService()
    }

    override fun onCleared() {
        super.onCleared()
        saveCurrentConversation()
        omniService?.disconnect()
        geminiService?.disconnect()
    }
}
