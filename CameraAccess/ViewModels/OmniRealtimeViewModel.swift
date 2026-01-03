/*
 * Omni Realtime ViewModel
 * Manages real-time multimodal conversation with AI
 */

import Foundation
import SwiftUI
import AVFoundation

@MainActor
class OmniRealtimeViewModel: ObservableObject {

    // Published state
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isSpeaking = false
    @Published var currentTranscript = ""
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var audioInputLevel: Float = 0
    @Published var audioRouteInfo: String = "未获取"
    @Published var audioFrameCount: Int = 0
    @Published var lastAudioFrameAt: Date?

    // Service
    private var omniService: OmniRealtimeService
    private let apiKey: String

    // Video frame
    private var currentVideoFrame: UIImage?
    private var isImageSendingEnabled = false // 是否已启用图片发送（第一次音频后）

    init(apiKey: String) {
        self.apiKey = apiKey
        self.omniService = OmniRealtimeService(apiKey: apiKey)
        setupCallbacks()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        omniService.onConnected = { [weak self] in
            Task { @MainActor in
                self?.isConnected = true
            }
        }

        omniService.onFirstAudioSent = { [weak self] in
            Task { @MainActor in
                print("✅ [OmniVM] 收到第一次音频发送回调，启用图片发送")
                // 延迟1秒后启用图片发送能力（确保音频已到达）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.isImageSendingEnabled = true
                    print("📸 [OmniVM] 图片发送已启用，等待用户语音触发")
                }
            }
        }

        omniService.onSpeechStarted = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = true

                // 用户语音触发模式：检测到用户开始说话时，发送一帧图片
                if let strongSelf = self,
                   strongSelf.isImageSendingEnabled,
                   let frame = strongSelf.currentVideoFrame {
                    print("🎤📸 [OmniVM] 检测到用户语音，发送当前视频帧")
                    strongSelf.omniService.sendImageAppend(frame)
                }
            }
        }

        omniService.onSpeechStopped = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
            }
        }

        omniService.onTranscriptDelta = { [weak self] delta in
            Task { @MainActor in
                print("📝 [OmniVM] AI回复片段: \(delta)")
                self?.currentTranscript += delta
            }
        }

        omniService.onUserTranscript = { [weak self] userText in
            Task { @MainActor in
                guard let self = self else { return }
                print("💬 [OmniVM] 保存用户语音: \(userText)")
                self.conversationHistory.append(
                    ConversationMessage(role: .user, content: userText)
                )
            }
        }

        omniService.onTranscriptDone = { [weak self] fullText in
            Task { @MainActor in
                guard let self = self else { return }
                // 使用累积的currentTranscript，因为done事件可能不包含text字段
                let textToSave = fullText.isEmpty ? self.currentTranscript : fullText
                guard !textToSave.isEmpty else {
                    print("⚠️ [OmniVM] AI回复为空，跳过保存")
                    return
                }
                print("💬 [OmniVM] 保存AI回复: \(textToSave)")
                self.conversationHistory.append(
                    ConversationMessage(role: .assistant, content: textToSave)
                )
                self.currentTranscript = ""
            }
        }

        omniService.onAudioDone = { [weak self] in
            Task { @MainActor in
                // Audio playback complete
            }
        }

        omniService.onError = { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error
                self?.showError = true
            }
        }

        omniService.onAudioInputLevel = { [weak self] level in
            Task { @MainActor in
                self?.audioInputLevel = level
            }
        }

        omniService.onAudioRouteInfo = { [weak self] info in
            Task { @MainActor in
                self?.audioRouteInfo = info
            }
        }

        omniService.onAudioFrameStats = { [weak self] count, lastAt in
            Task { @MainActor in
                self?.audioFrameCount = count
                self?.lastAudioFrameAt = lastAt
            }
        }
    }

    // MARK: - Connection

    func connect() {
        omniService.connect()
    }

    func disconnect() {
        // Save conversation before disconnecting
        saveConversation()

        stopRecording()
        omniService.disconnect()
        isConnected = false
        isImageSendingEnabled = false
    }

    private func saveConversation() {
        // Only save if there's meaningful conversation
        guard !conversationHistory.isEmpty else {
            print("💬 [OmniVM] 无对话内容，跳过保存")
            return
        }

        let record = ConversationRecord(
            messages: conversationHistory,
            aiModel: "qwen3-omni-flash-realtime",
            language: "zh-CN" // TODO: 从设置中获取
        )

        ConversationStorage.shared.saveConversation(record)
        print("💾 [OmniVM] 对话已保存: \(conversationHistory.count) 条消息")
    }

    // MARK: - Recording

    func startRecording() {
        guard isConnected else {
            print("⚠️ [OmniVM] 未连接，无法开始录音")
            errorMessage = "请先连接服务器"
            showError = true
            return
        }

        print("🎤 [OmniVM] 开始录音（语音触发模式）")
        omniService.startRecording()
        isRecording = true
    }

    func stopRecording() {
        print("🛑 [OmniVM] 停止录音")
        omniService.stopRecording()
        isRecording = false
    }

    // MARK: - Video Frames

    func updateVideoFrame(_ frame: UIImage) {
        currentVideoFrame = frame
    }

    // MARK: - Manual Mode (if needed)

    func sendMessage() {
        omniService.commitAudioBuffer()
    }

    // MARK: - Cleanup

    func dismissError() {
        showError = false
    }

    nonisolated deinit {
        Task { @MainActor [weak omniService] in
            omniService?.disconnect()
        }
    }
}

// MARK: - Conversation Message

struct ConversationMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp = Date()

    enum MessageRole {
        case user
        case assistant
    }
}
