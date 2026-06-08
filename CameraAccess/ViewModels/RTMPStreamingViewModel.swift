/*
 * RTMP Streaming ViewModel
 * Manages RTMP live streaming state and UI interactions
 */

import SwiftUI
import Combine
import Security
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.smartview.glassai", category: "RTMPStreaming")

@MainActor
class RTMPStreamingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var rtmpUrl: String = ""
    @Published var streamKey: String = ""
    @Published var selectedPlatform: StreamingPlatform = .custom
    @Published var bitrate: Int = 6_000_000 // 6 Mbps
    @Published var encodingMode: RTMPVideoEncodingMode = .h264

    @Published var isStreaming: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    @Published var framesSent: Int64 = 0
    @Published var currentFps: Double = 0.0
    @Published var connectionTime: TimeInterval = 0
    @Published var bytesSent: Int64 = 0
    @Published var sourceResolution: String = "-"
    @Published var outputResolution: String = "-"

    @Published var showError: Bool = false
    @Published var errorMessage: String?

    @Published var showSettings: Bool = false

    // MARK: - Types

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case streaming
        case error(String)

        var displayText: String {
            switch self {
            case .disconnected: return "rtmp.status.disconnected".localized
            case .connecting: return "rtmp.status.connecting".localized
            case .connected: return "rtmp.status.connected".localized
            case .streaming: return "rtmp.status.streaming".localized
            case .error(let msg): return msg
            }
        }

        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .connecting: return .yellow
            case .connected: return .green
            case .streaming: return .red
            case .error: return .orange
            }
        }
    }

    enum StreamingPlatform: String, CaseIterable {
        case custom = "custom"
        case youtube = "youtube"
        case twitch = "twitch"
        case bilibili = "bilibili"
        case douyin = "douyin"
        case tiktok = "tiktok"
        case facebook = "facebook"

        var displayName: String {
            switch self {
            case .custom: return "rtmp.platform.custom".localized
            case .youtube: return "YouTube Live"
            case .twitch: return "Twitch"
            case .bilibili: return "Bilibili (B站)"
            case .douyin: return "Douyin (抖音)"
            case .tiktok: return "TikTok"
            case .facebook: return "Facebook Live"
            }
        }

        var defaultRtmpUrl: String {
            switch self {
            case .custom: return ""
            case .youtube: return "rtmp://a.rtmp.youtube.com/live2"
            case .twitch: return "rtmp://live.twitch.tv/app"
            case .bilibili: return "rtmp://live-push.bilivideo.com/live-bvc"
            case .douyin: return "rtmp://push-rtmp-l6.douyincdn.com/third"
            case .tiktok: return "rtmp://push.tiktokv.com/live"
            case .facebook: return "rtmps://live-api-s.facebook.com:443/rtmp"
            }
        }

        var icon: String {
            switch self {
            case .custom: return "server.rack"
            case .youtube: return "play.rectangle.fill"
            case .twitch: return "gamecontroller.fill"
            case .bilibili: return "tv.fill"
            case .douyin: return "music.note"
            case .tiktok: return "music.note.tv.fill"
            case .facebook: return "f.circle.fill"
            }
        }
    }

    // MARK: - Private Properties

    private let streamingService: RTMPStreamingService
    private var statsTimer: Timer?
    private var startTime: Date?

    // MARK: - Initialization

    init() {
        self.streamingService = RTMPStreamingService()
        setupServiceCallbacks()
        loadSavedSettings()
        logger.info("RTMPStreamingViewModel initialized")
    }

    deinit {
        statsTimer?.invalidate()
        streamingService.stopStreaming()
    }

    // MARK: - Public Methods

    func selectPlatform(_ platform: StreamingPlatform) {
        selectedPlatform = platform
        if platform != .custom {
            rtmpUrl = platform.defaultRtmpUrl
        }
    }

    func startStreaming(videoFrame: UIImage?, sampleBuffer: CMSampleBuffer?) {
        guard !isStreaming else {
            logger.warning("Already streaming")
            return
        }

        guard hasCompleteRTMPDestination() else {
            showError(message: "rtmp.error.missingkey".localized)
            return
        }

        let fullUrl = buildFullUrl()
        guard !fullUrl.isEmpty else {
            showError(message: "rtmp.error.invalidurl".localized)
            return
        }

        logger.info("Starting RTMP streaming to: \(fullUrl)")

        isConnecting = true
        connectionStatus = .connecting

        guard let dimensions = videoDimensions(videoFrame: videoFrame, sampleBuffer: sampleBuffer) else {
            isConnecting = false
            connectionStatus = .disconnected
            showError(message: "rtmp.error.novideo".localized)
            return
        }

        let outputBitrate = max(bitrate, recommendedBitrate(width: dimensions.width, height: dimensions.height))
        sourceResolution = "\(dimensions.width)x\(dimensions.height)"
        outputResolution = "\(dimensions.width)x\(dimensions.height)"
        logger.info("RTMP video dimensions: \(dimensions.width)x\(dimensions.height), bitrate: \(outputBitrate), codec: \(self.encodingMode.rawValue)")

        streamingService.startStreaming(
            url: fullUrl,
            width: dimensions.width,
            height: dimensions.height,
            bitrate: outputBitrate,
            encodingMode: encodingMode
        )

        saveSettings()
    }

    func stopStreaming() {
        logger.info("Stopping RTMP streaming")
        streamingService.stopStreaming()

        isStreaming = false
        isConnecting = false
        connectionStatus = .disconnected

        statsTimer?.invalidate()
        statsTimer = nil

        framesSent = 0
        currentFps = 0.0
        connectionTime = 0
        bytesSent = 0
        outputResolution = "-"
    }

    func feedFrame(_ image: UIImage, timestamp: Int64) {
        let dimensions = videoDimensions(from: image)
        let resolution = "\(dimensions.width)x\(dimensions.height)"
        if sourceResolution != resolution {
            sourceResolution = resolution
            logger.info("RTMP source frame dimensions changed: \(resolution)")
        }
        guard isStreaming else { return }
        streamingService.feedFrame(image, timestamp: timestamp)
    }

    func feedSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if let dimensions = sampleBufferDimensions(sampleBuffer) {
            let resolution = "\(dimensions.width)x\(dimensions.height)"
            if sourceResolution != resolution {
                sourceResolution = resolution
                outputResolution = resolution
                logger.info("RTMP source sampleBuffer dimensions changed: \(resolution)")
            }
        }
        guard isStreaming else { return }
        streamingService.feedSampleBuffer(sampleBuffer)
    }

    func dismissError() {
        showError = false
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func setupServiceCallbacks() {
        streamingService.onStateChanged = { [weak self] state in
            Task { @MainActor in
                self?.handleStateChange(state)
            }
        }

        streamingService.onStatsUpdated = { [weak self] stats in
            Task { @MainActor in
                self?.framesSent = stats.framesSent
                self?.currentFps = stats.fps
                self?.connectionTime = stats.connectionTime
                self?.bytesSent = stats.bytesSent
            }
        }

        streamingService.onError = { [weak self] error in
            Task { @MainActor in
                self?.showError(message: error)
            }
        }
    }

    private func handleStateChange(_ state: RTMPStreamingState) {
        switch state {
        case .idle:
            connectionStatus = .disconnected
            isStreaming = false
            isConnecting = false

        case .connecting:
            connectionStatus = .connecting
            isConnecting = true
            isStreaming = false

        case .streaming:
            connectionStatus = .streaming
            isStreaming = true
            isConnecting = false
            startTime = Date()
            startStatsTimer()

        case .disconnected:
            connectionStatus = .disconnected
            isStreaming = false
            isConnecting = false
            statsTimer?.invalidate()

        case .error(let message):
            connectionStatus = .error(message)
            isStreaming = false
            isConnecting = false
            showError(message: message)
        }
    }

    private func buildFullUrl() -> String {
        var url = rtmpUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = streamKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !url.isEmpty else { return "" }

        if isCompleteRTMPUrl(url) {
            return url
        }

        if !key.isEmpty {
            if !url.hasSuffix("/") {
                url += "/"
            }
            url += key
        }

        return url
    }

    private func isCompleteRTMPUrl(_ url: String) -> Bool {
        guard let urlObj = URL(string: url),
              let scheme = urlObj.scheme?.lowercased(),
              scheme == "rtmp" || scheme == "rtmps" else {
            return false
        }

        return urlObj.path.split(separator: "/").count >= 2
    }

    private func hasCompleteRTMPDestination() -> Bool {
        let url = rtmpUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = streamKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let urlObj = URL(string: url),
              let scheme = urlObj.scheme?.lowercased(),
              scheme == "rtmp" || scheme == "rtmps" else {
            return false
        }

        if !key.isEmpty {
            return true
        }

        let pathComponents = urlObj.path.split(separator: "/")
        return pathComponents.count >= 2
    }

    private func videoDimensions(from image: UIImage) -> (width: Int, height: Int) {
        if let cgImage = image.cgImage {
            return (cgImage.width, cgImage.height)
        }

        let scale = max(image.scale, 1)
        return (Int(image.size.width * scale), Int(image.size.height * scale))
    }

    private func videoDimensions(videoFrame: UIImage?, sampleBuffer: CMSampleBuffer?) -> (width: Int, height: Int)? {
        switch encodingMode {
        case .h264:
            guard let videoFrame else { return nil }
            return videoDimensions(from: videoFrame)
        case .hevc:
            if let sampleBuffer, let dimensions = sampleBufferDimensions(sampleBuffer) {
                return dimensions
            }
            if let videoFrame {
                return videoDimensions(from: videoFrame)
            }
            return nil
        }
    }

    private func sampleBufferDimensions(_ sampleBuffer: CMSampleBuffer) -> (width: Int, height: Int)? {
        guard let formatDescription = sampleBuffer.formatDescription else { return nil }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
        guard dimensions.width > 0, dimensions.height > 0 else { return nil }
        return (Int(dimensions.width), Int(dimensions.height))
    }

    private func recommendedBitrate(width: Int, height: Int) -> Int {
        let pixels = width * height
        if pixels >= 1_900_000 {
            return 8_000_000
        }
        if pixels >= 900_000 {
            return 6_000_000
        }
        return 4_000_000
    }

    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startTime else { return }
                self.connectionTime = Date().timeIntervalSince(start)
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private func saveSettings() {
        UserDefaults.standard.set(rtmpUrl, forKey: "rtmp_url")
        UserDefaults.standard.set(selectedPlatform.rawValue, forKey: "rtmp_platform")
        UserDefaults.standard.set(bitrate, forKey: "rtmp_bitrate")
        UserDefaults.standard.set(encodingMode.rawValue, forKey: "rtmp_video_codec")
        // Stream key is sensitive, store in Keychain
        saveStreamKeyToKeychain(streamKey)
    }

    private func loadSavedSettings() {
        if let savedUrl = UserDefaults.standard.string(forKey: "rtmp_url") {
            rtmpUrl = savedUrl
        }
        streamKey = loadStreamKeyFromKeychain() ?? ""
        if let savedPlatform = UserDefaults.standard.string(forKey: "rtmp_platform"),
           let platform = StreamingPlatform(rawValue: savedPlatform) {
            selectedPlatform = platform
        }
        let savedBitrate = UserDefaults.standard.integer(forKey: "rtmp_bitrate")
        if savedBitrate > 0 {
            bitrate = max(savedBitrate, 6_000_000)
        }
        if let savedCodec = UserDefaults.standard.string(forKey: "rtmp_video_codec"),
           let codec = RTMPVideoEncodingMode(rawValue: savedCodec) {
            encodingMode = codec
        }
        // Migrate old UserDefaults key to Keychain
        if let oldKey = UserDefaults.standard.string(forKey: "rtmp_stream_key"), !oldKey.isEmpty {
            saveStreamKeyToKeychain(oldKey)
            if streamKey.isEmpty { streamKey = oldKey }
            UserDefaults.standard.removeObject(forKey: "rtmp_stream_key")
        }
    }

    private func saveStreamKeyToKeychain(_ key: String) {
        let service = "com.smartview.glassai.rtmp"
        let account = "stream_key"
        let data = key.data(using: .utf8) ?? Data()

        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary)

        guard !key.isEmpty else { return }
        SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ] as CFDictionary, nil)
    }

    private func loadStreamKeyFromKeychain() -> String? {
        let service = "com.smartview.glassai.rtmp"
        let account = "stream_key"
        var result: AnyObject?

        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true
        ] as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// String.localized is defined in LanguageManager.swift
