package com.turbometa.rayban.ui.screens

import android.graphics.Bitmap
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.turbometa.rayban.R
import com.turbometa.rayban.managers.APIProviderManager
import com.turbometa.rayban.services.VisionAPIService
import com.turbometa.rayban.ui.theme.*
import com.turbometa.rayban.utils.APIKeyManager
import com.turbometa.rayban.viewmodels.WearablesViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale

private const val TAG = "QuickVisionScreen"

/**
 * Quick Vision Screen - 1:1 port from iOS QuickVisionView
 *
 * Flow:
 * 1. Auto-starts stream on entry
 * 2. Waits for stream to be ready
 * 3. Captures photo
 * 4. Stops stream
 * 5. Analyzes with Vision API
 * 6. Speaks result with TTS
 * 7. Shows result on screen
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickVisionScreen(
    wearablesViewModel: WearablesViewModel,
    onBackClick: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    // State
    val streamState by wearablesViewModel.streamState.collectAsState()
    val currentFrame by wearablesViewModel.currentFrame.collectAsState()
    val capturedPhoto by wearablesViewModel.capturedPhoto.collectAsState()
    val hasActiveDevice by wearablesViewModel.hasActiveDevice.collectAsState()

    // Quick Vision state
    var isProcessing by remember { mutableStateOf(false) }
    var analysisResult by remember { mutableStateOf<String?>(null) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var statusText by remember { mutableStateOf("") }
    var photoForAnalysis by remember { mutableStateOf<Bitmap?>(null) }

    // TTS
    var tts by remember { mutableStateOf<TextToSpeech?>(null) }
    var isTtsReady by remember { mutableStateOf(false) }
    var isSpeaking by remember { mutableStateOf(false) }

    // Services
    val apiKeyManager = remember { APIKeyManager.getInstance(context) }
    val providerManager = remember { APIProviderManager.getInstance(context) }
    val visionService = remember { VisionAPIService(apiKeyManager, providerManager) }

    // Output language for TTS/API (user's preference for AI responses)
    val outputLanguage = remember { apiKeyManager.getOutputLanguage() }

    // UI strings from resources (follows app language)
    val lookingText = stringResource(R.string.vision_analyzing)
    val noDeviceText = stringResource(R.string.glasses_not_connected)
    val streamFailedText = stringResource(R.string.stream_failed)
    val captureFailedText = stringResource(R.string.capture_failed)
    val analysisFailedText = stringResource(R.string.analysis_failed)
    val stopSpeakingText = stringResource(R.string.liveai_stop)
    val jarvisTipText = stringResource(R.string.picovoice_description)

    // Initialize TTS
    DisposableEffect(Unit) {
        val textToSpeech = TextToSpeech(context) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val locale = when (outputLanguage) {
                    "zh-CN" -> Locale.CHINESE
                    "en-US" -> Locale.US
                    "ja-JP" -> Locale.JAPANESE
                    "ko-KR" -> Locale.KOREAN
                    else -> Locale.US
                }
                tts?.setLanguage(locale)
                tts?.setSpeechRate(1.1f)
                isTtsReady = true
                Log.d(TAG, "TTS initialized with locale: $locale")
            }
        }
        tts = textToSpeech

        onDispose {
            textToSpeech.stop()
            textToSpeech.shutdown()
        }
    }

    // Speak function
    fun speak(text: String) {
        if (!isTtsReady || text.isBlank()) return

        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                isSpeaking = true
            }
            override fun onDone(utteranceId: String?) {
                isSpeaking = false
            }
            override fun onError(utteranceId: String?) {
                isSpeaking = false
            }
        })

        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "quick_vision_${System.currentTimeMillis()}")
    }

    fun stopSpeaking() {
        tts?.stop()
        isSpeaking = false
    }

    // Perform Quick Vision - main flow
    suspend fun performQuickVision() {
        if (isProcessing) {
            Log.d(TAG, "Already processing, skip")
            return
        }

        isProcessing = true
        errorMessage = null
        analysisResult = null
        photoForAnalysis = null

        Log.d(TAG, "🚀 Starting Quick Vision")

        // Step 0: Check device
        if (!hasActiveDevice) {
            Log.e(TAG, "❌ No active device")
            errorMessage = noDeviceText
            speak(noDeviceText)
            isProcessing = false
            return
        }

        // Step 1: Speak "Analyzing"
        statusText = lookingText
        speak(lookingText)

        // Step 2: Start stream if not already streaming
        if (streamState !is WearablesViewModel.StreamState.Streaming) {
            Log.d(TAG, "📹 Starting stream...")
            wearablesViewModel.startStream()

            // Wait for stream to be ready (max 5 seconds)
            var streamWait = 0
            while (streamState !is WearablesViewModel.StreamState.Streaming && streamWait < 50) {
                delay(100)
                streamWait++
            }

            if (streamState !is WearablesViewModel.StreamState.Streaming) {
                Log.e(TAG, "❌ Failed to start stream")
                errorMessage = streamFailedText
                speak(streamFailedText)
                isProcessing = false
                return
            }
        }

        // Step 3: Wait for stream to stabilize
        Log.d(TAG, "⏳ Waiting for stream to stabilize...")
        delay(500)

        // Step 4: Clear previous photo and capture new one
        Log.d(TAG, "📸 Capturing photo...")
        wearablesViewModel.clearCapturedPhoto()
        wearablesViewModel.takePhoto()

        // Wait for photo (max 3 seconds)
        var photoWait = 0
        while (capturedPhoto == null && photoWait < 30) {
            delay(100)
            photoWait++
        }

        // Use captured photo or fallback to current frame
        val photo = capturedPhoto ?: currentFrame
        if (photo == null) {
            Log.e(TAG, "❌ No photo available")
            errorMessage = captureFailedText
            speak(captureFailedText)
            wearablesViewModel.stopStream()
            isProcessing = false
            return
        }

        photoForAnalysis = photo
        Log.d(TAG, "📸 Photo captured: ${photo.width}x${photo.height}")

        // Step 5: Stop stream immediately after capture
        Log.d(TAG, "🛑 Stopping stream...")
        wearablesViewModel.stopStream()

        // Step 6: Analyze with Vision API
        statusText = lookingText
        Log.d(TAG, "🔍 Analyzing image...")

        val result = visionService.quickVision(photo, outputLanguage)

        result.fold(
            onSuccess = { description ->
                Log.d(TAG, "✅ Analysis result: $description")
                analysisResult = description
                statusText = ""

                // Speak result
                speak(description)
            },
            onFailure = { error ->
                Log.e(TAG, "❌ Analysis failed: ${error.message}")
                errorMessage = analysisFailedText + ": " + (error.message ?: "")
                speak(analysisFailedText)
            }
        )

        isProcessing = false
    }

    // Trigger Quick Vision manually
    fun triggerQuickVision() {
        scope.launch {
            performQuickVision()
        }
    }

    // Auto-start on enter
    LaunchedEffect(hasActiveDevice) {
        if (hasActiveDevice) {
            // Wait a moment for device to be fully ready
            delay(500)
            performQuickVision()
        }
    }

    // Cleanup on exit
    DisposableEffect(Unit) {
        onDispose {
            Log.d(TAG, "🔴 Disposing QuickVisionScreen")
            stopSpeaking()
            wearablesViewModel.stopStream()
            wearablesViewModel.clearCapturedPhoto()
        }
    }

    // UI
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.feature_quickvision_title),
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = {
                        stopSpeaking()
                        wearablesViewModel.stopStream()
                        onBackClick()
                    }) {
                        Icon(
                            Icons.Default.Close,
                            contentDescription = "Close",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(AppSpacing.medium)
        ) {
            // Video Preview Section
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(350.dp)
                    .clip(RoundedCornerShape(AppRadius.large))
                    .background(Color.Gray.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                // Show captured photo first, then current frame
                when {
                    photoForAnalysis != null -> {
                        Image(
                            bitmap = photoForAnalysis!!.asImageBitmap(),
                            contentDescription = "Captured photo",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Fit
                        )
                    }
                    capturedPhoto != null -> {
                        Image(
                            bitmap = capturedPhoto!!.asImageBitmap(),
                            contentDescription = "Captured photo",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Fit
                        )
                    }
                    currentFrame != null -> {
                        Image(
                            bitmap = currentFrame!!.asImageBitmap(),
                            contentDescription = "Live stream",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Fit
                        )
                    }
                    !hasActiveDevice -> {
                        // Device not connected
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.SignalWifiOff,
                                contentDescription = null,
                                modifier = Modifier.size(50.dp),
                                tint = Warning
                            )
                            Spacer(modifier = Modifier.height(AppSpacing.medium))
                            Text(
                                text = stringResource(R.string.not_connected),
                                style = MaterialTheme.typography.titleMedium,
                                color = Color.White
                            )
                            Text(
                                text = noDeviceText,
                                style = MaterialTheme.typography.bodySmall,
                                color = Color.White.copy(alpha = 0.7f)
                            )
                        }
                    }
                    isProcessing -> {
                        // Processing indicator
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(48.dp),
                                color = Color.White,
                                strokeWidth = 3.dp
                            )
                            Spacer(modifier = Modifier.height(AppSpacing.medium))
                            Text(
                                text = statusText,
                                color = Color.White.copy(alpha = 0.8f)
                            )
                        }
                    }
                    else -> {
                        // Ready state
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Visibility,
                                contentDescription = null,
                                modifier = Modifier.size(50.dp),
                                tint = QuickVisionColor.copy(alpha = 0.7f)
                            )
                            Spacer(modifier = Modifier.height(AppSpacing.medium))
                            Text(
                                text = stringResource(R.string.feature_quickvision_title),
                                color = Color.White.copy(alpha = 0.8f)
                            )
                        }
                    }
                }

                // Processing overlay
                if (isProcessing && (photoForAnalysis != null || capturedPhoto != null || currentFrame != null)) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black.copy(alpha = 0.6f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(48.dp),
                                color = Color.White,
                                strokeWidth = 3.dp
                            )
                            Spacer(modifier = Modifier.height(AppSpacing.medium))
                            Text(
                                text = statusText,
                                style = MaterialTheme.typography.titleMedium,
                                color = Color.White
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(AppSpacing.large))

            // Status Section - Result or Error
            if (analysisResult != null) {
                // Result card
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(AppRadius.large),
                    colors = CardDefaults.cardColors(
                        containerColor = Color.White.copy(alpha = 0.1f)
                    )
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(AppSpacing.medium)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = null,
                                tint = Success,
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(AppSpacing.small))
                            Text(
                                text = stringResource(R.string.analysis_result),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.weight(1f))

                            // Replay button
                            IconButton(
                                onClick = { speak(analysisResult!!) }
                            ) {
                                Icon(
                                    imageVector = if (isSpeaking) Icons.Default.VolumeUp else Icons.Default.VolumeDown,
                                    contentDescription = "Replay",
                                    tint = Color.White
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(AppSpacing.medium))

                        Text(
                            text = analysisResult!!,
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.White.copy(alpha = 0.9f),
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    Color.White.copy(alpha = 0.1f),
                                    RoundedCornerShape(AppRadius.medium)
                                )
                                .padding(AppSpacing.medium)
                        )
                    }
                }
            }

            // Error message
            if (errorMessage != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(AppRadius.medium),
                    colors = CardDefaults.cardColors(
                        containerColor = Warning.copy(alpha = 0.1f)
                    )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(AppSpacing.medium),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = null,
                            tint = Warning
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Text(
                            text = errorMessage!!,
                            style = MaterialTheme.typography.bodySmall,
                            color = Warning
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(AppSpacing.large))

            // Action Buttons
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(AppSpacing.medium)
            ) {
                // Main button - Quick Vision
                Button(
                    onClick = { triggerQuickVision() },
                    enabled = !isProcessing && hasActiveDevice,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(AppRadius.large),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (!isProcessing && hasActiveDevice) QuickVisionColor else Color.Gray,
                        disabledContainerColor = Color.Gray
                    )
                ) {
                    if (isProcessing) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(24.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                    } else {
                        Icon(
                            imageVector = Icons.Default.Visibility,
                            contentDescription = null
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                    }
                    Text(
                        text = when {
                            isProcessing -> statusText
                            !hasActiveDevice -> stringResource(R.string.not_connected)
                            else -> stringResource(R.string.feature_quickvision_title)
                        },
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                // Stop speaking button
                if (isSpeaking) {
                    OutlinedButton(
                        onClick = { stopSpeaking() },
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(AppRadius.medium),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Error
                        )
                    ) {
                        Icon(
                            imageVector = Icons.Default.Stop,
                            contentDescription = null
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Text(text = stopSpeakingText)
                    }
                }
            }

            Spacer(modifier = Modifier.height(AppSpacing.extraLarge))

            // Jarvis tip
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(AppRadius.medium),
                colors = CardDefaults.cardColors(
                    containerColor = Color.White.copy(alpha = 0.05f)
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(AppSpacing.medium),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = null,
                        tint = QuickVisionColor,
                        modifier = Modifier.size(20.dp)
                    )
                    Spacer(modifier = Modifier.width(AppSpacing.small))
                    Text(
                        text = jarvisTipText,
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}
