package com.smartview.glassai.ui.screens

import android.graphics.Bitmap
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.smartview.glassai.ui.theme.AppRadius
import com.smartview.glassai.ui.theme.AppSpacing
import com.smartview.glassai.viewmodels.WearablesViewModel

@Composable
fun SimpleLiveStreamScreen(
    wearablesViewModel: WearablesViewModel,
    onBackClick: () -> Unit
) {
    val currentFrame by wearablesViewModel.currentFrame.collectAsState()
    val streamState by wearablesViewModel.streamState.collectAsState()
    val hasActiveDevice by wearablesViewModel.hasActiveDevice.collectAsState()

    // UI visibility toggle
    var showUI by remember { mutableStateOf(true) }

    // Start stream when entering
    // Note: Device connection is already verified before navigating here
    LaunchedEffect(Unit) {
        wearablesViewModel.startStream()
    }

    // Cleanup when leaving
    DisposableEffect(Unit) {
        onDispose {
            wearablesViewModel.stopStream()
        }
    }

    val isStreaming = streamState is WearablesViewModel.StreamState.Streaming

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = { showUI = !showUI }
            )
    ) {
        // Video feed
        currentFrame?.let { frame ->
            Image(
                bitmap = frame.asImageBitmap(),
                contentDescription = "Live stream",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
        } ?: run {
            // Loading state
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                CircularProgressIndicator(
                    modifier = Modifier.size(48.dp),
                    color = Color.White
                )
                Spacer(modifier = Modifier.height(AppSpacing.large))
                Text(
                    text = "Connecting to stream...",
                    fontSize = 16.sp,
                    color = Color.White
                )
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
                    // Close button
                    IconButton(
                        onClick = onBackClick,
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.Black.copy(alpha = 0.5f))
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Close",
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
                                .background(if (isStreaming) Color.Red else Color.Gray)
                        )
                        Text(
                            text = if (isStreaming) "Live" else "Connecting",
                            fontSize = 12.sp,
                            color = Color.White
                        )
                    }
                }

                // Bottom instructions
                Column(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(AppSpacing.large)
                        .navigationBarsPadding()
                        .clip(RoundedCornerShape(AppRadius.large))
                        .background(Color.Black.copy(alpha = 0.6f))
                        .padding(AppSpacing.large),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Live Streaming Tips",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.medium))

                    Text(
                        text = "1. Open TikTok/Douyin live streaming",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.small))

                    Text(
                        text = "2. Select screen recording feature",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.small))

                    Text(
                        text = "3. Start recording this screen to go live",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}
