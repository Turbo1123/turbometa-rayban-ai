/*
 * Gallery View
 * 图库 - 显示拍摄的照片
 */

import SwiftUI

struct GalleryView: View {
    @State private var photos: [GalleryPhoto] = []
    @State private var selectedPhoto: GalleryPhoto?
    @State private var showPhotoDetail = false

    let columns = [
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm),
        GridItem(.flexible(), spacing: AppSpacing.sm)
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                AppColors.secondaryBackground
                    .ignoresSafeArea()

                if photos.isEmpty {
                    // Empty state
                    VStack(spacing: AppSpacing.lg) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.textTertiary)

                        Text("暂无照片")
                            .font(AppTypography.title2)
                            .foregroundColor(AppColors.textPrimary)

                        Text("使用 Live AI 拍摄照片后将显示在这里")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                            ForEach(photos) { photo in
                                PhotoGridItem(photo: photo)
                                    .onTapGesture {
                                        selectedPhoto = photo
                                        showPhotoDetail = true
                                    }
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
            }
            .navigationTitle("图库")
            .sheet(isPresented: $showPhotoDetail) {
                if let photo = selectedPhoto {
                    PhotoDetailView(photo: photo)
                }
            }
        }
        .onAppear {
            loadPhotos()
        }
    }

    private func loadPhotos() {
        // TODO: Load photos from storage
        // For now, using placeholder data
        photos = []
    }
}

// MARK: - Gallery Photo Model

struct GalleryPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
    let aiDescription: String?
}

// MARK: - Photo Grid Item

struct PhotoGridItem: View {
    let photo: GalleryPhoto

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.width)
                .clipped()
                .cornerRadius(AppCornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.md)
                        .stroke(AppColors.textTertiary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: AppShadow.small(), radius: 4, x: 0, y: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Photo Detail View

struct PhotoDetailView: View {
    let photo: GalleryPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Photo
                    Image(uiImage: photo.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // AI Description (if available)
                    if let description = photo.aiDescription {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("AI 识别")
                                .font(AppTypography.headline)
                                .foregroundColor(.white)

                            Text(description)
                                .font(AppTypography.body)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(nil)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.lg)
                        .background(Color.black.opacity(0.8))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sharePhoto()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func sharePhoto() {
        let activityVC = UIActivityViewController(
            activityItems: [photo.image],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}
