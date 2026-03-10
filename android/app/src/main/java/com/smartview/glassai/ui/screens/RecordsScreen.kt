package com.smartview.glassai.ui.screens

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.smartview.glassai.R
import com.smartview.glassai.models.ConversationRecord
import com.smartview.glassai.models.MessageRole
import com.smartview.glassai.models.QuickVisionRecord
import com.smartview.glassai.ui.components.*
import com.smartview.glassai.ui.theme.*
import com.smartview.glassai.viewmodels.RecordsTab
import com.smartview.glassai.viewmodels.RecordsViewModel
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordsScreen(
    viewModel: RecordsViewModel = viewModel(),
    onBackClick: () -> Unit
) {
    val selectedTab by viewModel.selectedTab.collectAsState()
    val conversations by viewModel.conversations.collectAsState()
    val quickVisionRecords by viewModel.quickVisionRecords.collectAsState()
    val selectedConversation by viewModel.selectedConversation.collectAsState()
    val selectedQuickVisionRecord by viewModel.selectedQuickVisionRecord.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val message by viewModel.message.collectAsState()
    val showDeleteConfirmDialog by viewModel.showDeleteConfirmDialog.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadRecords()
    }

    // Show detail screens if an item is selected
    when {
        selectedConversation != null -> {
            ConversationDetailScreen(
                conversation = selectedConversation!!,
                onBackClick = { viewModel.clearSelection() },
                onDelete = { viewModel.showDeleteConfirm(selectedConversation!!.id) }
            )
        }
        selectedQuickVisionRecord != null -> {
            QuickVisionDetailScreen(
                record = selectedQuickVisionRecord!!,
                onBackClick = { viewModel.clearSelection() },
                onDelete = { viewModel.showDeleteConfirm(selectedQuickVisionRecord!!.id) }
            )
        }
        else -> {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = {
                            Text(
                                text = stringResource(R.string.conversation_records),
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
                ) {
                    // Tab Row
                    TabRow(
                        selectedTabIndex = if (selectedTab == RecordsTab.LIVE_AI) 0 else 1
                    ) {
                        Tab(
                            selected = selectedTab == RecordsTab.LIVE_AI,
                            onClick = { viewModel.selectTab(RecordsTab.LIVE_AI) },
                            text = { Text(stringResource(R.string.live_ai)) }
                        )
                        Tab(
                            selected = selectedTab == RecordsTab.QUICK_VISION,
                            onClick = { viewModel.selectTab(RecordsTab.QUICK_VISION) },
                            text = { Text(stringResource(R.string.quick_vision)) }
                        )
                    }

                    // Message
                    message?.let { msg ->
                        SuccessMessage(
                            message = msg,
                            onDismiss = { viewModel.clearMessage() },
                            modifier = Modifier.padding(AppSpacing.medium)
                        )
                    }

                    when {
                        isLoading -> {
                            LoadingIndicator(
                                modifier = Modifier.fillMaxSize(),
                                message = stringResource(R.string.loading)
                            )
                        }
                        selectedTab == RecordsTab.LIVE_AI -> {
                            if (conversations.isEmpty()) {
                                EmptyState(
                                    message = stringResource(R.string.no_records),
                                    icon = Icons.Default.History,
                                    modifier = Modifier.fillMaxSize()
                                )
                            } else {
                                LazyColumn(
                                    modifier = Modifier.fillMaxSize(),
                                    contentPadding = PaddingValues(AppSpacing.medium),
                                    verticalArrangement = Arrangement.spacedBy(AppSpacing.small)
                                ) {
                                    items(conversations) { conversation ->
                                        ConversationCard(
                                            conversation = conversation,
                                            preview = viewModel.getConversationPreview(conversation),
                                            formattedDate = viewModel.getFormattedDate(conversation.timestamp),
                                            messageCount = viewModel.getMessageCount(conversation),
                                            onClick = { viewModel.selectConversation(conversation) },
                                            onDelete = { viewModel.showDeleteConfirm(conversation.id) }
                                        )
                                    }
                                }
                            }
                        }
                        selectedTab == RecordsTab.QUICK_VISION -> {
                            if (quickVisionRecords.isEmpty()) {
                                EmptyState(
                                    message = stringResource(R.string.no_quick_vision_records),
                                    icon = Icons.Default.CameraAlt,
                                    modifier = Modifier.fillMaxSize()
                                )
                            } else {
                                LazyColumn(
                                    modifier = Modifier.fillMaxSize(),
                                    contentPadding = PaddingValues(AppSpacing.medium),
                                    verticalArrangement = Arrangement.spacedBy(AppSpacing.small)
                                ) {
                                    items(quickVisionRecords) { record ->
                                        QuickVisionCard(
                                            record = record,
                                            onClick = { viewModel.selectQuickVisionRecord(record) },
                                            onDelete = { viewModel.showDeleteConfirm(record.id) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Delete Confirmation Dialog
            if (showDeleteConfirmDialog) {
                ConfirmDialog(
                    title = stringResource(R.string.delete_record),
                    message = stringResource(R.string.delete_record_confirm),
                    confirmText = stringResource(R.string.delete),
                    dismissText = stringResource(R.string.cancel),
                    onConfirm = { viewModel.confirmDelete() },
                    onDismiss = { viewModel.hideDeleteConfirm() }
                )
            }
        }
    }
}

@Composable
private fun ConversationCard(
    conversation: ConversationRecord,
    preview: String,
    formattedDate: String,
    messageCount: Int,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            ),
        shape = RoundedCornerShape(AppRadius.medium),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(AppSpacing.medium),
            verticalAlignment = Alignment.Top
        ) {
            // Icon
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(RoundedCornerShape(AppRadius.small))
                    .background(Primary.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Chat,
                    contentDescription = null,
                    tint = Primary,
                    modifier = Modifier.size(20.dp)
                )
            }

            Spacer(modifier = Modifier.width(AppSpacing.medium))

            Column(modifier = Modifier.weight(1f)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = formattedDate,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "$messageCount ${stringResource(R.string.messages)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f)
                    )
                }

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = preview,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(AppSpacing.small))

                Row(
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.small)
                ) {
                    StatusBadge(
                        text = conversation.aiModel.replace("-realtime", ""),
                        color = Primary
                    )
                    StatusBadge(
                        text = conversation.language,
                        color = Secondary
                    )
                }
            }

            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Error.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@Composable
private fun QuickVisionCard(
    record: QuickVisionRecord,
    onClick: () -> Unit,
    onDelete: () -> Unit
) {
    val context = LocalContext.current

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            ),
        shape = RoundedCornerShape(AppRadius.medium),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(AppSpacing.medium),
            verticalAlignment = Alignment.Top
        ) {
            // Thumbnail
            val thumbnailBitmap = remember(record.thumbnailPath) {
                try {
                    val file = File(record.thumbnailPath)
                    if (file.exists()) {
                        BitmapFactory.decodeFile(file.absolutePath)
                    } else null
                } catch (e: Exception) {
                    null
                }
            }

            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(RoundedCornerShape(AppRadius.small))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center
            ) {
                if (thumbnailBitmap != null) {
                    Image(
                        bitmap = thumbnailBitmap.asImageBitmap(),
                        contentDescription = null,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.CameraAlt,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(24.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.width(AppSpacing.medium))

            Column(modifier = Modifier.weight(1f)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = record.formattedDate,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                }

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = record.result,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Spacer(modifier = Modifier.height(AppSpacing.small))

                Row(
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.small)
                ) {
                    StatusBadge(
                        text = record.mode.getDisplayName(context),
                        color = Primary
                    )
                    StatusBadge(
                        text = record.visionModel.replace("qwen-", ""),
                        color = Secondary
                    )
                }
            }

            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = Error.copy(alpha = 0.7f)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationDetailScreen(
    conversation: ConversationRecord,
    onBackClick: () -> Unit,
    onDelete: () -> Unit
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = stringResource(R.string.conversation_detail),
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = java.text.SimpleDateFormat(
                                "yyyy-MM-dd HH:mm",
                                java.util.Locale.getDefault()
                            ).format(java.util.Date(conversation.timestamp)),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onDelete) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "Delete",
                            tint = Error
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = AppSpacing.medium),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.small)
        ) {
            items(conversation.messages) { message ->
                val isUser = message.role == MessageRole.USER
                val backgroundColor = if (isUser) {
                    Primary
                } else {
                    MaterialTheme.colorScheme.surfaceVariant
                }
                val textColor = if (isUser) {
                    androidx.compose.ui.graphics.Color.White
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
                ) {
                    Column(
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
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = java.text.SimpleDateFormat(
                                "HH:mm",
                                java.util.Locale.getDefault()
                            ).format(java.util.Date(message.timestamp)),
                            color = textColor.copy(alpha = 0.6f),
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(AppSpacing.large))
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuickVisionDetailScreen(
    record: QuickVisionRecord,
    onBackClick: () -> Unit,
    onDelete: () -> Unit
) {
    val context = LocalContext.current

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Text(
                            text = stringResource(R.string.quick_vision_detail),
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = java.text.SimpleDateFormat(
                                "yyyy-MM-dd HH:mm",
                                java.util.Locale.getDefault()
                            ).format(java.util.Date(record.timestamp)),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onDelete) {
                        Icon(
                            imageVector = Icons.Default.Delete,
                            contentDescription = "Delete",
                            tint = Error
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = AppSpacing.medium),
            verticalArrangement = Arrangement.spacedBy(AppSpacing.medium)
        ) {
            // Thumbnail Image
            item {
                val thumbnailBitmap = remember(record.thumbnailPath) {
                    try {
                        val file = File(record.thumbnailPath)
                        if (file.exists()) {
                            BitmapFactory.decodeFile(file.absolutePath)
                        } else null
                    } catch (e: Exception) {
                        null
                    }
                }

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(AppRadius.medium)
                ) {
                    if (thumbnailBitmap != null) {
                        Image(
                            bitmap = thumbnailBitmap.asImageBitmap(),
                            contentDescription = null,
                            modifier = Modifier
                                .fillMaxWidth()
                                .aspectRatio(4f / 3f),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .aspectRatio(4f / 3f)
                                .background(MaterialTheme.colorScheme.surfaceVariant),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.BrokenImage,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }

            // Mode and Model Info
            item {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(AppSpacing.small)
                ) {
                    StatusBadge(
                        text = record.mode.getDisplayName(context),
                        color = Primary
                    )
                    StatusBadge(
                        text = record.visionModel,
                        color = Secondary
                    )
                }
            }

            // Result
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(AppRadius.medium)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(AppSpacing.medium)
                    ) {
                        Text(
                            text = stringResource(R.string.analysis_result),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = Primary
                        )
                        Spacer(modifier = Modifier.height(AppSpacing.small))
                        Text(
                            text = record.result,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(AppSpacing.large))
            }
        }
    }
}
