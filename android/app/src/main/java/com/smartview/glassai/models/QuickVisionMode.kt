package com.smartview.glassai.models

import android.content.Context
import com.smartview.glassai.R

/**
 * Quick Vision Modes
 * 快速识图模式 - 不同场景的识图助手
 */
enum class QuickVisionMode(val id: String) {
    STANDARD("standard"),       // 默认模式
    HEALTH("health"),           // 健康识图
    BLIND("blind"),             // 盲人模式
    READING("reading"),         // 阅读模式
    TRANSLATE("translate"),     // 翻译模式
    ENCYCLOPEDIA("encyclopedia"), // 百科（博物馆）模式
    CUSTOM("custom");           // 自定义提示词

    fun getDisplayName(context: Context): String {
        return when (this) {
            STANDARD -> context.getString(R.string.quickvision_mode_standard)
            HEALTH -> context.getString(R.string.quickvision_mode_health)
            BLIND -> context.getString(R.string.quickvision_mode_blind)
            READING -> context.getString(R.string.quickvision_mode_reading)
            TRANSLATE -> context.getString(R.string.quickvision_mode_translate)
            ENCYCLOPEDIA -> context.getString(R.string.quickvision_mode_encyclopedia)
            CUSTOM -> context.getString(R.string.quickvision_mode_custom)
        }
    }

    fun getDescription(context: Context): String {
        return when (this) {
            STANDARD -> context.getString(R.string.quickvision_mode_standard_desc)
            HEALTH -> context.getString(R.string.quickvision_mode_health_desc)
            BLIND -> context.getString(R.string.quickvision_mode_blind_desc)
            READING -> context.getString(R.string.quickvision_mode_reading_desc)
            TRANSLATE -> context.getString(R.string.quickvision_mode_translate_desc)
            ENCYCLOPEDIA -> context.getString(R.string.quickvision_mode_encyclopedia_desc)
            CUSTOM -> context.getString(R.string.quickvision_mode_custom_desc)
        }
    }


    /**
     * 获取模式对应的提示词（不包括翻译和自定义，这两个需要动态生成）
     */
    fun getPrompt(context: Context): String {
        return when (this) {
            STANDARD -> context.getString(R.string.prompt_quickvision_standard)
            HEALTH -> context.getString(R.string.prompt_quickvision_health)
            BLIND -> context.getString(R.string.prompt_quickvision_blind)
            READING -> context.getString(R.string.prompt_quickvision_reading)
            TRANSLATE -> "" // 需要通过 Manager 获取（包含目标语言）
            ENCYCLOPEDIA -> context.getString(R.string.prompt_quickvision_encyclopedia)
            CUSTOM -> "" // 需要通过 Manager 获取自定义内容
        }
    }

    companion object {
        fun fromId(id: String): QuickVisionMode {
            return entries.find { it.id == id } ?: STANDARD
        }
    }
}
