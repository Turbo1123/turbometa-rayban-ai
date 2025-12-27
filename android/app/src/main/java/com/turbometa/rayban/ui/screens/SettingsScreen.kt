package com.turbometa.rayban.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.turbometa.rayban.R
import com.turbometa.rayban.ui.components.*
import com.turbometa.rayban.ui.theme.*
import com.turbometa.rayban.utils.AIModel
import com.turbometa.rayban.utils.OutputLanguage
import com.turbometa.rayban.utils.StreamQuality
import com.turbometa.rayban.viewmodels.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = viewModel(),
    onBackClick: () -> Unit,
    onNavigateToRecords: () -> Unit
) {
    val hasApiKey by viewModel.hasApiKey.collectAsState()
    val apiKeyMasked by viewModel.apiKeyMasked.collectAsState()
    val selectedModel by viewModel.selectedModel.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    val selectedQuality by viewModel.selectedQuality.collectAsState()
    val conversationCount by viewModel.conversationCount.collectAsState()
    val message by viewModel.message.collectAsState()
    val showApiKeyDialog by viewModel.showApiKeyDialog.collectAsState()
    val showModelDialog by viewModel.showModelDialog.collectAsState()
    val showLanguageDialog by viewModel.showLanguageDialog.collectAsState()
    val showQualityDialog by viewModel.showQualityDialog.collectAsState()
    val showDeleteConfirmDialog by viewModel.showDeleteConfirmDialog.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.settings),
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
            // Message snackbar
            message?.let { msg ->
                SuccessMessage(
                    message = msg,
                    onDismiss = { viewModel.clearMessage() },
                    modifier = Modifier.padding(AppSpacing.medium)
                )
            }

            // API Configuration Section
            SettingsSection(title = stringResource(R.string.api_configuration)) {
                SettingsItem(
                    icon = Icons.Default.Key,
                    title = stringResource(R.string.api_key),
                    subtitle = if (hasApiKey) apiKeyMasked else stringResource(R.string.not_configured),
                    onClick = { viewModel.showApiKeyDialog() }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                SettingsItem(
                    icon = Icons.Default.SmartToy,
                    title = stringResource(R.string.ai_model),
                    subtitle = viewModel.getSelectedModelDisplayName(),
                    onClick = { viewModel.showModelDialog() }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                SettingsItem(
                    icon = Icons.Default.Language,
                    title = stringResource(R.string.output_language),
                    subtitle = viewModel.getSelectedLanguageDisplayName(),
                    onClick = { viewModel.showLanguageDialog() }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                SettingsItem(
                    icon = Icons.Default.HighQuality,
                    title = stringResource(R.string.video_quality),
                    subtitle = viewModel.getSelectedQualityDisplayName(),
                    onClick = { viewModel.showQualityDialog() }
                )
            }

            // Data Section
            SettingsSection(title = stringResource(R.string.data)) {
                SettingsItem(
                    icon = Icons.Default.History,
                    title = stringResource(R.string.conversation_records),
                    subtitle = "$conversationCount ${stringResource(R.string.records)}",
                    onClick = onNavigateToRecords
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                SettingsItem(
                    icon = Icons.Default.Delete,
                    title = stringResource(R.string.clear_all_records),
                    subtitle = stringResource(R.string.clear_records_desc),
                    onClick = { viewModel.showDeleteConfirmDialog() },
                    isDestructive = true
                )
            }

            // About Section
            SettingsSection(title = stringResource(R.string.about)) {
                SettingsItem(
                    icon = Icons.Default.Info,
                    title = stringResource(R.string.version),
                    subtitle = "1.0.0",
                    onClick = {}
                )
            }

            Spacer(modifier = Modifier.height(AppSpacing.large))
        }
    }

    // API Key Dialog
    if (showApiKeyDialog) {
        ApiKeyDialog(
            currentKey = viewModel.getCurrentApiKey(),
            onSave = { viewModel.saveApiKey(it) },
            onDelete = { viewModel.deleteApiKey() },
            onDismiss = { viewModel.hideApiKeyDialog() }
        )
    }

    // Model Selection Dialog
    if (showModelDialog) {
        ModelSelectionDialog(
            selectedModel = selectedModel,
            models = viewModel.getAvailableModels(),
            onSelect = { viewModel.selectModel(it) },
            onDismiss = { viewModel.hideModelDialog() }
        )
    }

    // Language Selection Dialog
    if (showLanguageDialog) {
        LanguageSelectionDialog(
            selectedLanguage = selectedLanguage,
            languages = viewModel.getAvailableLanguages(),
            onSelect = { viewModel.selectLanguage(it) },
            onDismiss = { viewModel.hideLanguageDialog() }
        )
    }

    // Video Quality Selection Dialog
    if (showQualityDialog) {
        QualitySelectionDialog(
            selectedQuality = selectedQuality,
            qualities = viewModel.getAvailableQualities(),
            onSelect = { viewModel.selectQuality(it) },
            onDismiss = { viewModel.hideQualityDialog() }
        )
    }

    // Delete Confirmation Dialog
    if (showDeleteConfirmDialog) {
        ConfirmDialog(
            title = stringResource(R.string.delete_all),
            message = stringResource(R.string.delete_confirm_message),
            confirmText = stringResource(R.string.delete),
            dismissText = stringResource(R.string.cancel),
            onConfirm = { viewModel.deleteAllConversations() },
            onDismiss = { viewModel.hideDeleteConfirmDialog() }
        )
    }
}

@Composable
private fun SettingsSection(
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

        Spacer(modifier = Modifier.height(AppSpacing.medium))
    }
}

@Composable
private fun SettingsItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
    isDestructive: Boolean = false
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
            tint = if (isDestructive) Error else Primary,
            modifier = Modifier.size(24.dp)
        )

        Spacer(modifier = Modifier.width(AppSpacing.medium))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                color = if (isDestructive) Error else MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        Icon(
            imageVector = Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
        )
    }
}

@Composable
private fun ApiKeyDialog(
    currentKey: String,
    onSave: (String) -> Boolean,
    onDelete: () -> Boolean,
    onDismiss: () -> Unit
) {
    var apiKey by remember { mutableStateOf(currentKey) }
    var isVisible by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = stringResource(R.string.api_key),
                fontWeight = FontWeight.SemiBold
            )
        },
        text = {
            Column {
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { apiKey = it },
                    label = { Text(stringResource(R.string.enter_api_key)) },
                    modifier = Modifier.fillMaxWidth(),
                    visualTransformation = if (isVisible) {
                        VisualTransformation.None
                    } else {
                        PasswordVisualTransformation()
                    },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    trailingIcon = {
                        IconButton(onClick = { isVisible = !isVisible }) {
                            Icon(
                                imageVector = if (isVisible) {
                                    Icons.Default.VisibilityOff
                                } else {
                                    Icons.Default.Visibility
                                },
                                contentDescription = "Toggle visibility"
                            )
                        }
                    },
                    singleLine = true
                )

                if (currentKey.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(AppSpacing.small))
                    TextButton(
                        onClick = {
                            onDelete()
                            onDismiss()
                        },
                        colors = ButtonDefaults.textButtonColors(contentColor = Error)
                    ) {
                        Icon(Icons.Default.Delete, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(stringResource(R.string.delete_api_key))
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (onSave(apiKey)) {
                        onDismiss()
                    }
                }
            ) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun ModelSelectionDialog(
    selectedModel: String,
    models: List<AIModel>,
    onSelect: (AIModel) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = stringResource(R.string.select_model),
                fontWeight = FontWeight.SemiBold
            )
        },
        text = {
            Column {
                models.forEach { model ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = { onSelect(model) }
                            )
                            .padding(vertical = AppSpacing.small),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = model.id == selectedModel,
                            onClick = { onSelect(model) }
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Text(
                            text = model.displayName,
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun LanguageSelectionDialog(
    selectedLanguage: String,
    languages: List<OutputLanguage>,
    onSelect: (OutputLanguage) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = stringResource(R.string.select_language),
                fontWeight = FontWeight.SemiBold
            )
        },
        text = {
            Column {
                languages.forEach { language ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = { onSelect(language) }
                            )
                            .padding(vertical = AppSpacing.small),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = language.code == selectedLanguage,
                            onClick = { onSelect(language) }
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Column {
                            Text(
                                text = language.nativeName,
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Text(
                                text = language.displayName,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun QualitySelectionDialog(
    selectedQuality: String,
    qualities: List<StreamQuality>,
    onSelect: (StreamQuality) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = stringResource(R.string.select_quality),
                fontWeight = FontWeight.SemiBold
            )
        },
        text = {
            Column {
                qualities.forEach { quality ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = { onSelect(quality) }
                            )
                            .padding(vertical = AppSpacing.small),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = quality.id == selectedQuality,
                            onClick = { onSelect(quality) }
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Column {
                            Text(
                                text = quality.displayName,
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Text(
                                text = quality.description,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}
