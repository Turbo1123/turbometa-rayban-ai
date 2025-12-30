/*
 * Settings View
 * 个人中心 - 设备管理和设置
 */

import SwiftUI
import MWDATCore

struct SettingsView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var languageManager = LanguageManager.shared
    let apiKey: String

    @State private var showAPIKeySettings = false
    @State private var showModelSettings = false
    @State private var showLanguageSettings = false
    @State private var showAppLanguageSettings = false
    @State private var showQualitySettings = false
    @State private var selectedModel = "qwen3-omni-flash-realtime"
    @State private var selectedLanguage = "zh-CN" // 默认中文
    @State private var selectedQuality = UserDefaults.standard.string(forKey: "video_quality") ?? "medium"
    @State private var hasAPIKey = false // 改为 State 变量

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self.apiKey = apiKey
    }

    // 刷新 API Key 状态
    private func refreshAPIKeyStatus() {
        hasAPIKey = APIKeyManager.shared.hasAPIKey()
    }

    var body: some View {
        NavigationView {
            List {
                // 设备管理
                Section {
                    // 连接状态
                    HStack {
                        Image(systemName: "eye.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ray-Ban Meta")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.textPrimary)
                            Text(streamViewModel.hasActiveDevice ? "settings.device.connected".localized : "settings.device.notconnected".localized)
                                .font(AppTypography.caption)
                                .foregroundColor(streamViewModel.hasActiveDevice ? .green : AppColors.textSecondary)
                        }

                        Spacer()

                        // 连接状态指示器
                        Circle()
                            .fill(streamViewModel.hasActiveDevice ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.vertical, AppSpacing.sm)

                    // 设备信息
                    if streamViewModel.hasActiveDevice {
                        InfoRow(title: "settings.device.status".localized, value: "settings.device.online".localized)

                        if streamViewModel.isStreaming {
                            InfoRow(title: "settings.device.stream".localized, value: "settings.device.stream.active".localized)
                        } else {
                            InfoRow(title: "settings.device.stream".localized, value: "settings.device.stream.inactive".localized)
                        }

                        // TODO: 从 SDK 获取更多设备信息
                        // InfoRow(title: "电量", value: "85%")
                        // InfoRow(title: "固件版本", value: "v20.0")
                    }
                } header: {
                    Text("settings.device".localized)
                }

                // AI 设置
                Section {
                    Button {
                        showAppLanguageSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe.asia.australia.fill")
                                .foregroundColor(AppColors.primary)
                            Text("settings.applanguage".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(languageManager.currentLanguage.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showModelSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(AppColors.accent)
                            Text("settings.model".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(selectedModel)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showLanguageSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(AppColors.translate)
                            Text("settings.language".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(languageDisplayName(selectedLanguage))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showAPIKeySettings = true
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(AppColors.wordLearn)
                            Text("settings.apikey".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(hasAPIKey ? "settings.apikey.configured".localized : "settings.apikey.notconfigured".localized)
                                .font(AppTypography.caption)
                                .foregroundColor(hasAPIKey ? .green : .red)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showQualitySettings = true
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                                .foregroundColor(AppColors.liveStream)
                            Text("settings.quality".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(qualityDisplayName(selectedQuality))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text("settings.ai".localized)
                }

                // 关于
                Section {
                    InfoRow(title: "settings.version".localized, value: "1.0.0")
                    InfoRow(title: "settings.sdkversion".localized, value: "0.3.0")
                } header: {
                    Text("settings.about".localized)
                }
            }
            .navigationTitle("settings.title".localized)
            .sheet(isPresented: $showAPIKeySettings) {
                APIKeySettingsView()
            }
            .onChange(of: showAPIKeySettings) { isShowing in
                // 当 API Key 设置界面关闭时，刷新状态
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showModelSettings) {
                ModelSettingsView(selectedModel: $selectedModel)
            }
            .sheet(isPresented: $showLanguageSettings) {
                LanguageSettingsView(selectedLanguage: $selectedLanguage)
            }
            .sheet(isPresented: $showQualitySettings) {
                VideoQualitySettingsView(selectedQuality: $selectedQuality)
            }
            .sheet(isPresented: $showAppLanguageSettings) {
                AppLanguageSettingsView()
            }
            .onAppear {
                // 视图出现时刷新 API Key 状态
                refreshAPIKeyStatus()
            }
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "zh-CN": return "中文"
        case "en-US": return "English"
        case "ja-JP": return "日本語"
        case "ko-KR": return "한국어"
        case "es-ES": return "Español"
        case "fr-FR": return "Français"
        default: return "中文"
        }
    }

    private func qualityDisplayName(_ code: String) -> String {
        switch code {
        case "low": return "低画质"
        case "medium": return "中画质"
        case "high": return "高画质"
        default: return "中画质"
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            Text(value)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - API Key Settings

struct APIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("请输入 API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("阿里云 Dashscope API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请前往阿里云控制台获取您的 API Key")
                        Link("获取 API Key", destination: URL(string: "https://help.aliyun.com/zh/model-studio/get-api-key")!)
                            .font(.caption)
                    }
                }

                Section {
                    Button("保存") {
                        saveAPIKey()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    if APIKeyManager.shared.hasAPIKey() {
                        Button("删除 API Key", role: .destructive) {
                            deleteAPIKey()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("API Key 管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("API Key 已安全保存")
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Load existing key if available
                if let existingKey = APIKeyManager.shared.getAPIKey() {
                    apiKey = existingKey
                }
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "API Key 不能为空"
            showError = true
            return
        }

        if APIKeyManager.shared.saveAPIKey(apiKey) {
            showSaveSuccess = true
        } else {
            errorMessage = "保存失败，请重试"
            showError = true
        }
    }

    private func deleteAPIKey() {
        if APIKeyManager.shared.deleteAPIKey() {
            apiKey = ""
            dismiss()
        } else {
            errorMessage = "删除失败，请重试"
            showError = true
        }
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @Binding var selectedModel: String
    @Environment(\.dismiss) private var dismiss

    let models = [
        "qwen3-omni-flash-realtime",
        "qwen3-omni-standard-realtime"
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(models, id: \.self) { model in
                        Button {
                            selectedModel = model
                        } label: {
                            HStack {
                                Text(model)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedModel == model {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择模型")
                } footer: {
                    Text("当前使用: \(selectedModel)")
                }
            }
            .navigationTitle("模型设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Language Settings

struct LanguageSettingsView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss

    let languages = [
        ("zh-CN", "中文"),
        ("en-US", "English"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
        ("es-ES", "Español"),
        ("fr-FR", "Français")
    ]

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(languages, id: \.0) { lang in
                        Button {
                            selectedLanguage = lang.0
                        } label: {
                            HStack {
                                Text(lang.1)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedLanguage == lang.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("选择输出语言")
                } footer: {
                    Text("AI 将使用该语言进行语音输出和文字回复")
                }
            }
            .navigationTitle("输出语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Video Quality Settings

struct VideoQualitySettingsView: View {
    @Binding var selectedQuality: String
    @Environment(\.dismiss) private var dismiss

    var qualities: [(String, String, String)] {
        [
            ("low", "settings.quality.low".localized, "settings.quality.low.desc".localized),
            ("medium", "settings.quality.medium".localized, "settings.quality.medium.desc".localized),
            ("high", "settings.quality.high".localized, "settings.quality.high.desc".localized)
        ]
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(qualities, id: \.0) { quality in
                        Button {
                            selectedQuality = quality.0
                            UserDefaults.standard.set(quality.0, forKey: "video_quality")
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quality.1)
                                        .foregroundColor(.primary)
                                    Text(quality.2)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if selectedQuality == quality.0 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.quality.select".localized)
                } footer: {
                    Text("settings.quality.description".localized)
                }
            }
            .navigationTitle("settings.quality".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - App Language Settings

struct AppLanguageSettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showRestartAlert = false
    @State private var pendingLanguage: AppLanguage?

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            // 只有选择不同语言时才提示重启
                            if languageManager.currentLanguage != language {
                                pendingLanguage = language
                                showRestartAlert = true
                            }
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.applanguage.select".localized)
                } footer: {
                    Text("settings.applanguage.description".localized)
                }
            }
            .navigationTitle("settings.applanguage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("settings.applanguage.restart.title".localized, isPresented: $showRestartAlert) {
                Button("cancel".localized, role: .cancel) {
                    pendingLanguage = nil
                }
                Button("settings.applanguage.restart.confirm".localized) {
                    if let language = pendingLanguage {
                        languageManager.currentLanguage = language
                        // 延迟一点退出，确保设置已保存
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            exit(0)
                        }
                    }
                }
            } message: {
                Text("settings.applanguage.restart.message".localized)
            }
        }
    }
}
