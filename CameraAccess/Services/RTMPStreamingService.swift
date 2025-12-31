/*
 * RTMP Streaming Service
 * Streams video from Ray-Ban Meta glasses to any RTMP server
 * Supports all major live streaming platforms: YouTube, Twitch, Bilibili, Douyin, TikTok, etc.
 *
 * Uses HaishinKit for RTMP streaming with H.264 encoding
 */

import Foundation
import UIKit
import AVFoundation
import VideoToolbox
import HaishinKit
import RTMPHaishinKit
import os.log

private let logger = Logger(subsystem: "com.turbometa.rayban", category: "RTMPStreaming")

// MARK: - Streaming State

enum RTMPStreamingState: Sendable {
    case idle
    case connecting
    case streaming
    case disconnected
    case error(String)
}

// MARK: - Streaming Stats

struct RTMPStreamingStats: Sendable {
    var framesSent: Int64 = 0
    var bytesSent: Int64 = 0
    var fps: Double = 0
    var connectionTime: TimeInterval = 0
}

// MARK: - RTMP Streaming Service

class RTMPStreamingService: NSObject, @unchecked Sendable {

    // MARK: - Constants

    private static let defaultBitrate: Int = 2_000_000 // 2 Mbps
    private static let defaultFPS: Int = 24

    // MARK: - Properties

    private var rtmpConnection: RTMPConnection?
    private var rtmpStream: RTMPStream?

    private var rtmpUrl: String = ""
    private var streamKey: String = ""
    private var videoWidth: Int = 0
    private var videoHeight: Int = 0
    private var bitrate: Int = RTMPStreamingService.defaultBitrate

    // State
    private(set) var isStreaming = false
    private var startTime: Date?

    // Frame tracking
    private var totalFrames: Int64 = 0
    private var frameIndex: Int64 = 0
    private var baseTimestamp: Int64 = 0
    private let targetFrameDuration: Int64 = 1_000_000 / Int64(RTMPStreamingService.defaultFPS)

    // Callbacks
    var onStateChanged: ((RTMPStreamingState) -> Void)?
    var onStatsUpdated: ((RTMPStreamingStats) -> Void)?
    var onError: ((String) -> Void)?

    // Status monitoring task
    private var statusTask: Task<Void, Never>?
    private var streamStatusTask: Task<Void, Never>?

    // MARK: - Initialization

    override init() {
        super.init()
        logger.info("RTMPStreamingService initialized with HaishinKit")
    }

    deinit {
        stopStreaming()
    }

    // MARK: - Public Methods

    /// Start RTMP streaming
    func startStreaming(url: String, width: Int, height: Int, bitrate: Int = defaultBitrate) {
        guard !isStreaming else {
            logger.warning("Already streaming")
            return
        }

        logger.info("Starting RTMP streaming to: \(url)")
        logger.info("Video: \(width)x\(height) @ \(bitrate) bps")

        self.videoWidth = width
        self.videoHeight = height
        self.bitrate = bitrate

        // Parse URL to get server URL and stream key
        guard let urlComponents = parseRTMPUrl(url) else {
            onStateChanged?(.error("Invalid RTMP URL"))
            onError?("Invalid RTMP URL format")
            return
        }

        self.rtmpUrl = urlComponents.serverUrl
        self.streamKey = urlComponents.streamKey

        onStateChanged?(.connecting)

        // Create connection and stream
        Task {
            await setupAndConnect()
        }
    }

    /// Stop streaming
    func stopStreaming() {
        logger.info("Stopping RTMP streaming")

        isStreaming = false

        // Cancel status monitoring tasks
        statusTask?.cancel()
        statusTask = nil
        streamStatusTask?.cancel()
        streamStatusTask = nil

        Task {
            if let stream = rtmpStream {
                _ = try? await stream.close()
            }
            if let connection = rtmpConnection {
                _ = try? await connection.close()
            }
        }

        rtmpStream = nil
        rtmpConnection = nil

        // Reset state
        totalFrames = 0
        frameIndex = 0
        baseTimestamp = 0
        startTime = nil

        onStateChanged?(.idle)
        logger.info("RTMP streaming stopped")
    }

    /// Feed a video frame for streaming
    func feedFrame(_ image: UIImage, timestamp: Int64) {
        guard isStreaming, let stream = rtmpStream else { return }

        totalFrames += 1

        // Convert UIImage to CMSampleBuffer
        guard let sampleBuffer = image.toCMSampleBuffer(timestamp: timestamp) else {
            logger.warning("Failed to create CMSampleBuffer from UIImage")
            return
        }

        // Append to stream
        Task {
            await stream.append(sampleBuffer)
        }

        // Update stats
        updateStats()
    }

    // MARK: - Private Methods

    private func setupAndConnect() async {
        // Create RTMP connection
        let connection = RTMPConnection()
        self.rtmpConnection = connection

        // Monitor connection status
        statusTask = Task { [weak self] in
            for await status in await connection.status {
                await self?.handleConnectionStatus(status)
            }
        }

        // Connect to server
        let url = self.rtmpUrl
        do {
            logger.info("RTMP: Connecting to \(url)")
            _ = try await connection.connect(url)
            logger.info("RTMP: Connected successfully")

            // Create stream and publish
            await createStreamAndPublish(connection: connection)
        } catch {
            logger.error("RTMP: Connection failed: \(error.localizedDescription)")
            await MainActor.run {
                onStateChanged?(.error(error.localizedDescription))
                onError?(error.localizedDescription)
            }
        }
    }

    private func createStreamAndPublish(connection: RTMPConnection) async {
        // Create RTMP stream
        let stream = RTMPStream(connection: connection)
        self.rtmpStream = stream

        // Configure video settings
        var videoSettings = VideoCodecSettings()
        videoSettings.videoSize = CGSize(width: videoWidth, height: videoHeight)
        videoSettings.bitRate = bitrate
        videoSettings.maxKeyFrameIntervalDuration = 1
        videoSettings.profileLevel = kVTProfileLevel_H264_Main_AutoLevel as String
        try? await stream.setVideoSettings(videoSettings)

        // Monitor stream status
        streamStatusTask = Task { [weak self] in
            for await status in await stream.status {
                await self?.handleStreamStatus(status)
            }
        }

        // Publish
        let key = self.streamKey
        do {
            logger.info("RTMP: Publishing stream with key: \(key)")
            _ = try await stream.publish(key, type: .live)
            logger.info("RTMP: Publish started")

            await MainActor.run { [weak self] in
                self?.isStreaming = true
                self?.startTime = Date()
                self?.onStateChanged?(.streaming)
            }
        } catch {
            logger.error("RTMP: Publish failed: \(error.localizedDescription)")
            await MainActor.run {
                onStateChanged?(.error(error.localizedDescription))
                onError?(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func handleConnectionStatus(_ status: RTMPStatus) {
        logger.info("RTMP: Connection status: \(status.code)")

        if status.code == RTMPConnection.Code.connectFailed.rawValue {
            isStreaming = false
            onStateChanged?(.error("Connection failed: \(status.description)"))
            onError?("Failed to connect to RTMP server")
        } else if status.code == RTMPConnection.Code.connectClosed.rawValue {
            isStreaming = false
            onStateChanged?(.disconnected)
        } else if status.code == RTMPConnection.Code.connectRejected.rawValue {
            isStreaming = false
            onStateChanged?(.error("Connection rejected: \(status.description)"))
            onError?("Connection rejected by server")
        }
    }

    @MainActor
    private func handleStreamStatus(_ status: RTMPStatus) {
        logger.info("RTMP: Stream status: \(status.code)")

        if status.code == RTMPStream.Code.publishStart.rawValue {
            isStreaming = true
            startTime = Date()
            onStateChanged?(.streaming)
        } else if status.code == RTMPStream.Code.publishBadName.rawValue {
            isStreaming = false
            onStateChanged?(.error("Invalid stream name"))
            onError?("Invalid stream name")
        } else if status.code == RTMPStream.Code.connectClosed.rawValue ||
                  status.code == RTMPStream.Code.connectFailed.rawValue {
            isStreaming = false
            onStateChanged?(.disconnected)
        }
    }

    private func parseRTMPUrl(_ url: String) -> (serverUrl: String, streamKey: String)? {
        // URL format: rtmp://server.com/app/streamkey
        // We need to split into: rtmp://server.com/app and streamkey

        guard let urlObj = URL(string: url) else { return nil }

        let pathComponents = urlObj.path.split(separator: "/")
        guard pathComponents.count >= 2 else {
            // If only one path component, use it as stream key with default app
            let streamKey = pathComponents.first.map(String.init) ?? "stream"
            let serverUrl = "\(urlObj.scheme ?? "rtmp")://\(urlObj.host ?? "localhost"):\(urlObj.port ?? 1935)/live"
            return (serverUrl, streamKey)
        }

        // Last component is stream key
        let streamKey = String(pathComponents.last!)

        // Everything before is the server URL with app
        let appPath = pathComponents.dropLast().map(String.init).joined(separator: "/")
        let serverUrl = "\(urlObj.scheme ?? "rtmp")://\(urlObj.host ?? "localhost"):\(urlObj.port ?? 1935)/\(appPath)"

        return (serverUrl, streamKey)
    }

    private func updateStats() {
        guard let start = startTime else { return }

        let elapsed = Date().timeIntervalSince(start)
        let fps = elapsed > 0 ? Double(totalFrames) / elapsed : 0

        let stats = RTMPStreamingStats(
            framesSent: totalFrames,
            bytesSent: 0, // HaishinKit doesn't expose this directly
            fps: fps,
            connectionTime: elapsed
        )

        onStatsUpdated?(stats)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func toCMSampleBuffer(timestamp: Int64) -> CMSampleBuffer? {
        guard let cgImage = cgImage else { return nil }

        let width = Int(size.width)
        let height = Int(size.height)

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create format description
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )

        guard let format = formatDescription else { return nil }

        // Create timing info
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 24),
            presentationTimeStamp: CMTime(value: timestamp, timescale: 1_000_000),
            decodeTimeStamp: .invalid
        )

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    func toPixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        guard let cgImage = cgImage else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
