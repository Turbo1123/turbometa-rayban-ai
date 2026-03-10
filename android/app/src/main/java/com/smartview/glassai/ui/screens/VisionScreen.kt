package com.smartview.glassai.ui.screens

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.smartview.glassai.R
import com.smartview.glassai.ui.components.*
import com.smartview.glassai.ui.theme.*
import com.smartview.glassai.viewmodels.VisionViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VisionScreen(
    viewModel: VisionViewModel = viewModel(),
    currentFrame: Bitmap? = null,
    onBackClick: () -> Unit,
    onTakePhoto: () -> Unit
) {
    val viewState by viewModel.viewState.collectAsState()
    val capturedImage by viewModel.capturedImage.collectAsState()
    val analysisResult by viewModel.analysisResult.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val customPrompt by viewModel.customPrompt.collectAsState()

    // Update captured image when frame is available
    LaunchedEffect(currentFrame) {
        currentFrame?.let { viewModel.setCapturedImage(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.vision_recognition),
                        fontWeight = FontWeight.SemiBold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Primary.copy(alpha = 0.1f)
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(MaterialTheme.colorScheme.background)
        ) {
            // Error message
            errorMessage?.let { error ->
                ErrorMessage(
                    message = error,
                    onDismiss = { viewModel.clearError() },
                    modifier = Modifier.padding(AppSpacing.medium)
                )
            }

            when (viewState) {
                is VisionViewModel.ViewState.Idle -> {
                    VisionIdleContent(onTakePhoto = onTakePhoto)
                }
                is VisionViewModel.ViewState.Capturing -> {
                    VisionCapturedContent(
                        image = capturedImage,
                        customPrompt = customPrompt,
                        onPromptChange = { viewModel.setCustomPrompt(it) },
                        defaultPrompts = viewModel.getDefaultPrompts(),
                        onAnalyze = { viewModel.analyzeImage() },
                        onRetake = { viewModel.retakePhoto() }
                    )
                }
                is VisionViewModel.ViewState.Analyzing -> {
                    VisionAnalyzingContent(image = capturedImage)
                }
                is VisionViewModel.ViewState.Result -> {
                    VisionResultContent(
                        image = capturedImage,
                        result = analysisResult ?: "",
                        onSave = { viewModel.saveImageToGallery() },
                        onRetake = { viewModel.retakePhoto() },
                        onReanalyze = { viewModel.analyzeImage() }
                    )
                }
                is VisionViewModel.ViewState.Error -> {
                    VisionErrorContent(
                        message = (viewState as VisionViewModel.ViewState.Error).message,
                        onRetry = { viewModel.analyzeImage() },
                        onRetake = { viewModel.retakePhoto() }
                    )
                }
            }
        }
    }
}

@Composable
private fun VisionIdleContent(onTakePhoto: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(AppSpacing.large),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Visibility,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = Primary.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(AppSpacing.large))
        Text(
            text = stringResource(R.string.capture_to_analyze),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(modifier = Modifier.height(AppSpacing.small))
        Text(
            text = stringResource(R.string.capture_to_analyze_desc),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(AppSpacing.extraLarge))
        GradientButton(
            text = stringResource(R.string.take_photo),
            onClick = onTakePhoto,
            gradientColors = listOf(Primary, PrimaryLight)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VisionCapturedContent(
    image: Bitmap?,
    customPrompt: String,
    onPromptChange: (String) -> Unit,
    defaultPrompts: List<String>,
    onAnalyze: () -> Unit,
    onRetake: () -> Unit
) {
    var showPromptMenu by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(AppSpacing.medium)
    ) {
        // Image preview
        image?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Captured image",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(250.dp)
                    .clip(RoundedCornerShape(AppRadius.large)),
                contentScale = ContentScale.Crop
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Prompt input
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(AppRadius.medium)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(AppSpacing.medium)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = stringResource(R.string.analysis_prompt),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )

                    Box {
                        IconButton(onClick = { showPromptMenu = true }) {
                            Icon(
                                imageVector = Icons.Default.MoreVert,
                                contentDescription = "Prompt options"
                            )
                        }
                        DropdownMenu(
                            expanded = showPromptMenu,
                            onDismissRequest = { showPromptMenu = false }
                        ) {
                            defaultPrompts.forEach { prompt ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            text = prompt.take(30) + if (prompt.length > 30) "..." else "",
                                            style = MaterialTheme.typography.bodyMedium
                                        )
                                    },
                                    onClick = {
                                        onPromptChange(prompt)
                                        showPromptMenu = false
                                    }
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(AppSpacing.small))

                OutlinedTextField(
                    value = customPrompt,
                    onValueChange = onPromptChange,
                    modifier = Modifier.fillMaxWidth(),
                    placeholder = { Text(stringResource(R.string.enter_prompt)) },
                    minLines = 3,
                    maxLines = 5
                )
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.large))

        // Action buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.medium)
        ) {
            OutlinedButton(
                onClick = onRetake,
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Refresh, contentDescription = null)
                Spacer(modifier = Modifier.width(AppSpacing.small))
                Text(stringResource(R.string.retake))
            }

            Button(
                onClick = onAnalyze,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = Primary)
            ) {
                Icon(Icons.Default.Search, contentDescription = null)
                Spacer(modifier = Modifier.width(AppSpacing.small))
                Text(stringResource(R.string.analyze))
            }
        }
    }
}

@Composable
private fun VisionAnalyzingContent(image: Bitmap?) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(AppSpacing.medium),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Image preview
        image?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Analyzing image",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(250.dp)
                    .clip(RoundedCornerShape(AppRadius.large)),
                contentScale = ContentScale.Crop
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.extraLarge))

        LoadingIndicator(message = stringResource(R.string.analyzing_image))
    }
}

@Composable
private fun VisionResultContent(
    image: Bitmap?,
    result: String,
    onSave: () -> Unit,
    onRetake: () -> Unit,
    onReanalyze: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(AppSpacing.medium)
    ) {
        // Image preview (smaller)
        image?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Analyzed image",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(AppRadius.large)),
                contentScale = ContentScale.Crop
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Analysis Result
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(AppRadius.large)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(AppSpacing.large)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Description,
                        contentDescription = null,
                        tint = Primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(AppSpacing.small))
                    Text(
                        text = stringResource(R.string.analysis_result),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Spacer(modifier = Modifier.height(AppSpacing.medium))

                Text(
                    text = result,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.9f)
                )
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.large))

        // Action buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.small)
        ) {
            OutlinedButton(
                onClick = onSave,
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Save, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(stringResource(R.string.save))
            }

            OutlinedButton(
                onClick = onReanalyze,
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(stringResource(R.string.reanalyze))
            }

            Button(
                onClick = onRetake,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = Primary)
            ) {
                Icon(Icons.Default.CameraAlt, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(stringResource(R.string.new_photo))
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.large))
    }
}

@Composable
private fun VisionErrorContent(
    message: String,
    onRetry: () -> Unit,
    onRetake: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(AppSpacing.large),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Error,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = Error
        )
        Spacer(modifier = Modifier.height(AppSpacing.medium))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyLarge,
            color = Error
        )
        Spacer(modifier = Modifier.height(AppSpacing.large))
        Row(horizontalArrangement = Arrangement.spacedBy(AppSpacing.medium)) {
            OutlinedButton(onClick = onRetake) {
                Text(stringResource(R.string.retake))
            }
            Button(
                onClick = onRetry,
                colors = ButtonDefaults.buttonColors(containerColor = Primary)
            ) {
                Text(stringResource(R.string.retry))
            }
        }
    }
}
