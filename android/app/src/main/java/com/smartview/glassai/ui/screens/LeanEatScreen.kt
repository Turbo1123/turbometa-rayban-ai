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
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.smartview.glassai.R
import com.smartview.glassai.models.FoodNutritionResponse
import com.smartview.glassai.ui.components.*
import com.smartview.glassai.ui.theme.*
import com.smartview.glassai.viewmodels.LeanEatViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeanEatScreen(
    viewModel: LeanEatViewModel = viewModel(),
    currentFrame: Bitmap? = null,
    onBackClick: () -> Unit,
    onTakePhoto: () -> Unit
) {
    val viewState by viewModel.viewState.collectAsState()
    val capturedImage by viewModel.capturedImage.collectAsState()
    val nutritionResult by viewModel.nutritionResult.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val isAnalyzing by viewModel.isAnalyzing.collectAsState()

    // Update captured image when frame is available
    LaunchedEffect(currentFrame) {
        currentFrame?.let { viewModel.setCapturedImage(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.lean_eat),
                        fontWeight = FontWeight.SemiBold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = LeanEatColor.copy(alpha = 0.1f)
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
                is LeanEatViewModel.ViewState.Idle -> {
                    IdleContent(onTakePhoto = onTakePhoto)
                }
                is LeanEatViewModel.ViewState.Capturing -> {
                    CapturedImageContent(
                        image = capturedImage,
                        onAnalyze = { viewModel.analyzeFood() },
                        onRetake = { viewModel.retakePhoto() }
                    )
                }
                is LeanEatViewModel.ViewState.Analyzing -> {
                    AnalyzingContent(image = capturedImage)
                }
                is LeanEatViewModel.ViewState.Result -> {
                    nutritionResult?.let { result ->
                        ResultContent(
                            image = capturedImage,
                            result = result,
                            onSave = { viewModel.saveImageToGallery() },
                            onRetake = { viewModel.retakePhoto() }
                        )
                    }
                }
                is LeanEatViewModel.ViewState.Error -> {
                    ErrorContent(
                        message = (viewState as LeanEatViewModel.ViewState.Error).message,
                        onRetry = { viewModel.analyzeFood() },
                        onRetake = { viewModel.retakePhoto() }
                    )
                }
            }
        }
    }
}

@Composable
private fun IdleContent(onTakePhoto: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(AppSpacing.large),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Restaurant,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = LeanEatColor.copy(alpha = 0.5f)
        )
        Spacer(modifier = Modifier.height(AppSpacing.large))
        Text(
            text = stringResource(R.string.capture_food),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(modifier = Modifier.height(AppSpacing.small))
        Text(
            text = stringResource(R.string.capture_food_desc),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(AppSpacing.extraLarge))
        GradientButton(
            text = stringResource(R.string.take_photo),
            onClick = onTakePhoto,
            gradientColors = listOf(LeanEatColor, LeanEatColorLight)
        )
    }
}

@Composable
private fun CapturedImageContent(
    image: Bitmap?,
    onAnalyze: () -> Unit,
    onRetake: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(AppSpacing.medium)
    ) {
        // Image preview
        image?.let { bitmap ->
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "Captured food",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(300.dp)
                    .clip(RoundedCornerShape(AppRadius.large)),
                contentScale = ContentScale.Crop
            )
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
                colors = ButtonDefaults.buttonColors(containerColor = LeanEatColor)
            ) {
                Icon(Icons.Default.Search, contentDescription = null)
                Spacer(modifier = Modifier.width(AppSpacing.small))
                Text(stringResource(R.string.analyze))
            }
        }
    }
}

@Composable
private fun AnalyzingContent(image: Bitmap?) {
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
                contentDescription = "Analyzing food",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(250.dp)
                    .clip(RoundedCornerShape(AppRadius.large)),
                contentScale = ContentScale.Crop
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.extraLarge))

        LoadingIndicator(message = stringResource(R.string.analyzing_nutrition))
    }
}

@Composable
private fun ResultContent(
    image: Bitmap?,
    result: FoodNutritionResponse,
    onSave: () -> Unit,
    onRetake: () -> Unit
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
                contentDescription = "Food",
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(AppRadius.large)),
                contentScale = ContentScale.Crop
            )
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Health Score
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(AppRadius.large)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(AppSpacing.large),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = stringResource(R.string.health_score),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "${result.totalCalories} kcal",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                    )
                }
                HealthScoreCircle(score = result.healthScore)
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Nutrition breakdown
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(AppRadius.large)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(AppSpacing.large)
            ) {
                Text(
                    text = stringResource(R.string.nutrition_breakdown),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )

                Spacer(modifier = Modifier.height(AppSpacing.medium))

                NutritionBar(
                    label = stringResource(R.string.protein),
                    value = result.totalProtein,
                    maxValue = 50.0,
                    color = NutritionProtein
                )

                Spacer(modifier = Modifier.height(AppSpacing.small))

                NutritionBar(
                    label = stringResource(R.string.carbs),
                    value = result.totalCarbs,
                    maxValue = 100.0,
                    color = NutritionCarbs
                )

                Spacer(modifier = Modifier.height(AppSpacing.small))

                NutritionBar(
                    label = stringResource(R.string.fat),
                    value = result.totalFat,
                    maxValue = 50.0,
                    color = NutritionFat
                )
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Food items
        if (result.foods.isNotEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(AppRadius.large)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(AppSpacing.large)
                ) {
                    Text(
                        text = stringResource(R.string.food_items),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.small))

                    result.foods.forEach { food ->
                        FoodItemRow(
                            name = food.name,
                            portion = food.portion,
                            calories = food.calories,
                            rating = food.healthRating
                        )
                        if (food != result.foods.last()) {
                            HorizontalDivider(modifier = Modifier.padding(vertical = AppSpacing.small))
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.medium))

        // Suggestions
        if (result.suggestions.isNotEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(AppRadius.large)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(AppSpacing.large)
                ) {
                    Text(
                        text = stringResource(R.string.suggestions),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.small))

                    result.suggestions.forEach { suggestion ->
                        Row(
                            modifier = Modifier.padding(vertical = 4.dp),
                            verticalAlignment = Alignment.Top
                        ) {
                            Icon(
                                imageVector = Icons.Default.Lightbulb,
                                contentDescription = null,
                                modifier = Modifier.size(16.dp),
                                tint = Warning
                            )
                            Spacer(modifier = Modifier.width(AppSpacing.small))
                            Text(
                                text = suggestion,
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.large))

        // Action buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(AppSpacing.medium)
        ) {
            OutlinedButton(
                onClick = onSave,
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Save, contentDescription = null)
                Spacer(modifier = Modifier.width(AppSpacing.small))
                Text(stringResource(R.string.save))
            }

            Button(
                onClick = onRetake,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = LeanEatColor)
            ) {
                Icon(Icons.Default.CameraAlt, contentDescription = null)
                Spacer(modifier = Modifier.width(AppSpacing.small))
                Text(stringResource(R.string.new_photo))
            }
        }

        Spacer(modifier = Modifier.height(AppSpacing.large))
    }
}

@Composable
private fun FoodItemRow(
    name: String,
    portion: String,
    calories: Int,
    rating: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = portion,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = "$calories kcal",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold
            )
            StatusBadge(
                text = rating,
                color = when (rating) {
                    "优秀" -> HealthExcellent
                    "良好" -> HealthGood
                    "一般" -> HealthFair
                    else -> HealthPoor
                }
            )
        }
    }
}

@Composable
private fun ErrorContent(
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
                colors = ButtonDefaults.buttonColors(containerColor = LeanEatColor)
            ) {
                Text(stringResource(R.string.retry))
            }
        }
    }
}
