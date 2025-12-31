package com.turbometa.rayban.services

import android.graphics.Bitmap
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.util.Base64
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonObject
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

/**
 * Gemini Live WebSocket Service
 * Provides real-time audio chat with Google Gemini AI
 * Uses gemini-2.0-flash-exp model for real-time audio conversation
 * 1:1 port from iOS GeminiLiveService.swift
 */
class GeminiLiveService(
    private val apiKey: String,
    private val model: String = "gemini-2.0-flash-exp",
    private val outputLanguage: String = "zh-CN"
) {
    companion object {
        private const val TAG = "GeminiLiveService"
        private const val WS_BASE_URL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

        // Gemini uses 16kHz for input, 24kHz for output
        private const val INPUT_SAMPLE_RATE = 16000
        private const val OUTPUT_SAMPLE_RATE = 24000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    // State
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking

    private val _currentTranscript = MutableStateFlow("")
    val currentTranscript: StateFlow<String> = _currentTranscript

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    // Callbacks
    var onTranscriptDelta: ((String) -> Unit)? = null
    var onTranscriptDone: ((String) -> Unit)? = null
    var onUserTranscript: ((String) -> Unit)? = null
    var onSpeechStarted: (() -> Unit)? = null
    var onSpeechStopped: (() -> Unit)? = null
    var onError: ((String) -> Unit)? = null
    var onConnected: (() -> Unit)? = null
    var onFirstAudioSent: (() -> Unit)? = null

    // Internal
    private var webSocket: WebSocket? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var recordingJob: Job? = null
    private var audioPlaybackJob: Job? = null
    private val audioQueue = mutableListOf<ByteArray>()
    private val gson = Gson()
    private var scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var isSessionConfigured = false
    private var hasAudioBeenSent = false
    private var pendingImageFrame: Bitmap? = null

    // Audio buffer management
    private var audioChunkCount = 0
    private val minChunksBeforePlay = 2
    private var hasStartedPlaying = false

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    fun connect() {
        if (_isConnected.value) return

        // Reset scope if it was cancelled (after previous disconnect)
        if (!scope.isActive) {
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
            Log.d(TAG, "Scope was cancelled, created new scope")
        }

        // Gemini Live WebSocket URL with API key
        val url = "$WS_BASE_URL?key=$apiKey"

        Log.d(TAG, "Connecting to Gemini Live WebSocket")

        val request = Request.Builder()
            .url(url)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected")
                _isConnected.value = true
                configureSession()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleServerEvent(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket error: ${t.message}")
                _isConnected.value = false
                _errorMessage.value = t.message
                onError?.invoke(t.message ?: "Connection failed")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $reason")
                _isConnected.value = false
                isSessionConfigured = false
            }
        })
    }

    fun disconnect() {
        Log.d(TAG, "Disconnecting from Gemini Live")
        stopRecording()
        stopAudioPlayback()
        webSocket?.close(1000, "User disconnected")
        webSocket = null
        _isConnected.value = false
        _isRecording.value = false
        _isSpeaking.value = false
        isSessionConfigured = false
        scope.cancel()
    }

    // MARK: - Session Configuration

    private fun configureSession() {
        if (isSessionConfigured) return

        // Matching iOS Live AI prompts exactly
        val instructions = getLiveAIPrompt(outputLanguage)

        // Gemini Live API setup message
        val setupMessage = mapOf(
            "setup" to mapOf(
                "model" to "models/$model",
                "generation_config" to mapOf(
                    "response_modalities" to listOf("AUDIO"),
                    "speech_config" to mapOf(
                        "voice_config" to mapOf(
                            "prebuilt_voice_config" to mapOf(
                                "voice_name" to "Aoede"  // Gemini voice options: Aoede, Charon, Fenrir, Kore, Puck
                            )
                        )
                    )
                ),
                "system_instruction" to mapOf(
                    "parts" to listOf(
                        mapOf("text" to instructions)
                    )
                )
            )
        )

        val json = gson.toJson(setupMessage)
        webSocket?.send(json)
        Log.d(TAG, "Sent session configuration")
    }

    /**
     * Get localized Live AI prompt matching iOS implementation
     */
    private fun getLiveAIPrompt(language: String): String {
        return when (language) {
            "zh-CN" -> """
                你是RayBan Meta智能眼镜AI助手。

                【重要】必须始终用中文回答，无论用户说什么语言。

                回答要简练、口语化，像朋友聊天一样。用户戴着眼镜可以看到周围环境，根据画面快速给出有用的建议。不要啰嗦，直接说重点。
            """.trimIndent()
            "en-US" -> """
                You are a RayBan Meta smart glasses AI assistant.

                [IMPORTANT] Always respond in English.

                Keep your answers concise and conversational, like chatting with a friend. The user is wearing glasses and can see their surroundings, provide quick and useful suggestions based on what they see. Be direct and to the point.
            """.trimIndent()
            "ja-JP" -> """
                あなたはRayBan Metaスマートグラスのアシスタントです。

                【重要】常に日本語で回答してください。

                回答は簡潔で会話的に、友達とチャットするように。ユーザーは眼鏡をかけて周囲を見ています。見えるものに基づいて素早く有用なアドバイスを。要点を直接伝えてください。
            """.trimIndent()
            "ko-KR" -> """
                당신은 RayBan Meta 스마트 안경 AI 어시스턴트입니다.

                【중요】항상 한국어로 응답하세요.

                친구와 대화하듯이 간결하고 대화적으로 답변하세요. 사용자는 안경을 착용하고 주변을 볼 수 있습니다. 보이는 것에 따라 빠르고 유용한 조언을 제공하세요. 요점만 말하세요.
            """.trimIndent()
            else -> getLiveAIPrompt("en-US")
        }
    }

    // MARK: - Audio Recording

    fun startRecording() {
        if (_isRecording.value) return

        try {
            Log.d(TAG, "Starting recording")

            val bufferSize = AudioRecord.getMinBufferSize(INPUT_SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                INPUT_SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "Failed to initialize AudioRecord")
                return
            }

            audioRecord?.startRecording()
            _isRecording.value = true
            hasAudioBeenSent = false

            recordingJob = scope.launch {
                val buffer = ByteArray(bufferSize)
                while (isActive && _isRecording.value) {
                    val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (bytesRead > 0) {
                        sendAudioData(buffer.copyOf(bytesRead))
                    }
                }
            }

            Log.d(TAG, "Recording started")
        } catch (e: SecurityException) {
            Log.e(TAG, "Microphone permission denied")
            _errorMessage.value = "Microphone permission denied"
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}")
            _errorMessage.value = e.message
        }
    }

    fun stopRecording() {
        if (!_isRecording.value) return

        Log.d(TAG, "Stopping recording")
        _isRecording.value = false
        recordingJob?.cancel()
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        hasAudioBeenSent = false
    }

    fun updateVideoFrame(frame: Bitmap) {
        pendingImageFrame = frame
    }

    private fun sendAudioData(audioData: ByteArray) {
        if (!_isConnected.value || !isSessionConfigured) return

        val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)

        // Gemini Live realtime input format
        val message = mapOf(
            "realtime_input" to mapOf(
                "media_chunks" to listOf(
                    mapOf(
                        "mime_type" to "audio/pcm;rate=$INPUT_SAMPLE_RATE",
                        "data" to base64Audio
                    )
                )
            )
        )

        webSocket?.send(gson.toJson(message))

        // Send image on first audio if available
        if (!hasAudioBeenSent) {
            hasAudioBeenSent = true
            Log.d(TAG, "First audio sent")
            onFirstAudioSent?.invoke()

            pendingImageFrame?.let { sendImageInput(it) }
        }
    }

    fun sendImageInput(bitmap: Bitmap) {
        try {
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 60, outputStream)
            val bytes = outputStream.toByteArray()
            val base64Image = Base64.encodeToString(bytes, Base64.NO_WRAP)

            Log.d(TAG, "Sending image: ${bytes.size} bytes")

            val message = mapOf(
                "realtime_input" to mapOf(
                    "media_chunks" to listOf(
                        mapOf(
                            "mime_type" to "image/jpeg",
                            "data" to base64Image
                        )
                    )
                )
            )

            webSocket?.send(gson.toJson(message))
        } catch (e: Exception) {
            Log.e(TAG, "Error sending image: ${e.message}")
        }
    }

    // MARK: - Handle Server Events

    private fun handleServerEvent(text: String) {
        try {
            val json = gson.fromJson(text, JsonObject::class.java)

            // Handle setup complete
            if (json.has("setupComplete")) {
                Log.d(TAG, "Session configuration complete")
                isSessionConfigured = true
                onConnected?.invoke()
                return
            }

            // Handle server content (audio/text responses)
            if (json.has("serverContent")) {
                val serverContent = json.getAsJsonObject("serverContent")
                handleServerContent(serverContent)
                return
            }

            // Handle tool calls (if any)
            if (json.has("toolCall")) {
                Log.d(TAG, "Tool call received: ${json.get("toolCall")}")
                return
            }

            // Handle errors
            if (json.has("error")) {
                val error = json.getAsJsonObject("error")
                val message = error.get("message")?.asString ?: "Unknown error"
                Log.e(TAG, "Server error: $message")
                _errorMessage.value = message
                onError?.invoke(message)
                return
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error handling server event: ${e.message}")
        }
    }

    private fun handleServerContent(content: JsonObject) {
        // Check for model turn
        if (content.has("modelTurn")) {
            val modelTurn = content.getAsJsonObject("modelTurn")
            if (modelTurn.has("parts")) {
                val parts = modelTurn.getAsJsonArray("parts")

                for (i in 0 until parts.size()) {
                    val part = parts[i].asJsonObject

                    // Handle text response
                    if (part.has("text")) {
                        val text = part.get("text").asString
                        Log.d(TAG, "AI response: $text")
                        _currentTranscript.value += text
                        onTranscriptDelta?.invoke(text)
                    }

                    // Handle inline audio data
                    if (part.has("inlineData")) {
                        val inlineData = part.getAsJsonObject("inlineData")
                        val mimeType = inlineData.get("mimeType")?.asString ?: ""
                        if (mimeType.contains("audio")) {
                            val base64Audio = inlineData.get("data")?.asString ?: ""
                            val audioData = Base64.decode(base64Audio, Base64.DEFAULT)
                            handleAudioChunk(audioData)
                        }
                    }
                }
            }
        }

        // Check if turn is complete
        if (content.has("turnComplete") && content.get("turnComplete").asBoolean) {
            Log.d(TAG, "AI response complete")
            finishAudioPlayback()
            onTranscriptDone?.invoke(_currentTranscript.value)
            _currentTranscript.value = ""
        }

        // Check for interrupted flag
        if (content.has("interrupted") && content.get("interrupted").asBoolean) {
            Log.d(TAG, "Response interrupted")
            stopAudioPlayback()
        }

        // Handle input transcription (user speech)
        if (content.has("inputTranscription")) {
            val inputTranscription = content.getAsJsonObject("inputTranscription")
            val text = inputTranscription.get("text")?.asString ?: ""
            Log.d(TAG, "User said: $text")
            onUserTranscript?.invoke(text)
        }

        // Handle output transcription (AI speech text)
        if (content.has("outputTranscription")) {
            val outputTranscription = content.getAsJsonObject("outputTranscription")
            val text = outputTranscription.get("text")?.asString ?: ""
            Log.d(TAG, "AI text: $text")
            onTranscriptDelta?.invoke(text)
        }
    }

    // MARK: - Audio Playback

    private fun handleAudioChunk(audioData: ByteArray) {
        audioChunkCount++

        if (!hasStartedPlaying) {
            synchronized(audioQueue) {
                audioQueue.add(audioData)
            }

            if (audioChunkCount >= minChunksBeforePlay) {
                hasStartedPlaying = true
                _isSpeaking.value = true
                startAudioPlayback()
            }
        } else {
            synchronized(audioQueue) {
                audioQueue.add(audioData)
            }
            if (audioPlaybackJob?.isActive != true) {
                startAudioPlayback()
            }
        }
    }

    private fun finishAudioPlayback() {
        audioChunkCount = 0
        hasStartedPlaying = false
    }

    private fun startAudioPlayback() {
        if (audioTrack == null) {
            val bufferSize = AudioTrack.getMinBufferSize(
                OUTPUT_SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            audioTrack = AudioTrack(
                AudioManager.STREAM_MUSIC,
                OUTPUT_SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize * 2,
                AudioTrack.MODE_STREAM
            )
            audioTrack?.play()
        }

        _isSpeaking.value = true

        audioPlaybackJob = scope.launch {
            while (isActive) {
                val data = synchronized(audioQueue) {
                    if (audioQueue.isNotEmpty()) audioQueue.removeAt(0) else null
                }

                if (data != null) {
                    audioTrack?.write(data, 0, data.size)
                } else {
                    delay(10)
                    val isEmpty = synchronized(audioQueue) { audioQueue.isEmpty() }
                    if (isEmpty) {
                        delay(100)
                        val stillEmpty = synchronized(audioQueue) { audioQueue.isEmpty() }
                        if (stillEmpty) {
                            _isSpeaking.value = false
                            break
                        }
                    }
                }
            }
        }
    }

    private fun stopAudioPlayback() {
        audioPlaybackJob?.cancel()
        synchronized(audioQueue) {
            audioQueue.clear()
        }
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        _isSpeaking.value = false
        audioChunkCount = 0
        hasStartedPlaying = false
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
