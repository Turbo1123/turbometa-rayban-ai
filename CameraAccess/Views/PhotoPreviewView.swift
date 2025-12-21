/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// PhotoPreviewView.swift
//
// UI for previewing and sharing photos captured from Meta wearable devices via the DAT SDK.
// This view displays photos captured using StreamSession.capturePhoto() and provides sharing
// functionality.
//

import SwiftUI

struct PhotoPreviewView: View {
  let photo: UIImage
  let onDismiss: () -> Void
  let onAIRecognition: (() -> Void)?
  let onLeanEat: (() -> Void)?

  @State private var showShareSheet = false
  @State private var dragOffset = CGSize.zero

  var body: some View {
    ZStack {
      // Semi-transparent background overlay
      Color.black.opacity(0.8)
        .ignoresSafeArea()
        .onTapGesture {
          dismissWithAnimation()
        }

      VStack(spacing: 20) {
        photoDisplayView

        // Action Buttons
        VStack(spacing: 12) {
          // Top row: AI Recognition and LeanEat
          HStack(spacing: 12) {
            // AI Recognition Button
            if let onAIRecognition = onAIRecognition {
              Button {
                onAIRecognition()
              } label: {
                HStack {
                  Image(systemName: "brain")
                  Text(NSLocalizedString("photo.ai", comment: "AI Recognition"))
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
              }
            }

            // LeanEat Button
            if let onLeanEat = onLeanEat {
              Button {
                onLeanEat()
              } label: {
                HStack {
                  Image(systemName: "chart.bar.fill")
                  Text(NSLocalizedString("photo.nutrition", comment: "Nutrition Analysis"))
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.leanEat)
                .foregroundColor(.white)
                .cornerRadius(12)
              }
            }
          }

          // Bottom row: Share
          Button {
            showShareSheet = true
          } label: {
            HStack {
              Image(systemName: "square.and.arrow.up")
              Text(NSLocalizedString("photo.share", comment: "Share"))
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(12)
          }
        }
        .padding(.horizontal, 40)
      }
      .padding()
      .offset(dragOffset)
      .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dragOffset)
    }
    .sheet(isPresented: $showShareSheet) {
      ShareSheet(photo: photo)
    }
  }

  private var photoDisplayView: some View {
    GeometryReader { geometry in
      Image(uiImage: photo)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height * 0.6)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .gesture(
          DragGesture()
            .onChanged { value in
              dragOffset = value.translation
            }
            .onEnded { value in
              if abs(value.translation.height) > 100 {
                dismissWithAnimation()
              } else {
                withAnimation(.spring()) {
                  dragOffset = .zero
                }
              }
            }
        )
    }
  }

  private func dismissWithAnimation() {
    withAnimation(.easeInOut(duration: 0.3)) {
      dragOffset = CGSize(width: 0, height: UIScreen.main.bounds.height)
    }
    Task {
      try? await Task.sleep(nanoseconds: 300_000_000)
      onDismiss()
    }
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let photo: UIImage

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let activityViewController = UIActivityViewController(
      activityItems: [photo],
      applicationActivities: nil
    )

    // Exclude certain activity types if needed
    activityViewController.excludedActivityTypes = [
      .assignToContact,
      .addToReadingList,
    ]

    return activityViewController
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // No updates needed
  }
}
