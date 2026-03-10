package com.smartview.glassai.services

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
import com.smartview.glassai.MainActivity
import com.smartview.glassai.R
import com.smartview.glassai.data.QuickVisionStorage
import com.smartview.glassai.managers.APIProviderManager
import com.smartview.glassai.managers.QuickVisionModeManager
import com.smartview.glassai.utils.APIKeyManager
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
        const val ACTION_CAPTURE_AND_ANALYZE = "com.smartview.glassai.CAPTURE_AND_ANALYZE"
        const val ACTION_STOP = "com.smartview.glassai.STOP_QUICK_VISION"

        // Broadcast actions
        const val ACTION_ANALYSIS_COMPLETE = "com.smartview.glassai.ANALYSIS_COMPLETE"
        const val ACTION_QUICK_VISION_STATUS = "com.smartview.glassai.QUICK_VISION_STATUS"
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
    private lateinit var quickVisionStorage: QuickVisionStorage
    private lateinit var modeManager: QuickVisionModeManager
    private val mainHandler = Handler(Looper.getMainLooper())
    private var systemLocale: Locale = Locale.getDefault()  // 系统语言，用于状态提示
    private var outputLocale: Locale = Locale.US  // 输出语言，用于AI回复

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
        visionService = VisionAPIService(apiKeyManager, providerManager, this)
        quickVisionStorage = QuickVisionStorage.getInstance(this)
        modeManager = QuickVisionModeManager.getInstance(this)

        // Initialize TTS
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        Log.d(TAG, "TTS onInit called with status: $status")
        if (status == TextToSpeech.SUCCESS) {
            // 保存系统语言（用于状态提示）
            systemLocale = Locale.getDefault()

            // 保存输出语言（用于AI回复）
            val language = apiKeyManager.getOutputLanguage()
            outputLocale = when (language) {
                "zh-CN" -> Locale.CHINESE
                "en-US" -> Locale.US
                "ja-JP" -> Locale.JAPANESE
                "ko-KR" -> Locale.KOREAN
                "es-ES" -> Locale("es", "ES")
                "fr-FR" -> Locale.FRENCH
                else -> Locale.US
            }

            // 初始使用系统语言（状态提示用）
            val result = tts?.setLanguage(systemLocale)
            isTtsReady = result != TextToSpeech.LANG_MISSING_DATA &&
                    result != TextToSpeech.LANG_NOT_SUPPORTED

            tts?.setSpeechRate(1.1f)

            if (!isTtsReady) {
                tts?.setLanguage(Locale.getDefault())
                isTtsReady = true
            }
            Log.d(TAG, "TTS initialized - system: $systemLocale, output: $outputLocale")
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

                            // Save record with thumbnail
                            val prompt = modeManager.getPrompt()
                            val currentMode = modeManager.currentMode.value
                            val visionModel = providerManager.selectedModel.value
                            quickVisionStorage.saveRecord(
                                bitmap = image,
                                prompt = prompt,
                                result = description,
                                mode = currentMode,
                                visionModel = visionModel
                            )
                            Log.d(TAG, "Record saved with thumbnail")

                            broadcastResult(description)
                            broadcastStatus("complete")
                            speakAndWait(description, useOutputLocale = true)  // AI回复使用输出语言
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

    private fun speak(text: String, useOutputLocale: Boolean = false) {
        if (!isTtsReady || text.isBlank()) return
        // 根据需要切换语言
        tts?.setLanguage(if (useOutputLocale) outputLocale else systemLocale)
        Log.d(TAG, "Speaking: $text (locale: ${if (useOutputLocale) outputLocale else systemLocale})")
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "qv_${System.currentTimeMillis()}")
    }

    private suspend fun speakAndWait(text: String, useOutputLocale: Boolean = false) = suspendCancellableCoroutine<Unit> { continuation ->
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

        // 根据需要切换语言
        tts?.setLanguage(if (useOutputLocale) outputLocale else systemLocale)
        Log.d(TAG, "Speaking (wait): $text (locale: ${if (useOutputLocale) outputLocale else systemLocale})")
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    private fun getLocalizedString(key: String): String {
        // 使用系统语言来显示状态提示
        val isChinese = systemLocale.language == "zh"
        val isJapanese = systemLocale.language == "ja"
        val isKorean = systemLocale.language == "ko"

        return when (key) {
            "looking" -> when {
                isChinese -> "正在识别"
                isJapanese -> "確認中"
                isKorean -> "확인 중"
                else -> "Looking"
            }
            "analyzing" -> when {
                isChinese -> "正在分析..."
                isJapanese -> "分析中..."
                isKorean -> "분석 중..."
                else -> "Analyzing..."
            }
            "no_device" -> when {
                isChinese -> "眼镜未连接"
                isJapanese -> "メガネが接続されていません"
                isKorean -> "안경이 연결되어 있지 않습니다"
                else -> "Glasses not connected"
            }
            "no_image" -> when {
                isChinese -> "无法获取图像"
                isJapanese -> "画像を取得できません"
                isKorean -> "이미지를 캡처할 수 없습니다"
                else -> "Unable to capture image"
            }
            "error" -> when {
                isChinese -> "发生错误"
                isJapanese -> "エラーが発生しました"
                isKorean -> "오류가 발생했습니다"
                else -> "An error occurred"
            }
            "analysis_failed" -> when {
                isChinese -> "图像分析失败"
                isJapanese -> "画像分析に失敗しました"
                isKorean -> "이미지 분석 실패"
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
