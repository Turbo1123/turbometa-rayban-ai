/*
 * Quick Vision View
 * 快速识图界面 - 一键拍照识别
 */

import SwiftUI

struct QuickVisionView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var quickVisionManager = QuickVisionManager.shared
    @StateObject private var tts = TTSService.shared
    let apiKey: String

    @Environment(\.dismiss) private var dismiss
    @State private var showSiriTip = false

    // Computed properties for button state
    private var buttonDisabled: Bool {
        quickVisionManager.isProcessing || !streamViewModel.hasActiveDevice
    }

    private var buttonText: String {
        if quickVisionManager.isProcessing {
            return "quickvision.processing".localized
        } else if !streamViewModel.hasActiveDevice {
            return "quickvision.glasses.notconnected".localized
        } else {
            return "quickvision.start".localized
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: AppSpacing.xl) {
                    // 视频预览区域
                    videoPreviewSection

                    // 状态和结果
                    statusSection

                    // 操作按钮
                    actionButtons

                    Spacer()

                    // Siri 提示
                    siriTipSection
                }
                .padding()
            }
            .navigationTitle("quickvision.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("close".localized) {
                        Task {
                            tts.stop() // 停止播报
                            await quickVisionManager.stopStream() // 停止视频流
                        }
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSiriTip.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            // 确保 streamViewModel 已设置
            quickVisionManager.setStreamViewModel(streamViewModel)

            // 等待设备连接（最多 2 秒）
            var deviceWait = 0
            while !streamViewModel.hasActiveDevice && deviceWait < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                deviceWait += 1
            }

            guard streamViewModel.hasActiveDevice else {
                print("❌ [QuickVisionView] No device connected")
                return
            }

            // 自动开始识图（包含启动流、拍照、停止流、识别、TTS）
            await quickVisionManager.performQuickVision()
        }
    }

    // MARK: - Video Preview Section

    private var videoPreviewSection: some View {
        ZStack {
            // 优先显示拍摄的照片，其次显示视频流
            if let photo = streamViewModel.capturedPhoto {
                // 显示拍摄的照片
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(AppCornerRadius.lg)
            } else if let frame = streamViewModel.currentVideoFrame {
                // 显示视频流
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(AppCornerRadius.lg)
            } else {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        if !streamViewModel.hasActiveDevice {
                            // 设备未连接
                            VStack(spacing: AppSpacing.md) {
                                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                Text("quickvision.glasses.notconnected".localized)
                                    .font(AppTypography.headline)
                                    .foregroundColor(.white)
                                Text("quickvision.error.nodevice".localized)
                                    .font(AppTypography.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        } else if streamViewModel.streamingStatus == .waiting || quickVisionManager.isProcessing {
                            VStack(spacing: AppSpacing.md) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text(quickVisionManager.isProcessing ? "quickvision.recognizing".localized : "stream.connecting".localized)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else {
                            VStack(spacing: AppSpacing.md) {
                                Image(systemName: "eye.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.purple.opacity(0.7))
                                Text("quickvision.start".localized)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
            }

            // 处理中遮罩（仅在有图片时显示）
            if quickVisionManager.isProcessing && (streamViewModel.capturedPhoto != nil || streamViewModel.currentVideoFrame != nil) {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg)
                    .fill(Color.black.opacity(0.6))
                    .overlay {
                        VStack(spacing: AppSpacing.md) {
                            ProgressView()
                                .scaleEffect(2)
                                .tint(.white)
                            Text("vision.analyzing".localized)
                                .font(AppTypography.headline)
                                .foregroundColor(.white)
                        }
                    }
            }
        }
        .frame(maxHeight: 350)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: AppSpacing.md) {
            // 识别结果
            if let result = quickVisionManager.lastResult {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("quickvision.result".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.white)
                        Spacer()

                        // 重新播报按钮
                        Button {
                            tts.speak(result)
                        } label: {
                            Image(systemName: tts.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundColor(.white)
                                .padding(AppSpacing.sm)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(AppCornerRadius.sm)
                        }
                    }

                    Text(result)
                        .font(AppTypography.body)
                        .foregroundColor(.white.opacity(0.9))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(AppCornerRadius.md)
                }
            }

            // 错误信息
            if let error = quickVisionManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(AppCornerRadius.md)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // 主按钮 - 快速识图
            Button {
                quickVisionManager.triggerQuickVision()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if quickVisionManager.isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "eye.fill")
                    }
                    Text(buttonText)
                }
                .font(AppTypography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(
                    LinearGradient(
                        colors: buttonDisabled ? [.gray, .gray.opacity(0.7)] : [.purple, .purple.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.lg)
            }
            .disabled(buttonDisabled)

            // 停止播报按钮
            if tts.isSpeaking {
                Button {
                    tts.stop()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("quickvision.stop.speaking".localized)
                    }
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white)
                    .padding(.vertical, AppSpacing.md)
                    .padding(.horizontal, AppSpacing.xl)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(AppCornerRadius.md)
                }
            }
        }
    }

    // MARK: - Siri Tip Section

    private var siriTipSection: some View {
        VStack(spacing: AppSpacing.sm) {
            if showSiriTip {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("quickvision.siri.tip.title".localized)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)

                    Text("quickvision.siri.tip.description".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("quickvision.siri.tip.voice".localized)
                        tipRow("quickvision.siri.tip.action".localized)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(AppCornerRadius.lg)
            } else {
                Button {
                    showSiriTip = true
                } label: {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .foregroundColor(.purple)
                        Text("quickvision.siri.support".localized)
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }

    private func tipRow(_ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.purple)
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
