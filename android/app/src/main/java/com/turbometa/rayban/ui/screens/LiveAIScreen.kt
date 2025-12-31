package com.turbometa.rayban.ui.screens

import android.graphics.Bitmap
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.turbometa.rayban.R
import com.turbometa.rayban.models.ConversationMessage
import com.turbometa.rayban.models.MessageRole
import com.turbometa.rayban.ui.components.*
import com.turbometa.rayban.ui.theme.*
import com.turbometa.rayban.viewmodels.OmniRealtimeViewModel
import com.turbometa.rayban.viewmodels.WearablesViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveAIScreen(
    viewModel: OmniRealtimeViewModel = viewModel(),
    wearablesViewModel: WearablesViewModel,
    onRequestWearablesPermission: suspend (Permission) -> PermissionStatus,
    onBackClick: () -> Unit
) {
    val viewState by viewModel.viewState.collectAsState()
    val messages by viewModel.messages.collectAsState()
    val currentTranscript by viewModel.currentTranscript.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isConnected by viewModel.isConnected.collectAsState()
    val isRecording by viewModel.isRecording.collectAsState()
    val isSpeaking by viewModel.isSpeaking.collectAsState()

    // Wearables state
    val currentFrame by wearablesViewModel.currentFrame.collectAsState()
    val streamState by wearablesViewModel.streamState.collectAsState()
    val hasActiveDevice by wearablesViewModel.hasActiveDevice.collectAsState()

    val listState = rememberLazyListState()

    // Connect to AI and start stream when entering LiveAI
    // Note: Device connection is already verified before navigating here
    LaunchedEffect(Unit) {
        // Start video stream first
        wearablesViewModel.startStream()
        // Then connect to AI
        if (!viewModel.isConnected.value) {
            viewModel.connect()
        }
    }

    // Auto-start recording after AI connection (like iOS)
    LaunchedEffect(isConnected) {
        if (isConnected && !isRecording) {
            viewModel.startRecording()
        }
    }

    // Send video frame to AI (like iOS)
    LaunchedEffect(currentFrame) {
        currentFrame?.let { frame ->
            viewModel.updateVideoFrame(frame)
        }
    }

    // Cleanup when leaving - CRITICAL: must stop stream
    DisposableEffect(Unit) {
        onDispose {
            // Stop stream first
            wearablesViewModel.stopStream()
            // Then disconnect AI
            viewModel.disconnect()
        }
    }

    // Auto-scroll to bottom when new messages arrive
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(messages.size - 1)
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Video stream background (like iOS)
        currentFrame?.let { frame ->
            Image(
                bitmap = frame.asImageBitmap(),
                contentDescription = "Camera stream",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
            // Dark overlay for better text readability
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.4f))
            )
        } ?: run {
            // Placeholder when no stream
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                LiveAIColor.copy(alpha = 0.3f),
                                Color.Black
                            )
                        )
                    )
            )
        }

        // Main content overlay
        Scaffold(
            containerColor = Color.Transparent,
            topBar = {
                TopAppBar(
                    title = {
                        Column {
                            Text(
                                text = stringResource(R.string.live_ai),
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )
                            Text(
                                text = getStatusText(viewState, streamState),
                                fontSize = 12.sp,
                                color = getStatusColor(viewState).copy(alpha = 0.9f)
                            )
                        }
                    },
                    navigationIcon = {
                        IconButton(onClick = onBackClick) {
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                tint = Color.White
                            )
                        }
                    },
                    actions = {
                        // Stream status indicator
                        if (streamState is WearablesViewModel.StreamState.Streaming) {
                            Icon(
                                Icons.Default.Videocam,
                                contentDescription = "Streaming",
                                tint = Success,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                        }
                        // Connection status indicator
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(if (isConnected) Success else Error)
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.medium))
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color.Transparent
                    )
                )
            }
        ) { paddingValues ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                // Error message
                errorMessage?.let { error ->
                    ErrorMessage(
                        message = error,
                        onDismiss = { viewModel.clearError() },
                        modifier = Modifier.padding(AppSpacing.medium)
                    )
                }

                // Messages list
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(horizontal = AppSpacing.medium),
                    state = listState,
                    verticalArrangement = Arrangement.spacedBy(AppSpacing.small)
                ) {
                    // Empty state (shown only when no video and no messages)
                    if (messages.isEmpty() && viewState == OmniRealtimeViewModel.ViewState.Idle && currentFrame == null) {
                        item {
                            EmptyConversationState()
                        }
                    }

                    items(messages) { message ->
                        MessageBubble(message = message)
                    }

                    // Current transcript (streaming response)
                    if (currentTranscript.isNotBlank()) {
                        item {
                            StreamingMessageBubble(text = currentTranscript)
                        }
                    }

                    // Speaking indicator
                    if (isSpeaking) {
                        item {
                            SpeakingIndicator()
                        }
                    }
                }

                // Control panel
                ControlPanel(
                    viewState = viewState,
                    isConnected = isConnected,
                    isRecording = isRecording,
                    hasActiveDevice = hasActiveDevice,
                    isStreaming = streamState is WearablesViewModel.StreamState.Streaming,
                    onConnect = { viewModel.connect() },
                    onDisconnect = { viewModel.disconnect() },
                    onStartRecording = { viewModel.startRecording() },
                    onStopRecording = { viewModel.stopRecording() }
                )
            }
        }
    }
}

@Composable
private fun EmptyConversationState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 100.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Mic,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = Primary.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(AppSpacing.medium))
        Text(
            text = stringResource(R.string.start_conversation),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(AppSpacing.small))
        Text(
            text = stringResource(R.string.tap_connect_to_start),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun MessageBubble(message: ConversationMessage) {
    val isUser = message.role == MessageRole.USER
    val backgroundColor = if (isUser) {
        Primary
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val textColor = if (isUser) {
        Color.White
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .clip(
                    RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isUser) 16.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 16.dp
                    )
                )
                .background(backgroundColor)
                .padding(AppSpacing.medium)
        ) {
            Text(
                text = message.content,
                color = textColor,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
private fun StreamingMessageBubble(text: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .clip(RoundedCornerShape(16.dp, 16.dp, 16.dp, 4.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .border(
                    width = 1.dp,
                    color = Primary.copy(alpha = 0.3f),
                    shape = RoundedCornerShape(16.dp, 16.dp, 16.dp, 4.dp)
                )
                .padding(AppSpacing.medium)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = text,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.weight(1f, fill = false)
                )
                // Blinking cursor
                val infiniteTransition = rememberInfiniteTransition(label = "cursor")
                val alpha by infiniteTransition.animateFloat(
                    initialValue = 1f,
                    targetValue = 0f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(500),
                        repeatMode = RepeatMode.Reverse
                    ),
                    label = "cursorAlpha"
                )
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(16.dp)
                        .background(Primary.copy(alpha = alpha))
                )
            }
        }
    }
}

@Composable
private fun SpeakingIndicator() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = AppSpacing.small),
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Animated speaking indicator
        val infiniteTransition = rememberInfiniteTransition(label = "speaking")
        repeat(3) { index ->
            val delay = index * 100
            val scale by infiniteTransition.animateFloat(
                initialValue = 0.5f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(300, delayMillis = delay),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "dot$index"
            )
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .scale(scale)
                    .clip(CircleShape)
                    .background(Primary)
            )
            if (index < 2) {
                Spacer(modifier = Modifier.width(4.dp))
            }
        }
        Spacer(modifier = Modifier.width(AppSpacing.small))
        Text(
            text = stringResource(R.string.ai_speaking),
            style = MaterialTheme.typography.bodySmall,
            color = Primary
        )
    }
}

@Composable
private fun ControlPanel(
    viewState: OmniRealtimeViewModel.ViewState,
    isConnected: Boolean,
    isRecording: Boolean,
    hasActiveDevice: Boolean,
    isStreaming: Boolean,
    onConnect: () -> Unit,
    onDisconnect: () -> Unit,
    onStartRecording: () -> Unit,
    onStopRecording: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shadowElevation = 8.dp,
        color = Color.Black.copy(alpha = 0.7f)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(AppSpacing.large),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (!isConnected) {
                // Connect button
                GradientButton(
                    text = stringResource(R.string.connect_to_ai),
                    onClick = onConnect,
                    gradientColors = listOf(LiveAIColor, LiveAIColorLight),
                    modifier = Modifier.fillMaxWidth()
                )
            } else {
                // Recording controls
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Disconnect button
                    OutlinedButton(
                        onClick = onDisconnect,
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Error
                        )
                    ) {
                        Icon(Icons.Default.Close, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(stringResource(R.string.end))
                    }

                    // Main recording button
                    RecordButton(
                        isRecording = isRecording,
                        viewState = viewState,
                        onStartRecording = onStartRecording,
                        onStopRecording = onStopRecording
                    )

                    // Stream status
                    Column(
                        modifier = Modifier.width(80.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Icon(
                            imageVector = if (isStreaming) Icons.Default.Videocam else Icons.Default.VideocamOff,
                            contentDescription = null,
                            tint = if (isStreaming) Success else Color.White.copy(alpha = 0.5f),
                            modifier = Modifier.size(24.dp)
                        )
                        Text(
                            text = stringResource(if (isStreaming) R.string.stream_live else R.string.stream_no_video),
                            style = MaterialTheme.typography.labelSmall,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                }
            }

            // Status text
            Spacer(modifier = Modifier.height(AppSpacing.small))
            Text(
                text = getInstructionText(viewState, isConnected, isRecording, hasActiveDevice),
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.8f),
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun RecordButton(
    isRecording: Boolean,
    viewState: OmniRealtimeViewModel.ViewState,
    onStartRecording: () -> Unit,
    onStopRecording: () -> Unit
) {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (isRecording) 1.1f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500),
            repeatMode = RepeatMode.Reverse
        ),
        label = "buttonScale"
    )

    val isProcessing = viewState == OmniRealtimeViewModel.ViewState.Processing ||
            viewState == OmniRealtimeViewModel.ViewState.Connecting

    FloatingActionButton(
        onClick = {
            if (isRecording) onStopRecording() else onStartRecording()
        },
        modifier = Modifier
            .size(72.dp)
            .scale(scale),
        containerColor = if (isRecording) Error else Primary,
        contentColor = Color.White,
        shape = CircleShape
    ) {
        if (isProcessing) {
            CircularProgressIndicator(
                modifier = Modifier.size(32.dp),
                color = Color.White,
                strokeWidth = 3.dp
            )
        } else {
            Icon(
                imageVector = if (isRecording) Icons.Default.Stop else Icons.Default.Mic,
                contentDescription = if (isRecording) "Stop" else "Record",
                modifier = Modifier.size(32.dp)
            )
        }
    }
}

@Composable
private fun getStatusText(
    state: OmniRealtimeViewModel.ViewState,
    streamState: WearablesViewModel.StreamState
): String {
    val streamText = when (streamState) {
        is WearablesViewModel.StreamState.Streaming -> "📹"
        is WearablesViewModel.StreamState.Waiting -> "⏳"
        else -> ""
    }
    val aiText = when (state) {
        is OmniRealtimeViewModel.ViewState.Idle -> stringResource(R.string.not_connected)
        is OmniRealtimeViewModel.ViewState.Connecting -> stringResource(R.string.connecting)
        is OmniRealtimeViewModel.ViewState.Connected -> stringResource(R.string.ready)
        is OmniRealtimeViewModel.ViewState.Recording -> stringResource(R.string.listening)
        is OmniRealtimeViewModel.ViewState.Processing -> stringResource(R.string.processing)
        is OmniRealtimeViewModel.ViewState.Speaking -> stringResource(R.string.speaking)
        is OmniRealtimeViewModel.ViewState.Error -> stringResource(R.string.error)
    }
    return if (streamText.isNotEmpty()) "$streamText $aiText" else aiText
}

@Composable
private fun getStatusColor(state: OmniRealtimeViewModel.ViewState): Color {
    return when (state) {
        is OmniRealtimeViewModel.ViewState.Connected,
        is OmniRealtimeViewModel.ViewState.Speaking -> Success
        is OmniRealtimeViewModel.ViewState.Recording -> Primary
        is OmniRealtimeViewModel.ViewState.Processing -> Warning
        is OmniRealtimeViewModel.ViewState.Error -> Error
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
    }
}

@Composable
private fun getInstructionText(
    state: OmniRealtimeViewModel.ViewState,
    isConnected: Boolean,
    isRecording: Boolean,
    hasActiveDevice: Boolean
): String {
    return when {
        !hasActiveDevice -> stringResource(R.string.please_connect_glasses)
        !isConnected -> stringResource(R.string.tap_connect_to_start)
        isRecording -> stringResource(R.string.speak_now)
        state == OmniRealtimeViewModel.ViewState.Processing -> stringResource(R.string.processing_response)
        state == OmniRealtimeViewModel.ViewState.Speaking -> stringResource(R.string.ai_speaking)
        else -> stringResource(R.string.tap_to_speak)
    }
}
