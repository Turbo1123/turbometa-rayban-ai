package com.smartview.glassai.managers

import android.content.Context
import android.content.SharedPreferences
import com.smartview.glassai.R
import com.smartview.glassai.models.LiveAIMode
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Live AI Mode Manager
 * 实时对话模式管理器 - 管理当前模式、自定义提示词、翻译目标语言
 */
class LiveAIModeManager private constructor(private val context: Context) {

    companion object {
        private const val PREFS_NAME = "live_ai_prefs"
        private const val KEY_MODE = "live_ai_mode"
        private const val KEY_CUSTOM_PROMPT = "live_ai_custom_prompt"
        private const val KEY_TRANSLATE_TARGET_LANGUAGE = "live_ai_translate_target_language"

        @Volatile
        private var instance: LiveAIModeManager? = null

        fun getInstance(context: Context): LiveAIModeManager {
            return instance ?: synchronized(this) {
                instance ?: LiveAIModeManager(context.applicationContext).also { instance = it }
            }
        }

        // 支持的翻译目标语言
        val supportedLanguages: List<Pair<String, String>> = listOf(
            "zh-CN" to "中文",
            "en-US" to "English",
            "ja-JP" to "日本語",
            "ko-KR" to "한국어",
            "fr-FR" to "Français",
            "de-DE" to "Deutsch",
            "es-ES" to "Español",
            "it-IT" to "Italiano",
            "pt-BR" to "Português",
            "ru-RU" to "Русский"
        )
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // 当前模式
    private val _currentMode = MutableStateFlow(loadMode())
    val currentMode: StateFlow<LiveAIMode> = _currentMode.asStateFlow()

    // 自定义提示词
    private val _customPrompt = MutableStateFlow(loadCustomPrompt())
    val customPrompt: StateFlow<String> = _customPrompt.asStateFlow()

    // 翻译目标语言
    private val _translateTargetLanguage = MutableStateFlow(loadTranslateTargetLanguage())
    val translateTargetLanguage: StateFlow<String> = _translateTargetLanguage.asStateFlow()

    private fun loadMode(): LiveAIMode {
        val modeId = prefs.getString(KEY_MODE, LiveAIMode.STANDARD.id) ?: LiveAIMode.STANDARD.id
        return LiveAIMode.fromId(modeId)
    }

    private fun loadCustomPrompt(): String {
        return prefs.getString(KEY_CUSTOM_PROMPT, context.getString(R.string.liveai_custom_default)) ?: ""
    }

    private fun loadTranslateTargetLanguage(): String {
        return prefs.getString(KEY_TRANSLATE_TARGET_LANGUAGE, "zh-CN") ?: "zh-CN"
    }

    fun setMode(mode: LiveAIMode) {
        _currentMode.value = mode
        prefs.edit().putString(KEY_MODE, mode.id).apply()
    }

    fun setCustomPrompt(prompt: String) {
        _customPrompt.value = prompt
        prefs.edit().putString(KEY_CUSTOM_PROMPT, prompt).apply()
    }

    fun setTranslateTargetLanguage(languageCode: String) {
        _translateTargetLanguage.value = languageCode
        prefs.edit().putString(KEY_TRANSLATE_TARGET_LANGUAGE, languageCode).apply()
    }

    /**
     * 获取当前模式的完整系统提示词
     */
    fun getSystemPrompt(): String {
        return when (_currentMode.value) {
            LiveAIMode.CUSTOM -> _customPrompt.value
            LiveAIMode.TRANSLATE -> getTranslatePrompt()
            else -> _currentMode.value.getSystemPrompt(context)
        }
    }

    /**
     * 获取指定模式的系统提示词
     */
    fun getSystemPrompt(mode: LiveAIMode): String {
        return when (mode) {
            LiveAIMode.CUSTOM -> _customPrompt.value
            LiveAIMode.TRANSLATE -> getTranslatePrompt()
            else -> mode.getSystemPrompt(context)
        }
    }

    /**
     * 获取翻译模式的提示词（包含目标语言）
     */
    private fun getTranslatePrompt(): String {
        val targetLanguageName = supportedLanguages.find { it.first == _translateTargetLanguage.value }?.second ?: "中文"
        val basePrompt = context.getString(R.string.prompt_liveai_translate)
        return basePrompt.replace("{LANGUAGE}", targetLanguageName)
    }

    /**
     * 获取目标语言名称
     */
    fun getTranslateTargetLanguageName(): String {
        return supportedLanguages.find { it.first == _translateTargetLanguage.value }?.second ?: "中文"
    }

    /**
     * 是否在语音触发时自动发送图片
     */
    fun autoSendImageOnSpeech(): Boolean {
        return _currentMode.value.autoSendImageOnSpeech()
    }
}
