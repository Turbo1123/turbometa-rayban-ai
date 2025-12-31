package com.turbometa.rayban.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.core.app.NotificationCompat
import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.startStreamSession
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoFrame
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.turbometa.rayban.MainActivity
import com.turbometa.rayban.R
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.utils.APIKeyManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import java.io.ByteArrayOutputStream
import java.util.Locale
import java.util.concurrent.CountDownLatch
import kotlin.coroutines.resume

/**
 * Quick Vision Service
 * Background service for capturing and analyzing images from the glasses camera
 * Flow: Start stream → Capture photo → Stop stream → Analyze with Vision API → TTS announce
 * 1:1 port from iOS QuickVisionService
 */
class QuickVisionService : Service(), TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "QuickVisionService"
        private const val NOTIFICATION_ID = 1002
        private const val CHANNEL_ID = "quick_vision_channel"

        // Service actions
        const val ACTION_CAPTURE_AND_ANALYZE = "com.turbometa.rayban.CAPTURE_AND_ANALYZE"
        const val ACTION_STOP = "com.turbometa.rayban.STOP_QUICK_VISION"

        // Broadcast actions
        const val ACTION_ANALYSIS_COMPLETE = "com.turbometa.rayban.ANALYSIS_COMPLETE"
        const val ACTION_QUICK_VISION_STATUS = "com.turbometa.rayban.QUICK_VISION_STATUS"
        const val EXTRA_RESULT = "analysis_result"
        const val EXTRA_ERROR = "analysis_error"
        const val EXTRA_STATUS = "status"
    }

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var tts: TextToSpeech? = null
    private var isTtsReady = false
    private var ttsInitLatch = CountDownLatch(1)
    private lateinit var apiKeyManager: APIKeyManager
    private lateinit var providerManager: APIProviderManager
    private lateinit var visionService: VisionAPIService
    private val mainHandler = Handler(Looper.getMainLooper())

    // DAT SDK components
    private val deviceSelector = AutoDeviceSelector()
    private var streamSession: StreamSession? = null
    private var videoJob: Job? = null
    private var stateJob: Job? = null
    private var capturedFrame: Bitmap? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        createNotificationChannel()

        apiKeyManager = APIKeyManager.getInstance(this)
        providerManager = APIProviderManager.getInstance(this)
        visionService = VisionAPIService(apiKeyManager, providerManager)

        // Initialize TTS
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        Log.d(TAG, "TTS onInit called with status: $status")
        if (status == TextToSpeech.SUCCESS) {
            val language = apiKeyManager.getOutputLanguage()
            val locale = when (language) {
                "zh-CN" -> Locale.CHINESE
                "en-US" -> Locale.US
                "ja-JP" -> Locale.JAPANESE
                "ko-KR" -> Locale.KOREAN
                "es-ES" -> Locale("es", "ES")
                "fr-FR" -> Locale.FRENCH
                else -> Locale.US
            }

            val result = tts?.setLanguage(locale)
            isTtsReady = result != TextToSpeech.LANG_MISSING_DATA &&
                    result != TextToSpeech.LANG_NOT_SUPPORTED

            tts?.setSpeechRate(1.1f)

            if (!isTtsReady) {
                tts?.setLanguage(Locale.getDefault())
                isTtsReady = true
            }
            Log.d(TAG, "TTS initialized with locale: $locale")
        }
        ttsInitLatch.countDown()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand with action: ${intent?.action}")
        startForeground(NOTIFICATION_ID, createNotification(getLocalizedString("looking")))

        broadcastStatus("started")

        when (intent?.action) {
            ACTION_CAPTURE_AND_ANALYZE -> captureAndAnalyze()
            ACTION_STOP -> stopService()
            else -> captureAndAnalyze()
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        cleanup()
        scope.cancel()
        tts?.stop()
        tts?.shutdown()

        // Broadcast finished so PorcupineWakeWordService can reset isProcessing
        broadcastStatus("finished")
        super.onDestroy()
    }

    private fun cleanup() {
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null
        streamSession?.close()
        streamSession = null
        capturedFrame = null
    }

    private fun captureAndAnalyze() {
        Log.d(TAG, "captureAndAnalyze called")

        scope.launch {
            try {
                // Wait for TTS to initialize
                withTimeoutOrNull(2000) {
                    suspendCancellableCoroutine<Unit> { continuation ->
                        if (isTtsReady) {
                            continuation.resume(Unit)
                        } else {
                            Thread {
                                ttsInitLatch.await()
                                mainHandler.post { continuation.resume(Unit) }
                            }.start()
                        }
                    }
                }

                // 1. Announce "正在识别"
                val lookingText = getLocalizedString("looking")
                Log.d(TAG, "Speaking: $lookingText")
                speak(lookingText)

                // 2. Check if device is available
                val hasDevice = deviceSelector.activeDevice(Wearables.devices).first() != null
                if (!hasDevice) {
                    Log.e(TAG, "No device connected")
                    speak(getLocalizedString("no_device"))
                    broadcastStatus("error")
                    delay(2000)
                    finishService()
                    return@launch
                }

                // 3. Start stream
                Log.d(TAG, "Starting stream session...")
                broadcastStatus("streaming")

                val session = Wearables.startStreamSession(
                    this@QuickVisionService,
                    deviceSelector,
                    StreamConfiguration(videoQuality = VideoQuality.MEDIUM, 24)
                ).also { streamSession = it }

                // 4. Wait for streaming state
                var isStreaming = false
                var frameReceived = false

                stateJob = launch {
                    session.state.collect { state ->
                        Log.d(TAG, "Stream state: $state")
                        if (state == StreamSessionState.STREAMING) {
                            isStreaming = true
                        }
                    }
                }

                videoJob = launch {
                    session.videoStream.collect { videoFrame ->
                        if (!frameReceived && isStreaming) {
                            Log.d(TAG, "First frame received, capturing...")
                            capturedFrame = convertVideoFrameToBitmap(videoFrame)
                            frameReceived = true
                        }
                    }
                }

                // Wait for stream to be ready and capture frame
                val timeout = 8000L
                val startTime = System.currentTimeMillis()
                while (!frameReceived && System.currentTimeMillis() - startTime < timeout) {
                    delay(100)
                }

                // 5. Stop stream
                Log.d(TAG, "Stopping stream...")
                videoJob?.cancel()
                stateJob?.cancel()
                session.close()
                streamSession = null

                // 6. Analyze the captured frame
                val image = capturedFrame
                if (image != null) {
                    Log.d(TAG, "Analyzing captured image: ${image.width}x${image.height}")
                    broadcastStatus("analyzing")
                    updateNotification(getLocalizedString("analyzing"))

                    val language = apiKeyManager.getOutputLanguage()
                    val result = visionService.quickVision(image, language)

                    result.fold(
                        onSuccess = { description ->
                            Log.d(TAG, "Analysis result: $description")
                            broadcastResult(description)
                            broadcastStatus("complete")
                            speakAndWait(description)
                        },
                        onFailure = { error ->
                            Log.e(TAG, "Analysis failed: ${error.message}")
                            speak(getLocalizedString("analysis_failed"))
                            broadcastError(error.message ?: "Unknown error")
                            broadcastStatus("error")
                        }
                    )
                } else {
                    Log.e(TAG, "No frame captured")
                    speak(getLocalizedString("no_image"))
                    broadcastStatus("error")
                }

                delay(500)
                finishService()

            } catch (e: Exception) {
                Log.e(TAG, "Error in captureAndAnalyze: ${e.message}", e)
                speak(getLocalizedString("error"))
                broadcastStatus("error")
                delay(2000)
                finishService()
            }
        }
    }

    private fun convertVideoFrameToBitmap(videoFrame: VideoFrame): Bitmap? {
        return try {
            val buffer = videoFrame.buffer
            val dataSize = buffer.remaining()
            val byteArray = ByteArray(dataSize)
            val originalPosition = buffer.position()
            buffer.get(byteArray)
            buffer.position(originalPosition)

            // Convert I420 to NV21
            val nv21 = convertI420toNV21(byteArray, videoFrame.width, videoFrame.height)
            val image = YuvImage(nv21, ImageFormat.NV21, videoFrame.width, videoFrame.height, null)

            val jpegBytes = ByteArrayOutputStream().use { stream ->
                image.compressToJpeg(Rect(0, 0, videoFrame.width, videoFrame.height), 85, stream)
                stream.toByteArray()
            }

            BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
        } catch (e: Exception) {
            Log.e(TAG, "Error converting video frame: ${e.message}")
            null
        }
    }

    private fun convertI420toNV21(input: ByteArray, width: Int, height: Int): ByteArray {
        val output = ByteArray(input.size)
        val size = width * height
        val quarter = size / 4

        input.copyInto(output, 0, 0, size)

        for (n in 0 until quarter) {
            output[size + n * 2] = input[size + quarter + n]
            output[size + n * 2 + 1] = input[size + n]
        }
        return output
    }

    private fun speak(text: String) {
        if (!isTtsReady || text.isBlank()) return
        Log.d(TAG, "Speaking: $text")
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "qv_${System.currentTimeMillis()}")
    }

    private suspend fun speakAndWait(text: String) = suspendCancellableCoroutine<Unit> { continuation ->
        if (!isTtsReady || text.isBlank()) {
            continuation.resume(Unit)
            return@suspendCancellableCoroutine
        }

        val utteranceId = "qv_${System.currentTimeMillis()}"

        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}
            override fun onDone(id: String?) {
                if (id == utteranceId && continuation.isActive) {
                    continuation.resume(Unit)
                }
            }
            override fun onError(id: String?) {
                if (id == utteranceId && continuation.isActive) {
                    continuation.resume(Unit)
                }
            }
        })

        Log.d(TAG, "Speaking (wait): $text")
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private fun getLocalizedString(key: String): String {
        val language = apiKeyManager.getOutputLanguage()
        return when (key) {
            "looking" -> when (language) {
                "zh-CN" -> "正在识别"
                "en-US" -> "Looking"
                "ja-JP" -> "確認中"
                "ko-KR" -> "확인 중"
                else -> "Looking"
            }
            "analyzing" -> when (language) {
                "zh-CN" -> "正在分析..."
                "en-US" -> "Analyzing..."
                "ja-JP" -> "分析中..."
                "ko-KR" -> "분석 중..."
                else -> "Analyzing..."
            }
            "no_device" -> when (language) {
                "zh-CN" -> "眼镜未连接"
                "en-US" -> "Glasses not connected"
                "ja-JP" -> "メガネが接続されていません"
                "ko-KR" -> "안경이 연결되어 있지 않습니다"
                else -> "Glasses not connected"
            }
            "no_image" -> when (language) {
                "zh-CN" -> "无法获取图像"
                "en-US" -> "Unable to capture image"
                "ja-JP" -> "画像を取得できません"
                "ko-KR" -> "이미지를 캡처할 수 없습니다"
                else -> "Unable to capture image"
            }
            "error" -> when (language) {
                "zh-CN" -> "发生错误"
                "en-US" -> "An error occurred"
                "ja-JP" -> "エラーが発生しました"
                "ko-KR" -> "오류가 발생했습니다"
                else -> "An error occurred"
            }
            "analysis_failed" -> when (language) {
                "zh-CN" -> "图像分析失败"
                "en-US" -> "Image analysis failed"
                "ja-JP" -> "画像分析に失敗しました"
                "ko-KR" -> "이미지 분석 실패"
                else -> "Image analysis failed"
            }
            else -> key
        }
    }

    private fun broadcastStatus(status: String) {
        val intent = Intent(ACTION_QUICK_VISION_STATUS).apply {
            putExtra(EXTRA_STATUS, status)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        Log.d(TAG, "Broadcast status: $status")
    }

    private fun broadcastResult(result: String) {
        val intent = Intent(ACTION_ANALYSIS_COMPLETE).apply {
            putExtra(EXTRA_RESULT, result)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    private fun broadcastError(error: String) {
        val intent = Intent(ACTION_ANALYSIS_COMPLETE).apply {
            putExtra(EXTRA_ERROR, error)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    private fun stopService() {
        finishService()
    }

    private fun finishService() {
        Log.d(TAG, "Finishing service")
        cleanup()
        broadcastStatus("finished")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun updateNotification(message: String) {
        mainHandler.post {
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(NOTIFICATION_ID, createNotification(message))
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Quick Vision",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Quick Vision image analysis"
                setShowBadge(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 200)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(message: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Quick Vision")
            .setContentText(message)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }
}
