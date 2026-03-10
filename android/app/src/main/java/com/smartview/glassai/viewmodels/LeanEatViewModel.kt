package com.smartview.glassai.viewmodels

import android.app.Application
import android.content.ContentValues
import android.graphics.Bitmap
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.smartview.glassai.models.FoodNutritionResponse
import com.smartview.glassai.services.LeanEatService
import com.smartview.glassai.utils.APIKeyManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.IOException

class LeanEatViewModel(application: Application) : AndroidViewModel(application) {

    private val apiKeyManager = APIKeyManager.getInstance(application)
    private var leanEatService: LeanEatService? = null

    // State
    sealed class ViewState {
        object Idle : ViewState()
        object Capturing : ViewState()
        object Analyzing : ViewState()
        data class Result(val response: FoodNutritionResponse) : ViewState()
        data class Error(val message: String) : ViewState()
    }

    private val _viewState = MutableStateFlow<ViewState>(ViewState.Idle)
    val viewState: StateFlow<ViewState> = _viewState.asStateFlow()

    private val _capturedImage = MutableStateFlow<Bitmap?>(null)
    val capturedImage: StateFlow<Bitmap?> = _capturedImage.asStateFlow()

    private val _nutritionResult = MutableStateFlow<FoodNutritionResponse?>(null)
    val nutritionResult: StateFlow<FoodNutritionResponse?> = _nutritionResult.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isAnalyzing = MutableStateFlow(false)
    val isAnalyzing: StateFlow<Boolean> = _isAnalyzing.asStateFlow()

    init {
        initializeService()
    }

    private fun initializeService() {
        val apiKey = apiKeyManager.getAPIKey()
        if (!apiKey.isNullOrBlank()) {
            leanEatService = LeanEatService(apiKey)
        }
    }

    fun setCapturedImage(bitmap: Bitmap) {
        _capturedImage.value = bitmap
        _viewState.value = ViewState.Capturing
        _nutritionResult.value = null
    }

    fun analyzeFood() {
        val image = _capturedImage.value
        if (image == null) {
            _errorMessage.value = "No image captured"
            return
        }

        if (leanEatService == null) {
            val apiKey = apiKeyManager.getAPIKey()
            if (apiKey.isNullOrBlank()) {
                _errorMessage.value = "API Key not configured"
                _viewState.value = ViewState.Error("API Key not configured")
                return
            }
            leanEatService = LeanEatService(apiKey)
        }

        viewModelScope.launch {
            _viewState.value = ViewState.Analyzing
            _isAnalyzing.value = true

            try {
                val result = leanEatService!!.analyzeFood(image)

                result.fold(
                    onSuccess = { response ->
                        _nutritionResult.value = response
                        _viewState.value = ViewState.Result(response)
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
        _nutritionResult.value = null
        _viewState.value = ViewState.Idle
        _errorMessage.value = null
    }

    fun saveImageToGallery(): Boolean {
        val bitmap = _capturedImage.value ?: return false
        val context = getApplication<Application>()

        return try {
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "LeanEat_${System.currentTimeMillis()}.jpg")
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
        _nutritionResult.value = null
        _viewState.value = ViewState.Idle
        _errorMessage.value = null
    }

    fun refreshService() {
        leanEatService = null
        initializeService()
    }

    override fun onCleared() {
        super.onCleared()
        _capturedImage.value?.recycle()
    }
}
