/*
 * Audio Session Manager
 * 音频会话管理器 - 统一管理应用的所有音频会话配置
 */

import AVFoundation

@MainActor
class AudioSessionManager {

    static let shared = AudioSessionManager()

    private var currentCategory: AVAudioSession.Category = .playback
    private var currentMode: AVAudioSession.Mode = .default

    private init() {}

    // MARK: - Configuration Types

    enum AudioSessionType {
        case playback           // 播放模式（TTS）
        case playAndRecord      // 录音+播放（实时对话）
        case voiceChat          // 语音聊天（实时对话）
        case measurement        // 测量模式

        var category: AVAudioSession.Category {
            switch self {
            case .playback:
                return .playback
            case .playAndRecord, .voiceChat, .measurement:
                return .playAndRecord
            }
        }

        var mode: AVAudioSession.Mode {
            switch self {
            case .playback:
                return .default
            case .playAndRecord:
                return .default
            case .voiceChat:
                return .voiceChat
            case .measurement:
                return .measurement
            }
        }

        var options: AVAudioSession.CategoryOptions {
            switch self {
            case .playback:
                return [.duckOthers]
            case .playAndRecord:
                return [.defaultToSpeaker, .allowBluetooth]
            case .voiceChat:
                return [.allowBluetooth, .allowBluetoothA2DP]
            case .measurement:
                return [.mixWithOthers]
            }
        }
    }

    // MARK: - Public Methods

    /// 配置音频会话
    /// - Parameters:
    ///   - type: 会话类型
    ///   - preferredSampleRate: 期望的采样率
    /// - Throws: 音频会话错误
    func configure(type: AudioSessionType, preferredSampleRate: Double? = nil) throws {
        let audioSession = AVAudioSession.sharedInstance()

        // 配置基本属性
        try audioSession.setCategory(type.category, mode: type.mode, options: type.options)

        // 配置采样率（如果指定）
        if let sampleRate = preferredSampleRate {
            try audioSession.setPreferredSampleRate(sampleRate)
        }

        // 配置缓冲区持续时间
        try audioSession.setPreferredIOBufferDuration(0.02)

        // 激活会话
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // 保存当前配置
        currentCategory = type.category
        currentMode = type.mode

        logCurrentConfiguration()
    }

    /// 为录音配置音频会话（使用蓝牙或iPhone麦克风）
    /// - Parameter useBluetooth: 是否使用蓝牙麦克风
    /// - Throws: 音频会话错误
    func configureForRecording(useBluetooth: Bool = true) throws {
        let type: AudioSessionType = useBluetooth ? .voiceChat : .playAndRecord
        try configure(type: type, preferredSampleRate: 24000)

        if useBluetooth {
            try ensureBluetoothInput()
        }
    }

    /// 为播放配置音频会话
    /// - Throws: 音频会话错误
    func configureForPlayback() throws {
        try configure(type: .playback, preferredSampleRate: 24000)
    }

    /// 停止音频会话
    func deactivate() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("🔊 [AudioSession] Session deactivated")
        } catch {
            print("⚠️ [AudioSession] Failed to deactivate: \(error)")
        }
    }

    // MARK: - Audio Route Management

    /// 确保使用蓝牙输入
    func ensureBluetoothInput() throws {
        let audioSession = AVAudioSession.sharedInstance()
        guard let inputs = audioSession.availableInputs else { return }

        // 优先选择蓝牙HFP（更好的音频质量）
        if let bluetoothInput = inputs.first(where: { $0.portType == .bluetoothHFP }) {
            if audioSession.preferredInput?.portType != .bluetoothHFP {
                try audioSession.setPreferredInput(bluetoothInput)
                print("🎧 [AudioSession] 蓝牙HFP麦克风已选择: \(bluetoothInput.portName)")
            }
            return
        }

        // 备选：蓝牙A2DP
        if let bluetoothInput = inputs.first(where: { $0.portType == .bluetoothA2DP }) {
            if audioSession.preferredInput?.portType != .bluetoothA2DP {
                try audioSession.setPreferredInput(bluetoothInput)
                print("🎧 [AudioSession] 蓝牙A2DP麦克风已选择: \(bluetoothInput.portName)")
            }
        }
    }

    /// 获取当前音频路由信息
    func getCurrentAudioRoute() -> String {
        let audioSession = AVAudioSession.sharedInstance()
        let inputs = audioSession.currentRoute.inputs.map { "\($0.portType.rawValue)(\($0.portName))" }
        let outputs = audioSession.currentRoute.outputs.map { "\($0.portType.rawValue)(\($0.portName))" }
        return "输入: \(inputs.joined(separator: ", ")) | 输出: \(outputs.joined(separator: ", "))"
    }

    /// 检查是否连接了蓝牙设备
    var hasBluetoothDevice: Bool {
        let audioSession = AVAudioSession.sharedInstance()
        return audioSession.currentRoute.inputs.contains { $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP }
    }

    // MARK: - Logging

    private func logCurrentConfiguration() {
        let audioSession = AVAudioSession.sharedInstance()
        print("🔊 [AudioSession] 当前配置:")
        print("  - Category: \(audioSession.category.rawValue)")
        print("  - Mode: \(audioSession.mode.rawValue)")
        print("  - Sample Rate: \(audioSession.sampleRate) Hz")
        print("  - IO Buffer Duration: \(audioSession.ioBufferDuration) s")
        print("  - Route: \(getCurrentAudioRoute())")
    }
}

// MARK: - Convenience Methods

extension AudioSessionManager {

    /// 快速配置为实时对话模式
    func configureForRealtimeChat() throws {
        try configureForRecording(useBluetooth: true)
    }

    /// 快速配置为翻译模式
    func configureForTranslation(useBluetooth: Bool = false) throws {
        try configureForRecording(useBluetooth: useBluetooth)
    }

    /// 快速配置为TTS播放模式
    func configureForTTS() throws {
        try configureForPlayback()
    }
}
