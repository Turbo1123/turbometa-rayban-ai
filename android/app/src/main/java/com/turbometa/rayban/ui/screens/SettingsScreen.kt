package com.turbometa.rayban.ui.screens

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.OpenInNew
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.turbometa.rayban.R
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import com.turbometa.rayban.managers.AlibabaEndpoint
import com.turbometa.rayban.managers.AlibabaVisionModel
import com.turbometa.rayban.managers.APIProvider
import com.turbometa.rayban.managers.AppLanguage
import com.turbometa.rayban.managers.LiveAIProvider
import com.turbometa.rayban.managers.OpenRouterModel
import com.turbometa.rayban.services.PorcupineWakeWordService
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
    val context = LocalContext.current

    // Provider states
    val visionProvider by viewModel.visionProvider.collectAsState()
    val alibabaEndpoint by viewModel.alibabaEndpoint.collectAsState()
    val liveAIProvider by viewModel.liveAIProvider.collectAsState()

    // API Key states
    val hasAlibabaBeijingKey by viewModel.hasAlibabaBeijingKey.collectAsState()
    val hasAlibabaSingaporeKey by viewModel.hasAlibabaSingaporeKey.collectAsState()
    val hasOpenRouterKey by viewModel.hasOpenRouterKey.collectAsState()
    val hasGoogleKey by viewModel.hasGoogleKey.collectAsState()

    // Other states
    val selectedModel by viewModel.selectedModel.collectAsState()
    val selectedLanguage by viewModel.selectedLanguage.collectAsState()
    val selectedQuality by viewModel.selectedQuality.collectAsState()
    val conversationCount by viewModel.conversationCount.collectAsState()
    val message by viewModel.message.collectAsState()

    // Dialog states
    val showApiKeyDialog by viewModel.showApiKeyDialog.collectAsState()
    val showModelDialog by viewModel.showModelDialog.collectAsState()
    val showLanguageDialog by viewModel.showLanguageDialog.collectAsState()
    val showQualityDialog by viewModel.showQualityDialog.collectAsState()
    val showDeleteConfirmDialog by viewModel.showDeleteConfirmDialog.collectAsState()
    val showVisionProviderDialog by viewModel.showVisionProviderDialog.collectAsState()
    val showEndpointDialog by viewModel.showEndpointDialog.collectAsState()
    val showLiveAIProviderDialog by viewModel.showLiveAIProviderDialog.collectAsState()
    val showAppLanguageDialog by viewModel.showAppLanguageDialog.collectAsState()
    val appLanguage by viewModel.appLanguage.collectAsState()
    val editingKeyType by viewModel.editingKeyType.collectAsState()
    val showVisionModelDialog by viewModel.showVisionModelDialog.collectAsState()
    val selectedVisionModel by viewModel.selectedVisionModel.collectAsState()
    val openRouterModels by viewModel.openRouterModels.collectAsState()
    val isLoadingModels by viewModel.isLoadingModels.collectAsState()
    val modelsError by viewModel.modelsError.collectAsState()

    // Picovoice states
    var hasPicovoiceKey by remember { mutableStateOf(PorcupineWakeWordService.hasAccessKey(context)) }
    var showPicovoiceDialog by remember { mutableStateOf(false) }
    var isWakeWordEnabled by remember { mutableStateOf(isServiceRunning(context, PorcupineWakeWordService::class.java)) }
    var pendingWakeWordEnable by remember { mutableStateOf(false) }

    // Permission launcher for microphone
    val microphonePermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            // Permission granted, start the service
            val intent = Intent(context, PorcupineWakeWordService::class.java).apply {
                action = PorcupineWakeWordService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            isWakeWordEnabled = true
            Toast.makeText(context, context.getString(R.string.picovoice_enabled), Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(context, context.getString(R.string.permission_microphone), Toast.LENGTH_LONG).show()
        }
        pendingWakeWordEnable = false
    }

    // Function to toggle wake word service
    fun toggleWakeWordService(enabled: Boolean) {
        if (enabled) {
            // Check if access key is configured
            if (!PorcupineWakeWordService.hasAccessKey(context)) {
                Toast.makeText(context, context.getString(R.string.picovoice_not_configured), Toast.LENGTH_SHORT).show()
                showPicovoiceDialog = true
                return
            }
            // Check microphone permission
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                // Request permission
                pendingWakeWordEnable = true
                microphonePermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                return
            }
            // Start the service
            val intent = Intent(context, PorcupineWakeWordService::class.java).apply {
                action = PorcupineWakeWordService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            isWakeWordEnabled = true
            Toast.makeText(context, context.getString(R.string.picovoice_enabled), Toast.LENGTH_SHORT).show()
        } else {
            // Stop the service
            val intent = Intent(context, PorcupineWakeWordService::class.java).apply {
                action = PorcupineWakeWordService.ACTION_STOP
            }
            context.startService(intent)
            isWakeWordEnabled = false
            Toast.makeText(context, context.getString(R.string.picovoice_disabled), Toast.LENGTH_SHORT).show()
        }
    }

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

            // Vision API Provider Section
            SettingsSection(title = stringResource(R.string.settings_provider)) {
                // Vision Provider
                SettingsItem(
                    icon = Icons.Default.Cloud,
                    title = stringResource(R.string.settings_provider),
                    subtitle = if (visionProvider == APIProvider.ALIBABA)
                        stringResource(R.string.provider_alibaba)
                    else
                        stringResource(R.string.provider_openrouter),
                    onClick = { viewModel.showVisionProviderDialog() }
                )

                // Alibaba Endpoint (only when Alibaba selected)
                if (visionProvider == APIProvider.ALIBABA) {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))
                    SettingsItem(
                        icon = Icons.Default.Public,
                        title = stringResource(R.string.settings_endpoint),
                        subtitle = if (alibabaEndpoint == AlibabaEndpoint.BEIJING)
                            stringResource(R.string.endpoint_beijing)
                        else
                            stringResource(R.string.endpoint_singapore),
                        onClick = { viewModel.showEndpointDialog() }
                    )
                }

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                // Current Provider API Key
                val currentKeyTitle = when {
                    visionProvider == APIProvider.ALIBABA && alibabaEndpoint == AlibabaEndpoint.BEIJING ->
                        stringResource(R.string.apikey_alibaba_beijing)
                    visionProvider == APIProvider.ALIBABA && alibabaEndpoint == AlibabaEndpoint.SINGAPORE ->
                        stringResource(R.string.apikey_alibaba_singapore)
                    else -> stringResource(R.string.apikey_openrouter)
                }
                val hasCurrentKey = when {
                    visionProvider == APIProvider.ALIBABA && alibabaEndpoint == AlibabaEndpoint.BEIJING -> hasAlibabaBeijingKey
                    visionProvider == APIProvider.ALIBABA && alibabaEndpoint == AlibabaEndpoint.SINGAPORE -> hasAlibabaSingaporeKey
                    else -> hasOpenRouterKey
                }
                SettingsItem(
                    icon = Icons.Default.Key,
                    title = currentKeyTitle,
                    subtitle = if (hasCurrentKey)
                        stringResource(R.string.settings_apikey_configured)
                    else
                        stringResource(R.string.settings_apikey_not_configured),
                    subtitleColor = if (hasCurrentKey) Success else Error,
                    onClick = {
                        val keyType = when {
                            visionProvider == APIProvider.ALIBABA && alibabaEndpoint == AlibabaEndpoint.BEIJING ->
                                SettingsViewModel.EditingKeyType.ALIBABA_BEIJING
                            visionProvider == APIProvider.ALIBABA && alibabaEndpoint == AlibabaEndpoint.SINGAPORE ->
                                SettingsViewModel.EditingKeyType.ALIBABA_SINGAPORE
                            else -> SettingsViewModel.EditingKeyType.OPENROUTER
                        }
                        viewModel.showApiKeyDialogForType(keyType)
                    }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                // Vision Model Selection
                SettingsItem(
                    icon = Icons.Default.SmartToy,
                    title = stringResource(R.string.vision_model),
                    subtitle = viewModel.getSelectedVisionModelDisplayName(),
                    onClick = { viewModel.showVisionModelDialog() }
                )
            }

            // Live AI Settings Section
            SettingsSection(title = stringResource(R.string.settings_liveai_provider)) {
                SettingsItem(
                    icon = Icons.Default.RecordVoiceOver,
                    title = stringResource(R.string.settings_liveai_provider),
                    subtitle = if (liveAIProvider == LiveAIProvider.ALIBABA)
                        stringResource(R.string.liveai_alibaba)
                    else
                        stringResource(R.string.liveai_google),
                    onClick = { viewModel.showLiveAIProviderDialog() }
                )

                // Google API Key (only when Google selected for Live AI)
                if (liveAIProvider == LiveAIProvider.GOOGLE) {
                    HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))
                    SettingsItem(
                        icon = Icons.Default.Key,
                        title = stringResource(R.string.apikey_google),
                        subtitle = if (hasGoogleKey)
                            stringResource(R.string.settings_apikey_configured)
                        else
                            stringResource(R.string.settings_apikey_not_configured),
                        subtitleColor = if (hasGoogleKey) Success else Error,
                        onClick = {
                            viewModel.showApiKeyDialogForType(SettingsViewModel.EditingKeyType.GOOGLE)
                        }
                    )
                }
            }

            // Quick Vision / Picovoice Section
            SettingsSection(title = stringResource(R.string.settings_quickvision)) {
                // Wake Word Toggle
                SettingsToggleItem(
                    icon = Icons.Default.RecordVoiceOver,
                    title = stringResource(R.string.wakeword_detection),
                    subtitle = if (isWakeWordEnabled)
                        stringResource(R.string.wakeword_enabled_desc)
                    else
                        stringResource(R.string.wakeword_disabled_desc),
                    checked = isWakeWordEnabled,
                    onCheckedChange = { toggleWakeWordService(it) }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                SettingsItem(
                    icon = Icons.Default.Key,
                    title = stringResource(R.string.picovoice_accesskey),
                    subtitle = if (hasPicovoiceKey)
                        stringResource(R.string.picovoice_configured)
                    else
                        stringResource(R.string.picovoice_not_configured),
                    subtitleColor = if (hasPicovoiceKey) Success else Error,
                    onClick = { showPicovoiceDialog = true }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                // Battery optimization settings
                SettingsItem(
                    icon = Icons.Default.BatteryChargingFull,
                    title = stringResource(R.string.background_running),
                    subtitle = stringResource(R.string.background_running_desc),
                    onClick = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            context.startActivity(intent)
                        }
                    }
                )
            }

            // AI Settings Section
            SettingsSection(title = stringResource(R.string.settings_ai)) {
                // App Language (界面语言)
                SettingsItem(
                    icon = Icons.Default.Translate,
                    title = stringResource(R.string.settings_applanguage),
                    subtitle = viewModel.getAppLanguageDisplayName(),
                    onClick = { viewModel.showAppLanguageDialog() }
                )

                HorizontalDivider(modifier = Modifier.padding(horizontal = AppSpacing.medium))

                // Output Language (AI输出语言)
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
                    subtitle = "1.3.0",
                    onClick = {}
                )
            }

            Spacer(modifier = Modifier.height(AppSpacing.large))
        }
    }

    // Vision Provider Dialog
    if (showVisionProviderDialog) {
        ProviderSelectionDialog(
            title = stringResource(R.string.settings_provider),
            options = listOf(
                APIProvider.ALIBABA to stringResource(R.string.provider_alibaba),
                APIProvider.OPENROUTER to stringResource(R.string.provider_openrouter)
            ),
            selected = visionProvider,
            onSelect = { viewModel.selectVisionProvider(it) },
            onDismiss = { viewModel.hideVisionProviderDialog() }
        )
    }

    // Endpoint Dialog
    if (showEndpointDialog) {
        ProviderSelectionDialog(
            title = stringResource(R.string.settings_endpoint),
            options = listOf(
                AlibabaEndpoint.BEIJING to stringResource(R.string.endpoint_beijing),
                AlibabaEndpoint.SINGAPORE to stringResource(R.string.endpoint_singapore)
            ),
            selected = alibabaEndpoint,
            onSelect = { viewModel.selectEndpoint(it) },
            onDismiss = { viewModel.hideEndpointDialog() }
        )
    }

    // Live AI Provider Dialog
    if (showLiveAIProviderDialog) {
        ProviderSelectionDialog(
            title = stringResource(R.string.settings_liveai_provider),
            options = listOf(
                LiveAIProvider.ALIBABA to stringResource(R.string.liveai_alibaba),
                LiveAIProvider.GOOGLE to stringResource(R.string.liveai_google)
            ),
            selected = liveAIProvider,
            onSelect = { viewModel.selectLiveAIProvider(it) },
            onDismiss = { viewModel.hideLiveAIProviderDialog() }
        )
    }

    // API Key Dialog
    if (showApiKeyDialog) {
        val keyType = editingKeyType
        val title = when (keyType) {
            SettingsViewModel.EditingKeyType.ALIBABA_BEIJING -> stringResource(R.string.apikey_alibaba_beijing)
            SettingsViewModel.EditingKeyType.ALIBABA_SINGAPORE -> stringResource(R.string.apikey_alibaba_singapore)
            SettingsViewModel.EditingKeyType.OPENROUTER -> stringResource(R.string.apikey_openrouter)
            SettingsViewModel.EditingKeyType.GOOGLE -> stringResource(R.string.apikey_google)
            else -> stringResource(R.string.api_key)
        }
        val helpUrl = when (keyType) {
            SettingsViewModel.EditingKeyType.ALIBABA_BEIJING,
            SettingsViewModel.EditingKeyType.ALIBABA_SINGAPORE -> "https://help.aliyun.com/zh/model-studio/get-api-key"
            SettingsViewModel.EditingKeyType.OPENROUTER -> "https://openrouter.ai/keys"
            SettingsViewModel.EditingKeyType.GOOGLE -> "https://aistudio.google.com/apikey"
            else -> null
        }

        ApiKeyDialog(
            title = title,
            currentKey = viewModel.getCurrentApiKey(),
            helpUrl = helpUrl,
            onSave = { viewModel.saveApiKey(it) },
            onDelete = { viewModel.deleteApiKey() },
            onDismiss = { viewModel.hideApiKeyDialog() }
        )
    }

    // Picovoice Dialog
    if (showPicovoiceDialog) {
        PicovoiceKeyDialog(
            currentKey = PorcupineWakeWordService.getAccessKey(context) ?: "",
            onSave = { key ->
                PorcupineWakeWordService.saveAccessKey(context, key)
                hasPicovoiceKey = PorcupineWakeWordService.hasAccessKey(context)
                true
            },
            onDismiss = { showPicovoiceDialog = false }
        )
    }

    // Vision Model Selection Dialog
    if (showVisionModelDialog) {
        VisionModelSelectionDialog(
            visionProvider = visionProvider,
            selectedModel = selectedVisionModel,
            alibabaModels = viewModel.getAlibabaVisionModels(),
            openRouterModels = openRouterModels,
            isLoading = isLoadingModels,
            error = modelsError,
            onSearch = { viewModel.searchOpenRouterModels(it) },
            onRefresh = { viewModel.fetchOpenRouterModels() },
            onSelect = { viewModel.selectVisionModel(it) },
            onDismiss = { viewModel.hideVisionModelDialog() }
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

    // App Language Selection Dialog
    if (showAppLanguageDialog) {
        AppLanguageSelectionDialog(
            selectedLanguage = appLanguage,
            languages = viewModel.getAvailableAppLanguages(),
            onSelect = { viewModel.selectAppLanguage(it) },
            onDismiss = { viewModel.hideAppLanguageDialog() }
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
    isDestructive: Boolean = false,
    subtitleColor: Color? = null
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
                color = subtitleColor ?: MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
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
private fun <T> ProviderSelectionDialog(
    title: String,
    options: List<Pair<T, String>>,
    selected: T,
    onSelect: (T) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(text = title, fontWeight = FontWeight.SemiBold)
        },
        text = {
            Column {
                options.forEach { (value, label) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                                onClick = { onSelect(value) }
                            )
                            .padding(vertical = AppSpacing.small),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = value == selected,
                            onClick = { onSelect(value) }
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Text(text = label, style = MaterialTheme.typography.bodyLarge)
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
private fun ApiKeyDialog(
    title: String,
    currentKey: String,
    helpUrl: String?,
    onSave: (String) -> Boolean,
    onDelete: () -> Boolean,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var apiKey by remember { mutableStateOf(currentKey) }
    var isVisible by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(text = title, fontWeight = FontWeight.SemiBold)
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
                                imageVector = if (isVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = "Toggle visibility"
                            )
                        }
                    },
                    singleLine = true
                )

                helpUrl?.let { url ->
                    Spacer(modifier = Modifier.height(AppSpacing.small))
                    TextButton(
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            context.startActivity(intent)
                        }
                    ) {
                        Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Get API Key")
                    }
                }

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
private fun PicovoiceKeyDialog(
    currentKey: String,
    onSave: (String) -> Boolean,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    var accessKey by remember { mutableStateOf(currentKey) }
    var isVisible by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(text = stringResource(R.string.picovoice_accesskey), fontWeight = FontWeight.SemiBold)
        },
        text = {
            Column {
                Text(
                    text = stringResource(R.string.picovoice_description),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                )

                Spacer(modifier = Modifier.height(AppSpacing.medium))

                OutlinedTextField(
                    value = accessKey,
                    onValueChange = { accessKey = it },
                    label = { Text(stringResource(R.string.picovoice_accesskey_hint)) },
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
                                imageVector = if (isVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                                contentDescription = "Toggle visibility"
                            )
                        }
                    },
                    singleLine = true
                )

                Spacer(modifier = Modifier.height(AppSpacing.small))

                TextButton(
                    onClick = {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://console.picovoice.ai/"))
                        context.startActivity(intent)
                    }
                ) {
                    Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(stringResource(R.string.picovoice_get_key))
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (onSave(accessKey)) {
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VisionModelSelectionDialog(
    visionProvider: APIProvider,
    selectedModel: String,
    alibabaModels: List<AlibabaVisionModel>,
    openRouterModels: List<OpenRouterModel>,
    isLoading: Boolean,
    error: String?,
    onSearch: (String) -> List<OpenRouterModel>,
    onRefresh: () -> Unit,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    var showVisionOnly by remember { mutableStateOf(true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.fillMaxHeight(0.8f),
        title = {
            Text(text = stringResource(R.string.select_vision_model), fontWeight = FontWeight.SemiBold)
        },
        text = {
            Column(modifier = Modifier.fillMaxWidth()) {
                if (visionProvider == APIProvider.ALIBABA) {
                    // Alibaba models - static list
                    LazyColumn {
                        items(alibabaModels) { model ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable(
                                        interactionSource = remember { MutableInteractionSource() },
                                        indication = null,
                                        onClick = { onSelect(model.id) }
                                    )
                                    .padding(vertical = AppSpacing.small),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                RadioButton(
                                    selected = model.id == selectedModel,
                                    onClick = { onSelect(model.id) }
                                )
                                Spacer(modifier = Modifier.width(AppSpacing.small))
                                Column {
                                    Text(
                                        text = model.displayName,
                                        style = MaterialTheme.typography.bodyLarge
                                    )
                                    Text(
                                        text = model.description,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // OpenRouter models - with search
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        label = { Text(stringResource(R.string.search_models)) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        leadingIcon = {
                            Icon(Icons.Default.Search, contentDescription = null)
                        },
                        trailingIcon = {
                            if (searchQuery.isNotEmpty()) {
                                IconButton(onClick = { searchQuery = "" }) {
                                    Icon(Icons.Default.Clear, contentDescription = "Clear")
                                }
                            }
                        }
                    )

                    Spacer(modifier = Modifier.height(AppSpacing.small))

                    // Vision only toggle
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Checkbox(
                            checked = showVisionOnly,
                            onCheckedChange = { showVisionOnly = it }
                        )
                        Text(
                            text = stringResource(R.string.vision_capable_only),
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }

                    Spacer(modifier = Modifier.height(AppSpacing.small))

                    when {
                        isLoading -> {
                            Box(
                                modifier = Modifier.fillMaxWidth().height(200.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                        error != null -> {
                            Column(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    text = error,
                                    color = Error,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                                Spacer(modifier = Modifier.height(AppSpacing.small))
                                TextButton(onClick = onRefresh) {
                                    Text(stringResource(R.string.retry))
                                }
                            }
                        }
                        else -> {
                            val filteredModels = remember(searchQuery, showVisionOnly, openRouterModels) {
                                val searched = if (searchQuery.isEmpty()) openRouterModels else onSearch(searchQuery)
                                if (showVisionOnly) searched.filter { it.isVisionCapable } else searched
                            }

                            LazyColumn(modifier = Modifier.weight(1f)) {
                                items(filteredModels) { model ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable(
                                                interactionSource = remember { MutableInteractionSource() },
                                                indication = null,
                                                onClick = { onSelect(model.id) }
                                            )
                                            .padding(vertical = AppSpacing.small),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        RadioButton(
                                            selected = model.id == selectedModel,
                                            onClick = { onSelect(model.id) }
                                        )
                                        Spacer(modifier = Modifier.width(AppSpacing.small))
                                        Column(modifier = Modifier.weight(1f)) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Text(
                                                    text = model.displayName,
                                                    style = MaterialTheme.typography.bodyLarge,
                                                    maxLines = 1
                                                )
                                                if (model.isVisionCapable) {
                                                    Spacer(modifier = Modifier.width(4.dp))
                                                    Icon(
                                                        Icons.Default.Visibility,
                                                        contentDescription = "Vision",
                                                        modifier = Modifier.size(16.dp),
                                                        tint = Primary
                                                    )
                                                }
                                            }
                                            Text(
                                                text = model.id,
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f),
                                                maxLines = 1
                                            )
                                            if (model.priceDisplay.isNotEmpty()) {
                                                Text(
                                                    text = model.priceDisplay,
                                                    style = MaterialTheme.typography.labelSmall,
                                                    color = Success
                                                )
                                            }
                                        }
                                    }
                                }
                            }
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
private fun LanguageSelectionDialog(
    selectedLanguage: String,
    languages: List<OutputLanguage>,
    onSelect: (OutputLanguage) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(text = stringResource(R.string.select_language), fontWeight = FontWeight.SemiBold)
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
                            Text(text = language.nativeName, style = MaterialTheme.typography.bodyLarge)
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
            Text(text = stringResource(R.string.select_quality), fontWeight = FontWeight.SemiBold)
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
                            Text(text = quality.displayName, style = MaterialTheme.typography.bodyLarge)
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

@Composable
private fun AppLanguageSelectionDialog(
    selectedLanguage: AppLanguage,
    languages: List<AppLanguage>,
    onSelect: (AppLanguage) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(text = stringResource(R.string.select_applanguage), fontWeight = FontWeight.SemiBold)
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
                            selected = language == selectedLanguage,
                            onClick = { onSelect(language) }
                        )
                        Spacer(modifier = Modifier.width(AppSpacing.small))
                        Column {
                            Text(text = language.nativeName, style = MaterialTheme.typography.bodyLarge)
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
private fun SettingsToggleItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = { onCheckedChange(!checked) }
            )
            .padding(AppSpacing.medium),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (checked) Success else Primary,
            modifier = Modifier.size(24.dp)
        )

        Spacer(modifier = Modifier.width(AppSpacing.medium))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Success,
                checkedTrackColor = Success.copy(alpha = 0.5f)
            )
        )
    }
}

// Helper function to check if a service is running
private fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
    val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    @Suppress("DEPRECATION")
    for (service in manager.getRunningServices(Int.MAX_VALUE)) {
        if (serviceClass.name == service.service.className) {
            return true
        }
    }
    return false
}
