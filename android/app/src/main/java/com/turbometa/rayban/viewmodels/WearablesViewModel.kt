package com.turbometa.rayban.viewmodels

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.startStreamSession
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.turbometa.rayban.utils.APIKeyManager
import com.meta.wearable.dat.core.selectors.DeviceSelector
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.core.types.RegistrationState
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

class WearablesViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "WearablesViewModel"
    }

    // Connection states
    sealed class ConnectionState {
        object Disconnected : ConnectionState()
        object Searching : ConnectionState()
        object Connecting : ConnectionState()
        data class Connected(val deviceName: String) : ConnectionState()
        data class Error(val message: String) : ConnectionState()
    }

    sealed class StreamState {
        object Idle : StreamState()
        object Starting : StreamState()
        object Streaming : StreamState()
        object Stopping : StreamState()
        data class Error(val message: String) : StreamState()
    }

    // State flows
    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _registrationState = MutableStateFlow<RegistrationState>(RegistrationState.Unavailable())
    val registrationState: StateFlow<RegistrationState> = _registrationState.asStateFlow()

    private val _streamState = MutableStateFlow<StreamState>(StreamState.Idle)
    val streamState: StateFlow<StreamState> = _streamState.asStateFlow()

    private val _currentFrame = MutableStateFlow<Bitmap?>(null)
    val currentFrame: StateFlow<Bitmap?> = _currentFrame.asStateFlow()

    private val _capturedPhoto = MutableStateFlow<Bitmap?>(null)
    val capturedPhoto: StateFlow<Bitmap?> = _capturedPhoto.asStateFlow()

    private val _batteryLevel = MutableStateFlow<Int?>(null)
    val batteryLevel: StateFlow<Int?> = _batteryLevel.asStateFlow()

    private val _devices = MutableStateFlow<List<DeviceIdentifier>>(emptyList())
    val devices: StateFlow<List<DeviceIdentifier>> = _devices.asStateFlow()

    private val _hasActiveDevice = MutableStateFlow(false)
    val hasActiveDevice: StateFlow<Boolean> = _hasActiveDevice.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _isStreaming = MutableStateFlow(false)
    val isStreaming: StateFlow<Boolean> = _isStreaming.asStateFlow()

    // DAT SDK components
    val deviceSelector: DeviceSelector = AutoDeviceSelector()
    private var streamSession: StreamSession? = null
    private var videoJob: Job? = null
    private var stateJob: Job? = null
    private var deviceSelectorJob: Job? = null
    private var monitoringStarted = false

    // Callbacks for external use
    var onFrameReceived: ((Bitmap) -> Unit)? = null
    var onPhotoTaken: ((Bitmap) -> Unit)? = null

    fun startMonitoring() {
        if (monitoringStarted) return
        monitoringStarted = true

        Log.d(TAG, "Starting monitoring")

        // Monitor device selector for active device
        deviceSelectorJob = viewModelScope.launch {
            deviceSelector.activeDevice(Wearables.devices).collect { device ->
                Log.d(TAG, "Active device changed: $device, hasActiveDevice = ${device != null}")
                val wasActive = _hasActiveDevice.value
                _hasActiveDevice.value = device != null
                Log.d(TAG, "hasActiveDevice changed from $wasActive to ${_hasActiveDevice.value}")
                if (device != null) {
                    _connectionState.value = ConnectionState.Connected(device.toString())
                } else if (_connectionState.value is ConnectionState.Connected) {
                    _connectionState.value = ConnectionState.Disconnected
                }
            }
        }

        // Monitor registration state
        viewModelScope.launch {
            Wearables.registrationState.collect { state ->
                Log.d(TAG, "Registration state changed: $state")
                _registrationState.value = state
                when (state) {
                    is RegistrationState.Registered -> {
                        Log.d(TAG, "Device registered")
                        // Update connection state when registered
                        if (_connectionState.value is ConnectionState.Searching ||
                            _connectionState.value is ConnectionState.Connecting) {
                            if (_hasActiveDevice.value) {
                                // Will be updated by device selector
                            } else {
                                _connectionState.value = ConnectionState.Connecting
                            }
                        }
                    }
                    is RegistrationState.Unavailable -> {
                        Log.d(TAG, "Registration unavailable")
                        _connectionState.value = ConnectionState.Disconnected
                    }
                    is RegistrationState.Available -> {
                        Log.d(TAG, "Registration available")
                        // SDK is ready, can start registration
                    }
                    is RegistrationState.Registering -> {
                        Log.d(TAG, "Registering...")
                        _connectionState.value = ConnectionState.Connecting
                    }
                    is RegistrationState.Unregistering -> {
                        Log.d(TAG, "Unregistering...")
                    }
                }
            }
        }

        // Monitor available devices
        viewModelScope.launch {
            Wearables.devices.collect { deviceSet ->
                Log.d(TAG, "Devices changed: ${deviceSet.size} devices")
                _devices.value = deviceSet.toList()
            }
        }
    }

    fun startDeviceSearch() {
        Log.d(TAG, "Starting device search, registration state: ${_registrationState.value}")
        _connectionState.value = ConnectionState.Searching

        // Start registration - this will open Meta AI app
        startRegistration()
    }

    fun stopDeviceSearch() {
        if (_connectionState.value is ConnectionState.Searching) {
            _connectionState.value = ConnectionState.Disconnected
        }
    }

    fun startRegistration() {
        Log.d(TAG, "Starting registration")
        Wearables.startRegistration(getApplication())
    }

    fun startUnregistration() {
        Log.d(TAG, "Starting unregistration")
        Wearables.startUnregistration(getApplication())
    }

    fun disconnect() {
        viewModelScope.launch {
            stopStream()
            startUnregistration()
            _connectionState.value = ConnectionState.Disconnected
            _batteryLevel.value = null
        }
    }

    // Navigate to streaming (check permission first)
    // Note: This only sets isStreaming = true, actual streaming is started separately
    fun navigateToStreaming(onRequestWearablesPermission: suspend (Permission) -> PermissionStatus) {
        viewModelScope.launch {
            val permission = Permission.CAMERA
            val result = Wearables.checkPermissionStatus(permission)

            result.onFailure { error, _ ->
                setError("Permission check error: ${error.description}")
                return@launch
            }

            val permissionStatus = result.getOrNull()
            if (permissionStatus == PermissionStatus.Granted) {
                _isStreaming.value = true
                return@launch
            }

            // Request permission
            val requestedPermissionStatus = onRequestWearablesPermission(permission)
            when (requestedPermissionStatus) {
                PermissionStatus.Denied -> {
                    setError("Permission denied")
                }
                PermissionStatus.Granted -> {
                    _isStreaming.value = true
                }
            }
        }
    }

    fun navigateToDeviceSelection() {
        _isStreaming.value = false
        // Note: stopStream() should be called separately by the caller if needed
    }

    // Streaming
    suspend fun checkCameraPermission(): Boolean {
        val result = Wearables.checkPermissionStatus(Permission.CAMERA)
        return result.getOrNull() == PermissionStatus.Granted
    }

    fun startStream() {
        Log.d(TAG, "Starting stream")

        // IMPORTANT: Clean up any existing session first to prevent resource leaks
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null
        streamSession?.let { oldSession ->
            Log.d(TAG, "Closing previous session before starting new one")
            oldSession.close()
        }
        streamSession = null
        _currentFrame.value = null

        // Get saved video quality setting
        val apiKeyManager = APIKeyManager.getInstance(getApplication())
        val savedQuality = apiKeyManager.getVideoQuality()
        val videoQuality = when (savedQuality) {
            "LOW" -> VideoQuality.LOW
            "HIGH" -> VideoQuality.HIGH
            else -> VideoQuality.MEDIUM
        }
        Log.d(TAG, "Using video quality: $savedQuality")

        val session = Wearables.startStreamSession(
            getApplication(),
            deviceSelector,
            StreamConfiguration(videoQuality = videoQuality, 24)
        ).also { streamSession = it }

        _streamState.value = StreamState.Starting

        // Collect video frames
        videoJob = viewModelScope.launch {
            session.videoStream.collect { videoFrame ->
                handleVideoFrame(videoFrame)
            }
        }

        // Monitor stream state
        stateJob = viewModelScope.launch {
            var prevState: StreamSessionState? = null
            session.state.collect { currentState ->
                Log.d(TAG, "Stream state: $currentState (prev: $prevState)")
                when (currentState) {
                    StreamSessionState.STREAMING -> {
                        _streamState.value = StreamState.Streaming
                    }
                    StreamSessionState.STOPPED -> {
                        // CRITICAL: When stream transitions to STOPPED, properly clean up the session
                        // This matches SDK sample behavior to prevent battery drain on glasses
                        if (prevState != null && prevState != StreamSessionState.STOPPED) {
                            Log.d(TAG, "Stream transitioned to STOPPED, cleaning up session")
                            // Cancel jobs and close session (same as stopStream but we're already in stateJob)
                            videoJob?.cancel()
                            videoJob = null
                            streamSession?.close()
                            streamSession = null
                            _currentFrame.value = null
                        }
                        _streamState.value = StreamState.Idle
                    }
                    StreamSessionState.STARTING -> {
                        _streamState.value = StreamState.Starting
                    }
                    else -> {
                        Log.d(TAG, "Other stream state: $currentState")
                    }
                }
                prevState = currentState
            }
        }
    }

    fun stopStream() {
        Log.d(TAG, "Stopping stream")
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null
        streamSession?.close()
        streamSession = null
        _currentFrame.value = null
        _streamState.value = StreamState.Idle
    }

    fun takePhoto(): Bitmap? {
        if (_streamState.value != StreamState.Streaming) {
            Log.w(TAG, "Cannot take photo: not streaming")
            return null
        }

        viewModelScope.launch {
            try {
                streamSession?.capturePhoto()
                    ?.onSuccess { photoData ->
                        val bitmap = when (photoData) {
                            is com.meta.wearable.dat.camera.types.PhotoData.Bitmap -> photoData.bitmap
                            is com.meta.wearable.dat.camera.types.PhotoData.HEIC -> {
                                val byteArray = ByteArray(photoData.data.remaining())
                                photoData.data.get(byteArray)
                                BitmapFactory.decodeByteArray(byteArray, 0, byteArray.size)
                            }
                        }
                        _capturedPhoto.value = bitmap
                        onPhotoTaken?.invoke(bitmap)
                    }
                    ?.onFailure {
                        Log.e(TAG, "Photo capture failed")
                        _errorMessage.value = "Photo capture failed"
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to take photo: ${e.message}")
            }
        }
        return _capturedPhoto.value
    }

    private fun handleVideoFrame(videoFrame: VideoFrame) {
        try {
            val buffer = videoFrame.buffer
            val dataSize = buffer.remaining()
            val byteArray = ByteArray(dataSize)

            val originalPosition = buffer.position()
            buffer.get(byteArray)
            buffer.position(originalPosition)

            // Convert I420 to NV21 format
            val nv21 = convertI420toNV21(byteArray, videoFrame.width, videoFrame.height)
            val image = YuvImage(nv21, ImageFormat.NV21, videoFrame.width, videoFrame.height, null)

            val out = ByteArrayOutputStream()
            image.compressToJpeg(Rect(0, 0, videoFrame.width, videoFrame.height), 50, out)
            val jpegBytes = out.toByteArray()

            val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            _currentFrame.value = bitmap
            onFrameReceived?.invoke(bitmap)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling video frame: ${e.message}")
        }
    }

    private fun convertI420toNV21(input: ByteArray, width: Int, height: Int): ByteArray {
        val output = ByteArray(input.size)
        val size = width * height
        val quarter = size / 4

        input.copyInto(output, 0, 0, size) // Y is the same

        for (n in 0 until quarter) {
            output[size + n * 2] = input[size + quarter + n] // V first
            output[size + n * 2 + 1] = input[size + n] // U second
        }
        return output
    }

    fun clearCapturedPhoto() {
        _capturedPhoto.value = null
    }

    fun clearError() {
        _errorMessage.value = null
    }

    fun setError(message: String) {
        _errorMessage.value = message
    }

    // Check if registered with Meta AI app
    val isRegistered: Boolean
        get() = _registrationState.value is RegistrationState.Registered

    override fun onCleared() {
        super.onCleared()
        stopStream()
        deviceSelectorJob?.cancel()
    }
}
