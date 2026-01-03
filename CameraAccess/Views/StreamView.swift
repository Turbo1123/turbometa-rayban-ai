/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming from Meta wearable devices using the DAT SDK.
// This view demonstrates the complete streaming API: video streaming with real-time display, photo capture,
// and error handling.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var showAPIKeyMissingAlert = false

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // 未连接设备提醒
      if !viewModel.hasActiveDevice {
        deviceNotConnectedView
      } else {
        // Video backdrop
        if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        GeometryReader { geometry in
          Image(uiImage: videoFrame)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundColor(.white)
      }

      // Bottom controls layer

      VStack {
        Spacer()
        ControlsView(viewModel: viewModel)
      }
      .padding(.all, 24)
      // Timer display area with fixed height
      VStack {
        Spacer()
        if viewModel.activeTimeLimit.isTimeLimited && viewModel.remainingTime > 0 {
          Text("Streaming ending in \(viewModel.remainingTime.formattedCountdown)")
            .font(.system(size: 15))
            .foregroundColor(.white)
        }
      }

      // Close Button (Always visible)
      VStack {
          HStack {
              Button {
                  Task {
                      await viewModel.stopSession()
                  }
                  dismiss()
              } label: {
                  Image(systemName: "xmark.circle.fill")
                      .font(.system(size: 32))
                      .foregroundColor(.white.opacity(0.8))
                      .padding()
              }
              Spacer()
          }
          Spacer()
      }
      }
    }
    .onChange(of: viewModel.hasActiveDevice) { isConnected in
      if isConnected {
        print("⚡️ StreamView: Device connected, starting stream...")
        Task {
          await viewModel.handleStartStreaming()
        }
      }
    }
    .onAppear {
      // 只有设备连接时才启动视频流
      guard viewModel.hasActiveDevice else {
        print("⚠️ StreamView: 未连接RayBan Meta眼镜，跳过启动")
        return
      }

      // 自动启动视频流
      Task {
        print("🎥 StreamView: 启动视频流")
        await viewModel.handleStartStreaming()
      }
    }
    .onDisappear {
      Task {
        if viewModel.streamingStatus != .stopped {
          await viewModel.stopSession()
        }
      }
    }
    // Show captured photos from DAT SDK in a preview sheet
    .sheet(isPresented: $viewModel.showPhotoPreview) {
      if let photo = viewModel.capturedPhoto {
        PhotoPreviewView(
          photo: photo,
          onDismiss: {
            viewModel.dismissPhotoPreview()
          },
          onAIRecognition: {
            if VisionAPIConfig.apiKey.isEmpty {
              showAPIKeyMissingAlert = true
            } else {
              viewModel.showPhotoPreview = false
              viewModel.showVisionRecognition = true
            }
          },
          onLeanEat: {
            if VisionAPIConfig.apiKey.isEmpty {
              showAPIKeyMissingAlert = true
            } else {
              viewModel.showPhotoPreview = false
              viewModel.showLeanEat = true
            }
          }
        )
      }
    }
    // Show AI Vision Recognition view
    .sheet(isPresented: $viewModel.showVisionRecognition) {
      if let photo = viewModel.capturedPhoto {
        VisionRecognitionView(
          photo: photo,
          apiKey: VisionAPIConfig.apiKey
        )
      }
    }
    // Show LeanEat nutrition analysis view
    .sheet(isPresented: $viewModel.showLeanEat) {
      if let photo = viewModel.capturedPhoto {
        LeanEatView(
          photo: photo,
          apiKey: VisionAPIConfig.apiKey
        )
      }
    }
    // Show Omni Realtime Chat view
    .fullScreenCover(isPresented: $viewModel.showOmniRealtime) {
      OmniRealtimeView(
        streamViewModel: viewModel,
        apiKey: VisionAPIConfig.apiKey
      )
    }
    .alert("需要配置 API Key", isPresented: $showAPIKeyMissingAlert) {
      Button("知道了") {}
    } message: {
      Text("请先在“我的”→“API Key 管理”中完成配置")
    }
  }

  // MARK: - Device Not Connected View

  private var deviceNotConnectedView: some View {
    VStack(spacing: AppSpacing.xl) {
      Spacer()

      VStack(spacing: AppSpacing.lg) {
        Image(systemName: "eyeglasses")
          .font(.system(size: 80))
          .foregroundColor(.white.opacity(0.6))

        Text("未连接RayBan Meta眼镜")
          .font(AppTypography.title2)
          .foregroundColor(.white)

        Text("请先在首页连接你的智能眼镜，\n然后再使用直播功能")
          .font(AppTypography.body)
          .foregroundColor(.white.opacity(0.8))
          .multilineTextAlignment(.center)
          .padding(.horizontal, AppSpacing.xl)
      }

      Spacer()

      // 返回按钮
      Button {
        dismiss()
      } label: {
        HStack(spacing: AppSpacing.sm) {
          Image(systemName: "chevron.left")
          Text("返回首页")
            .font(AppTypography.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(.white)
        .foregroundColor(.black)
        .cornerRadius(AppCornerRadius.lg)
      }
      .padding(.horizontal, AppSpacing.xl)
      .padding(.bottom, AppSpacing.xl)
    }
  }
}

// Extracted controls for clarity
struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  var body: some View {
    // Controls row
    HStack(spacing: 8) {
      CustomButton(
        title: "Stop streaming",
        style: .destructive,
        isDisabled: false
      ) {
        Task {
          await viewModel.stopSession()
        }
      }

      // Timer button
      CircleButton(
        icon: "timer",
        text: viewModel.activeTimeLimit != .noLimit ? viewModel.activeTimeLimit.displayText : nil
      ) {
        let nextTimeLimit = viewModel.activeTimeLimit.next
        viewModel.setTimeLimit(nextTimeLimit)
      }

      // Photo button
      CircleButton(icon: "camera.fill", text: nil) {
        viewModel.capturePhoto()
      }

      // AI Realtime Chat button
      CircleButton(icon: "brain.head.profile", text: nil) {
        viewModel.showOmniRealtime = true
      }
    }
  }
}
