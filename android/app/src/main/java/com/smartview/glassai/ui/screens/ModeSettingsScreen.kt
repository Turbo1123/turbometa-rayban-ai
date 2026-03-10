package com.smartview.glassai.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.smartview.glassai.R
import com.smartview.glassai.managers.LiveAIModeManager
import com.smartview.glassai.managers.QuickVisionModeManager
import com.smartview.glassai.models.LiveAIMode
import com.smartview.glassai.models.QuickVisionMode
import com.smartview.glassai.ui.theme.*

/**
 * Quick Vision Mode Settings Screen
 * 快速识图模式设置界面
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickVisionModeScreen(
    onBackClick: () -> Unit
) {
    val context = LocalContext.current
    val modeManager = remember { QuickVisionModeManager.getInstance(context) }

    val currentMode by modeManager.currentMode.collectAsState()
    val customPrompt by modeManager.customPrompt.collectAsState()
    val translateTargetLanguage by modeManager.translateTargetLanguage.collectAsState()

    var editingCustomPrompt by remember { mutableStateOf(customPrompt) }

    // Update editing prompt when loaded
    LaunchedEffect(customPrompt) {
        editingCustomPrompt = customPrompt
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.quickvision_mode_settings),
                        fontWeight = FontWeight.SemiBold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
        ) {
            // Mode Selection Section
            SettingsSectionCard(title = stringResource(R.string.quickvision_mode_section)) {
                QuickVisionMode.entries.forEach { mode ->
                    ModeSelectionItem(
                        mode = mode,
                        isSelected = currentMode == mode,
                        icon = getModeIcon(mode),
                        iconColor = getModeColor(mode),
                        displayName = mode.getDisplayName(context),
                        description = mode.getDescription(context),
                        onClick = { modeManager.setMode(mode) }
                    )
                    if (mode != QuickVisionMode.entries.last()) {
                        HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))
                    }
                }
            }

            // Translate Target Language (only show when translate mode is selected)
            if (currentMode == QuickVisionMode.TRANSLATE) {
                Spacer(modifier = Modifier.height(AppSpacing.medium))
                SettingsSectionCard(title = stringResource(R.string.quickvision_target_language)) {
                    QuickVisionModeManager.supportedLanguages.forEach { (code, name) ->
                        LanguageSelectionItem(
                            languageCode = code,
                            languageName = name,
                            isSelected = translateTargetLanguage == code,
                            onClick = { modeManager.setTranslateTargetLanguage(code) }
                        )
                        if (code != QuickVisionModeManager.supportedLanguages.last().first) {
                            HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))
                        }
                    }
                }
            }

            // Custom Prompt Editor (only show when custom mode is selected)
            if (currentMode == QuickVisionMode.CUSTOM) {
                Spacer(modifier = Modifier.height(AppSpacing.medium))
                SettingsSectionCard(title = stringResource(R.string.quickvision_custom_prompt)) {
                    OutlinedTextField(
                        value = editingCustomPrompt,
                        onValueChange = {
                            editingCustomPrompt = it
                            modeManager.setCustomPrompt(it)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(AppSpacing.medium)
                            .heightIn(min = 150.dp),
                        placeholder = { Text(stringResource(R.string.quickvision_custom_hint)) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(AppSpacing.large))
        }
    }
}

/**
 * Live AI Mode Settings Screen
 * 实时对话模式设置界面
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LiveAIModeScreen(
    onBackClick: () -> Unit
) {
    val context = LocalContext.current
    val modeManager = remember { LiveAIModeManager.getInstance(context) }

    val currentMode by modeManager.currentMode.collectAsState()
    val customPrompt by modeManager.customPrompt.collectAsState()
    val translateTargetLanguage by modeManager.translateTargetLanguage.collectAsState()

    var editingCustomPrompt by remember { mutableStateOf(customPrompt) }

    // Update editing prompt when loaded
    LaunchedEffect(customPrompt) {
        editingCustomPrompt = customPrompt
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.liveai_mode_settings),
                        fontWeight = FontWeight.SemiBold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
        ) {
            // Mode Selection Section
            SettingsSectionCard(title = stringResource(R.string.liveai_mode_section)) {
                LiveAIMode.entries.forEach { mode ->
                    ModeSelectionItem(
                        mode = mode,
                        isSelected = currentMode == mode,
                        icon = getLiveAIModeIcon(mode),
                        iconColor = getLiveAIModeColor(mode),
                        displayName = mode.getDisplayName(context),
                        description = mode.getDescription(context),
                        onClick = { modeManager.setMode(mode) }
                    )
                    if (mode != LiveAIMode.entries.last()) {
                        HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))
                    }
                }
            }

            // Footer text
            Text(
                text = stringResource(R.string.liveai_mode_footer),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                modifier = Modifier.padding(horizontal = AppSpacing.medium, vertical = AppSpacing.small)
            )

            // Translate Target Language (only show when translate mode is selected)
            if (currentMode == LiveAIMode.TRANSLATE) {
                Spacer(modifier = Modifier.height(AppSpacing.medium))
                SettingsSectionCard(title = stringResource(R.string.liveai_target_language)) {
                    LiveAIModeManager.supportedLanguages.forEach { (code, name) ->
                        LanguageSelectionItem(
                            languageCode = code,
                            languageName = name,
                            isSelected = translateTargetLanguage == code,
                            onClick = { modeManager.setTranslateTargetLanguage(code) }
                        )
                        if (code != LiveAIModeManager.supportedLanguages.last().first) {
                            HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))
                        }
                    }
                }
            }

            // Custom Prompt Editor (only show when custom mode is selected)
            if (currentMode == LiveAIMode.CUSTOM) {
                Spacer(modifier = Modifier.height(AppSpacing.medium))
                SettingsSectionCard(title = stringResource(R.string.liveai_custom_prompt)) {
                    OutlinedTextField(
                        value = editingCustomPrompt,
                        onValueChange = {
                            editingCustomPrompt = it
                            modeManager.setCustomPrompt(it)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(AppSpacing.medium)
                            .heightIn(min = 150.dp),
                        placeholder = { Text(stringResource(R.string.liveai_custom_hint)) }
                    )

                    Text(
                        text = stringResource(R.string.liveai_custom_footer),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                        modifier = Modifier.padding(horizontal = AppSpacing.medium, vertical = AppSpacing.small)
                    )
                }
            }

            Spacer(modifier = Modifier.height(AppSpacing.large))
        }
    }
}

// MARK: - Helper Components

@Composable
private fun SettingsSectionCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(
                horizontal = AppSpacing.medium,
                vertical = AppSpacing.small
            )
        )

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = AppSpacing.medium),
            shape = RoundedCornerShape(AppRadius.medium)
        ) {
            Column(content = content)
        }
    }
}

@Composable
private fun <T> ModeSelectionItem(
    mode: T,
    isSelected: Boolean,
    icon: ImageVector,
    iconColor: Color,
    displayName: String,
    description: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            )
            .padding(AppSpacing.medium),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(24.dp)
        )

        Spacer(modifier = Modifier.width(AppSpacing.medium))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = displayName,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        if (isSelected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Selected",
                tint = Primary
            )
        }
    }
}

@Composable
private fun LanguageSelectionItem(
    languageCode: String,
    languageName: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            )
            .padding(AppSpacing.medium),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = languageName,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )

        if (isSelected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Selected",
                tint = Primary
            )
        }
    }
}

// MARK: - Icon and Color Helpers

private fun getModeIcon(mode: QuickVisionMode): ImageVector {
    return when (mode) {
        QuickVisionMode.STANDARD -> Icons.Default.Visibility
        QuickVisionMode.HEALTH -> Icons.Default.Favorite
        QuickVisionMode.BLIND -> Icons.Default.Accessibility
        QuickVisionMode.READING -> Icons.Default.MenuBook
        QuickVisionMode.TRANSLATE -> Icons.Default.Translate
        QuickVisionMode.ENCYCLOPEDIA -> Icons.Default.Museum
        QuickVisionMode.CUSTOM -> Icons.Default.Edit
    }
}

private fun getModeColor(mode: QuickVisionMode): Color {
    return when (mode) {
        QuickVisionMode.STANDARD -> Primary
        QuickVisionMode.HEALTH -> Error
        QuickVisionMode.BLIND -> Color(0xFF9C27B0) // Purple
        QuickVisionMode.READING -> Success
        QuickVisionMode.TRANSLATE -> Color(0xFFFF9800) // Orange
        QuickVisionMode.ENCYCLOPEDIA -> Color(0xFF795548) // Brown
        QuickVisionMode.CUSTOM -> Color.Gray
    }
}

private fun getLiveAIModeIcon(mode: LiveAIMode): ImageVector {
    return when (mode) {
        LiveAIMode.STANDARD -> Icons.Default.Psychology
        LiveAIMode.MUSEUM -> Icons.Default.Museum
        LiveAIMode.BLIND -> Icons.Default.Accessibility
        LiveAIMode.READING -> Icons.Default.MenuBook
        LiveAIMode.TRANSLATE -> Icons.Default.Translate
        LiveAIMode.CUSTOM -> Icons.Default.Edit
    }
}

private fun getLiveAIModeColor(mode: LiveAIMode): Color {
    return when (mode) {
        LiveAIMode.STANDARD -> Primary
        LiveAIMode.MUSEUM -> Color(0xFF795548) // Brown
        LiveAIMode.BLIND -> Color(0xFF9C27B0) // Purple
        LiveAIMode.READING -> Success
        LiveAIMode.TRANSLATE -> Color(0xFFFF9800) // Orange
        LiveAIMode.CUSTOM -> Color.Gray
    }
}
