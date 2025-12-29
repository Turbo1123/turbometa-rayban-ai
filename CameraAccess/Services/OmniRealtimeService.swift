/*
 * Qwen-Omni-Realtime WebSocket Service
 * Provides real-time audio and video chat with AI
 */

import Foundation
import UIKit
import AVFoundation

// MARK: - WebSocket Events

enum OmniClientEvent: String {
    case sessionUpdate = "session.update"
    case inputAudioBufferAppend = "input_audio_buffer.append"
    case inputAudioBufferCommit = "input_audio_buffer.commit"
    case inputImageBufferAppend = "input_image_buffer.append"
    case responseCreate = "response.create"
}

enum OmniServerEvent: String {
    case sessionCreated = "session.created"
    case sessionUpdated = "session.updated"
    case inputAudioBufferSpeechStarted = "input_audio_buffer.speech_started"
    case inputAudioBufferSpeechStopped = "input_audio_buffer.speech_stopped"
    case inputAudioBufferCommitted = "input_audio_buffer.committed"
    case responseCreated = "response.created"
    case responseAudioTranscriptDelta = "response.audio_transcript.delta"
    case responseAudioTranscriptDone = "response.audio_transcript.done"
    case responseAudioDelta = "response.audio.delta"
    case responseAudioDone = "response.audio.done"
    case responseDone = "response.done"
    case conversationItemCreated = "conversation.item.created"
    case conversationItemInputAudioTranscriptionCompleted = "conversation.item.input_audio_transcription.completed"
    case error = "error"
}

// MARK: - Service Class

class OmniRealtimeService: NSObject {

    // WebSocket
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Configuration
    private let apiKey: String
    private let model = "qwen3-omni-flash-realtime"
    private let baseURL = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime"

    // Audio Engine (for recording)
    private var audioEngine: AVAudioEngine?

    // Audio Playback Engine (separate engine for playback)
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true)

    // Audio buffer management
    private var audioBuffer = Data()
    private var isCollectingAudio = false
    private var audioChunkCount = 0
    private let minChunksBeforePlay = 2 // 首次收到2个片段后开始播放
    private var hasStartedPlaying = false
    private var isPlaybackEngineRunning = false

    // Callbacks
    var onTranscriptDelta: ((String) -> Void)?
    var onTranscriptDone: ((String) -> Void)?
    var onUserTranscript: ((String) -> Void)? // 用户语音识别结果
    var onAudioDelta: ((Data) -> Void)?
    var onAudioDone: (() -> Void)?
    var onSpeechStarted: (() -> Void)?
    var onSpeechStopped: (() -> Void)?
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onFirstAudioSent: (() -> Void)?

    // State
    private var isRecording = false
    private var hasAudioBeenSent = false
    private var eventIdCounter = 0

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        // Recording engine
        audioEngine = AVAudioEngine()

        // Playback engine (separate from recording)
        setupPlaybackEngine()
    }

    private func setupPlaybackEngine() {
        playbackEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        guard let playbackEngine = playbackEngine,
              let playerNode = playerNode,
              let audioFormat = audioFormat else {
            print("❌ [Omni] 无法初始化播放引擎")
            return
        }

        // Attach player node
        playbackEngine.attach(playerNode)

        // Connect player node to output
        playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: audioFormat)

        print("✅ [Omni] 播放引擎初始化完成: PCM16 @ 24kHz")
    }

    private func startPlaybackEngine() {
        guard let playbackEngine = playbackEngine, !isPlaybackEngineRunning else { return }

        do {
            try playbackEngine.start()
            isPlaybackEngineRunning = true
            print("▶️ [Omni] 播放引擎已启动")
        } catch {
            print("❌ [Omni] 播放引擎启动失败: \(error)")
        }
    }

    private func stopPlaybackEngine() {
        guard let playbackEngine = playbackEngine, isPlaybackEngineRunning else { return }

        // 重要：先重置 playerNode 以清除所有已调度但未播放的 buffer
        playerNode?.stop()
        playerNode?.reset()  // 清除队列中的所有 buffer
        playbackEngine.stop()
        isPlaybackEngineRunning = false
        print("⏹️ [Omni] 播放引擎已停止并清除队列")
    }

    // MARK: - WebSocket Connection

    func connect() {
        let urlString = "\(baseURL)?model=\(model)"
        print("🔌 [Omni] 准备连接 WebSocket: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ [Omni] 无效的 URL")
            onError?("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())

        webSocket = urlSession?.webSocketTask(with: request)
        webSocket?.resume()

        print("🔌 [Omni] WebSocket 任务已启动")
        receiveMessage()

        // Wait a bit then send session configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("⚙️ [Omni] 准备配置会话")
            self.configureSession()
        }
    }

    func disconnect() {
        print("🔌 [Omni] 断开 WebSocket 连接")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        stopRecording()
        stopPlaybackEngine()
    }

    // MARK: - Session Configuration

    private func configureSession() {
        let sessionConfig: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.sessionUpdate.rawValue,
            "session": [
                "modalities": ["text", "audio"],
                "voice": "Cherry",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm24",
                "smooth_output": true,
                "instructions": "你是RayBan Meta智能眼镜AI助手。\n\n【重要】必须始终用中文回答，无论用户说什么语言。\n\n回答要简练、口语化，像朋友聊天一样。用户戴着眼镜可以看到周围环境，根据画面快速给出有用的建议。不要啰嗦，直接说重点。",
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "silence_duration_ms": 800
                ]
            ]
        ]

        sendEvent(sessionConfig)
    }

    // MARK: - Audio Recording

    func startRecording() {
        guard !isRecording else {
            return
        }

        do {
            print("🎤 [Omni] 开始录音")

            // Stop engine if already running and remove any existing taps
            if let engine = audioEngine, engine.isRunning {
                engine.stop()
                engine.inputNode.removeTap(onBus: 0)
            }

            let audioSession = AVAudioSession.sharedInstance()

            // Allow Bluetooth to use the glasses' microphone
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)

            guard let engine = audioEngine else {
                print("❌ [Omni] 音频引擎未初始化")
                return
            }

            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            // Convert to PCM16 24kHz mono
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }

            engine.prepare()
            try engine.start()

            isRecording = true
            print("✅ [Omni] 录音已启动")

        } catch {
            print("❌ [Omni] 启动录音失败: \(error.localizedDescription)")
            onError?("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard isRecording else {
            return
        }

        print("🛑 [Omni] 停止录音")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false
        hasAudioBeenSent = false
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert Float32 audio to PCM16 format
        guard let floatChannelData = buffer.floatChannelData else {
            return
        }

        let frameLength = Int(buffer.frameLength)
        let channel = floatChannelData.pointee

        // Convert Float32 (-1.0 to 1.0) to Int16 (-32768 to 32767)
        var int16Data = [Int16](repeating: 0, count: frameLength)
        for i in 0..<frameLength {
            let sample = channel[i]
            let clampedSample = max(-1.0, min(1.0, sample))
            int16Data[i] = Int16(clampedSample * 32767.0)
        }

        let data = Data(bytes: int16Data, count: frameLength * MemoryLayout<Int16>.size)
        let base64Audio = data.base64EncodedString()

        sendAudioAppend(base64Audio)

        // 通知第一次音频已发送
        if !hasAudioBeenSent {
            hasAudioBeenSent = true
            print("✅ [Omni] 第一次音频已发送，启用语音触发模式")
            DispatchQueue.main.async { [weak self] in
                self?.onFirstAudioSent?()
            }
        }
    }

    // MARK: - Send Events

    private func sendEvent(_ event: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: event),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("❌ [Omni] 无法序列化事件")
            return
        }

        let message = URLSessionWebSocketTask.Message.string(jsonString)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ [Omni] 发送事件失败: \(error.localizedDescription)")
                self.onError?("Send error: \(error.localizedDescription)")
            }
        }
    }

    func sendAudioAppend(_ base64Audio: String) {
        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.inputAudioBufferAppend.rawValue,
            "audio": base64Audio
        ]
        sendEvent(event)
    }

    func sendImageAppend(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            print("❌ [Omni] 无法压缩图片")
            return
        }
        let base64Image = imageData.base64EncodedString()

        print("📸 [Omni] 发送图片: \(imageData.count) bytes")

        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.inputImageBufferAppend.rawValue,
            "image": base64Image
        ]
        sendEvent(event)
    }

    func commitAudioBuffer() {
        let event: [String: Any] = [
            "event_id": generateEventId(),
            "type": OmniClientEvent.inputAudioBufferCommit.rawValue
        ]
        sendEvent(event)
    }

    // MARK: - Receive Messages

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue receiving

            case .failure(let error):
                print("❌ [Omni] 接收消息失败: \(error.localizedDescription)")
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
            return
        }

        DispatchQueue.main.async {
            switch type {
            case OmniServerEvent.sessionCreated.rawValue,
                 OmniServerEvent.sessionUpdated.rawValue:
                print("✅ [Omni] 会话已建立")
                self.onConnected?()

            case OmniServerEvent.inputAudioBufferSpeechStarted.rawValue:
                print("🎤 [Omni] 检测到语音开始")
                self.onSpeechStarted?()

            case OmniServerEvent.inputAudioBufferSpeechStopped.rawValue:
                print("🛑 [Omni] 检测到语音停止")
                self.onSpeechStopped?()

            case OmniServerEvent.responseAudioTranscriptDelta.rawValue:
                if let delta = json["delta"] as? String {
                    print("💬 [Omni] AI回复片段: \(delta)")
                    self.onTranscriptDelta?(delta)
                }

            case OmniServerEvent.responseAudioTranscriptDone.rawValue:
                let text = json["text"] as? String ?? ""
                if text.isEmpty {
                    print("⚠️ [Omni] AI回复完成但done事件无text字段（使用累积的delta）")
                } else {
                    print("✅ [Omni] AI完整回复: \(text)")
                }
                // 总是调用回调，即使text为空，让ViewModel使用累积的片段
                self.onTranscriptDone?(text)

            case OmniServerEvent.responseAudioDelta.rawValue:
                if let base64Audio = json["delta"] as? String,
                   let audioData = Data(base64Encoded: base64Audio) {
                    self.onAudioDelta?(audioData)

                    // Buffer audio chunks
                    if !self.isCollectingAudio {
                        self.isCollectingAudio = true
                        self.audioBuffer = Data()
                        self.audioChunkCount = 0
                        self.hasStartedPlaying = false

                        // 清除 playerNode 队列中可能残留的旧 buffer
                        if self.isPlaybackEngineRunning {
                            // 重要：reset 会断开 playerNode，需要完全重新初始化
                            self.stopPlaybackEngine()
                            self.setupPlaybackEngine()
                            self.startPlaybackEngine()
                            self.playerNode?.play()
                            print("🔄 [Omni] 重新初始化播放引擎")
                        }
                    }

                    self.audioChunkCount += 1

                    // 流式播放策略：收集少量片段后开始流式调度
                    if !self.hasStartedPlaying {
                        // 首次播放前：先收集
                        self.audioBuffer.append(audioData)

                        if self.audioChunkCount >= self.minChunksBeforePlay {
                            // 已收集足够片段，开始播放
                            self.hasStartedPlaying = true
                            self.playAudio(self.audioBuffer)
                            self.audioBuffer = Data()
                        }
                    } else {
                        // 已开始播放：直接调度每个片段，AVAudioPlayerNode 会自动排队
                        self.playAudio(audioData)
                    }
                }

            case OmniServerEvent.responseAudioDone.rawValue:
                self.isCollectingAudio = false

                // Play remaining buffered audio (if any)
                if !self.audioBuffer.isEmpty {
                    self.playAudio(self.audioBuffer)
                    self.audioBuffer = Data()
                }

                self.audioChunkCount = 0
                self.hasStartedPlaying = false
                self.onAudioDone?()

            case OmniServerEvent.conversationItemInputAudioTranscriptionCompleted.rawValue:
                // 用户语音识别完成
                if let transcript = json["transcript"] as? String {
                    print("👤 [Omni] 用户说: \(transcript)")
                    self.onUserTranscript?(transcript)
                }

            case OmniServerEvent.conversationItemCreated.rawValue:
                // 可能包含其他类型的会话项
                break

            case OmniServerEvent.error.rawValue:
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("❌ [Omni] 服务器错误: \(message)")
                    self.onError?(message)
                }

            default:
                break
            }
        }
    }

    // MARK: - Audio Playback (AVAudioEngine + AVAudioPlayerNode)

    private func playAudio(_ audioData: Data) {
        guard let playerNode = playerNode,
              let audioFormat = audioFormat else {
            return
        }

        // Start playback engine if not running
        if !isPlaybackEngineRunning {
            startPlaybackEngine()
            playerNode.play()
        } else {
            // 确保 playerNode 在运行
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }

        // Convert PCM16 Data to AVAudioPCMBuffer
        guard let pcmBuffer = createPCMBuffer(from: audioData, format: audioFormat) else {
            return
        }

        // Schedule buffer for playback
        playerNode.scheduleBuffer(pcmBuffer)
    }

    private func createPCMBuffer(from data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // Calculate frame count (each frame is 2 bytes for PCM16 mono)
        let frameCount = data.count / 2

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channelData = buffer.int16ChannelData else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        // Copy PCM16 data directly to buffer
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Pointer = baseAddress.assumingMemoryBound(to: Int16.self)
            channelData[0].update(from: int16Pointer, count: frameCount)
        }

        return buffer
    }

    // MARK: - Helpers

    private func generateEventId() -> String {
        eventIdCounter += 1
        return "event_\(eventIdCounter)_\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - URLSessionWebSocketDelegate

extension OmniRealtimeService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Omni] WebSocket 连接已建立, protocol: \(`protocol` ?? "none")")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
        print("🔌 [Omni] WebSocket 已断开, closeCode: \(closeCode.rawValue), reason: \(reasonString)")
    }
}
