/*
 * TurboMeta Home View
 * 主页 - 功能入口
 */

import SwiftUI

struct TurboMetaHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel
    @StateObject private var quickVisionManager = QuickVisionManager.shared
    @StateObject private var liveAIManager = LiveAIManager.shared
    let apiKey: String

    @State private var showLiveAI = false
    @State private var showLiveStream = false
    @State private var showRTMPStreaming = false
    @State private var showLeanEat = false
    @State private var showQuickVision = false
    @State private var showLiveTranslate = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.1),
                        AppColors.secondary.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        VStack(spacing: AppSpacing.sm) {
                            Text("app.name".localized)
                                .font(AppTypography.largeTitle)
                                .foregroundColor(AppColors.textPrimary)

                            Text("app.subtitle".localized)
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, AppSpacing.xl)

                        // Feature Grid
                        VStack(spacing: AppSpacing.md) {
                            // Row 1
                            HStack(spacing: AppSpacing.md) {
                                FeatureCard(
                                    title: "home.liveai.title".localized,
                                    subtitle: "home.liveai.subtitle".localized,
                                    icon: "brain.head.profile",
                                    gradient: [AppColors.liveAI, AppColors.liveAI.opacity(0.7)]
                                ) {
                                    showLiveAI = true
                                }

                                FeatureCard(
                                    title: "home.quickvision.title".localized,
                                    subtitle: "home.quickvision.subtitle".localized,
                                    icon: "eye.circle.fill",
                                    gradient: [Color.purple, Color.purple.opacity(0.7)]
                                ) {
                                    showQuickVision = true
                                }
                            }

                            // Row 2
                            HStack(spacing: AppSpacing.md) {
                                FeatureCard(
                                    title: "home.translate.title".localized,
                                    subtitle: "home.translate.subtitle".localized,
                                    icon: "globe",
                                    gradient: [Color.teal, Color.teal.opacity(0.7)]
                                ) {
                                    showLiveTranslate = true
                                }

                                FeatureCard(
                                    title: "home.leaneat.title".localized,
                                    subtitle: "home.leaneat.subtitle".localized,
                                    icon: "chart.bar.fill",
                                    gradient: [AppColors.leanEat, AppColors.leanEat.opacity(0.7)]
                                ) {
                                    showLeanEat = true
                                }
                            }

                            // Row 3 - RTMP Streaming (Experimental)
                            FeatureCardWide(
                                title: "home.rtmp.title".localized,
                                subtitle: "home.rtmp.subtitle".localized,
                                icon: "antenna.radiowaves.left.and.right",
                                gradient: [Color.red, Color.orange],
                                badge: "home.experimental".localized
                            ) {
                                showRTMPStreaming = true
                            }

                            // Row 4 - Screen Recording Stream
                            FeatureCardWide(
                                title: "home.livestream.title".localized,
                                subtitle: "home.livestream.subtitle".localized,
                                icon: "video.fill",
                                gradient: [AppColors.liveStream, AppColors.liveStream.opacity(0.7)]
                            ) {
                                showLiveStream = true
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showLiveAI) {
                LiveAIView(streamViewModel: streamViewModel, apiKey: apiKey)
            }
            .fullScreenCover(isPresented: $showLiveStream) {
                SimpleLiveStreamView(streamViewModel: streamViewModel)
            }
            .fullScreenCover(isPresented: $showRTMPStreaming) {
                RTMPStreamingView(streamViewModel: streamViewModel)
            }
            .fullScreenCover(isPresented: $showLeanEat) {
                StreamView(viewModel: streamViewModel, wearablesVM: wearablesViewModel)
            }
            .fullScreenCover(isPresented: $showQuickVision) {
                QuickVisionView(streamViewModel: streamViewModel, apiKey: apiKey)
            }
            .fullScreenCover(isPresented: $showLiveTranslate) {
                LiveTranslateView(streamViewModel: streamViewModel)
            }
        }
        .onAppear {
            // 确保 QuickVisionManager 有 streamViewModel 引用
            quickVisionManager.setStreamViewModel(streamViewModel)
            // 确保 LiveAIManager 有 streamViewModel 引用
            liveAIManager.setStreamViewModel(streamViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .liveAITriggered)) { _ in
            // 从快捷指令触发，自动打开 Live AI 界面
            showLiveAI = true
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    var isPlaceholder: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.md) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text
                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                if isPlaceholder {
                    Text("home.comingsoon".localized)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(.white.opacity(0.2))
                        .cornerRadius(AppCornerRadius.sm)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
        }
        .disabled(isPlaceholder)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Feature Card Wide

struct FeatureCardWide: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(title)
                            .font(AppTypography.title2)
                            .foregroundColor(.white)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.25))
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(AppSpacing.lg)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
