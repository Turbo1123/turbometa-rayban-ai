package com.smartview.glassai.models

import java.text.SimpleDateFormat
import java.util.*

data class ConversationRecord(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val messages: List<ConversationMessage> = emptyList(),
    val aiModel: String = "qwen3-omni-flash-realtime",
    val language: String = "zh-CN"
) {
    val title: String
        get() = messages.firstOrNull { it.role == MessageRole.USER }?.content?.take(30) ?: "New Conversation"

    val summary: String
        get() = messages.lastOrNull()?.content?.take(50) ?: ""

    val messageCount: Int
        get() = messages.size

    val formattedDate: String
        get() {
            val now = Calendar.getInstance()
            val recordDate = Calendar.getInstance().apply { timeInMillis = timestamp }

            return when {
                isSameDay(now, recordDate) -> {
                    SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(timestamp))
                }
                isYesterday(now, recordDate) -> {
                    "Yesterday " + SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(timestamp))
                }
                else -> {
                    SimpleDateFormat("MM-dd HH:mm", Locale.getDefault()).format(Date(timestamp))
                }
            }
        }

    private fun isSameDay(cal1: Calendar, cal2: Calendar): Boolean {
        return cal1.get(Calendar.YEAR) == cal2.get(Calendar.YEAR) &&
                cal1.get(Calendar.DAY_OF_YEAR) == cal2.get(Calendar.DAY_OF_YEAR)
    }

    private fun isYesterday(today: Calendar, other: Calendar): Boolean {
        val yesterday = Calendar.getInstance().apply {
            timeInMillis = today.timeInMillis
            add(Calendar.DAY_OF_YEAR, -1)
        }
        return isSameDay(yesterday, other)
    }
}

data class ConversationMessage(
    val id: String = UUID.randomUUID().toString(),
    val role: MessageRole,
    val content: String,
    val timestamp: Long = System.currentTimeMillis()
)

enum class MessageRole {
    USER,
    ASSISTANT
}
