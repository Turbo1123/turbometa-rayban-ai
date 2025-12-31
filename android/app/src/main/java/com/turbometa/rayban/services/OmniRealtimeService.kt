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
import com.turbometa.rayban.managers.AlibabaEndpoint
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.*
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.TimeUnit

/**
 * Alibaba Qwen Omni Realtime Service
 * Supports multi-region endpoints (Beijing/Singapore)
 * 1:1 port from iOS OmniRealtimeService.swift
 */
class OmniRealtimeService(
    private val apiKey: String,
    private val model: String = "qwen3-omni-flash-realtime",
    private val outputLanguage: String = "zh-CN",
    private val endpoint: AlibabaEndpoint = AlibabaEndpoint.BEIJING
) {
    companion object {
        private const val TAG = "OmniRealtimeService"
        private const val WS_BEIJING_URL = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"
        private const val WS_SINGAPORE_URL = "wss://dashscope-intl.aliyuncs.com/api-ws/v1/realtime"
        private const val SAMPLE_RATE = 24000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private val websocketURL: String
        get() = when (endpoint) {
            AlibabaEndpoint.BEIJING -> WS_BEIJING_URL
            AlibabaEndpoint.SINGAPORE -> WS_SINGAPORE_URL
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

    // Internal
    private var webSocket: WebSocket? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    private var recordingJob: Job? = null
    private var audioPlaybackJob: Job? = null
    private val audioQueue = mutableListOf<ByteArray>()
    private val gson = Gson()
    private var scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var isFirstAudioSent = false
    private var pendingImageFrame: Bitmap? = null

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    fun connect() {
        if (_isConnected.value) return

        // Reset scope if it was cancelled (after previous disconnect)
        if (!scope.isActive) {
            scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
            Log.d(TAG, "Scope was cancelled, created new scope")
        }

        val url = "$websocketURL?model=$model"
        Log.d(TAG, "Connecting to endpoint: ${endpoint.displayName}")
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $apiKey")
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected")
                _isConnected.value = true
                sendSessionUpdate()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
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
            }
        })
    }

    fun disconnect() {
        stopRecording()
        stopAudioPlayback()
        webSocket?.close(1000, "User disconnected")
        webSocket = null
        _isConnected.value = false
        _isRecording.value = false
        _isSpeaking.value = false
        scope.cancel()
    }

    fun startRecording() {
        if (_isRecording.value) return

        try {
            val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
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
            isFirstAudioSent = false

            recordingJob = scope.launch {
                val buffer = ByteArray(bufferSize)
                while (isActive && _isRecording.value) {
                    val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (bytesRead > 0) {
                        sendAudioData(buffer.copyOf(bytesRead))
                    }
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Microphone permission denied")
            _errorMessage.value = "Microphone permission denied"
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}")
            _errorMessage.value = e.message
        }
    }

    fun stopRecording() {
        _isRecording.value = false
        recordingJob?.cancel()
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    fun updateVideoFrame(frame: Bitmap) {
        pendingImageFrame = frame
    }

    private fun sendSessionUpdate() {
        // Matching iOS Live AI prompts exactly
        val instructions = getLiveAIPrompt(outputLanguage)

        val sessionConfig = mapOf(
            "type" to "session.update",
            "session" to mapOf(
                "modalities" to listOf("text", "audio"),
                "voice" to "Cherry",
                "input_audio_format" to "pcm16",
                "output_audio_format" to "pcm16",  // PCM16 works better with Android AudioTrack
                "smooth_output" to true,
                "instructions" to instructions,
                "turn_detection" to mapOf(
                    "type" to "server_vad",
                    "threshold" to 0.5,
                    "silence_duration_ms" to 800
                )
            )
        )

        val json = gson.toJson(sessionConfig)
        webSocket?.send(json)
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

    private fun sendAudioData(audioData: ByteArray) {
        if (!_isConnected.value) return

        val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)
        val message = mapOf(
            "type" to "input_audio_buffer.append",
            "audio" to base64Audio
        )

        webSocket?.send(gson.toJson(message))

        // Send image on first audio if available
        if (!isFirstAudioSent && pendingImageFrame != null) {
            isFirstAudioSent = true
            sendImageFrame(pendingImageFrame!!)
        }
    }

    private fun sendImageFrame(bitmap: Bitmap) {
        try {
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 60, outputStream)
            val bytes = outputStream.toByteArray()
            val base64Image = Base64.encodeToString(bytes, Base64.NO_WRAP)

            val message = mapOf(
                "type" to "input_image_buffer.append",
                "image" to base64Image
            )

            webSocket?.send(gson.toJson(message))
            Log.d(TAG, "Image frame sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending image: ${e.message}")
        }
    }

    private fun handleMessage(text: String) {
        try {
            val json = gson.fromJson(text, JsonObject::class.java)
            val type = json.get("type")?.asString ?: return

            when (type) {
                "session.created", "session.updated" -> {
                    Log.d(TAG, "Session ready")
                }
                "input_audio_buffer.speech_started" -> {
                    _isSpeaking.value = false
                    stopAudioPlayback()
                    onSpeechStarted?.invoke()
                }
                "input_audio_buffer.speech_stopped" -> {
                    onSpeechStopped?.invoke()
                }
                "response.audio_transcript.delta" -> {
                    val delta = json.get("delta")?.asString ?: ""
                    _currentTranscript.value += delta
                    onTranscriptDelta?.invoke(delta)
                }
                "response.audio_transcript.done" -> {
                    val transcript = _currentTranscript.value
                    onTranscriptDone?.invoke(transcript)
                    _currentTranscript.value = ""
                }
                "conversation.item.input_audio_transcription.completed" -> {
                    val transcript = json.get("transcript")?.asString ?: ""
                    onUserTranscript?.invoke(transcript)
                }
                "response.audio.delta" -> {
                    val audioData = json.get("delta")?.asString ?: return
                    val audioBytes = Base64.decode(audioData, Base64.DEFAULT)
                    playAudio(audioBytes)
                }
                "response.audio.done" -> {
                    _isSpeaking.value = false
                }
                "error" -> {
                    val errorMsg = json.get("error")?.asJsonObject?.get("message")?.asString
                    Log.e(TAG, "Server error: $errorMsg")
                    _errorMessage.value = errorMsg
                    onError?.invoke(errorMsg ?: "Unknown error")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message: ${e.message}")
        }
    }

    private fun playAudio(audioData: ByteArray) {
        synchronized(audioQueue) {
            audioQueue.add(audioData)
        }

        if (audioPlaybackJob?.isActive != true) {
            startAudioPlayback()
        }
    }

    private fun startAudioPlayback() {
        if (audioTrack == null) {
            val bufferSize = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

            audioTrack = AudioTrack(
                AudioManager.STREAM_MUSIC,
                SAMPLE_RATE,
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
                    // Directly write PCM16 data - no conversion needed
                    audioTrack?.write(data, 0, data.size)
                } else {
                    delay(10)
                    // Check if queue is still empty
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
    }

    private fun convertPcm24ToPcm16(pcm24Data: ByteArray): ByteArray {
        // PCM24 is 3 bytes per sample, PCM16 is 2 bytes per sample
        // We need to convert by taking the upper 16 bits of each 24-bit sample
        val sampleCount = pcm24Data.size / 3
        val pcm16Data = ByteArray(sampleCount * 2)
        val buffer = ByteBuffer.wrap(pcm24Data).order(ByteOrder.LITTLE_ENDIAN)
        val outBuffer = ByteBuffer.wrap(pcm16Data).order(ByteOrder.LITTLE_ENDIAN)

        for (i in 0 until sampleCount) {
            val sample24 = buffer.get().toInt() and 0xFF or
                    ((buffer.get().toInt() and 0xFF) shl 8) or
                    ((buffer.get().toInt() and 0xFF) shl 16)

            // Sign extend if negative
            val signedSample = if (sample24 and 0x800000 != 0) {
                sample24 or 0xFF000000.toInt()
            } else {
                sample24
            }

            // Take upper 16 bits
            val sample16 = (signedSample shr 8).toShort()
            outBuffer.putShort(sample16)
        }

        return pcm16Data
    }

    fun clearError() {
        _errorMessage.value = null
    }
}
