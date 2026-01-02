/*
 * Live Translate WebSocket Service
 * 基于 qwen3-livetranslate-flash-realtime 的实时翻译服务
 */

import Foundation
import UIKit
import AVFoundation

// MARK: - Service Class

class LiveTranslateService: NSObject {

    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Configuration
    private let apiKey: String
    private let model = "qwen3-livetranslate-flash-realtime"
    // 根据用户设置的区域动态获取 WebSocket URL
    private var baseURL: String {
        return APIProviderManager.staticLiveAIWebsocketURL
    }

    // Audio Engine (for recording)
    private var audioEngine: AVAudioEngine?

    // Audio Playback Engine (separate engine for playback)
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let playbackFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)

    // Audio buffer management
    private var audioBuffer = Data()
    private var isCollectingAudio = false
    private var audioChunkCount = 0
    private let minChunksBeforePlay = 2
    private var hasStartedPlaying = false
    private var isPlaybackEngineRunning = false

    // Translation settings
    private var sourceLanguage: TranslateLanguage = .en
    private var targetLanguage: TranslateLanguage = .zh
    private var voice: TranslateVoice = .cherry
    private var audioOutputEnabled = true

    // Audio resampling
    private var audioConverter: AVAudioConverter?
    private let targetSampleRate: Double = 16000  // API expects 16kHz

    // Callbacks
    var onConnected: (() -> Void)?
    var onTranslationText: ((String) -> Void)?    // 翻译结果文本
    var onTranslationDelta: ((String) -> Void)?   // 增量翻译文本
    var onAudioDelta: ((Data) -> Void)?
    var onAudioDone: (() -> Void)?
    var onError: ((String) -> Void)?

    // State
    private var isRecording = false
    private var eventIdCounter = 0

    // Image sending
    private var lastImageSendTime: Date?
    private let imageInterval: TimeInterval = 0.5  // 每0.5秒最多发送一张图片

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        setupPlaybackEngine()
    }

    private func setupPlaybackEngine() {
        playbackEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let playbackEngine = playbackEngine,
              let playerNode = playerNode,
              let playbackFormat = playbackFormat else {
            print("❌ [Translate] 无法初始化播放引擎")
            return
        }

        playbackEngine.attach(playerNode)
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: playbackFormat)
        playbackEngine.prepare()

        print("✅ [Translate] 播放引擎初始化完成: Float32 @ 24kHz")
    }

    private func startPlaybackEngine() {
        guard let playbackEngine = playbackEngine, !isPlaybackEngineRunning else { return }

        do {
            try playbackEngine.start()
            isPlaybackEngineRunning = true
            print("▶️ [Translate] 播放引擎已启动")
        } catch {
            print("❌ [Translate] 播放引擎启动失败: \(error)")
        }
    }

    private func stopPlaybackEngine() {
        guard let playbackEngine = playbackEngine, isPlaybackEngineRunning else { return }

        playerNode?.stop()
        playerNode?.reset()
        playbackEngine.stop()
        isPlaybackEngineRunning = false
        print("⏹️ [Translate] 播放引擎已停止")
    }

    // MARK: - WebSocket Connection

    func connect() {
        let urlString = "\(baseURL)?model=\(model)"
        print("🔌 [Translate] 准备连接 WebSocket: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ [Translate] 无效的 URL")
            onError?("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())

        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()

        print("🔌 [Translate] WebSocket 任务已启动")
        receiveMessage()

        // 等待连接后发送配置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("⚙️ [Translate] 准备配置会话")
            self.configureSession()
        }
    }

    func disconnect() {
        print("🔌 [Translate] 断开 WebSocket 连接")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        stopRecording()
        stopPlaybackEngine()
    }

    // MARK: - Configuration

    func updateSettings(
        sourceLanguage: TranslateLanguage,
        targetLanguage: TranslateLanguage,
        voice: TranslateVoice,
        audioEnabled: Bool
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.voice = voice
        self.audioOutputEnabled = audioEnabled

        // 如果已连接，重新配置会话
        if webSocket != nil {
            configureSession()
        }
    }

    private func configureSession() {
        var modalities: [String] = ["text"]
        if audioOutputEnabled {
            modalities.append("audio")
        }

        let sessionConfig: [String: Any] = [
            "event_id": generateEventId(),
            "type": TranslateClientEvent.sessionUpdate.rawValue,
            "session": [
                "modalities": modalities,
                "voice": voice.rawValue,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm24",
                "input_audio_transcription": [
                    "language": sourceLanguage.rawValue
                ],
                "translation": [
                    "language": targetLanguage.rawValue
                ],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 500
                ]
            ]
        ]

        sendEvent(sessionConfig)
        print("📤 [Translate] 配置会话: \(sourceLanguage.rawValue) → \(targetLanguage.rawValue), 音色: \(voice.rawValue)")
    }

    // MARK: - Audio Recording

    func startRecording(usePhoneMic: Bool = false) {
        guard !isRecording else { return }

        do {
            print("🎤 [Translate] 开始录音, 使用\(usePhoneMic ? "iPhone" : "蓝牙")麦克风")

            if let engine = audioEngine, engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }

            let audioSession = AVAudioSession.sharedInstance()

            if usePhoneMic {
                // 使用 iPhone 麦克风 - 适合翻译对方说的话
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker]  // 不启用蓝牙，强制使用 iPhone 麦克风
                )
                print("🎙️ [Translate] 使用 iPhone 麦克风（翻译对方）")
            } else {
                // 使用蓝牙麦克风（眼镜）- 适合翻译自己说的话
                try audioSession.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.allowBluetooth, .defaultToSpeaker]
                )
                print("🎙️ [Translate] 使用蓝牙麦克风（翻译自己）")
            }
            try audioSession.setActive(true)

            // 打印当前音频输入设备
            if let inputRoute = audioSession.currentRoute.inputs.first {
                print("🎙️ [Translate] 当前输入设备: \(inputRoute.portName) (\(inputRoute.portType.rawValue))")
            }

            guard let engine = audioEngine else {
                print("❌ [Translate] 音频引擎未初始化")
                return
            }

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            print("🎵 [Translate] 输入格式: \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount) channels")
            print("🎵 [Translate] 目标格式: \(targetSampleRate) Hz (将自动重采样)")

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            print("✅ [Translate] 录音已启动")

        } catch {
            print("❌ [Translate] 启动录音失败: \(error.localizedDescription)")
            onError?("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        print("🛑 [Translate] 停止录音")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }

        let inputSampleRate = buffer.format.sampleRate

        // 如果采样率不是 16kHz，需要重采样
        if inputSampleRate != targetSampleRate {
            guard let resampledBuffer = resampleBuffer(buffer) else {
                return
            }
            sendBufferAsPCM16(resampledBuffer)
        } else {
            sendBufferAsPCM16(buffer)
        }
    }

    private func resampleBuffer(_ inputBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let inputFormat = inputBuffer.format
        guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: targetSampleRate, channels: 1) else {
            return nil
        }

        // 创建或更新 converter
        if audioConverter == nil || audioConverter?.inputFormat != inputFormat {
            audioConverter = AVAudioConverter(from: inputFormat, to: outputFormat)
        }

        guard let converter = audioConverter else {
            print("❌ [Translate] 无法创建音频转换器")
            return nil
        }

        // 计算输出帧数
        let ratio = targetSampleRate / inputFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else {
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("❌ [Translate] 重采样失败: \(error.localizedDescription)")
            return nil
        }

        return outputBuffer
    }

    private func sendBufferAsPCM16(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channel = floatChannelData.pointee

        // Float32 → PCM16
        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = channel[i]
            let clampedSample = max(-1.0, min(1.0, sample))
            int16Data[i] = Int16(clampedSample * 32767.0)
        }

        let data = Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
        let base64Audio = data.base64EncodedString()

        sendAudioAppend(base64Audio)
    }

    // MARK: - Image Sending

    func sendImageFrame(_ image: UIImage) {
        // 限制发送频率：每0.5秒最多一张
        let now = Date()
        if let lastTime = lastImageSendTime, now.timeIntervalSince(lastTime) < imageInterval {
            return
        }
        lastImageSendTime = now

        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("❌ [Translate] 无法压缩图片")
            return
        }

        // 限制图片大小 500KB
        guard imageData.count <= 500 * 1024 else {
            print("⚠️ [Translate] 图片过大，跳过发送")
            return
        }

        let base64Image = imageData.base64EncodedString()
        print("📸 [Translate] 发送图片: \(imageData.count) bytes")

        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": TranslateClientEvent.inputImageBufferAppend.rawValue,
            "image": base64Image
        ]
        sendEvent(event)
    }

    // MARK: - Send Events

    private func sendEvent(_ event: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: event),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [Translate] 无法序列化事件")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ [Translate] 发送事件失败: \(error.localizedDescription)")
                self.onError?("Send error: \(error.localizedDescription)")
            }
        }
    }

    private var audioSendCount = 0

    private func sendAudioAppend(_ base64Audio: String) {
        audioSendCount += 1
        if audioSendCount == 1 || audioSendCount % 50 == 0 {
            print("🎵 [Translate] 发送音频块 #\(audioSendCount), 大小: \(base64Audio.count) bytes")
        }

        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": TranslateClientEvent.inputAudioBufferAppend.rawValue,
            "audio": base64Audio
        ]
        sendEvent(event)
    }

    // MARK: - Receive Messages

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()

            case .failure(let error):
                print("❌ [Translate] 接收消息失败: \(error.localizedDescription)")
                self?.onError?("Receive error: \(error.localizedDescription)")
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleServerEvent(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleServerEvent(text)
            }
        @unknown default:
            break
        }
    }

    private func handleServerEvent(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("⚠️ [Translate] 收到无法解析的消息: \(jsonString.prefix(200))")
            return
        }

        // 打印所有收到的事件类型
        print("📥 [Translate] 收到事件: \(type)")

        DispatchQueue.main.async {
            switch type {
            case TranslateServerEvent.sessionCreated.rawValue,
                 TranslateServerEvent.sessionUpdated.rawValue:
                print("✅ [Translate] 会话已建立")
                self.onConnected?()

            case TranslateServerEvent.responseAudioTranscriptText.rawValue:
                // 增量翻译文本
                if let delta = json["delta"] as? String {
                    print("💬 [Translate] 翻译片段: \(delta)")
                    self.onTranslationDelta?(delta)
                }

            case TranslateServerEvent.responseAudioTranscriptDone.rawValue:
                // 翻译文本完成（输出音频+文本模式）
                if let text = json["text"] as? String {
                    print("✅ [Translate] 翻译完成: \(text)")
                    self.onTranslationText?(text)
                }

            case TranslateServerEvent.responseTextDone.rawValue:
                // 翻译文本完成（仅文本模式）
                if let text = json["text"] as? String {
                    print("✅ [Translate] 翻译完成(文本): \(text)")
                    self.onTranslationText?(text)
                }

            case TranslateServerEvent.responseAudioDelta.rawValue:
                if let base64Audio = json["delta"] as? String,
                   let audioData = Data(base64Encoded: base64Audio) {
                    self.onAudioDelta?(audioData)
                    self.handleAudioChunk(audioData)
                }

            case TranslateServerEvent.responseAudioDone.rawValue:
                self.isCollectingAudio = false
                if !self.audioBuffer.isEmpty {
                    self.playAudio(self.audioBuffer)
                    self.audioBuffer = Data()
                }
                self.audioChunkCount = 0
                self.hasStartedPlaying = false
                self.onAudioDone?()

            case TranslateServerEvent.error.rawValue:
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ [Translate] 服务器错误: \(message)")
                    self.onError?(message)
                }

            default:
                break
            }
        }
    }

    // MARK: - Audio Playback

    private func handleAudioChunk(_ audioData: Data) {
        if !isCollectingAudio {
            isCollectingAudio = true
            audioBuffer = Data()
            audioChunkCount = 0
            hasStartedPlaying = false

            if isPlaybackEngineRunning {
                stopPlaybackEngine()
                setupPlaybackEngine()
                startPlaybackEngine()
                playerNode?.play()
            }
        }

        audioChunkCount += 1

        if !hasStartedPlaying {
            audioBuffer.append(audioData)
            if audioChunkCount >= minChunksBeforePlay {
                hasStartedPlaying = true
                playAudio(audioBuffer)
                audioBuffer = Data()
            }
        } else {
            playAudio(audioData)
        }
    }

    private func playAudio(_ audioData: Data) {
        guard let playerNode = playerNode,
              let playbackFormat = playbackFormat else { return }

        if !isPlaybackEngineRunning {
            startPlaybackEngine()
            playerNode.play()
        } else if !playerNode.isPlaying {
            playerNode.play()
        }

        guard let pcmBuffer = createPCMBuffer(from: audioData, format: playbackFormat) else { return }
        playerNode.scheduleBuffer(pcmBuffer)
    }

    private func createPCMBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = data.count / 2
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.floatChannelData else { return nil }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // PCM16 → Float32
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            let floatData = channelData[0]
            for i in 0..<frameCount {
                floatData[i] = Float(int16Pointer[i]) / 32768.0
            }
        }

        return buffer
    }

    // MARK: - Helpers

    private func generateEventId() -> String {
        eventIdCounter += 1
        return "translate_\(eventIdCounter)_\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - URLSessionWebSocketDelegate

extension LiveTranslateService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Translate] WebSocket 连接已建立")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        print("🔌 [Translate] WebSocket 已断开, closeCode: \(closeCode.rawValue), reason: \(reasonString)")
    }
}
