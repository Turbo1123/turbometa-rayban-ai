/*
 * Simple Live Stream View
 * 简化的直播视图 - 用于抖音/快手等平台
 */

import SwiftUI

struct SimpleLiveStreamView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showUI = true // 控制 UI 显示/隐藏

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .edgesIgnoringSafeArea(.all)

            // Video feed
            if let videoFrame = streamViewModel.currentVideoFrame {
                GeometryReader { geometry in
                    Image(uiImage: videoFrame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .foregroundColor(.white)
                    Text("正在连接视频流...")
                        .font(AppTypography.body)
                        .foregroundColor(.white)
                }
            }

            // UI 元素 - 点击屏幕可隐藏
            if showUI {
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }

                        Spacer()

                        // Status indicator
                        HStack(spacing: AppSpacing.sm) {
                            Circle()
                                .fill(streamViewModel.isStreaming ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(streamViewModel.isStreaming ? "直播中" : "未连接")
                                .font(AppTypography.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(AppCornerRadius.lg)
                        .padding(AppSpacing.md)
                    }

                    Spacer()

                    // Instructions
                    VStack(spacing: AppSpacing.md) {
                        Text("直播提示")
                            .font(AppTypography.headline)
                            .foregroundColor(.white)

                        Text("1. 打开抖音/快手等直播平台")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text("2. 选择屏幕录制功能")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.8))

                        Text("3. 开始录制此画面即可直播")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(AppSpacing.lg)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(AppCornerRadius.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showUI.toggle()
            }
        }
        .onAppear {
            // 启动视频流
            Task {
                print("🎥 SimpleLiveStreamView: 启动视频流")
                await streamViewModel.handleStartStreaming()
            }
        }
        .onDisappear {
            // 停止视频流
            Task {
                print("🎥 SimpleLiveStreamView: 停止视频流")
                if streamViewModel.streamingStatus != .stopped {
                    await streamViewModel.stopSession()
                }
            }
        }
    }
}
