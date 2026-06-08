/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionViewModel.swift
//
// Core view model demonstrating video streaming from Meta wearable devices using the DAT SDK.
// This class showcases the key streaming patterns: device selection, session management,
// video frame handling, photo capture, and error handling.
//

import MWDATCamera
import MWDATCore
import SwiftUI
import CoreMedia
import os.log

private let logger = Logger(subsystem: "com.smartview.glassai", category: "StreamSession")

enum StreamingStatus {
  case streaming
  case waiting
  case stopped
}

@MainActor
class StreamSessionViewModel: ObservableObject {
  @Published var currentVideoFrame: UIImage?
  @Published var currentSampleBuffer: CMSampleBuffer?
  @Published var hasReceivedFirstFrame: Bool = false
  @Published var streamingStatus: StreamingStatus = .stopped
  @Published var showError: Bool = false
  @Published var errorMessage: String = ""
  @Published var hasActiveDevice: Bool = false

  var isStreaming: Bool {
    streamingStatus != .stopped
  }

  // Timer properties
  @Published var activeTimeLimit: StreamTimeLimit = .noLimit
  @Published var remainingTime: TimeInterval = 0

  // Photo capture properties
  @Published var capturedPhoto: UIImage?
  @Published var showPhotoPreview: Bool = false
  @Published var showVisionRecognition: Bool = false
  @Published var showOmniRealtime: Bool = false
  @Published var showLeanEat: Bool = false

  private var timerTask: Task<Void, Never>?
  // The core DAT SDK StreamSession - handles all streaming operations
  // IMPORTANT: SDK requires ONE session instance, reused with start()/stop()
  private var streamSession: StreamSession
  // Listener tokens are used to manage DAT SDK event subscriptions
  private var stateListenerToken: AnyListenerToken?
  private var videoFrameListenerToken: AnyListenerToken?
  private var errorListenerToken: AnyListenerToken?
  private var photoDataListenerToken: AnyListenerToken?
  private let wearables: WearablesInterface
  private let deviceSelector: AutoDeviceSelector
  private var deviceMonitorTask: Task<Void, Never>?
  private var isProcessingFrame = false

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    logger.info("🟢 StreamSessionViewModel init")
    // Let the SDK auto-select from available devices
    self.deviceSelector = AutoDeviceSelector(wearables: wearables)

    // Create ONE session at init - SDK pattern requires reusing same session
    streamSession = Self.makeStreamSession(deviceSelector: deviceSelector)
    logger.info("🟢 StreamSession created")

    // Monitor device availability
    deviceMonitorTask = Task { @MainActor in
      for await device in deviceSelector.activeDeviceStream() {
        logger.info("📱 Device changed: \(device != nil ? "connected" : "disconnected")")
        self.hasActiveDevice = device != nil
      }
    }

    subscribeToStreamSession()

    updateStatusFromState(streamSession.state)
    logger.info("🟢 StreamSessionViewModel init complete")
  }

  func handleStartStreaming() async {
    logger.info("▶️ handleStartStreaming called")
    let permission = Permission.camera
    do {
      let status = try await wearables.checkPermissionStatus(permission)
      logger.info("▶️ Permission status: \(String(describing: status))")
      if status == .granted {
        await startSession()
        return
      }
      let requestStatus = try await wearables.requestPermission(permission)
      logger.info("▶️ Permission request result: \(String(describing: requestStatus))")
      if requestStatus == .granted {
        await startSession()
        return
      }
      showError("Permission denied")
    } catch {
      logger.error("❌ Permission error: \(error.localizedDescription)")
      showError("Permission error: \(error.description)")
    }
  }

  func applyVideoQuality(_ quality: String) async {
    UserDefaults.standard.set(quality, forKey: "video_quality")
    logger.info("🎥 Applying video quality: \(quality)")
    await recreateStreamSession()
  }

  func applyRTMPEncodingMode(_ mode: RTMPVideoEncodingMode) async {
    UserDefaults.standard.set(mode.rawValue, forKey: "rtmp_video_codec")
    logger.info("🎥 Applying RTMP video codec: \(mode.rawValue)")
    await recreateStreamSession()
  }

  private func recreateStreamSession() async {
    let wasStreaming = streamingStatus != .stopped
    if wasStreaming {
      await streamSession.stop()
    }

    stateListenerToken = nil
    videoFrameListenerToken = nil
    errorListenerToken = nil
    photoDataListenerToken = nil
    currentVideoFrame = nil
    currentSampleBuffer = nil
    hasReceivedFirstFrame = false
    isProcessingFrame = false

    streamSession = Self.makeStreamSession(deviceSelector: deviceSelector)
    subscribeToStreamSession()
    updateStatusFromState(streamSession.state)

    if wasStreaming {
      await startSession()
    }
  }

  func startSession() async {
    logger.info("🚀 startSession START")

    // Reset to unlimited time when starting a new stream
    activeTimeLimit = .noLimit
    remainingTime = 0
    stopTimer()

    // Reset frame state
    hasReceivedFirstFrame = false

    logger.info("🚀 Calling session.start()...")
    await streamSession.start()
    logger.info("🚀 startSession END - session.start() returned")
  }

  private func showError(_ message: String) {
    errorMessage = message
    showError = true
  }

  func stopSession() async {
    logger.info("⏹️ stopSession START")
    stopTimer()
    await streamSession.stop()
    logger.info("⏹️ stopSession END")
  }

  func dismissError() {
    showError = false
    errorMessage = ""
  }

  func setTimeLimit(_ limit: StreamTimeLimit) {
    activeTimeLimit = limit
    remainingTime = limit.durationInSeconds ?? 0

    if limit.isTimeLimited {
      startTimer()
    } else {
      stopTimer()
    }
  }

  func capturePhoto() {
    streamSession.capturePhoto(format: .jpeg)
  }

  func dismissPhotoPreview() {
    showPhotoPreview = false
    capturedPhoto = nil
  }

  private func startTimer() {
    stopTimer()
    timerTask = Task { @MainActor [weak self] in
      while let self, remainingTime > 0 {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
        guard !Task.isCancelled else { break }
        remainingTime -= 1
      }
      if let self, !Task.isCancelled {
        await stopSession()
      }
    }
  }

  private func stopTimer() {
    timerTask?.cancel()
    timerTask = nil
  }

  private func updateStatusFromState(_ state: StreamSessionState) {
    logger.info("📊 updateStatusFromState: \(String(describing: state)) -> streamingStatus update")
    switch state {
    case .stopped:
      logger.info("📊 State is STOPPED - clearing frame")
      currentVideoFrame = nil
      currentSampleBuffer = nil
      streamingStatus = .stopped
    case .waitingForDevice, .starting, .stopping, .paused:
      logger.info("📊 State is WAITING (\(String(describing: state)))")
      streamingStatus = .waiting
    case .streaming:
      logger.info("📊 State is STREAMING ✅")
      streamingStatus = .streaming
    }
  }

  private static func makeStreamSession(deviceSelector: AutoDeviceSelector) -> StreamSession {
    let quality = UserDefaults.standard.string(forKey: "video_quality") ?? "high"
    let resolution: StreamingResolution
    switch quality {
    case "low":
      resolution = .low
    case "medium":
      resolution = .medium
    default:
      resolution = .high
    }

    logger.info("🟢 Using video quality: \(quality) -> \(String(describing: resolution))")
    let codecSetting = UserDefaults.standard.string(forKey: "rtmp_video_codec") ?? RTMPVideoEncodingMode.h264.rawValue
    let videoCodec: VideoCodec = codecSetting == RTMPVideoEncodingMode.hevc.rawValue ? .hvc1 : .raw
    logger.info("🟢 Using video codec: \(codecSetting) -> \(String(describing: videoCodec))")

    let config = StreamSessionConfig(
      videoCodec: videoCodec,
      resolution: resolution,
      frameRate: 24)
    return StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
  }

  private func subscribeToStreamSession() {
    stateListenerToken = streamSession.statePublisher.listen { [weak self] state in
      Task { @MainActor [weak self] in
        logger.info("📊 State changed: \(String(describing: state))")
        self?.updateStatusFromState(state)
      }
    }

    videoFrameListenerToken = streamSession.videoFramePublisher.listen { [weak self] videoFrame in
      Task { @MainActor [weak self] in
        guard let self, !self.isProcessingFrame else { return }
        self.isProcessingFrame = true
        defer { self.isProcessingFrame = false }

        self.currentSampleBuffer = videoFrame.sampleBuffer

        if let image = videoFrame.makeUIImage() {
          self.currentVideoFrame = image
          if !self.hasReceivedFirstFrame {
            logger.info("🎥 First frame received and converted")
            self.hasReceivedFirstFrame = true
          }
        } else if !self.hasReceivedFirstFrame {
          logger.info("🎥 First compressed frame received")
          self.hasReceivedFirstFrame = true
        }
      }
    }

    errorListenerToken = streamSession.errorPublisher.listen { [weak self] error in
      Task { @MainActor [weak self] in
        guard let self else { return }
        logger.error("❌ Stream error: \(String(describing: error))")
        let newErrorMessage = formatStreamingError(error)
        if newErrorMessage != self.errorMessage {
          showError(newErrorMessage)
        }
      }
    }

    photoDataListenerToken = streamSession.photoDataPublisher.listen { [weak self] photoData in
      Task { @MainActor [weak self] in
        guard let self else { return }
        logger.info("📸 Photo captured - size: \(photoData.data.count) bytes")
        if let uiImage = UIImage(data: photoData.data) {
          self.capturedPhoto = uiImage
          self.showPhotoPreview = true
        }
      }
    }
  }

  private func formatStreamingError(_ error: StreamSessionError) -> String {
    switch error {
    case .internalError:
      return "An internal error occurred. Please try again."
    case .deviceNotFound:
      return "Device not found. Please ensure your device is connected."
    case .deviceNotConnected:
      return "Device not connected. Please check your connection and try again."
    case .timeout:
      return "The operation timed out. Please try again."
    case .videoStreamingError:
      return "Video streaming failed. Please try again."
    case .permissionDenied:
      return "Camera permission denied. Please grant permission in Settings."
    case .hingesClosed:
      return "Glasses hinges are closed. Please open them to continue."
    case .thermalCritical:
      return "Device temperature is too high. Streaming paused."
    @unknown default:
      return "An unknown streaming error occurred."
    }
  }

  /// Full cleanup of all resources - call when ViewModel is no longer needed
  func cleanup() async {
    logger.info("🔴 cleanup START")
    stopTimer()
    deviceMonitorTask?.cancel()
    deviceMonitorTask = nil
    await streamSession.stop()
    // Clear listeners
    stateListenerToken = nil
    videoFrameListenerToken = nil
    errorListenerToken = nil
    photoDataListenerToken = nil
    logger.info("🔴 cleanup END")
  }
}
