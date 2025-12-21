/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// HomeScreenView.swift
//
// Welcome screen that guides users through the DAT SDK registration process.
// This view is displayed when the app is not yet registered.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel
  @State private var showConnectionSuccess = false

  var body: some View {
    ZStack {
      // Gradient background
      LinearGradient(
        colors: [
          AppColors.primary.opacity(0.15),
          AppColors.secondary.opacity(0.15),
          Color.white
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .edgesIgnoringSafeArea(.all)

      VStack(spacing: AppSpacing.xl) {
        Spacer()

        // TurboMeta Logo
        VStack(spacing: AppSpacing.md) {
          Image(.cameraAccessIcon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)

          Text("TurboMeta")
            .font(AppTypography.largeTitle)
            .foregroundColor(AppColors.textPrimary)

          Text("Rayban Meta助手")
            .font(AppTypography.callout)
            .foregroundColor(AppColors.textSecondary)
        }

        // Features
        VStack(spacing: AppSpacing.md) {
          FeatureTipView(
            icon: "video.fill",
            title: "实时视频",
            text: "从眼镜视角直接录制视频，捕捉你的所见所闻"
          )
          FeatureTipView(
            icon: "brain.head.profile",
            title: "AI 对话",
            text: "实时 AI 助手，随时随地为你提供智能帮助"
          )
          FeatureTipView(
            icon: "waveform",
            title: "开放式音频",
            text: "保持耳朵对周围世界的开放，同时接收通知"
          )
        }

        Spacer()

        // Connection Button
        VStack(spacing: AppSpacing.md) {
          Text("将跳转到 Meta AI 应用确认连接")
            .font(AppTypography.footnote)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.lg)

          Button {
            viewModel.connectGlasses()
          } label: {
            HStack(spacing: AppSpacing.sm) {
              if viewModel.registrationState == .registering {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("连接中...")
              } else {
                Image(systemName: "eye.circle.fill")
                  .font(.title3)
                Text("连接 Ray-Ban Meta")
              }
            }
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
              LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 8, x: 0, y: 4)
          }
          .disabled(viewModel.registrationState == .registering)
          .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.xl)
      }
      .padding(.vertical, AppSpacing.xl)

      // Connection Success Toast
      if showConnectionSuccess {
        VStack {
          Spacer()

          HStack(spacing: AppSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
              .font(.title2)
              .foregroundColor(.green)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
              Text("连接成功")
                .font(AppTypography.headline)
                .foregroundColor(.white)
              Text("正在进入 TurboMeta...")
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.9))
            }

            Spacer()
          }
          .padding(AppSpacing.md)
          .background(Color.black.opacity(0.85))
          .cornerRadius(AppCornerRadius.lg)
          .shadow(color: AppShadow.large(), radius: 15, x: 0, y: 8)
          .padding(AppSpacing.lg)
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .onChange(of: viewModel.registrationState) { newState in
      if newState == .registered {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
          showConnectionSuccess = true
        }

        // Auto dismiss after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          withAnimation {
            showConnectionSuccess = false
          }
        }
      }
    }
  }

}

// MARK: - Feature Tip View

struct FeatureTipView: View {
  let icon: String
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: AppSpacing.md) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [AppColors.primary.opacity(0.2), AppColors.secondary.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 48, height: 48)

        Image(systemName: icon)
          .font(.title3)
          .foregroundColor(AppColors.primary)
      }

      VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(title)
          .font(AppTypography.headline)
          .foregroundColor(AppColors.textPrimary)

        Text(text)
          .font(AppTypography.subheadline)
          .foregroundColor(AppColors.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()
    }
    .padding(.horizontal, AppSpacing.lg)
  }
}
