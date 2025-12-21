/*
 * Permissions Manager
 * 统一管理应用所需的所有权限
 */

import Foundation
import UIKit
import AVFoundation
import Photos

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var allPermissionsGranted = false

    private init() {}

    // MARK: - 请求所有权限

    func requestAllPermissions(completion: @escaping (Bool) -> Void) {
        print("📋 [Permissions] 开始请求所有权限...")

        // 使用 DispatchGroup 等待所有权限请求完成
        let group = DispatchGroup()
        var microphoneGranted = false
        var photoLibraryGranted = false

        // 1. 请求麦克风权限
        group.enter()
        requestMicrophonePermission { granted in
            microphoneGranted = granted
            group.leave()
        }

        // 2. 请求相册权限
        group.enter()
        requestPhotoLibraryPermission { granted in
            photoLibraryGranted = granted
            group.leave()
        }

        // 所有权限请求完成
        group.notify(queue: .main) {
            let allGranted = microphoneGranted && photoLibraryGranted
            self.allPermissionsGranted = allGranted

            if allGranted {
                print("✅ [Permissions] 所有权限已授予")
            } else {
                print("⚠️ [Permissions] 部分权限未授予:")
                print("   麦克风: \(microphoneGranted ? "✅" : "❌")")
                print("   相册: \(photoLibraryGranted ? "✅" : "❌")")
            }

            completion(allGranted)
        }
    }

    // MARK: - 检查所有权限状态

    func checkAllPermissions() -> Bool {
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        let microphoneGranted = microphoneStatus == .authorized
        let photoGranted = photoStatus == .authorized || photoStatus == .limited

        allPermissionsGranted = microphoneGranted && photoGranted
        return allPermissionsGranted
    }

    // MARK: - 麦克风权限

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            print("✅ [Permissions] 麦克风权限已授予")
            completion(true)

        case .notDetermined:
            print("🎤 [Permissions] 请求麦克风权限...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    print(granted ? "✅ [Permissions] 麦克风权限已授予" : "❌ [Permissions] 麦克风权限被拒绝")
                    completion(granted)
                }
            }

        case .denied, .restricted:
            print("❌ [Permissions] 麦克风权限被拒绝或受限")
            completion(false)

        @unknown default:
            completion(false)
        }
    }

    // MARK: - 相册权限

    private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            print("✅ [Permissions] 相册权限已授予")
            completion(true)

        case .notDetermined:
            print("📷 [Permissions] 请求相册权限...")
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    let granted = newStatus == .authorized || newStatus == .limited
                    print(granted ? "✅ [Permissions] 相册权限已授予" : "❌ [Permissions] 相册权限被拒绝")
                    completion(granted)
                }
            }

        case .denied, .restricted:
            print("❌ [Permissions] 相册权限被拒绝或受限")
            completion(false)

        @unknown default:
            completion(false)
        }
    }

    // MARK: - 打开系统设置

    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
}
