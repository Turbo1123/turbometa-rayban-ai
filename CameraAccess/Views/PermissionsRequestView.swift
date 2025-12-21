/*
 * Permissions Request View
 * 应用启动时的权限请求界面
 */

import SwiftUI

struct PermissionsRequestView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    @State private var isRequesting = false
    @State private var showSettings = false
    let onComplete: (Bool) -> Void

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [AppColors.primary.opacity(0.1), AppColors.secondary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.primary)

                // Title
                VStack(spacing: AppSpacing.sm) {
                    Text("需要您的授权")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.textPrimary)

                    Text("TurboMeta 需要以下权限才能正常工作")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }

                // Permissions List
                VStack(spacing: AppSpacing.md) {
                    PermissionRow(
                        icon: "mic.fill",
                        title: "麦克风",
                        description: "语音对话和录音"
                    )

                    PermissionRow(
                        icon: "photo.fill",
                        title: "相册",
                        description: "保存眼镜拍摄的照片"
                    )
                }
                .padding(.horizontal, AppSpacing.xl)

                Spacer()

                // Request Button
                VStack(spacing: AppSpacing.md) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                    } else if showSettings {
                        VStack(spacing: AppSpacing.sm) {
                            Text("部分权限未授予")
                                .font(AppTypography.caption)
                                .foregroundColor(.red)

                            Button {
                                permissionsManager.openSettings()
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("前往设置")
                                        .font(AppTypography.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(AppCornerRadius.lg)
                            }

                            Button("继续使用（功能受限）") {
                                onComplete(false)
                            }
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        Button {
                            requestPermissions()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("授予权限")
                                    .font(AppTypography.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(AppCornerRadius.lg)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .onAppear {
            // 检查是否已有权限
            if permissionsManager.checkAllPermissions() {
                onComplete(true)
            }
        }
    }

    private func requestPermissions() {
        isRequesting = true

        permissionsManager.requestAllPermissions { allGranted in
            isRequesting = false

            if allGranted {
                // 所有权限已授予，继续
                onComplete(true)
            } else {
                // 部分权限未授予，显示设置按钮
                showSettings = true
            }
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(AppColors.primary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.white)
        .cornerRadius(AppCornerRadius.md)
        .shadow(color: AppShadow.small(), radius: 5, x: 0, y: 2)
    }
}
