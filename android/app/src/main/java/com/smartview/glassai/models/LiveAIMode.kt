package com.smartview.glassai.models

import android.content.Context
import com.smartview.glassai.R

/**
 * Live AI Modes
 * 实时对话模式 - 不同场景的对话助手
 */
enum class LiveAIMode(val id: String) {
    STANDARD("standard"),   // 默认模式 - 自由对话
    MUSEUM("museum"),       // 博物馆模式
    BLIND("blind"),         // 盲人模式
    READING("reading"),     // 阅读模式
    TRANSLATE("translate"), // 翻译模式
    CUSTOM("custom");       // 自定义提示词

    fun getDisplayName(context: Context): String {
        return when (this) {
            STANDARD -> context.getString(R.string.liveai_mode_standard)
            MUSEUM -> context.getString(R.string.liveai_mode_museum)
            BLIND -> context.getString(R.string.liveai_mode_blind)
            READING -> context.getString(R.string.liveai_mode_reading)
            TRANSLATE -> context.getString(R.string.liveai_mode_translate)
            CUSTOM -> context.getString(R.string.liveai_mode_custom)
        }
    }

    fun getDescription(context: Context): String {
        return when (this) {
            STANDARD -> context.getString(R.string.liveai_mode_standard_desc)
            MUSEUM -> context.getString(R.string.liveai_mode_museum_desc)
            BLIND -> context.getString(R.string.liveai_mode_blind_desc)
            READING -> context.getString(R.string.liveai_mode_reading_desc)
            TRANSLATE -> context.getString(R.string.liveai_mode_translate_desc)
            CUSTOM -> context.getString(R.string.liveai_mode_custom_desc)
        }
    }


    /**
     * 获取模式对应的系统提示词（不包括翻译和自定义，这两个需要动态生成）
     */
    fun getSystemPrompt(context: Context): String {
        return when (this) {
            STANDARD -> context.getString(R.string.prompt_liveai_standard)
            MUSEUM -> context.getString(R.string.prompt_liveai_museum)
            BLIND -> context.getString(R.string.prompt_liveai_blind)
            READING -> context.getString(R.string.prompt_liveai_reading)
            TRANSLATE -> "" // 需要通过 Manager 获取（包含目标语言）
            CUSTOM -> "" // 需要通过 Manager 获取自定义内容
        }
    }

    /**
     * 是否在用户说话时自动发送图片
     */
    fun autoSendImageOnSpeech(): Boolean {
        return when (this) {
            STANDARD -> true  // 默认模式：语音触发时发送图片
            MUSEUM, BLIND, READING, TRANSLATE -> true  // 这些模式都需要看图
            CUSTOM -> true  // 自定义模式也支持图片
        }
    }

    companion object {
        fun fromId(id: String): LiveAIMode {
            return entries.find { it.id == id } ?: STANDARD
        }
    }
}
