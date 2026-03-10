package com.smartview.glassai.viewmodels

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.smartview.glassai.data.ConversationStorage
import com.smartview.glassai.data.QuickVisionStorage
import com.smartview.glassai.models.ConversationRecord
import com.smartview.glassai.models.QuickVisionRecord
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class RecordsTab {
    LIVE_AI,
    QUICK_VISION
}

class RecordsViewModel(application: Application) : AndroidViewModel(application) {

    private val conversationStorage = ConversationStorage.getInstance(application)
    private val quickVisionStorage = QuickVisionStorage.getInstance(application)

    // Tab selection
    private val _selectedTab = MutableStateFlow(RecordsTab.LIVE_AI)
    val selectedTab: StateFlow<RecordsTab> = _selectedTab.asStateFlow()

    // Live AI conversations
    private val _conversations = MutableStateFlow<List<ConversationRecord>>(emptyList())
    val conversations: StateFlow<List<ConversationRecord>> = _conversations.asStateFlow()

    private val _selectedConversation = MutableStateFlow<ConversationRecord?>(null)
    val selectedConversation: StateFlow<ConversationRecord?> = _selectedConversation.asStateFlow()

    // Quick Vision records
    private val _quickVisionRecords = MutableStateFlow<List<QuickVisionRecord>>(emptyList())
    val quickVisionRecords: StateFlow<List<QuickVisionRecord>> = _quickVisionRecords.asStateFlow()

    private val _selectedQuickVisionRecord = MutableStateFlow<QuickVisionRecord?>(null)
    val selectedQuickVisionRecord: StateFlow<QuickVisionRecord?> = _selectedQuickVisionRecord.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()

    private val _showDeleteConfirmDialog = MutableStateFlow(false)
    val showDeleteConfirmDialog: StateFlow<Boolean> = _showDeleteConfirmDialog.asStateFlow()

    private var itemToDelete: String? = null

    init {
        loadRecords()
    }

    fun selectTab(tab: RecordsTab) {
        _selectedTab.value = tab
        loadRecords()
    }

    fun loadRecords() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                _conversations.value = conversationStorage.getAllConversations()
                _quickVisionRecords.value = quickVisionStorage.getAllRecords()
            } catch (e: Exception) {
                _message.value = "Failed to load records: ${e.message}"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun loadConversations() {
        loadRecords()
    }

    fun selectConversation(conversation: ConversationRecord) {
        _selectedConversation.value = conversation
    }

    fun selectQuickVisionRecord(record: QuickVisionRecord) {
        _selectedQuickVisionRecord.value = record
    }

    fun clearSelection() {
        _selectedConversation.value = null
        _selectedQuickVisionRecord.value = null
    }

    fun showDeleteConfirm(id: String) {
        itemToDelete = id
        _showDeleteConfirmDialog.value = true
    }

    fun hideDeleteConfirm() {
        itemToDelete = null
        _showDeleteConfirmDialog.value = false
    }

    fun confirmDelete() {
        val id = itemToDelete ?: return
        viewModelScope.launch {
            when (_selectedTab.value) {
                RecordsTab.LIVE_AI -> {
                    val success = conversationStorage.deleteConversation(id)
                    if (success) {
                        _conversations.value = _conversations.value.filter { it.id != id }
                        if (_selectedConversation.value?.id == id) {
                            _selectedConversation.value = null
                        }
                        _message.value = "Conversation deleted"
                    } else {
                        _message.value = "Failed to delete conversation"
                    }
                }
                RecordsTab.QUICK_VISION -> {
                    val success = quickVisionStorage.deleteRecord(id)
                    if (success) {
                        _quickVisionRecords.value = _quickVisionRecords.value.filter { it.id != id }
                        if (_selectedQuickVisionRecord.value?.id == id) {
                            _selectedQuickVisionRecord.value = null
                        }
                        _message.value = "Record deleted"
                    } else {
                        _message.value = "Failed to delete record"
                    }
                }
            }
            hideDeleteConfirm()
        }
    }

    fun deleteAllConversations() {
        viewModelScope.launch {
            val success = conversationStorage.deleteAllConversations()
            if (success) {
                _conversations.value = emptyList()
                _selectedConversation.value = null
                _message.value = "All conversations deleted"
            } else {
                _message.value = "Failed to delete conversations"
            }
        }
    }

    fun deleteAllQuickVisionRecords() {
        viewModelScope.launch {
            val success = quickVisionStorage.deleteAllRecords()
            if (success) {
                _quickVisionRecords.value = emptyList()
                _selectedQuickVisionRecord.value = null
                _message.value = "All records deleted"
            } else {
                _message.value = "Failed to delete records"
            }
        }
    }

    fun clearMessage() {
        _message.value = null
    }

    fun getConversationPreview(record: ConversationRecord): String {
        val lastMessage = record.messages.lastOrNull()
        return lastMessage?.content?.take(100) ?: "No messages"
    }

    fun getFormattedDate(timestamp: Long): String {
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm", java.util.Locale.getDefault())
        return sdf.format(java.util.Date(timestamp))
    }

    fun getMessageCount(record: ConversationRecord): Int {
        return record.messages.size
    }
}
