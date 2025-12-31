package com.turbometa.rayban.viewmodels

import android.app.Application
import android.content.ContentValues
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.services.VisionAPIService
import com.turbometa.rayban.utils.APIKeyManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.IOException

class VisionViewModel(application: Application) : AndroidViewModel(application) {

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private val providerManager = APIProviderManager.getInstance(application)
    private var visionService: VisionAPIService? = null

    // State
    sealed class ViewState {
        object Idle : ViewState()
        object Capturing : ViewState()
        object Analyzing : ViewState()
        data class Result(val description: String) : ViewState()
        data class Error(val message: String) : ViewState()
    }

    private val _viewState = MutableStateFlow<ViewState>(ViewState.Idle)
    val viewState: StateFlow<ViewState> = _viewState.asStateFlow()

    private val _capturedImage = MutableStateFlow<Bitmap?>(null)
    val capturedImage: StateFlow<Bitmap?> = _capturedImage.asStateFlow()

    private val _analysisResult = MutableStateFlow<String?>(null)
    val analysisResult: StateFlow<String?> = _analysisResult.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isAnalyzing = MutableStateFlow(false)
    val isAnalyzing: StateFlow<Boolean> = _isAnalyzing.asStateFlow()

    // Custom prompt for analysis
    private val _customPrompt = MutableStateFlow("")
    val customPrompt: StateFlow<String> = _customPrompt.asStateFlow()

    companion object {
        private val DEFAULT_PROMPTS = listOf(
            "请描述这张图片中你看到的内容，包括主要物体、场景和任何有趣的细节。",
            "What do you see in this image? Describe the main objects, scene, and any interesting details.",
            "请识别图片中的文字内容。",
            "Please identify and read any text visible in this image.",
            "这是什么？请详细说明。",
            "What is this? Please explain in detail."
        )
    }

    init {
        initializeService()
    }

    private fun initializeService() {
        if (providerManager.hasAPIKey(apiKeyManager)) {
            visionService = VisionAPIService(apiKeyManager, providerManager)
        }
    }

    fun setCapturedImage(bitmap: Bitmap) {
        _capturedImage.value = bitmap
        _viewState.value = ViewState.Capturing
        _analysisResult.value = null
    }

    fun setCustomPrompt(prompt: String) {
        _customPrompt.value = prompt
    }

    fun analyzeImage(prompt: String? = null) {
        val image = _capturedImage.value
        if (image == null) {
            _errorMessage.value = "No image captured"
            return
        }

        if (visionService == null) {
            if (!providerManager.hasAPIKey(apiKeyManager)) {
                _errorMessage.value = "API Key not configured"
                _viewState.value = ViewState.Error("API Key not configured")
                return
            }
            visionService = VisionAPIService(apiKeyManager, providerManager)
        }

        val analysisPrompt = prompt ?: _customPrompt.value.ifBlank { DEFAULT_PROMPTS[0] }

        viewModelScope.launch {
            _viewState.value = ViewState.Analyzing
            _isAnalyzing.value = true

            try {
                val result = visionService!!.analyzeImage(image, analysisPrompt)

                result.fold(
                    onSuccess = { description ->
                        _analysisResult.value = description
                        _viewState.value = ViewState.Result(description)
                    },
                    onFailure = { error ->
                        _errorMessage.value = error.message
                        _viewState.value = ViewState.Error(error.message ?: "Analysis failed")
                    }
                )
            } catch (e: Exception) {
                _errorMessage.value = e.message
                _viewState.value = ViewState.Error(e.message ?: "Analysis failed")
            } finally {
                _isAnalyzing.value = false
            }
        }
    }

    fun retakePhoto() {
        _capturedImage.value = null
        _analysisResult.value = null
        _viewState.value = ViewState.Idle
        _errorMessage.value = null
        _customPrompt.value = ""
    }

    fun saveImageToGallery(): Boolean {
        val bitmap = _capturedImage.value ?: return false
        val context = getApplication<Application>()

        return try {
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "Vision_${System.currentTimeMillis()}.jpg")
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/TurboMeta")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw IOException("Failed to create media store entry")

            resolver.openOutputStream(uri)?.use { outputStream ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 90, outputStream)) {
                    throw IOException("Failed to save bitmap")
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentValues.clear()
                contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)
            }

            true
        } catch (e: Exception) {
            _errorMessage.value = "Failed to save image: ${e.message}"
            false
        }
    }

    fun clearError() {
        _errorMessage.value = null
        if (_viewState.value is ViewState.Error) {
            _viewState.value = if (_capturedImage.value != null) {
                ViewState.Capturing
            } else {
                ViewState.Idle
            }
        }
    }

    fun reset() {
        _capturedImage.value = null
        _analysisResult.value = null
        _viewState.value = ViewState.Idle
        _errorMessage.value = null
        _customPrompt.value = ""
    }

    fun refreshService() {
        visionService = null
        initializeService()
    }

    fun getDefaultPrompts(): List<String> = DEFAULT_PROMPTS

    override fun onCleared() {
        super.onCleared()
        _capturedImage.value?.recycle()
    }
}
