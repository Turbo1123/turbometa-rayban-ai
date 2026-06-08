/*
 * RTMP Streaming View
 * Live streaming interface with video preview and RTMP controls
 *
 * Supports all major streaming platforms:
 * - YouTube Live, Twitch, Bilibili, Douyin, TikTok, Facebook Live
 * - Any custom RTMP server (MediaMTX, nginx-rtmp, etc.)
 */

import SwiftUI
import CoreMedia

struct RTMPStreamingView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @StateObject private var rtmpViewModel = RTMPStreamingViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showUI = true
    @State private var frameTimer: Timer?
    @State private var lastH264Frame: UIImage?
    @State private var lastHEVCPresentationTime: CMTime = .invalid

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Video preview
            if let videoFrame = streamViewModel.currentVideoFrame {
                GeometryReader { geometry in
                    Image(uiImage: videoFrame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else if rtmpViewModel.encodingMode == .hevc && streamViewModel.currentSampleBuffer != nil {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.green)
                    Text("rtmp.hevc.ready".localized)
                        .font(AppTypography.body)
                        .foregroundColor(.white)
                    Text("rtmp.hevc.previewnote".localized)
                        .font(AppTypography.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, AppSpacing.xl)
                }
            } else {
                VStack(spacing: AppSpacing.lg) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("rtmp.connecting.video".localized)
                        .font(AppTypography.body)
                        .foregroundColor(.white)
                }
            }

            // UI Overlay
            if showUI {
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()

                    // Stats (when streaming)
                    if rtmpViewModel.isStreaming {
                        statsView
                            .transition(.opacity)
                    }

                    // Controls
                    controlsView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showUI.toggle()
            }
        }
        .onAppear {
            startVideoStream()
            UIApplication.shared.isIdleTimerDisabled = rtmpViewModel.isStreaming
        }
        .onDisappear {
            stopAll()
        }
        .onChange(of: rtmpViewModel.isStreaming) { _, isStreaming in
            UIApplication.shared.isIdleTimerDisabled = isStreaming
        }
        .sheet(isPresented: $rtmpViewModel.showSettings) {
            RTMPSettingsView(viewModel: rtmpViewModel, streamViewModel: streamViewModel)
        }
        .alert("error".localized, isPresented: $rtmpViewModel.showError) {
            Button("ok".localized) {
                rtmpViewModel.dismissError()
            }
        } message: {
            if let error = rtmpViewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }

            Spacer()

            // Connection status
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(rtmpViewModel.connectionStatus.color)
                    .frame(width: 10, height: 10)

                Text(rtmpViewModel.connectionStatus.displayText)
                    .font(AppTypography.caption)
                    .foregroundColor(.white)

                if rtmpViewModel.isStreaming {
                    // Blinking record indicator
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .modifier(BlinkingModifier())
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.black.opacity(0.6))
            .cornerRadius(AppCornerRadius.lg)

            Spacer()

            // Settings button
            Button {
                rtmpViewModel.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding(AppSpacing.md)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Stats View

    private var statsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.lg) {
                StatItem(label: "FPS", value: String(format: "%.1f", rtmpViewModel.currentFps))
                StatItem(label: "源", value: rtmpViewModel.sourceResolution)
                StatItem(label: "推流", value: rtmpViewModel.outputResolution)
                StatItem(label: "rtmp.frames".localized, value: "\(rtmpViewModel.framesSent)")
                StatItem(label: "rtmp.time".localized, value: formatTime(rtmpViewModel.connectionTime))
            }
            .padding(AppSpacing.md)
        }
        .background(Color.black.opacity(0.6))
        .cornerRadius(AppCornerRadius.md)
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: AppSpacing.md) {
            // Platform selector
            if !rtmpViewModel.isStreaming {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(RTMPStreamingViewModel.StreamingPlatform.allCases, id: \.self) { platform in
                            PlatformButton(
                                platform: platform,
                                isSelected: rtmpViewModel.selectedPlatform == platform
                            ) {
                                rtmpViewModel.selectPlatform(platform)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }

            // URL and Stream Key inputs (when not streaming)
            if !rtmpViewModel.isStreaming && !rtmpViewModel.isConnecting {
                VStack(spacing: AppSpacing.sm) {
                    // RTMP URL
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.white.opacity(0.6))
                        TextField("rtmp.url.placeholder".localized, text: $rtmpViewModel.rtmpUrl)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(AppSpacing.sm)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(AppCornerRadius.sm)

                    // Stream Key
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundColor(.white.opacity(0.6))
                        SecureField("rtmp.key.placeholder".localized, text: $rtmpViewModel.streamKey)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding(AppSpacing.sm)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(AppCornerRadius.sm)
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            // Start/Stop button
            Button {
                if rtmpViewModel.isStreaming {
                    rtmpViewModel.stopStreaming()
                } else {
                    rtmpViewModel.startStreaming(
                        videoFrame: streamViewModel.currentVideoFrame,
                        sampleBuffer: streamViewModel.currentSampleBuffer
                    )
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if rtmpViewModel.isConnecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: rtmpViewModel.isStreaming ? "stop.fill" : "video.fill")
                    }
                    Text(rtmpViewModel.isStreaming ? "rtmp.stop".localized : "rtmp.start".localized)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(rtmpViewModel.isStreaming ? Color.red : AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.md)
            }
            .disabled(
                rtmpViewModel.isConnecting ||
                (rtmpViewModel.rtmpUrl.isEmpty && !rtmpViewModel.isStreaming) ||
                (!rtmpViewModel.isStreaming && !hasStartableVideo)
            )
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.vertical, AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Helper Methods

    private func startVideoStream() {
        Task {
            await streamViewModel.handleStartStreaming()
        }

        // Start feeding frames to RTMP when streaming
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { _ in
            Task { @MainActor in
                guard rtmpViewModel.isStreaming else { return }

                switch rtmpViewModel.encodingMode {
                case .h264:
                    guard let frame = streamViewModel.currentVideoFrame else { return }
                    if let lastH264Frame, lastH264Frame === frame { return }
                    lastH264Frame = frame
                    let timestamp = Int64(Date().timeIntervalSince1970 * 1_000_000)
                    rtmpViewModel.feedFrame(frame, timestamp: timestamp)
                case .hevc:
                    guard let sampleBuffer = streamViewModel.currentSampleBuffer else { return }
                    let presentationTime = sampleBuffer.presentationTimeStamp
                    guard presentationTime != lastHEVCPresentationTime else { return }
                    lastHEVCPresentationTime = presentationTime
                    rtmpViewModel.feedSampleBuffer(sampleBuffer)
                }
            }
        }
    }

    private func stopAll() {
        frameTimer?.invalidate()
        frameTimer = nil
        lastH264Frame = nil
        lastHEVCPresentationTime = .invalid

        if rtmpViewModel.isStreaming {
            rtmpViewModel.stopStreaming()
        }

        UIApplication.shared.isIdleTimerDisabled = false

        Task {
            if streamViewModel.streamingStatus != .stopped {
                await streamViewModel.stopSession()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    private var hasStartableVideo: Bool {
        switch rtmpViewModel.encodingMode {
        case .h264:
            return streamViewModel.currentVideoFrame != nil
        case .hevc:
            return streamViewModel.currentSampleBuffer != nil
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTypography.headline)
                .foregroundColor(.white)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct PlatformButton: View {
    let platform: RTMPStreamingViewModel.StreamingPlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: platform.icon)
                    .font(.system(size: 20))
                Text(platform.displayName)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(isSelected ? AppColors.primary : Color.white.opacity(0.1))
            .foregroundColor(.white)
            .cornerRadius(AppCornerRadius.sm)
        }
    }
}

struct BlinkingModifier: ViewModifier {
    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - RTMP Settings View

struct RTMPSettingsView: View {
    @ObservedObject var viewModel: RTMPStreamingViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("video_quality") private var videoQuality = "high"
    @AppStorage("rtmp_video_codec") private var rtmpVideoCodec = RTMPVideoEncodingMode.h264.rawValue

    let bitrateOptions = [
        (4_000_000, "4 Mbps"),
        (6_000_000, "6 Mbps (rtmp.recommended".localized + ")"),
        (8_000_000, "8 Mbps"),
        (10_000_000, "10 Mbps")
    ]

    let qualityOptions = [
        ("low", "settings.quality.low".localized, "settings.quality.low.desc".localized),
        ("medium", "settings.quality.medium".localized, "settings.quality.medium.desc".localized),
        ("high", "settings.quality.high".localized, "settings.quality.high.desc".localized)
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(RTMPVideoEncodingMode.allCases, id: \.self) { mode in
                        Button {
                            rtmpVideoCodec = mode.rawValue
                            viewModel.encodingMode = mode
                            Task {
                                await streamViewModel.applyRTMPEncodingMode(mode)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayName)
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(AppTypography.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if viewModel.encodingMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(viewModel.isStreaming)
                    }
                } header: {
                    Text("rtmp.codec.section".localized)
                } footer: {
                    Text("rtmp.codec.footer".localized)
                }

                Section {
                    ForEach(qualityOptions, id: \.0) { quality in
                        Button {
                            videoQuality = quality.0
                            Task {
                                await streamViewModel.applyVideoQuality(quality.0)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quality.1)
                                        .foregroundColor(.primary)
                                    Text(quality.2)
                                        .font(AppTypography.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if videoQuality == quality.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(viewModel.isStreaming)
                    }
                } header: {
                    Text("眼镜采集画质")
                } footer: {
                    Text("高画质会请求 720x1280；中画质通常是 504x896。请停止 RTMP 推流后切换，切换后会重启眼镜视频流。")
                }

                Section {
                    ForEach(bitrateOptions, id: \.0) { option in
                        Button {
                            viewModel.bitrate = option.0
                        } label: {
                            HStack {
                                Text(option.1)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.bitrate == option.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("rtmp.settings.bitrate".localized)
                } footer: {
                    Text("rtmp.settings.bitrate.description".localized)
                }

                Section {
                    ForEach(RTMPStreamingViewModel.StreamingPlatform.allCases, id: \.self) { platform in
                        Button {
                            viewModel.selectPlatform(platform)
                        } label: {
                            HStack {
                                Image(systemName: platform.icon)
                                    .frame(width: 24)
                                Text(platform.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedPlatform == platform {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("rtmp.settings.platform".localized)
                }

                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("rtmp.settings.experimental".localized)
                            .font(AppTypography.headline)
                            .foregroundColor(.orange)

                        Text("rtmp.settings.experimental.description".localized)
                            .font(AppTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, AppSpacing.sm)
                } header: {
                    Text("rtmp.settings.note".localized)
                }
            }
            .navigationTitle("rtmp.settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}
