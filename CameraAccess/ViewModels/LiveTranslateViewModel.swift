/*
 * Live Translate ViewModel
 * 实时翻译状态管理
 */

import Foundation
import SwiftUI
import UIKit

// MARK: - Constants

private enum TranslateConstants {
    static let imageSendInterval: TimeInterval = 0.5
    static let maxHistoryCount = 50
    static let reconnectDelay: TimeInterval = 0.3
}

@MainActor
class LiveTranslateViewModel: ObservableObject {

    // MARK: - Connection State
    @Published var isConnected = false
    @Published var isRecording = false

    // MARK: - Translation State
    @Published var currentTranslation = ""       // 当前翻译结果
    @Published var currentOriginal = ""          // 当前原文（暂不支持，保留字段）
    @Published var streamingTranslation = ""     // 流式翻译片段
    @Published var translationHistory: [TranslateRecord] = []

    // MARK: - Error State
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Settings (持久化)
    @Published var sourceLanguage: TranslateLanguage {
        didSet {
            UserDefaults.standard.set(sourceLanguage.rawValue, forKey: "translate_source_language")
            updateServiceSettings()
        }
    }

    @Published var targetLanguage: TranslateLanguage {
        didSet {
            UserDefaults.standard.set(targetLanguage.rawValue, forKey: "translate_target_language")
            updateServiceSettings()
        }
    }

    @Published var selectedVoice: TranslateVoice {
        didSet {
            UserDefaults.standard.set(selectedVoice.rawValue, forKey: "translate_voice")
            updateServiceSettings()
        }
    }

    @Published var audioOutputEnabled: Bool {
        didSet {
            UserDefaults.standard.set(audioOutputEnabled, forKey: "translate_audio_enabled")
            updateServiceSettings()
        }
    }

    @Published var imageEnhanceEnabled: Bool {
        didSet {
            UserDefaults.standard.set(imageEnhanceEnabled, forKey: "translate_image_enhance")
        }
    }

    /// 使用 iPhone 麦克风（而非眼镜麦克风）
    /// 眼镜麦克风适合翻译自己说的话，iPhone 麦克风适合翻译对方说的话
    @Published var usePhoneMic: Bool {
        didSet {
            UserDefaults.standard.set(usePhoneMic, forKey: "translate_use_phone_mic")
        }
    }

    // MARK: - Video Frame (for image enhancement)
    var currentVideoFrame: UIImage?

    // MARK: - Private
    private var translateService: LiveTranslateService?
    private var imageTimer: Timer?

    // MARK: - Init

    init() {
        // 从 UserDefaults 加载设置
        let savedSource = UserDefaults.standard.string(forKey: "translate_source_language") ?? "en"
        self.sourceLanguage = TranslateLanguage(rawValue: savedSource) ?? .en

        let savedTarget = UserDefaults.standard.string(forKey: "translate_target_language") ?? "zh"
        self.targetLanguage = TranslateLanguage(rawValue: savedTarget) ?? .zh

        let savedVoice = UserDefaults.standard.string(forKey: "translate_voice") ?? "Cherry"
        self.selectedVoice = TranslateVoice(rawValue: savedVoice) ?? .cherry

        self.audioOutputEnabled = UserDefaults.standard.object(forKey: "translate_audio_enabled") as? Bool ?? true
        self.imageEnhanceEnabled = UserDefaults.standard.object(forKey: "translate_image_enhance") as? Bool ?? false
        self.usePhoneMic = UserDefaults.standard.object(forKey: "translate_use_phone_mic") as? Bool ?? false
    }

    // MARK: - Connection

    func connect() {
        let apiKey = APIProviderManager.staticLiveAIAPIKey
        guard !apiKey.isEmpty else {
            errorMessage = "livetranslate.error.noApiKey".localized
            showError = true
            return
        }

        translateService = LiveTranslateService(apiKey: apiKey)
        setupCallbacks()

        translateService?.updateSettings(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            voice: selectedVoice,
            audioEnabled: audioOutputEnabled
        )

        translateService?.connect()
    }

    func disconnect() {
        stopImageTimer()
        translateService?.disconnect()
        translateService = nil
        isConnected = false
        isRecording = false
    }

    // MARK: - Recording

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        translateService?.startRecording(usePhoneMic: usePhoneMic)
        isRecording = true

        // 如果启用图像增强，开始定时发送图片
        if imageEnhanceEnabled {
            startImageTimer()
        }
    }

    func stopRecording() {
        translateService?.stopRecording()
        isRecording = false
        stopImageTimer()

        // 保存当前翻译到历史
        if !currentTranslation.isEmpty {
            let record = TranslateRecord(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                originalText: currentOriginal,
                translatedText: currentTranslation
            )
            translationHistory.insert(record, at: 0)

            // 限制历史记录数量
            if translationHistory.count > TranslateConstants.maxHistoryCount {
                translationHistory = Array(translationHistory.prefix(TranslateConstants.maxHistoryCount))
            }
        }
    }

    // MARK: - Language Swap

    func swapLanguages() {
        // 只有当两种语言都支持作为目标语言时才能交换
        guard sourceLanguage.supportsAudioOutput && targetLanguage.supportsAudioOutput else {
            errorMessage = "livetranslate.error.cannotSwap".localized
            showError = true
            return
        }

        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp

        // 清空当前翻译
        currentTranslation = ""
        streamingTranslation = ""
    }

    // MARK: - Video Frame

    func updateVideoFrame(_ frame: UIImage) {
        currentVideoFrame = frame
    }

    // MARK: - Private Methods

    private func setupCallbacks() {
        translateService?.onConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = true
                print("✅ [TranslateVM] 已连接")
            }
        }

        translateService?.onTranslationDelta = { [weak self] delta in
            DispatchQueue.main.async {
                self?.streamingTranslation += delta
            }
        }

        translateService?.onTranslationText = { [weak self] text in
            DispatchQueue.main.async {
                self?.currentTranslation = text
                self?.streamingTranslation = ""
            }
        }

        translateService?.onAudioDone = { [weak self] in
            DispatchQueue.main.async {
                print("🔊 [TranslateVM] 音频播放完成")
            }
        }

        translateService?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error
                self?.showError = true
            }
        }
    }

    private func updateServiceSettings() {
        // 如果已连接，需要断开并重新连接以应用新设置
        // 因为 LiveTranslate 不支持在会话进行中更新配置
        if isConnected {
            print("🔄 [TranslateVM] 设置已更改，正在重新连接...")
            disconnect()
            // 短暂延迟后重新连接
            DispatchQueue.main.asyncAfter(deadline: .now() + TranslateConstants.reconnectDelay) { [weak self] in
                self?.connect()
            }
        } else {
            // 未连接时只更新本地设置
            translateService?.updateSettings(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                voice: selectedVoice,
                audioEnabled: audioOutputEnabled
            )
        }
    }

    // MARK: - Image Timer

    private func startImageTimer() {
        stopImageTimer()
        imageTimer = Timer.scheduledTimer(withTimeInterval: TranslateConstants.imageSendInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.sendCurrentFrame()
            }
        }
    }

    private func stopImageTimer() {
        imageTimer?.invalidate()
        imageTimer = nil
    }

    private func sendCurrentFrame() {
        guard imageEnhanceEnabled, let frame = currentVideoFrame else { return }
        translateService?.sendImageFrame(frame)
    }

    // MARK: - Clear

    func clearTranslation() {
        currentTranslation = ""
        streamingTranslation = ""
        currentOriginal = ""
    }

    func clearHistory() {
        translationHistory.removeAll()
    }
}
