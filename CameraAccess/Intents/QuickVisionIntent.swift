/*
 * Quick Vision Intent
 * App Intent - 支持 Siri 和快捷指令触发快速识图
 *
 * 使用方式：
 * 1. Siri: "嘿 Siri，用 TurboMeta 识图"
 * 2. 快捷指令：添加 "TurboMeta 快速识图" 动作
 * 3. 锁屏快捷方式
 */

import AppIntents
import UIKit
import SwiftUI

// MARK: - Quick Vision Intent

@available(iOS 16.0, *)
struct QuickVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "快速识图"
    static var description = IntentDescription("使用 Ray-Ban Meta 眼镜拍照并识别图像内容")

    // 尝试后台运行（但 SDK 可能需要前台）
    // 设为 false 可以在锁屏时尝试执行，但视频流可能受限
    static var openAppWhenRun: Bool = false

    // Intent 参数（可选）
    @Parameter(title: "自定义提示")
    var customPrompt: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        print("🚀 [QuickVisionIntent] Intent triggered (background mode)")

        // 检查 QuickVisionManager 是否已初始化
        let manager = QuickVisionManager.shared

        // 如果 streamViewModel 没有设置，说明 App 未完全初始化
        // 此时需要打开 App
        if manager.streamViewModel == nil {
            print("⚠️ [QuickVisionIntent] App not initialized, sending notification")
            // 发送通知，让 App 打开并执行快速识图
            NotificationCenter.default.post(
                name: .quickVisionTriggered,
                object: nil,
                userInfo: ["customPrompt": customPrompt as Any]
            )
            return .result(dialog: "正在启动快速识图，请稍候...")
        }

        // App 已初始化，直接执行
        print("🚀 [QuickVisionIntent] App initialized, executing directly")
        await manager.performQuickVisionFromIntent(customPrompt: customPrompt)

        if let result = manager.lastResult {
            return .result(dialog: "识别完成：\(result)")
        } else if let error = manager.errorMessage {
            return .result(dialog: "识别失败：\(error)")
        } else {
            return .result(dialog: "识别完成")
        }
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct TurboMetaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickVisionIntent(),
            phrases: [
                "用 \(.applicationName) 识图",
                "用 \(.applicationName) 看看这是什么",
                "\(.applicationName) 快速识图",
                "\(.applicationName) 拍照识别",
                "\(.applicationName) 帮我识别眼前的东西"
            ],
            shortTitle: "快速识图",
            systemImageName: "eye.circle.fill"
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

    // 公开 streamViewModel 用于 Intent 检查初始化状态
    private(set) var streamViewModel: StreamSessionViewModel?
    private let tts = TTSService.shared

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
        Task { @MainActor in
            // 从快捷指令触发时，完成后自动停止流
            await performQuickVisionFromIntent(customPrompt: customPrompt)
        }
    }

    /// 执行快速识图
    /// 流程：启动流 -> 拍照 -> 停止流 -> 识图 -> TTS播报
    func performQuickVision(customPrompt: String? = nil) async {
        guard !isProcessing else {
            print("⚠️ [QuickVision] Already processing")
            return
        }

        guard let streamViewModel = streamViewModel else {
            print("❌ [QuickVision] StreamViewModel not set")
            tts.speak("识图功能未初始化，请先打开应用")
            return
        }

        isProcessing = true
        errorMessage = nil
        lastResult = nil

        // 获取 API Key（后面 TTS 也要用）
        guard let apiKey = APIKeyManager.shared.getAPIKey(), !apiKey.isEmpty else {
            errorMessage = "请先在设置中配置 API Key"
            tts.speak("请先在设置中配置 API Key")
            isProcessing = false
            return
        }

        // 播报开始
        tts.speak("正在识别", apiKey: apiKey)

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

            // 5. 预配置 TTS 音频会话（在停止流之前，避免会话冲突）
            tts.prepareAudioSession()

            // 6. 立即停止视频流（不再需要）
            print("🛑 [QuickVision] Stopping stream after capture")
            await streamViewModel.stopSession()

            // 7. 调用识图 API（使用开头获取的 apiKey）
            let service = QuickVisionService(apiKey: apiKey)
            let result = try await service.analyzeImage(photo, customPrompt: customPrompt)

            // 8. 保存结果
            lastResult = result

            // 9. TTS 播报结果
            tts.speak(result, apiKey: apiKey)

            print("✅ [QuickVision] Complete: \(result)")

        } catch let error as QuickVisionError {
            errorMessage = error.localizedDescription
            print("❌ [QuickVision] QuickVisionError: \(error)")
            tts.speak(error.localizedDescription, apiKey: apiKey)
            // 出错也要停止流
            await streamViewModel.stopSession()
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [QuickVision] Error: \(error)")
            tts.speak("识别失败，\(error.localizedDescription)", apiKey: apiKey)
            // 出错也要停止流
            await streamViewModel.stopSession()
        }

        isProcessing = false
    }

    /// 执行快速识图（从快捷指令/Siri 触发）
    /// 与 performQuickVision 相同，流已在识别完成后停止
    func performQuickVisionFromIntent(customPrompt: String? = nil) async {
        await performQuickVision(customPrompt: customPrompt)
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
}
