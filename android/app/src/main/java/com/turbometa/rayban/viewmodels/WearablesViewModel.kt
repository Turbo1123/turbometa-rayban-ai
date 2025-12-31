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
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

/**
 * WearablesViewModel - Core DAT SDK Integration
 *
 * This ViewModel demonstrates the core DAT API patterns for:
 * - Device registration and unregistration using the DAT SDK
 * - Permission management for wearable devices
 * - Device discovery and state management
 * - Video streaming from wearable devices
 *
 * Based on iOS StreamSessionViewModel pattern:
 * - Single session instance, reused with start/stop
 * - Proper cleanup on view disposal
 */
class WearablesViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "WearablesViewModel"
    }

    // Connection states
    sealed class ConnectionState {
        object Disconnected : ConnectionState()
        object Searching : ConnectionState()
        object Connecting : ConnectionState()
        data class Registered(val deviceName: String) : ConnectionState() // Device registered but may not be actively connected
        data class Connected(val deviceName: String) : ConnectionState() // Device is actively connected and ready
        data class Error(val message: String) : ConnectionState()
    }

    // Streaming status (matching iOS StreamingStatus enum)
    sealed class StreamState {
        object Stopped : StreamState()
        object Waiting : StreamState()  // starting, stopping, paused
        object Streaming : StreamState()
        data class Error(val message: String) : StreamState()
    }

    // State flows
    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _registrationState = MutableStateFlow<RegistrationState>(RegistrationState.Unavailable())
    val registrationState: StateFlow<RegistrationState> = _registrationState.asStateFlow()

    private val _streamState = MutableStateFlow<StreamState>(StreamState.Stopped)
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

    // Stream session - can be null when not streaming
    // Following Android SDK pattern: create new session each time, close when done
    private var streamSession: StreamSession? = null

    // Coroutine jobs for stream management
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

        Log.d(TAG, "🟢 Starting monitoring")

        // Monitor device selector for active device
        deviceSelectorJob = viewModelScope.launch {
            deviceSelector.activeDevice(Wearables.devices).collect { device ->
                Log.d(TAG, "📱 Device changed: ${if (device != null) "connected" else "disconnected"}")
                _hasActiveDevice.value = device != null

                if (device != null) {
                    // Device is registered, but may not be actively connected
                    if (_connectionState.value !is ConnectionState.Connected) {
                        _connectionState.value = ConnectionState.Registered(device.toString())
                    }
                } else if (_connectionState.value is ConnectionState.Connected ||
                           _connectionState.value is ConnectionState.Registered) {
                    _connectionState.value = ConnectionState.Disconnected
                }
            }
        }

        // Monitor registration state
        viewModelScope.launch {
            Wearables.registrationState.collect { state ->
                Log.d(TAG, "📊 Registration state changed: $state")
                _registrationState.value = state
                when (state) {
                    is RegistrationState.Registered -> {
                        Log.d(TAG, "✅ Device registered")
                    }
                    is RegistrationState.Unavailable -> {
                        Log.d(TAG, "❌ Registration unavailable")
                        _connectionState.value = ConnectionState.Disconnected
                    }
                    is RegistrationState.Available -> {
                        Log.d(TAG, "📱 Registration available")
                    }
                    is RegistrationState.Registering -> {
                        Log.d(TAG, "⏳ Registering...")
                        _connectionState.value = ConnectionState.Connecting
                    }
                    is RegistrationState.Unregistering -> {
                        Log.d(TAG, "⏳ Unregistering...")
                    }
                }
            }
        }

        // Monitor available devices
        viewModelScope.launch {
            Wearables.devices.collect { deviceSet ->
                Log.d(TAG, "📱 Devices changed: ${deviceSet.size} devices")
                _devices.value = deviceSet.toList()
            }
        }
    }

    fun startDeviceSearch() {
        Log.d(TAG, "🔍 Starting device search")
        _connectionState.value = ConnectionState.Searching
        startRegistration()
    }

    fun stopDeviceSearch() {
        if (_connectionState.value is ConnectionState.Searching) {
            _connectionState.value = ConnectionState.Disconnected
        }
    }

    fun startRegistration() {
        Log.d(TAG, "📝 Starting registration")
        Wearables.startRegistration(getApplication())
    }

    fun startUnregistration() {
        Log.d(TAG, "📝 Starting unregistration")
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
    }

    // Streaming
    suspend fun checkCameraPermission(): Boolean {
        val result = Wearables.checkPermissionStatus(Permission.CAMERA)
        return result.getOrNull() == PermissionStatus.Granted
    }

    /**
     * Start streaming from the wearable device camera
     * Following Android SDK sample pattern: create new session, collect streams
     */
    fun startStream() {
        Log.d(TAG, "🚀 startStream START")

        // Cancel any existing jobs first
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null

        // Close any existing session
        streamSession?.let { oldSession ->
            Log.d(TAG, "⚠️ Closing previous session before starting new one")
            oldSession.close()
        }
        streamSession = null

        // Reset state
        _currentFrame.value = null
        _streamState.value = StreamState.Waiting

        // Get saved video quality setting
        val apiKeyManager = APIKeyManager.getInstance(getApplication())
        val savedQuality = apiKeyManager.getVideoQuality()
        val videoQuality = when (savedQuality) {
            "LOW" -> VideoQuality.LOW
            "HIGH" -> VideoQuality.HIGH
            else -> VideoQuality.MEDIUM
        }
        Log.d(TAG, "🎥 Using video quality: $savedQuality")

        // Create new session (Android SDK pattern)
        val session = Wearables.startStreamSession(
            getApplication(),
            deviceSelector,
            StreamConfiguration(videoQuality = videoQuality, 24)
        ).also { streamSession = it }

        Log.d(TAG, "🎥 StreamSession created")

        // Collect video frames
        videoJob = viewModelScope.launch {
            Log.d(TAG, "🎥 Starting video frame collection")
            session.videoStream.collect { videoFrame ->
                handleVideoFrame(videoFrame)
            }
        }

        // Monitor stream state
        stateJob = viewModelScope.launch {
            var prevState: StreamSessionState? = null
            session.state.collect { currentState ->
                Log.d(TAG, "📊 Stream state: $currentState (prev: $prevState)")

                when (currentState) {
                    StreamSessionState.STREAMING -> {
                        _streamState.value = StreamState.Streaming
                        // Upgrade connection state to Connected when streaming confirmed
                        val currentConnection = _connectionState.value
                        if (currentConnection is ConnectionState.Registered) {
                            _connectionState.value = ConnectionState.Connected(currentConnection.deviceName)
                            Log.d(TAG, "✅ Upgraded to Connected (streaming confirmed)")
                        }
                    }
                    StreamSessionState.STOPPED -> {
                        // When stream transitions to STOPPED, clean up (as per SDK sample)
                        if (prevState != null && prevState != StreamSessionState.STOPPED) {
                            Log.d(TAG, "⏹️ Stream transitioned to STOPPED, calling stopStream()")
                            stopStream()
                        }
                        _streamState.value = StreamState.Stopped
                    }
                    StreamSessionState.STARTING -> {
                        _streamState.value = StreamState.Waiting
                    }
                    else -> {
                        Log.d(TAG, "📊 Other stream state: $currentState")
                        _streamState.value = StreamState.Waiting
                    }
                }
                prevState = currentState
            }
        }

        Log.d(TAG, "🚀 startStream END")
    }

    /**
     * Stop streaming and release all resources
     * Following iOS stopSession() pattern
     */
    fun stopStream() {
        Log.d(TAG, "⏹️ stopStream START")

        // Cancel jobs first
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null

        // Close session to stop the camera on glasses
        streamSession?.close()
        streamSession = null

        // Clear frame (let GC handle bitmap)
        _currentFrame.value = null
        _streamState.value = StreamState.Stopped

        // Downgrade connection state
        val currentConnection = _connectionState.value
        if (currentConnection is ConnectionState.Connected) {
            _connectionState.value = ConnectionState.Registered(currentConnection.deviceName)
            Log.d(TAG, "📱 Downgraded to Registered (stream stopped)")
        }

        Log.d(TAG, "⏹️ stopStream END")
    }

    /**
     * Capture a photo from the stream
     */
    fun takePhoto(): Bitmap? {
        if (_streamState.value != StreamState.Streaming) {
            Log.w(TAG, "⚠️ Cannot take photo: not streaming")
            return null
        }

        viewModelScope.launch {
            try {
                Log.d(TAG, "📸 Capturing photo...")
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
                        Log.d(TAG, "📸 Photo captured: ${bitmap.width}x${bitmap.height}")
                        _capturedPhoto.value = bitmap
                        onPhotoTaken?.invoke(bitmap)
                    }
                    ?.onFailure {
                        Log.e(TAG, "❌ Photo capture failed")
                        _errorMessage.value = "Photo capture failed"
                    }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to take photo: ${e.message}")
            }
        }
        return _capturedPhoto.value
    }

    /**
     * Handle incoming video frames
     * Following SDK sample pattern with ByteArrayOutputStream.use{}
     */
    private fun handleVideoFrame(videoFrame: VideoFrame) {
        try {
            val buffer = videoFrame.buffer
            val dataSize = buffer.remaining()
            val byteArray = ByteArray(dataSize)

            // Save current position
            val originalPosition = buffer.position()
            buffer.get(byteArray)
            // Restore position
            buffer.position(originalPosition)

            // Convert I420 to NV21 format
            val nv21 = convertI420toNV21(byteArray, videoFrame.width, videoFrame.height)
            val image = YuvImage(nv21, ImageFormat.NV21, videoFrame.width, videoFrame.height, null)

            // Use .use{} to auto-close the stream (as per SDK sample)
            val jpegBytes = ByteArrayOutputStream().use { stream ->
                image.compressToJpeg(Rect(0, 0, videoFrame.width, videoFrame.height), 50, stream)
                stream.toByteArray()
            }

            val newBitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

            // Update the state (let GC handle old bitmap as per SDK sample)
            _currentFrame.value = newBitmap
            onFrameReceived?.invoke(newBitmap)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling video frame: ${e.message}")
        }
    }

    // Convert I420 (YYYYYYYY:UUVV) to NV21 (YYYYYYYY:VUVU)
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

    /**
     * Full cleanup of all resources
     * Following iOS cleanup() pattern - call when ViewModel is no longer needed
     */
    override fun onCleared() {
        Log.d(TAG, "🔴 onCleared START - cleaning up all resources")
        super.onCleared()

        // Stop stream first to release camera resources
        stopStream()

        // Cancel device monitoring
        deviceSelectorJob?.cancel()
        deviceSelectorJob = null
        monitoringStarted = false

        Log.d(TAG, "🔴 onCleared END - cleanup complete")
    }
}
