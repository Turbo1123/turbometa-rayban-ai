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
import com.meta.wearable.dat.core.selectors.DeviceSelector
import com.turbometa.rayban.services.RTMPStreamingService
import com.turbometa.rayban.utils.APIKeyManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

/**
 * RTMPStreamingViewModel - Manages RTMP streaming from glasses camera
 *
 * Integrates DAT SDK video stream with RTMPStreamingService for live broadcasting.
 */
class RTMPStreamingViewModel(application: Application) : AndroidViewModel(application) {

    companion object {
        private const val TAG = "RTMPStreamingVM"
        const val DEFAULT_RTMP_URL = "rtmp://localhost/live/stream"
    }

    // States
    sealed class UIState {
        object Idle : UIState()
        object Connecting : UIState()
        object Streaming : UIState()
        data class Error(val message: String) : UIState()
    }

    private val _uiState = MutableStateFlow<UIState>(UIState.Idle)
    val uiState: StateFlow<UIState> = _uiState.asStateFlow()

    private val _rtmpUrl = MutableStateFlow(DEFAULT_RTMP_URL)
    val rtmpUrl: StateFlow<String> = _rtmpUrl.asStateFlow()

    private val _previewFrame = MutableStateFlow<Bitmap?>(null)
    val previewFrame: StateFlow<Bitmap?> = _previewFrame.asStateFlow()

    private val _streamStats = MutableStateFlow(RTMPStreamingService.StreamingStats())
    val streamStats: StateFlow<RTMPStreamingService.StreamingStats> = _streamStats.asStateFlow()

    private val _cameraState = MutableStateFlow<StreamSessionState?>(null)
    val cameraState: StateFlow<StreamSessionState?> = _cameraState.asStateFlow()

    private val _bitrate = MutableStateFlow(2_000_000) // 2 Mbps default
    val bitrate: StateFlow<Int> = _bitrate.asStateFlow()

    // Services
    private val rtmpService = RTMPStreamingService(application)
    private val deviceSelector: DeviceSelector = AutoDeviceSelector()

    // Stream session
    private var streamSession: StreamSession? = null
    private var videoJob: Job? = null
    private var stateJob: Job? = null
    private var statsJob: Job? = null

    // Video parameters (set when stream starts)
    private var videoWidth = 0
    private var videoHeight = 0
    private var frameTimestampBase = 0L

    init {
        // Load saved RTMP URL
        val apiKeyManager = APIKeyManager.getInstance(application)
        apiKeyManager.getRtmpUrl()?.let { savedUrl ->
            if (savedUrl.isNotEmpty()) {
                _rtmpUrl.value = savedUrl
            }
        }

        // Observe RTMP service state
        viewModelScope.launch {
            rtmpService.state.collect { state ->
                when (state) {
                    is RTMPStreamingService.StreamingState.Idle -> {
                        if (_uiState.value != UIState.Idle) {
                            _uiState.value = UIState.Idle
                        }
                    }
                    is RTMPStreamingService.StreamingState.Connecting -> {
                        _uiState.value = UIState.Connecting
                    }
                    is RTMPStreamingService.StreamingState.Streaming -> {
                        _uiState.value = UIState.Streaming
                    }
                    is RTMPStreamingService.StreamingState.Error -> {
                        _uiState.value = UIState.Error(state.message)
                    }
                    is RTMPStreamingService.StreamingState.Disconnected -> {
                        _uiState.value = UIState.Error("Disconnected from server")
                    }
                }
            }
        }

        // Observe stats
        statsJob = viewModelScope.launch {
            rtmpService.stats.collect { stats ->
                _streamStats.value = stats
            }
        }
    }

    fun updateRtmpUrl(url: String) {
        _rtmpUrl.value = url
        // Save URL
        val apiKeyManager = APIKeyManager.getInstance(getApplication())
        apiKeyManager.saveRtmpUrl(url)
    }

    fun updateBitrate(newBitrate: Int) {
        _bitrate.value = newBitrate
    }

    /**
     * Start RTMP streaming
     * 1. Starts camera stream from glasses
     * 2. Connects to RTMP server
     * 3. Begins encoding and streaming
     */
    fun startStreaming() {
        if (_uiState.value == UIState.Streaming || _uiState.value == UIState.Connecting) {
            Log.w(TAG, "Already streaming or connecting")
            return
        }

        Log.d(TAG, "Starting streaming to: ${_rtmpUrl.value}")
        _uiState.value = UIState.Connecting

        // Start DAT SDK camera stream first
        startCameraStream()
    }

    private fun startCameraStream() {
        // Cancel any existing jobs
        videoJob?.cancel()
        stateJob?.cancel()

        // Close existing session
        streamSession?.close()
        streamSession = null

        // Get video quality setting
        val apiKeyManager = APIKeyManager.getInstance(getApplication())
        val savedQuality = apiKeyManager.getVideoQuality()
        val videoQuality = when (savedQuality) {
            "LOW" -> VideoQuality.LOW
            "HIGH" -> VideoQuality.HIGH
            else -> VideoQuality.MEDIUM
        }

        Log.d(TAG, "Starting camera stream with quality: $savedQuality")

        // Create stream session
        val session = Wearables.startStreamSession(
            getApplication(),
            deviceSelector,
            StreamConfiguration(videoQuality = videoQuality, 24)
        ).also { streamSession = it }

        // Monitor stream state
        stateJob = viewModelScope.launch {
            session.state.collect { state ->
                Log.d(TAG, "Camera state: $state")
                _cameraState.value = state

                when (state) {
                    StreamSessionState.STREAMING -> {
                        // Camera is ready, RTMP will connect after first frame arrives
                        Log.d(TAG, "Camera streaming, waiting for first frame...")
                    }
                    StreamSessionState.STOPPED -> {
                        if (rtmpService.isStreaming()) {
                            stopStreaming()
                        }
                    }
                    else -> { }
                }
            }
        }

        // Collect video frames
        videoJob = viewModelScope.launch {
            frameTimestampBase = 0L
            session.videoStream.collect { videoFrame ->
                handleVideoFrame(videoFrame)
            }
        }
    }

    private fun connectRtmp() {
        viewModelScope.launch {
            val success = rtmpService.startStreaming(
                rtmpUrl = _rtmpUrl.value,
                width = videoWidth,
                height = videoHeight,
                bitrate = _bitrate.value
            )

            if (!success) {
                Log.e(TAG, "Failed to connect RTMP")
                _uiState.value = UIState.Error("Failed to connect to RTMP server")
            }
        }
    }

    private fun handleVideoFrame(videoFrame: VideoFrame) {
        // Set video dimensions on first frame and connect RTMP
        if (videoWidth == 0 || videoHeight == 0) {
            // Use original dimensions - modern MediaCodec handles alignment internally
            videoWidth = videoFrame.width
            videoHeight = videoFrame.height
            Log.d(TAG, "Video dimensions: ${videoWidth}x${videoHeight}")

            // Now connect RTMP with proper dimensions
            if (_uiState.value == UIState.Connecting && !rtmpService.isStreaming()) {
                connectRtmp()
            }
        }

        // Calculate timestamp
        val timestampUs = if (frameTimestampBase == 0L) {
            frameTimestampBase = System.nanoTime() / 1000
            0L
        } else {
            System.nanoTime() / 1000 - frameTimestampBase
        }

        // Feed raw frame to RTMP encoder
        rtmpService.feedFrame(
            buffer = videoFrame.buffer,
            width = videoFrame.width,
            height = videoFrame.height,
            timestampUs = timestampUs
        )

        // Also update preview (convert to bitmap for display)
        updatePreview(videoFrame)
    }

    private fun updatePreview(videoFrame: VideoFrame) {
        try {
            val buffer = videoFrame.buffer
            val dataSize = buffer.remaining()
            val byteArray = ByteArray(dataSize)

            val originalPosition = buffer.position()
            buffer.get(byteArray)
            buffer.position(originalPosition)

            // Convert I420 to NV21 for preview
            val nv21 = convertI420toNV21(byteArray, videoFrame.width, videoFrame.height)
            val image = YuvImage(nv21, ImageFormat.NV21, videoFrame.width, videoFrame.height, null)

            val jpegBytes = ByteArrayOutputStream().use { stream ->
                image.compressToJpeg(Rect(0, 0, videoFrame.width, videoFrame.height), 50, stream)
                stream.toByteArray()
            }

            val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            _previewFrame.value = bitmap
        } catch (e: Exception) {
            Log.e(TAG, "Error updating preview: ${e.message}")
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

    /**
     * Stop streaming
     */
    fun stopStreaming() {
        Log.d(TAG, "Stopping streaming")

        // Stop RTMP service
        rtmpService.stopStreaming()

        // Stop camera stream
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null

        streamSession?.close()
        streamSession = null

        // Reset
        videoWidth = 0
        videoHeight = 0
        frameTimestampBase = 0L
        _previewFrame.value = null
        _uiState.value = UIState.Idle
    }

    fun clearError() {
        if (_uiState.value is UIState.Error) {
            _uiState.value = UIState.Idle
        }
    }

    override fun onCleared() {
        super.onCleared()
        stopStreaming()
        rtmpService.release()
        statsJob?.cancel()
    }
}
