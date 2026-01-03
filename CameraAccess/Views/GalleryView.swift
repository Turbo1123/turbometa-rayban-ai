/*
 * Gallery View
 * 图库 - 显示拍摄的照片
 */

import SwiftUI
import UIKit

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
        photos = PhotoStorageService.shared.loadPhotos()
    }
}

// MARK: - Gallery Photo Model



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

// MARK: - Photo Storage Service
// (Placed here to ensure compilation visibility)
class PhotoStorageService {
    static let shared = PhotoStorageService()
    
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var photosDirectory: URL {
        documentsDirectory.appendingPathComponent("CapturedPhotos")
    }
    
    init() {
        createDirectoryIfNeeded()
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            try? fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        }
    }
    
    func savePhoto(_ image: UIImage, description: String? = nil) {
        let timestamp = Date()
        let filename = "\(Int(timestamp.timeIntervalSince1970)).jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)
        
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        
        do {
            try data.write(to: fileURL)
            print("✅ [PhotoStorage] Saved photo to \(fileURL.path)")
        } catch {
            print("❌ [PhotoStorage] Failed to save photo: \(error)")
        }
    }
    
    func loadPhotos() -> [GalleryPhoto] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        let sortedURLs = fileURLs.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
        
        return sortedURLs.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return nil }
            
            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
            
            return GalleryPhoto(image: image, timestamp: creationDate, aiDescription: nil)
        }
    }
}

public struct GalleryPhoto: Identifiable {
    public let id = UUID()
    public let image: UIImage
    public let timestamp: Date
    public let aiDescription: String?
}
