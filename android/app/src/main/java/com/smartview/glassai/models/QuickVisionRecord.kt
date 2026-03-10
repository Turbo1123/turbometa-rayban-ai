package com.smartview.glassai.models

import java.text.SimpleDateFormat
import java.util.*

/**
 * Quick Vision record model with thumbnail support
 */
data class QuickVisionRecord(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: Long = System.currentTimeMillis(),
    val thumbnailPath: String,        // Local file path for thumbnail image
    val prompt: String,               // The prompt/question used
    val result: String,               // AI analysis result
    val mode: QuickVisionMode = QuickVisionMode.STANDARD,
    val visionModel: String = "qwen-vl-plus"
) {
    val title: String
        get() = result.take(30).ifEmpty { "Quick Vision" }

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
