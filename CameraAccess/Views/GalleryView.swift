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
        let loadedPhotos = PhotoStorageService.shared.loadPhotos()
        // 限制照片数量以避免内存问题
        let maxPhotos = 1000
        if loadedPhotos.count > maxPhotos {
            photos = Array(loadedPhotos.prefix(maxPhotos))
            logWarning("Gallery photo count limited to \(maxPhotos)", category: .performance)
        } else {
            photos = loadedPhotos
        }
        logInfo("Gallery loaded (\(photos.count) photos)", category: .ui)
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

    // 最大存储照片数量
    private let maxStoredPhotos = 1000

    init() {
        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: photosDirectory.path) {
            do {
                try fileManager.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
                logInfo("Created photos directory: \(photosDirectory.path)", category: .general)
            } catch {
                logError("Failed to create photos directory: \(error.localizedDescription)", category: .general)
            }
        }
    }

    func savePhoto(_ image: UIImage, description: String? = nil) {
        // 使用ImageProcessor优化压缩
        guard let data = image.compressed(maxFileSizeKB: 500) else {
            logError("Failed to compress image for storage", category: .general)
            return
        }

        let timestamp = Date()
        let filename = "\(Int(timestamp.timeIntervalSince1970)).jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            logInfo("Saved photo to storage", category: .general)

            // 清理旧照片
            cleanupOldPhotos()
        } catch {
            logError("Failed to save photo: \(error.localizedDescription)", category: .general)
        }
    }

    func loadPhotos() -> [GalleryPhoto] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: photosDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        let sortedURLs = fileURLs.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }

        let photos = sortedURLs.compactMap { url -> GalleryPhoto? in
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                return nil
            }

            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()

            return GalleryPhoto(image: image, timestamp: creationDate, aiDescription: nil)
        }

        logInfo("Loaded \(photos.count) photos from storage", category: .general)
        return photos
    }

    /// 清理旧照片，保持最大数量限制
    private func cleanupOldPhotos() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: photosDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        if fileURLs.count > maxStoredPhotos {
            let sortedURLs = fileURLs.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }

            // 删除最旧的照片
            let urlsToDelete = Array(sortedURLs.prefix(fileURLs.count - maxStoredPhotos))
            for url in urlsToDelete {
                try? fileManager.removeItem(at: url)
            }

            logInfo("Cleaned up \(urlsToDelete.count) old photos", category: .general)
        }
    }

    /// 清除所有照片
    func clearAllPhotos() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)
            for url in fileURLs {
                try fileManager.removeItem(at: url)
            }
            logInfo("Cleared all photos from storage", category: .general)
        } catch {
            logError("Failed to clear photos: \(error.localizedDescription)", category: .general)
        }
    }
}

public struct GalleryPhoto: Identifiable {
    public let id = UUID()
    public let image: UIImage
    public let timestamp: Date
    public let aiDescription: String?
}
