package com.turbometa.rayban.services

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import com.pedro.rtmp.rtmp.RtmpClient
import com.pedro.rtmp.utils.ConnectCheckerRtmp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.nio.ByteBuffer

/**
 * RTMPStreamingService - Streams video from Ray-Ban Meta glasses to RTMP server
 *
 * This service takes raw I420 (YUV420P) frames from the DAT SDK,
 * encodes them to H.264 using MediaCodec, and streams via RTMP.
 *
 * Frame flow:
 * DAT SDK (I420) -> H.264 Encoder (MediaCodec) -> RTMP Client -> Server
 */
class RTMPStreamingService(private val context: Context) {

    companion object {
        private const val TAG = "RTMPStreamingService"

        // Default encoding parameters
        private const val DEFAULT_BITRATE = 2_000_000 // 2 Mbps
        private const val DEFAULT_FPS = 24
        private const val I_FRAME_INTERVAL = 1 // I-frame every 1 second for faster recovery

        // MIME type for H.264
        private const val MIME_TYPE = MediaFormat.MIMETYPE_VIDEO_AVC
    }

    // Streaming states
    sealed class StreamingState {
        object Idle : StreamingState()
        object Connecting : StreamingState()
        object Streaming : StreamingState()
        data class Error(val message: String) : StreamingState()
        object Disconnected : StreamingState()
    }

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private val _state = MutableStateFlow<StreamingState>(StreamingState.Idle)
    val state: StateFlow<StreamingState> = _state.asStateFlow()

    private val _stats = MutableStateFlow(StreamingStats())
    val stats: StateFlow<StreamingStats> = _stats.asStateFlow()

    // RTMP client
    private var rtmpClient: RtmpClient? = null

    // H.264 encoder
    private var encoder: MediaCodec? = null
    private var encoderInputBuffers: Array<ByteBuffer>? = null
    private var encoderJob: Job? = null

    // Video parameters
    private var videoWidth = 0
    private var videoHeight = 0
    private var isStreaming = false

    // SPS/PPS for H.264 stream initialization
    private var sps: ByteArray? = null
    private var pps: ByteArray? = null

    // Frame statistics
    private var frameCount = 0L
    private var startTime = 0L

    data class StreamingStats(
        val framesSent: Long = 0,
        val bitrate: Long = 0,
        val fps: Double = 0.0,
        val connectionTime: Long = 0
    )

    /**
     * Connect to RTMP server and start streaming
     * @param rtmpUrl Full RTMP URL (e.g., rtmp://server.com/live/streamkey)
     * @param width Video width from DAT SDK
     * @param height Video height from DAT SDK
     * @param bitrate Target bitrate in bps (default 2Mbps)
     */
    suspend fun startStreaming(
        rtmpUrl: String,
        width: Int,
        height: Int,
        bitrate: Int = DEFAULT_BITRATE
    ): Boolean = withContext(Dispatchers.IO) {
        if (isStreaming) {
            Log.w(TAG, "Already streaming")
            return@withContext false
        }

        try {
            Log.d(TAG, "Starting RTMP streaming to: $rtmpUrl")
            Log.d(TAG, "Video: ${width}x${height} @ $bitrate bps")

            _state.value = StreamingState.Connecting

            videoWidth = width
            videoHeight = height

            // Initialize H.264 encoder
            if (!initEncoder(width, height, bitrate)) {
                _state.value = StreamingState.Error("Failed to initialize encoder")
                return@withContext false
            }

            // Initialize RTMP client
            rtmpClient = RtmpClient(object : ConnectCheckerRtmp {
                override fun onConnectionStartedRtmp(rtmpUrl: String) {
                    Log.d(TAG, "RTMP connection started: $rtmpUrl")
                }

                override fun onConnectionSuccessRtmp() {
                    Log.d(TAG, "RTMP connected successfully")
                    _state.value = StreamingState.Streaming
                    startTime = System.currentTimeMillis()
                }

                override fun onConnectionFailedRtmp(reason: String) {
                    Log.e(TAG, "RTMP connection failed: $reason")
                    _state.value = StreamingState.Error(reason)
                    stopStreaming()
                }

                override fun onNewBitrateRtmp(bitrate: Long) {
                    Log.d(TAG, "RTMP bitrate: $bitrate")
                    updateStats(bitrate = bitrate)
                }

                override fun onDisconnectRtmp() {
                    Log.d(TAG, "RTMP disconnected")
                    _state.value = StreamingState.Disconnected
                }

                override fun onAuthErrorRtmp() {
                    Log.e(TAG, "RTMP auth error")
                    _state.value = StreamingState.Error("Authentication failed")
                }

                override fun onAuthSuccessRtmp() {
                    Log.d(TAG, "RTMP auth success")
                }
            })

            // Connect to RTMP server
            rtmpClient?.connect(rtmpUrl)

            isStreaming = true
            frameCount = 0

            // Start encoder output processing
            startEncoderOutputProcessing()

            Log.d(TAG, "RTMP streaming started")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start streaming: ${e.message}", e)
            _state.value = StreamingState.Error(e.message ?: "Unknown error")
            stopStreaming()
            false
        }
    }

    /**
     * Initialize H.264 encoder using MediaCodec
     */
    private fun initEncoder(width: Int, height: Int, bitrate: Int): Boolean {
        try {
            // Find encoder for H.264
            encoder = MediaCodec.createEncoderByType(MIME_TYPE)

            // Use YUV420Planar (I420) format to match DAT SDK output
            val format = MediaFormat.createVideoFormat(MIME_TYPE, width, height).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
                setInteger(MediaFormat.KEY_FRAME_RATE, DEFAULT_FPS)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
                )
                // Lower latency encoding
                setInteger(MediaFormat.KEY_LATENCY, 0)
            }

            encoder?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder?.start()

            Log.d(TAG, "H.264 encoder initialized: ${width}x${height} (I420/YUV420Planar)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize encoder: ${e.message}", e)
            return false
        }
    }

    /**
     * Process encoder output and send to RTMP
     */
    private fun startEncoderOutputProcessing() {
        encoderJob = scope.launch(Dispatchers.IO) {
            val bufferInfo = MediaCodec.BufferInfo()

            while (isStreaming) {
                try {
                    val outputIndex = encoder?.dequeueOutputBuffer(bufferInfo, 10000) ?: -1

                    when {
                        outputIndex >= 0 -> {
                            val outputBuffer = encoder?.getOutputBuffer(outputIndex)
                            if (outputBuffer != null && bufferInfo.size > 0) {
                                // Check for codec config (SPS/PPS)
                                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
                                    extractSpsPps(outputBuffer, bufferInfo.size)
                                } else {
                                    // Send H.264 data to RTMP
                                    sendH264Data(outputBuffer, bufferInfo)
                                }
                            }
                            encoder?.releaseOutputBuffer(outputIndex, false)
                        }
                        outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            Log.d(TAG, "Encoder output format changed: ${encoder?.outputFormat}")
                        }
                    }
                } catch (e: Exception) {
                    if (isStreaming) {
                        Log.e(TAG, "Encoder output error: ${e.message}")
                    }
                }
            }
        }
    }

    /**
     * Extract SPS and PPS from codec config
     */
    private fun extractSpsPps(buffer: ByteBuffer, size: Int) {
        val data = ByteArray(size)
        buffer.get(data)
        buffer.rewind()

        // Parse SPS and PPS from AnnexB format
        // Format: 00 00 00 01 [SPS] 00 00 00 01 [PPS]
        var spsStart = -1
        var spsEnd = -1
        var ppsStart = -1

        for (i in 0 until size - 4) {
            if (data[i] == 0.toByte() && data[i + 1] == 0.toByte() &&
                data[i + 2] == 0.toByte() && data[i + 3] == 1.toByte()) {
                if (spsStart == -1) {
                    spsStart = i + 4
                } else if (spsEnd == -1) {
                    spsEnd = i
                    ppsStart = i + 4
                }
            }
        }

        if (spsStart >= 0 && spsEnd > spsStart && ppsStart >= 0) {
            sps = data.copyOfRange(spsStart, spsEnd)
            pps = data.copyOfRange(ppsStart, size)
            Log.d(TAG, "SPS/PPS extracted: SPS=${sps?.size} bytes, PPS=${pps?.size} bytes")

            // Send SPS/PPS to RTMP client
            val localSps = sps
            val localPps = pps
            if (localSps != null && localPps != null) {
                rtmpClient?.setVideoInfo(ByteBuffer.wrap(localSps), ByteBuffer.wrap(localPps), null)
            }
        }
    }

    /**
     * Send H.264 encoded data to RTMP server
     */
    private fun sendH264Data(buffer: ByteBuffer, bufferInfo: MediaCodec.BufferInfo) {
        val data = ByteArray(bufferInfo.size)
        buffer.get(data)

        val isKeyFrame = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
        val timestamp = bufferInfo.presentationTimeUs / 1000 // Convert to milliseconds

        // Send to RTMP
        rtmpClient?.sendVideo(ByteBuffer.wrap(data), bufferInfo)

        frameCount++
        updateStats(framesSent = frameCount)
    }

    /**
     * Feed a raw I420 frame to the encoder
     * Call this method when a new VideoFrame is received from DAT SDK
     *
     * @param i420Data Raw I420 (YUV420P) frame data
     * @param width Frame width
     * @param height Frame height
     * @param timestampUs Presentation timestamp in microseconds
     */
    fun feedFrame(i420Data: ByteArray, width: Int, height: Int, timestampUs: Long) {
        if (!isStreaming || encoder == null) return

        try {
            val inputIndex = encoder?.dequeueInputBuffer(0) ?: -1
            if (inputIndex >= 0) {
                val inputBuffer = encoder?.getInputBuffer(inputIndex)
                inputBuffer?.clear()
                inputBuffer?.put(i420Data)
                encoder?.queueInputBuffer(inputIndex, 0, i420Data.size, timestampUs, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error feeding frame: ${e.message}")
        }
    }

    // Frame tracking
    private var totalFrames = 0L
    private var droppedFrames = 0L
    private var lastLogTime = 0L

    // Timestamp smoothing for consistent frame timing
    private var baseTimestampUs = 0L
    private var frameIndex = 0L
    private val targetFrameDurationUs = 1_000_000L / DEFAULT_FPS // ~41666 us for 24fps

    /**
     * Feed a raw I420 frame from ByteBuffer (direct from DAT SDK VideoFrame)
     * Directly passes I420 data to encoder configured with COLOR_FormatYUV420Planar
     */
    fun feedFrame(buffer: ByteBuffer, width: Int, height: Int, timestampUs: Long) {
        if (!isStreaming || encoder == null) return

        totalFrames++

        try {
            // Use longer timeout to reduce frame drops
            val inputIndex = encoder?.dequeueInputBuffer(10000) ?: -1
            if (inputIndex >= 0) {
                val inputBuffer = encoder?.getInputBuffer(inputIndex)
                inputBuffer?.clear()

                // Make a defensive copy to avoid race conditions
                val position = buffer.position()
                val dataSize = buffer.remaining()

                // Validate frame size (I420 = width * height * 1.5)
                val expectedSize = width * height * 3 / 2
                if (dataSize != expectedSize) {
                    Log.w(TAG, "Frame size mismatch! Expected: $expectedSize, Got: $dataSize")
                }

                // Create a local copy of the data
                val frameCopy = ByteArray(dataSize)
                buffer.get(frameCopy)
                buffer.position(position) // Restore position

                // Put the copied data into encoder
                inputBuffer?.put(frameCopy)

                // Use smoothed timestamp for consistent frame rate
                // This prevents timing jitter from causing decoder issues
                if (baseTimestampUs == 0L) {
                    baseTimestampUs = timestampUs
                }
                val smoothedTimestamp = baseTimestampUs + (frameIndex * targetFrameDurationUs)
                frameIndex++

                encoder?.queueInputBuffer(inputIndex, 0, dataSize, smoothedTimestamp, 0)
            } else {
                droppedFrames++
                Log.w(TAG, "Dropped frame - encoder queue full (total dropped: $droppedFrames)")
            }

            // Log stats every 5 seconds
            val now = System.currentTimeMillis()
            if (now - lastLogTime > 5000) {
                Log.d(TAG, "Frame stats: total=$totalFrames, dropped=$droppedFrames, drop rate=${droppedFrames * 100 / maxOf(totalFrames, 1)}%")
                lastLogTime = now
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error feeding frame from buffer: ${e.message}", e)
        }
    }

    /**
     * Stop streaming and release resources
     */
    fun stopStreaming() {
        Log.d(TAG, "Stopping RTMP streaming")
        isStreaming = false

        // Stop encoder processing
        encoderJob?.cancel()
        encoderJob = null

        // Stop and release encoder
        try {
            encoder?.stop()
            encoder?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping encoder: ${e.message}")
        }
        encoder = null

        // Disconnect RTMP
        try {
            rtmpClient?.disconnect()
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting RTMP: ${e.message}")
        }
        rtmpClient = null

        // Clear SPS/PPS
        sps = null
        pps = null

        // Reset frame counters and timestamp smoothing
        totalFrames = 0
        droppedFrames = 0
        lastLogTime = 0
        baseTimestampUs = 0
        frameIndex = 0

        _state.value = StreamingState.Idle
        Log.d(TAG, "RTMP streaming stopped")
    }

    private fun updateStats(framesSent: Long? = null, bitrate: Long? = null) {
        val current = _stats.value
        val elapsed = if (startTime > 0) System.currentTimeMillis() - startTime else 0
        val fps = if (elapsed > 0) (framesSent ?: current.framesSent) * 1000.0 / elapsed else 0.0

        _stats.value = StreamingStats(
            framesSent = framesSent ?: current.framesSent,
            bitrate = bitrate ?: current.bitrate,
            fps = fps,
            connectionTime = elapsed
        )
    }

    /**
     * Check if currently streaming
     */
    fun isStreaming(): Boolean = isStreaming

    /**
     * Release all resources
     */
    fun release() {
        stopStreaming()
        scope.cancel()
    }
}
