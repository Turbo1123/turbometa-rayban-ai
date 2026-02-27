/*
 * Live AI View
 * 自动启动的实时 AI 对话界面
 */

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

struct LiveAIView: View {
    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConversation = true // 控制对话内容显示/隐藏
    @State private var frameTimer: Timer?
    @State private var hasAutoStartedRecording = false
    @State private var showAPIKeyAlert = false
    @State private var showAudioDebugPanel = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @StateObject private var volumeHandler = VolumeButtonHandler.shared
    @StateObject private var phoneCameraManager = PhoneCameraManager()
    @State private var usePhoneCamera = false

    let apiKey: String

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self.apiKey = apiKey
        self._viewModel = StateObject(wrappedValue: OmniRealtimeViewModel(apiKey: apiKey))
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // 根据用户选择的摄像头来源显示预览
            if usePhoneCamera {
                // 手机摄像头预览
                if let phoneFrame = phoneCameraManager.currentFrame {
                    GeometryReader { geometry in
                        Image(uiImage: phoneFrame)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                } else if !phoneCameraManager.isRunning {
                    // 启动手机摄像头提示
                    VStack(spacing: 20) {
                        ProgressView()
                            .tint(.white)
                        Text("正在启动摄像头...")
                            .foregroundColor(.white)
                    }
                }
            } else {
                // 眩镜视频流
                if let videoFrame = streamViewModel.currentVideoFrame {
                    GeometryReader { geometry in
                        Image(uiImage: videoFrame)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                }
            }

                VStack(spacing: 0) {
                // Header (紧贴状态栏)
                headerView
                    .padding(.top, 8) // 状态栏下方一点点

                // Conversation history (可隐藏)
                if showConversation {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.conversationHistory) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                // Current AI response (streaming)
                                if !viewModel.currentTranscript.isEmpty {
                                    MessageBubble(
                                        message: ConversationMessage(
                                            role: .assistant,
                                            content: viewModel.currentTranscript
                                        )
                                    )
                                    .id("current")
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.conversationHistory.count) { _ in
                            if let lastMessage = viewModel.conversationHistory.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.currentTranscript) { _ in
                            withAnimation {
                                proxy.scrollTo("current", anchor: .bottom)
                            }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Spacer()
                }

                if showAudioDebugPanel {
                    audioDebugPanel
                        .transition(.opacity)
                }

                // Status and stop button
                controlsView
                }
                .overlay(
                ZStack {
                     if showToast {
                         VStack {
                             Spacer()
                             Text(toastMessage)
                                 .foregroundColor(.white)
                                 .padding()
                                 .background(Color.black.opacity(0.7))
                                 .cornerRadius(20)
                                 .padding(.bottom, 120) // Higher to avoid controls
                         }
                         .transition(.opacity)
                         .zIndex(100)
                     }
                }
            )
        } // end ZStack
        .onAppear {
            volumeHandler.startHandler()

            guard !apiKey.isEmpty else {
                showAPIKeyAlert = true
                return
            }

            // 根据设备连接状态选择视频源
            if streamViewModel.hasActiveDevice {
                // 使用眩镜摄像头
                usePhoneCamera = false
                Task {
                    print("🎥 LiveAIView: 启动眩镜视频流")
                    await streamViewModel.handleStartStreaming()
                }
            } else {
                // 使用手机摄像头
                usePhoneCamera = true
                print("📱 LiveAIView: 启动手机摄像头")
                phoneCameraManager.startCamera()
            }

            // 自动连接并开始录音
            viewModel.connect()

            // 更新视频帧（使用 weak self 避免循环引用）
            if frameTimer == nil {
                frameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    // 根据当前选择的视频源更新帧
                    if self.usePhoneCamera {
                        if let frame = self.phoneCameraManager.currentFrame {
                            self.viewModel.updateVideoFrame(frame)
                        }
                    } else {
                        if let frame = self.streamViewModel.currentVideoFrame {
                            self.viewModel.updateVideoFrame(frame)
                        }
                    }
                }
            }
        }
        .onReceive(volumeHandler.$volumePressed) { pressed in
            // 根据当前选择的摄像头获取帧
            let currentFrame = usePhoneCamera ? phoneCameraManager.currentFrame : streamViewModel.currentVideoFrame
            if pressed && currentFrame != nil {
                print("📸 [LiveAI] Volume key capture triggering...")
                saveFrameToAlbum()
            }
        }
        .onChange(of: viewModel.isConnected) { connected in
            if connected && !hasAutoStartedRecording {
                hasAutoStartedRecording = true
                viewModel.startRecording()
            }
        }
        .onDisappear {
            frameTimer?.invalidate()
            frameTimer = nil
            hasAutoStartedRecording = false

            // 停止 AI 对话和视频流
            print("🎥 LiveAIView: 停止 AI 对话和视频流")
            viewModel.disconnect()
            Task {
                if streamViewModel.streamingStatus != .stopped {
                    await streamViewModel.stopSession()
                }
            }

            volumeHandler.stopHandler()
            phoneCameraManager.stopCamera()
        }
        .alert("需要配置 API Key", isPresented: $showAPIKeyAlert) {
            Button("返回") {
                dismiss()
            }
        } message: {
            Text("请先在“我的”→“API Key 管理”中完成配置")
        }
        .alert(NSLocalizedString("error", comment: "Error"), isPresented: $viewModel.showError) {
            Button(NSLocalizedString("ok", comment: "OK")) {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("liveai.title", comment: "Live AI title"))
                .font(AppTypography.headline)
                .foregroundColor(.white)

            Spacer()

            // Hide/show conversation button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showConversation.toggle()
                }
            } label: {
                Image(systemName: showConversation ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAudioDebugPanel.toggle()
                }
            } label: {
                Image(systemName: showAudioDebugPanel ? "waveform.badge.minus" : "waveform.badge.plus")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }

            // Camera source toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    toggleCameraSource()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: usePhoneCamera ? "iphone" : "eyeglasses")
                        .font(.system(size: 14))
                    Text(usePhoneCamera ? "手机" : "眼镜")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(usePhoneCamera ? Color.blue.opacity(0.6) : Color.green.opacity(0.6))
                .cornerRadius(12)
            }

            // Camera front/back switch button (only for phone camera)
            if usePhoneCamera {
                Button {
                    phoneCameraManager.switchCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
            }

            // Connection status
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? NSLocalizedString("liveai.connected", comment: "Connected") : NSLocalizedString("liveai.connecting", comment: "Connecting"))
                    .font(AppTypography.caption)
                    .foregroundColor(.white)
            }

            // Speaking indicator
            if viewModel.isSpeaking {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("liveai.speaking", comment: "AI speaking"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: AppSpacing.md) {
            // Recording status
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("liveai.listening", comment: "Listening"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("liveai.stop", comment: "Stopped"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.black.opacity(0.6))
            .cornerRadius(AppCornerRadius.xl)

            // Controls Row
            HStack(spacing: 30) {
                // Stop button
                Button {
                    viewModel.disconnect()
                    dismiss()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                        Text(NSLocalizedString("liveai.stop", comment: "Stop"))
                            .font(AppTypography.headline)
                    }
                    .frame(width: 140)
                    .padding(.vertical, AppSpacing.md)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(AppCornerRadius.lg)
                }
                
                // Capture Button
                if streamViewModel.currentVideoFrame != nil {
                    Button {
                        saveFrameToAlbum()
                    } label: {
                        VStack {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Audio Debug Panel

    private var audioDebugPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("音频调试")
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: AppSpacing.sm) {
                Text("输入电平")
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.8))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(viewModel.audioInputLevel > 0.02 ? Color.green : Color.gray)
                            .frame(width: geometry.size.width * CGFloat(min(max(viewModel.audioInputLevel * 8, 0), 1)), height: 8)
                    }
                }
                .frame(height: 8)
                Text(String(format: "%.3f", viewModel.audioInputLevel))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }

            Text("路由：\(viewModel.audioRouteInfo)")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))

            Text(audioFrameStatusText)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(AppSpacing.sm)
        .background(Color.black.opacity(0.6))
        .cornerRadius(AppCornerRadius.md)
        .padding(.horizontal, AppSpacing.md)

    }
    
    private func saveFrameToAlbum() {
        // 根据当前选择的摄像头源获取帧
        let frame: UIImage?
        if usePhoneCamera {
            frame = phoneCameraManager.currentFrame
        } else {
            frame = streamViewModel.currentVideoFrame
        }
        guard let frame = frame else { return }
        UIImageWriteToSavedPhotosAlbum(frame, nil, nil, nil)
        PhotoStorageService.shared.savePhoto(frame)
        
        // Show Toast
        toastMessage = "已抓拍并保存"
        showToast = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        Task {
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            showToast = false
        }
    }
    
    private func toggleCameraSource() {
        if usePhoneCamera {
            // 切换到眼镜摄像头
            phoneCameraManager.stopCamera()
            usePhoneCamera = false
            if streamViewModel.hasActiveDevice {
                Task {
                    await streamViewModel.handleStartStreaming()
                }
            } else {
                // 眼镜未连接，显示提示
                toastMessage = "眼镜未连接，请先连接设备"
                showToast = true
                Task {
                    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                    showToast = false
                    // 回退到手机摄像头
                    usePhoneCamera = true
                    phoneCameraManager.startCamera()
                }
            }
        } else {
            // 切换到手机摄像头
            Task {
                await streamViewModel.stopSession()
            }
            usePhoneCamera = true
            phoneCameraManager.startCamera()
        }
    }

    private var audioFrameStatusText: String {
        if let lastAt = viewModel.lastAudioFrameAt {
            let interval = Date().timeIntervalSince(lastAt)
            return "音频帧: \(viewModel.audioFrameCount) | 最近: \(String(format: "%.1f", interval))s"
        }
        return "音频帧: 0 | 最近: 无"
    }

    // MARK: - Device Not Connected View

    private var deviceNotConnectedView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.liveAI.opacity(0.6))

                Text(NSLocalizedString("liveai.device.notconnected.title", comment: "Device not connected"))
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text(NSLocalizedString("liveai.device.notconnected.message", comment: "Connection message"))
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            // Back button
            Button {
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text(NSLocalizedString("liveai.device.backtohome", comment: "Back to home"))
                        .font(AppTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}

// MARK: - Shared Volume Button Handler
// (Placed here to ensure compilation visibility across views)
class VolumeButtonHandler: NSObject, ObservableObject {
    static let shared = VolumeButtonHandler()
    
    @Published var volumePressed = false
    private var audioSession = AVAudioSession.sharedInstance()
    private var observer: NSKeyValueObservation?
    private var initialVolume: Float = 0.0
    
    override init() {
        super.init()
    }
    
    func startHandler() {
        do {
            try audioSession.setCategory(.ambient, options: .mixWithOthers)
            try audioSession.setActive(true)
            initialVolume = audioSession.outputVolume
            
            observer = audioSession.observe(\.outputVolume) { [weak self] session, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.volumePressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.volumePressed = false
                    }
                }
            }
        } catch {
            print("❌ [VolumeHandler] Failed to start: \(error)")
        }
    }
    
    func stopHandler() {
        observer?.invalidate()
        observer = nil
    }
}

// MARK: - Phone Camera Manager
// (Placed here to ensure compilation visibility)
class PhoneCameraManager: NSObject, ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var isRunning = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "PhoneCameraSessionQueue")
    
    override init() {
        super.init()
    }
    
    func startCamera() {
        sessionQueue.async { [weak self] in
            self?.setupCaptureSession()
        }
    }
    
    func stopCamera() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.currentFrame = nil
            }
        }
    }
    
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = (self.cameraPosition == .back) ? .front : .back
            
            self.captureSession?.stopRunning()
            self.captureSession = nil
            
            DispatchQueue.main.async {
                self.cameraPosition = newPosition
            }
            
            self.setupCaptureSession()
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            print("❌ [PhoneCamera] No camera available for position: \(cameraPosition)")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "PhoneCameraVideoQueue"))
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if cameraPosition == .front && connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }
            
            self.captureSession = session
            self.videoOutput = output
            
            session.startRunning()
            
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
                print("✅ [PhoneCamera] Camera started")
            }
            
        } catch {
            print("❌ [PhoneCamera] Failed to setup camera: \(error)")
        }
    }
}

extension PhoneCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = image
        }
    }
}

