/*
 * RTMP Streaming ViewModel
 * Manages RTMP live streaming state and UI interactions
 */

import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: "com.turbometa.rayban", category: "RTMPStreaming")

@MainActor
class RTMPStreamingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var rtmpUrl: String = ""
    @Published var streamKey: String = ""
    @Published var selectedPlatform: StreamingPlatform = .custom
    @Published var bitrate: Int = 2_000_000 // 2 Mbps

    @Published var isStreaming: Bool = false
    @Published var isConnecting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    @Published var framesSent: Int64 = 0
    @Published var currentFps: Double = 0.0
    @Published var connectionTime: TimeInterval = 0
    @Published var bytesSent: Int64 = 0

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
    private weak var streamViewModel: StreamSessionViewModel?
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
    }

    // MARK: - Public Methods

    func setStreamViewModel(_ viewModel: StreamSessionViewModel) {
        self.streamViewModel = viewModel
    }

    func selectPlatform(_ platform: StreamingPlatform) {
        selectedPlatform = platform
        if platform != .custom {
            rtmpUrl = platform.defaultRtmpUrl
        }
    }

    func startStreaming() {
        guard !isStreaming else {
            logger.warning("Already streaming")
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

        // Get video dimensions from current frame
        let width = 504  // Default from Ray-Ban Meta
        let height = 504

        streamingService.startStreaming(url: fullUrl, width: width, height: height, bitrate: bitrate)

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
    }

    func feedFrame(_ image: UIImage, timestamp: Int64) {
        guard isStreaming else { return }
        streamingService.feedFrame(image, timestamp: timestamp)
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

        if !key.isEmpty {
            if !url.hasSuffix("/") {
                url += "/"
            }
            url += key
        }

        return url
    }

    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            Task { @MainActor in
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
        UserDefaults.standard.set(streamKey, forKey: "rtmp_stream_key")
        UserDefaults.standard.set(selectedPlatform.rawValue, forKey: "rtmp_platform")
        UserDefaults.standard.set(bitrate, forKey: "rtmp_bitrate")
    }

    private func loadSavedSettings() {
        if let savedUrl = UserDefaults.standard.string(forKey: "rtmp_url") {
            rtmpUrl = savedUrl
        }
        if let savedKey = UserDefaults.standard.string(forKey: "rtmp_stream_key") {
            streamKey = savedKey
        }
        if let savedPlatform = UserDefaults.standard.string(forKey: "rtmp_platform"),
           let platform = StreamingPlatform(rawValue: savedPlatform) {
            selectedPlatform = platform
        }
        let savedBitrate = UserDefaults.standard.integer(forKey: "rtmp_bitrate")
        if savedBitrate > 0 {
            bitrate = savedBitrate
        }
    }
}

// String.localized is defined in LanguageManager.swift
