/*
 * Quick Vision Intent
 * App Intent - 支持 Siri 和快捷指令触发快速识图
 *
 * 支持的模式：
 * - 默认模式：通用图像描述
 * - 健康识图：分析食品健康程度
 * - 盲人模式：为视障用户描述环境
 * - 阅读模式：识别并朗读文字
 * - 翻译模式：识别并翻译文字
 * - 百科模式：百科知识介绍
 * - 自定义：使用自定义提示词
 */

import AppIntents
import UIKit
import SwiftUI

// MARK: - Quick Vision Intent (Default Mode)

@available(iOS 16.0, *)
struct QuickVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "快速识图"
    static var description = IntentDescription("使用 Ray-Ban Meta 眼镜拍照并识别图像内容")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "自定义提示")
    var customPrompt: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.standard, customPrompt: customPrompt)
        return formatResult(manager)
    }
}

// MARK: - Health Mode Intent

@available(iOS 16.0, *)
struct QuickVisionHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "健康识图"
    static var description = IntentDescription("分析食品/饮料的健康程度")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.health)
        return formatResult(manager)
    }
}

// MARK: - Blind Mode Intent

@available(iOS 16.0, *)
struct QuickVisionBlindIntent: AppIntent {
    static var title: LocalizedStringResource = "环境描述"
    static var description = IntentDescription("为视障用户详细描述眼前的环境")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.blind)
        return formatResult(manager)
    }
}

// MARK: - Reading Mode Intent

@available(iOS 16.0, *)
struct QuickVisionReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "朗读文字"
    static var description = IntentDescription("识别并朗读图片中的文字内容")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.reading)
        return formatResult(manager)
    }
}

// MARK: - Translation Mode Intent

@available(iOS 16.0, *)
struct QuickVisionTranslateIntent: AppIntent {
    static var title: LocalizedStringResource = "翻译文字"
    static var description = IntentDescription("识别并翻译图片中的外语文字")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.translate)
        return formatResult(manager)
    }
}

// MARK: - Encyclopedia Mode Intent

@available(iOS 16.0, *)
struct QuickVisionEncyclopediaIntent: AppIntent {
    static var title: LocalizedStringResource = "百科识别"
    static var description = IntentDescription("识别物体并提供百科知识介绍")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = QuickVisionManager.shared
        await manager.performQuickVisionWithMode(.encyclopedia)
        return formatResult(manager)
    }
}

// MARK: - Helper Function

@available(iOS 16.0, *)
@MainActor
private func formatResult(_ manager: QuickVisionManager) -> some IntentResult & ProvidesDialog {
    if let result = manager.lastResult {
        return .result(dialog: "识别完成：\(result)")
    } else if let error = manager.errorMessage {
        return .result(dialog: "识别失败：\(error)")
    } else {
        return .result(dialog: "识别完成")
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct TurboMetaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // 默认识图
        AppShortcut(
            intent: QuickVisionIntent(),
            phrases: [
                "用 \(.applicationName) 识图",
                "用 \(.applicationName) 看看这是什么",
                "\(.applicationName) 快速识图",
                "\(.applicationName) 拍照识别"
            ],
            shortTitle: "快速识图",
            systemImageName: "eye.circle.fill"
        )

        // 健康识图
        AppShortcut(
            intent: QuickVisionHealthIntent(),
            phrases: [
                "用 \(.applicationName) 分析健康",
                "\(.applicationName) 健康识图",
                "\(.applicationName) 这个食物健康吗"
            ],
            shortTitle: "健康识图",
            systemImageName: "heart.circle.fill"
        )

        // 盲人模式
        AppShortcut(
            intent: QuickVisionBlindIntent(),
            phrases: [
                "用 \(.applicationName) 描述环境",
                "\(.applicationName) 看看周围有什么",
                "\(.applicationName) 帮我看看前面"
            ],
            shortTitle: "环境描述",
            systemImageName: "figure.walk.circle.fill"
        )

        // 阅读模式
        AppShortcut(
            intent: QuickVisionReadingIntent(),
            phrases: [
                "用 \(.applicationName) 朗读文字",
                "\(.applicationName) 读一下这个",
                "\(.applicationName) 帮我读文字"
            ],
            shortTitle: "朗读文字",
            systemImageName: "text.viewfinder"
        )

        // 翻译模式
        AppShortcut(
            intent: QuickVisionTranslateIntent(),
            phrases: [
                "用 \(.applicationName) 翻译",
                "\(.applicationName) 翻译这个",
                "\(.applicationName) 这个是什么意思"
            ],
            shortTitle: "翻译文字",
            systemImageName: "character.bubble.fill"
        )

        // 百科模式
        AppShortcut(
            intent: QuickVisionEncyclopediaIntent(),
            phrases: [
                "用 \(.applicationName) 介绍这个",
                "\(.applicationName) 百科识别",
                "\(.applicationName) 这是什么东西"
            ],
            shortTitle: "百科识别",
            systemImageName: "books.vertical.circle.fill"
        )

        // 实时对话
        AppShortcut(
            intent: LiveAIIntent(),
            phrases: [
                "用 \(.applicationName) 实时对话",
                "\(.applicationName) 实时对话",
                "开始 \(.applicationName) 实时对话",
                "\(.applicationName) 开始对话"
            ],
            shortTitle: "实时对话",
            systemImageName: "brain.head.profile"
        )

        // 停止实时对话
        AppShortcut(
            intent: StopLiveAIIntent(),
            phrases: [
                "\(.applicationName) 停止实时对话",
                "停止 \(.applicationName) 实时对话",
                "\(.applicationName) 结束对话"
            ],
            shortTitle: "停止实时对话",
            systemImageName: "stop.circle.fill"
        )
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let quickVisionTriggered = Notification.Name("quickVisionTriggered")
}

// MARK: - Quick Vision Manager

@MainActor
class QuickVisionManager: ObservableObject {
    static let shared = QuickVisionManager()

    @Published var isProcessing = false
    @Published var lastResult: String?
    @Published var errorMessage: String?
    @Published var lastImage: UIImage?
    @Published var lastMode: QuickVisionMode = .standard

    // 公开 streamViewModel 用于 Intent 检查初始化状态
    private(set) var streamViewModel: StreamSessionViewModel?
    private let tts = TTSService.shared

    // 超时保护：如果处理时间超过这个值，自动重置状态
    private let processingTimeout: TimeInterval = 60 // 60秒超时
    private var processingStartTime: Date?
    private var timeoutCheckTimer: Timer?

    private init() {
        // 监听 Intent 触发
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQuickVisionTrigger(_:)),
            name: .quickVisionTriggered,
            object: nil
        )
    }

    /// 设置 StreamSessionViewModel 引用
    func setStreamViewModel(_ viewModel: StreamSessionViewModel) {
        self.streamViewModel = viewModel
    }

    @objc private func handleQuickVisionTrigger(_ notification: Notification) {
        let customPrompt = notification.userInfo?["customPrompt"] as? String
        let modeString = notification.userInfo?["mode"] as? String
        let mode = modeString.flatMap { QuickVisionMode(rawValue: $0) } ?? .standard

        Task { @MainActor in
            await performQuickVisionWithMode(mode, customPrompt: customPrompt)
        }
    }

    /// 使用指定模式执行快速识图
    func performQuickVisionWithMode(_ mode: QuickVisionMode, customPrompt: String? = nil) async {
        // 检查是否已在处理中，如果是则检查是否超时
        if isProcessing {
            if let startTime = processingStartTime,
               Date().timeIntervalSince(startTime) > processingTimeout {
                // 超时，重置状态
                print("⏰ [QuickVision] Processing timeout detected, resetting state")
                resetProcessingState()
            } else {
                print("⚠️ [QuickVision] Already processing")
                return
            }
        }

        guard let streamViewModel = streamViewModel else {
            print("❌ [QuickVision] StreamViewModel not set")
            tts.speak("识图功能未初始化，请先打开应用")
            return
        }

        // 开始处理
        isProcessing = true
        processingStartTime = Date()
        errorMessage = nil
        lastResult = nil
        lastImage = nil
        lastMode = mode

        // 启动超时检查定时器
        startTimeoutCheck()

        // 获取 API Key
        let apiKey = APIProviderManager.staticAPIKey
        guard !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 API Key"
            tts.speak("请先在设置中配置 API Key")
            isProcessing = false
            return
        }

        // 播报开始
        tts.speak("正在识别", apiKey: apiKey)

        // 获取提示词
        let prompt = customPrompt ?? QuickVisionModeManager.shared.getPrompt(for: mode)

        do {
            // 0. 检查设备是否已连接
            if !streamViewModel.hasActiveDevice {
                print("❌ [QuickVision] No active device connected")
                throw QuickVisionError.noDevice
            }

            // 1. 启动视频流（如果未启动）
            if streamViewModel.streamingStatus != .streaming {
                print("📹 [QuickVision] Starting stream...")
                await streamViewModel.handleStartStreaming()

                // 等待流进入 streaming 状态（最多 5 秒）
                var streamWait = 0
                while streamViewModel.streamingStatus != .streaming && streamWait < 50 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    streamWait += 1
                }

                if streamViewModel.streamingStatus != .streaming {
                    print("❌ [QuickVision] Failed to start streaming")
                    throw QuickVisionError.streamNotReady
                }
            }

            // 2. 等待流稳定
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            // 3. 清除之前的照片，然后拍照
            streamViewModel.dismissPhotoPreview()
            print("📸 [QuickVision] Capturing photo...")
            streamViewModel.capturePhoto()

            // 4. 等待照片捕获完成（最多 3 秒）
            var photoWait = 0
            while streamViewModel.capturedPhoto == nil && photoWait < 30 {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                photoWait += 1
            }

            // 如果 SDK capturePhoto 失败，使用当前视频帧作为备选
            let photo: UIImage
            if let capturedPhoto = streamViewModel.capturedPhoto {
                photo = capturedPhoto
                print("📸 [QuickVision] Using SDK captured photo")
            } else if let videoFrame = streamViewModel.currentVideoFrame {
                photo = videoFrame
                print("📸 [QuickVision] SDK capturePhoto failed, using video frame as fallback")
            } else {
                print("❌ [QuickVision] No photo or video frame available")
                throw QuickVisionError.frameTimeout
            }

            print("📸 [QuickVision] Photo captured: \(photo.size.width)x\(photo.size.height)")

            // 保存图片用于历史记录
            lastImage = photo

            // 5. 预配置 TTS 音频会话
            tts.prepareAudioSession()

            // 6. 立即停止视频流
            print("🛑 [QuickVision] Stopping stream after capture")
            await streamViewModel.stopSession()

            // 7. 调用识图 API
            let service = QuickVisionService(apiKey: apiKey)
            let result = try await service.analyzeImage(photo, customPrompt: prompt)

            // 8. 保存结果
            lastResult = result

            // 9. 保存到历史记录
            saveToHistory(mode: mode, prompt: prompt, result: result, image: photo)

            // 10. TTS 播报结果
            tts.speak(result, apiKey: apiKey)

            print("✅ [QuickVision] Complete: \(result)")

        } catch let error as QuickVisionError {
            errorMessage = error.localizedDescription
            print("❌ [QuickVision] QuickVisionError: \(error)")
            tts.speak(error.localizedDescription, apiKey: apiKey)
            await streamViewModel.stopSession()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [QuickVision] Error: \(error)")
            tts.speak("识别失败，\(error.localizedDescription)", apiKey: apiKey)
            await streamViewModel.stopSession()
        }

        // 处理完成，清理状态
        resetProcessingState()
    }

    // MARK: - Helper Methods

    /// 重置处理状态
    private func resetProcessingState() {
        isProcessing = false
        processingStartTime = nil
        timeoutCheckTimer?.invalidate()
        timeoutCheckTimer = nil
    }

    /// 启动超时检查定时器
    private func startTimeoutCheck() {
        timeoutCheckTimer?.invalidate()
        timeoutCheckTimer = Timer.scheduledTimer(withTimeInterval: processingTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isProcessing else { return }
                print("⏰ [QuickVision] Processing timeout reached, forcing reset")
                self.tts.speak("识别超时，请重试")
                self.resetProcessingState()
            }
        }
    }

    /// 执行快速识图（使用当前设置的模式）
    func performQuickVision(customPrompt: String? = nil) async {
        await performQuickVisionWithMode(QuickVisionModeManager.staticCurrentMode, customPrompt: customPrompt)
    }

    /// 执行快速识图（从快捷指令/Siri 触发）
    func performQuickVisionFromIntent(customPrompt: String? = nil) async {
        await performQuickVision(customPrompt: customPrompt)
    }

    /// 保存识图结果到历史记录
    private func saveToHistory(mode: QuickVisionMode, prompt: String, result: String, image: UIImage) {
        let record = QuickVisionRecord(
            mode: mode,
            prompt: prompt,
            result: result,
            thumbnail: image
        )
        QuickVisionStorage.shared.saveRecord(record)
        print("💾 [QuickVision] Record saved to history")
    }

    /// 停止视频流（在页面关闭时调用）
    func stopStream() async {
        await streamViewModel?.stopSession()
    }

    /// 手动触发快速识图（从 UI 调用）
    func triggerQuickVision(customPrompt: String? = nil) {
        Task { @MainActor in
            await performQuickVision(customPrompt: customPrompt)
        }
    }

    /// 手动触发指定模式的快速识图（从 UI 调用）
    func triggerQuickVisionWithMode(_ mode: QuickVisionMode) {
        Task { @MainActor in
            await performQuickVisionWithMode(mode)
        }
    }
}
