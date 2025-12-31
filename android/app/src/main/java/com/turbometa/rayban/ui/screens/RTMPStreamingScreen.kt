package com.turbometa.rayban.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.turbometa.rayban.R
import com.turbometa.rayban.ui.theme.AppRadius
import com.turbometa.rayban.ui.theme.AppSpacing
import com.turbometa.rayban.viewmodels.RTMPStreamingViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RTMPStreamingScreen(
    onBackClick: () -> Unit,
    viewModel: RTMPStreamingViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val rtmpUrl by viewModel.rtmpUrl.collectAsState()
    val previewFrame by viewModel.previewFrame.collectAsState()
    val streamStats by viewModel.streamStats.collectAsState()
    val cameraState by viewModel.cameraState.collectAsState()
    val bitrate by viewModel.bitrate.collectAsState()

    // UI visibility toggle
    var showUI by remember { mutableStateOf(true) }
    var showSettingsDialog by remember { mutableStateOf(false) }

    // Cleanup when leaving
    DisposableEffect(Unit) {
        onDispose {
            viewModel.stopStreaming()
        }
    }

    val isStreaming = uiState is RTMPStreamingViewModel.UIState.Streaming
    val isConnecting = uiState is RTMPStreamingViewModel.UIState.Connecting

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(Unit) {
                detectTapGestures { showUI = !showUI }
            }
    ) {
        // Video preview
        previewFrame?.let { frame ->
            Image(
                bitmap = frame.asImageBitmap(),
                contentDescription = "Stream preview",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        } ?: run {
            // Placeholder when no preview
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                if (isConnecting) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(48.dp),
                        color = Color.White
                    )
                    Spacer(modifier = Modifier.height(AppSpacing.large))
                    Text(
                        text = "Connecting...",
                        fontSize = 16.sp,
                        color = Color.White
                    )
                } else {
                    Text(
                        text = "RTMP Streaming",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Spacer(modifier = Modifier.height(AppSpacing.medium))
                    Text(
                        text = "Configure and start streaming",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                }
            }
        }

        // UI Overlay
        AnimatedVisibility(
            visible = showUI,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                // Top bar
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .statusBarsPadding()
                        .padding(AppSpacing.medium),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Back button
                    IconButton(
                        onClick = onBackClick,
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.5f))
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }

                    // Status indicator
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(AppRadius.large))
                            .background(Color.Black.copy(alpha = 0.5f))
                            .padding(horizontal = AppSpacing.medium, vertical = AppSpacing.small),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(AppSpacing.small)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(
                                    when {
                                        isStreaming -> Color.Red
                                        isConnecting -> Color.Yellow
                                        else -> Color.Gray
                                    }
                                )
                        )
                        Text(
                            text = when {
                                isStreaming -> "LIVE"
                                isConnecting -> "Connecting"
                                else -> "Ready"
                            },
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }

                    // Settings button
                    IconButton(
                        onClick = { showSettingsDialog = true },
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.5f))
                    ) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = "Settings",
                            tint = Color.White
                        )
                    }
                }

                // Stats overlay (when streaming)
                if (isStreaming) {
                    Column(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(top = 80.dp, end = AppSpacing.medium)
                            .clip(RoundedCornerShape(AppRadius.medium))
                            .background(Color.Black.copy(alpha = 0.6f))
                            .padding(AppSpacing.small)
                    ) {
                        Text(
                            text = "FPS: %.1f".format(streamStats.fps),
                            fontSize = 12.sp,
                            color = Color.White
                        )
                        Text(
                            text = "Frames: ${streamStats.framesSent}",
                            fontSize = 12.sp,
                            color = Color.White
                        )
                        Text(
                            text = "Bitrate: ${streamStats.bitrate / 1000} kbps",
                            fontSize = 12.sp,
                            color = Color.White
                        )
                    }
                }

                // Error message
                (uiState as? RTMPStreamingViewModel.UIState.Error)?.let { error ->
                    Card(
                        modifier = Modifier
                            .align(Alignment.Center)
                            .padding(AppSpacing.large),
                        colors = CardDefaults.cardColors(
                            containerColor = Color.Red.copy(alpha = 0.8f)
                        )
                    ) {
                        Column(
                            modifier = Modifier.padding(AppSpacing.large),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Error",
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.height(AppSpacing.small))
                            Text(
                                text = error.message,
                                fontSize = 14.sp,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.height(AppSpacing.medium))
                            TextButton(
                                onClick = { viewModel.clearError() }
                            ) {
                                Text("Dismiss", color = Color.White)
                            }
                        }
                    }
                }

                // Bottom controls
                Column(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(AppSpacing.large)
                        .navigationBarsPadding()
                        .fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // RTMP URL display (truncated)
                    Text(
                        text = rtmpUrl.take(50) + if (rtmpUrl.length > 50) "..." else "",
                        fontSize = 12.sp,
                        color = Color.White.copy(alpha = 0.7f),
                        maxLines = 1
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.medium))

                    // Start/Stop button
                    Button(
                        onClick = {
                            if (isStreaming || isConnecting) {
                                viewModel.stopStreaming()
                            } else {
                                viewModel.startStreaming()
                            }
                        },
                        modifier = Modifier
                            .size(72.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isStreaming) Color.Red else Color.White
                        ),
                        enabled = uiState !is RTMPStreamingViewModel.UIState.Error
                    ) {
                        Icon(
                            imageVector = if (isStreaming || isConnecting)
                                Icons.Default.Stop
                            else
                                Icons.Default.PlayArrow,
                            contentDescription = if (isStreaming) "Stop" else "Start",
                            modifier = Modifier.size(32.dp),
                            tint = if (isStreaming) Color.White else Color.Black
                        )
                    }
                }
            }
        }
    }

    // Settings Dialog
    if (showSettingsDialog) {
        RTMPSettingsDialog(
            currentUrl = rtmpUrl,
            currentBitrate = bitrate,
            onUrlChange = { viewModel.updateRtmpUrl(it) },
            onBitrateChange = { viewModel.updateBitrate(it) },
            onDismiss = { showSettingsDialog = false }
        )
    }
}

@Composable
private fun RTMPSettingsDialog(
    currentUrl: String,
    currentBitrate: Int,
    onUrlChange: (String) -> Unit,
    onBitrateChange: (Int) -> Unit,
    onDismiss: () -> Unit
) {
    var urlText by remember { mutableStateOf(currentUrl) }
    var selectedBitrate by remember { mutableStateOf(currentBitrate) }

    val bitrateOptions = listOf(
        500_000 to "500 kbps (Low)",
        1_000_000 to "1 Mbps",
        2_000_000 to "2 Mbps (Recommended)",
        4_000_000 to "4 Mbps (High)",
        6_000_000 to "6 Mbps (Very High)"
    )

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("RTMP Settings")
        },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(AppSpacing.medium)
            ) {
                // RTMP URL
                OutlinedTextField(
                    value = urlText,
                    onValueChange = { urlText = it },
                    label = { Text("RTMP URL") },
                    placeholder = { Text("rtmp://server.com/live/key") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri)
                )

                // Bitrate selection
                Text(
                    text = "Bitrate",
                    style = MaterialTheme.typography.labelMedium
                )

                Column {
                    bitrateOptions.forEach { (bitrate, label) ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .selectable(
                                    selected = selectedBitrate == bitrate,
                                    onClick = { selectedBitrate = bitrate },
                                    role = Role.RadioButton
                                )
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = selectedBitrate == bitrate,
                                onClick = null
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(label)
                        }
                    }
                }

                // Info text
                Text(
                    text = "Note: Higher bitrate = better quality but requires more bandwidth",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    onUrlChange(urlText)
                    onBitrateChange(selectedBitrate)
                    onDismiss()
                }
            ) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
