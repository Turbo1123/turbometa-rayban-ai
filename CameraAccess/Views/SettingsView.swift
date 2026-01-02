/*
 * Settings View
 * 个人中心 - 设备管理和设置
 */

import SwiftUI
import MWDATCore

struct SettingsView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var languageManager = LanguageManager.shared
    @ObservedObject var providerManager = APIProviderManager.shared
    let apiKey: String

    @State private var showAPIKeySettings = false
    @State private var showProviderSettings = false
    @State private var showModelSettings = false
    @State private var showLanguageSettings = false
    @State private var showAppLanguageSettings = false
    @State private var showQualitySettings = false
    @State private var showLiveAIProviderSettings = false
    @State private var showGoogleAPIKeySettings = false
    @State private var showQuickVisionSettings = false
    @State private var showLiveAISettings = false
    @State private var showLiveTranslateSettings = false
    @ObservedObject var quickVisionModeManager = QuickVisionModeManager.shared
    @ObservedObject var liveAIModeManager = LiveAIModeManager.shared
    @State private var selectedModel = "qwen3-omni-flash-realtime"
    @State private var selectedLanguage = "zh-CN" // 默认中文
    @State private var selectedQuality = UserDefaults.standard.string(forKey: "video_quality") ?? "medium"
    @State private var hasAPIKey = false // 改为 State 变量
    @State private var hasGoogleAPIKey = false // Google API Key 状态

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self.apiKey = apiKey
    }

    // 刷新 API Key 状态
    private func refreshAPIKeyStatus() {
        hasAPIKey = providerManager.hasAPIKey
        hasGoogleAPIKey = APIKeyManager.shared.hasGoogleAPIKey()
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

                    // API Provider
                    Button {
                        showProviderSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundColor(AppColors.accent)
                            Text("settings.provider".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(providerManager.currentProvider.displayName)
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
                            Text(providerManager.selectedModel)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
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

                    // Quick Vision Settings
                    Button {
                        showQuickVisionSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "eye.circle.fill")
                                .foregroundColor(AppColors.quickVision)
                            Text("quickvision.settings".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(quickVisionModeManager.currentMode.displayName)
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

                // Live AI 设置
                Section {
                    // Live AI Provider
                    Button {
                        showLiveAIProviderSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "waveform.circle.fill")
                                .foregroundColor(AppColors.primary)
                            Text("settings.liveai.provider".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(providerManager.liveAIProvider.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Google API Key (only show when Google is selected for Live AI)
                    if providerManager.liveAIProvider == .google {
                        Button {
                            showGoogleAPIKeySettings = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.orange)
                                Text("Google API Key")
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text(hasGoogleAPIKey ? "settings.apikey.configured".localized : "settings.apikey.notconfigured".localized)
                                    .font(AppTypography.caption)
                                    .foregroundColor(hasGoogleAPIKey ? .green : .red)
                                Image(systemName: "chevron.right")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }

                    // Live AI Mode Settings
                    Button {
                        showLiveAISettings = true
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(AppColors.liveAI)
                            Text("liveai.settings".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(liveAIModeManager.currentMode.displayName)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    // Live Translate Settings
                    Button {
                        showLiveTranslateSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(AppColors.translate)
                            Text("livetranslate.settings.title".localized)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text("settings.liveai".localized)
                }

                // 关于
                Section {
                    InfoRow(title: "settings.version".localized, value: "1.5.0")
                    InfoRow(title: "settings.sdkversion".localized, value: "0.3.0")
                } header: {
                    Text("settings.about".localized)
                }
            }
            .navigationTitle("settings.title".localized)
            .sheet(isPresented: $showAPIKeySettings) {
                if providerManager.currentProvider == .alibaba {
                    APIKeySettingsView(provider: providerManager.currentProvider, endpoint: providerManager.alibabaEndpoint)
                } else {
                    APIKeySettingsView(provider: providerManager.currentProvider)
                }
            }
            .onChange(of: showAPIKeySettings) { isShowing in
                // 当 API Key 设置界面关闭时，刷新状态
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showProviderSettings) {
                APIProviderSettingsView()
            }
            .onChange(of: showProviderSettings) { isShowing in
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showModelSettings) {
                VisionModelSettingsView()
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
            .sheet(isPresented: $showLiveAIProviderSettings) {
                LiveAIProviderSettingsView()
            }
            .sheet(isPresented: $showGoogleAPIKeySettings) {
                GoogleAPIKeySettingsView()
            }
            .onChange(of: showGoogleAPIKeySettings) { isShowing in
                // 当 Google API Key 设置界面关闭时，刷新状态
                if !isShowing {
                    refreshAPIKeyStatus()
                }
            }
            .sheet(isPresented: $showQuickVisionSettings) {
                QuickVisionSettingsView()
            }
            .sheet(isPresented: $showLiveAISettings) {
                LiveAISettingsView()
            }
            .sheet(isPresented: $showLiveTranslateSettings) {
                LiveTranslateSettingsView(viewModel: LiveTranslateViewModel())
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

// MARK: - API Provider Settings

struct APIProviderSettingsView: View {
    @ObservedObject var providerManager = APIProviderManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(APIProvider.allCases, id: \.self) { provider in
                        Button {
                            providerManager.currentProvider = provider
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.displayName)
                                        .foregroundColor(.primary)
                                    Text(provider == .alibaba ? "settings.provider.alibaba.desc".localized : "settings.provider.openrouter.desc".localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if providerManager.currentProvider == provider {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.provider.select".localized)
                } footer: {
                    Text("settings.provider.description".localized)
                }

                // Alibaba endpoint selection (only show when Alibaba is selected)
                if providerManager.currentProvider == .alibaba {
                    Section {
                        ForEach(AlibabaEndpoint.allCases, id: \.self) { endpoint in
                            Button {
                                providerManager.alibabaEndpoint = endpoint
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(endpoint.displayName)
                                            .foregroundColor(.primary)
                                        Text(endpoint == .beijing ? "settings.endpoint.beijing.desc".localized : "settings.endpoint.singapore.desc".localized)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    Spacer()
                                    if providerManager.alibabaEndpoint == endpoint {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("settings.endpoint".localized)
                    } footer: {
                        Text("settings.endpoint.description".localized)
                    }
                }

                // API Key status for current provider
                Section {
                    HStack {
                        Text("settings.apikey.status".localized)
                        Spacer()
                        if providerManager.hasAPIKey {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("settings.apikey.configured".localized)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("settings.apikey.notconfigured".localized)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Link(destination: URL(string: providerManager.currentProvider.apiKeyHelpURL)!) {
                        HStack {
                            Text("settings.provider.getapikey".localized)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                } header: {
                    if providerManager.currentProvider == .alibaba {
                        Text("\(providerManager.currentProvider.displayName) (\(providerManager.alibabaEndpoint.displayName)) API Key")
                    } else {
                        Text("\(providerManager.currentProvider.displayName) API Key")
                    }
                }
            }
            .navigationTitle("settings.provider".localized)
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

// MARK: - API Key Settings

struct APIKeySettingsView: View {
    let provider: APIProvider
    var endpoint: AlibabaEndpoint? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var displayTitle: String {
        if provider == .alibaba, let endpoint = endpoint {
            return "\(provider.displayName) (\(endpoint.displayName))"
        }
        return provider.displayName
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("settings.apikey.placeholder".localized, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("\(displayTitle) API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(provider == .alibaba ? "settings.apikey.alibaba.help".localized : "settings.apikey.openrouter.help".localized)
                        Link("settings.apikey.get".localized, destination: URL(string: provider.apiKeyHelpURL)!)
                            .font(.caption)
                    }
                }

                Section {
                    Button("save".localized) {
                        saveAPIKey()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    if APIKeyManager.shared.hasAPIKey(for: provider, endpoint: endpoint) {
                        Button("settings.apikey.delete".localized, role: .destructive) {
                            deleteAPIKey()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("settings.apikey.manage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("settings.apikey.saved".localized, isPresented: $showSaveSuccess) {
                Button("ok".localized) {
                    dismiss()
                }
            } message: {
                Text("settings.apikey.saved.message".localized)
            }
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Load existing key if available
                if let existingKey = APIKeyManager.shared.getAPIKey(for: provider, endpoint: endpoint) {
                    apiKey = existingKey
                }
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "settings.apikey.empty".localized
            showError = true
            return
        }

        if APIKeyManager.shared.saveAPIKey(apiKey, for: provider, endpoint: endpoint) {
            showSaveSuccess = true
        } else {
            errorMessage = "settings.apikey.savefailed".localized
            showError = true
        }
    }

    private func deleteAPIKey() {
        if APIKeyManager.shared.deleteAPIKey(for: provider, endpoint: endpoint) {
            apiKey = ""
            dismiss()
        } else {
            errorMessage = "settings.apikey.deletefailed".localized
            showError = true
        }
    }
}

// MARK: - Vision Model Settings

struct VisionModelSettingsView: View {
    @ObservedObject var providerManager = APIProviderManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showVisionOnly = true

    var body: some View {
        NavigationView {
            Group {
                if providerManager.currentProvider == .alibaba {
                    alibabaModelList
                } else {
                    openRouterModelList
                }
            }
            .navigationTitle("settings.model".localized)
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

    private var alibabaModelList: some View {
        let models = [
            ("qwen3-vl-plus", "Qwen3 VL Plus", "settings.model.qwen3vlplus.desc".localized),
            ("qwen3-vl-max", "Qwen3 VL Max", "settings.model.qwen3vlmax.desc".localized)
        ]

        return List {
            Section {
                ForEach(models, id: \.0) { model in
                    Button {
                        providerManager.selectedModel = model.0
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.1)
                                    .foregroundColor(.primary)
                                Text(model.2)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            if providerManager.selectedModel == model.0 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } header: {
                Text("settings.model.alibaba".localized)
            } footer: {
                Text("settings.model.current".localized + ": \(providerManager.selectedModel)")
            }
        }
    }

    private var openRouterModelList: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("settings.model.search".localized, text: $searchText)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)

            // Vision only toggle
            Toggle("settings.model.visiononly".localized, isOn: $showVisionOnly)
                .padding(.horizontal)
                .padding(.vertical, 4)

            if providerManager.isLoadingModels {
                Spacer()
                ProgressView("settings.model.loading".localized)
                Spacer()
            } else if let error = providerManager.modelsError {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("settings.model.retry".localized) {
                        Task {
                            await providerManager.fetchOpenRouterModels()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else {
                List {
                    let filteredModels = getFilteredModels()

                    if filteredModels.isEmpty {
                        Text("settings.model.notfound".localized)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredModels) { model in
                            Button {
                                providerManager.selectedModel = model.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(model.displayName)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            if model.isVisionCapable {
                                                Image(systemName: "eye.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                        Text(model.id)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                        if !model.priceDisplay.isEmpty {
                                            Text(model.priceDisplay)
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    Spacer()
                                    if providerManager.selectedModel == model.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .task {
            if providerManager.openRouterModels.isEmpty {
                await providerManager.fetchOpenRouterModels()
            }
        }
    }

    private func getFilteredModels() -> [OpenRouterModel] {
        var models = providerManager.openRouterModels

        if showVisionOnly {
            models = models.filter { $0.isVisionCapable }
        }

        if !searchText.isEmpty {
            models = providerManager.searchModels(searchText)
            if showVisionOnly {
                models = models.filter { $0.isVisionCapable }
            }
        }

        return models
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

// MARK: - Live AI Provider Settings

struct LiveAIProviderSettingsView: View {
    @ObservedObject var providerManager = APIProviderManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(LiveAIProvider.allCases, id: \.self) { provider in
                        Button {
                            providerManager.liveAIProvider = provider
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.displayName)
                                        .foregroundColor(.primary)
                                    Text(liveAIProviderDescription(provider))
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                if providerManager.liveAIProvider == provider {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("settings.liveai.provider.select".localized)
                } footer: {
                    Text("settings.liveai.provider.description".localized)
                }

                // API Key status
                Section {
                    HStack {
                        Text("settings.apikey.status".localized)
                        Spacer()
                        if providerManager.hasLiveAIAPIKey {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("settings.apikey.configured".localized)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("settings.apikey.notconfigured".localized)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Link(destination: URL(string: providerManager.liveAIProvider.apiKeyHelpURL)!) {
                        HStack {
                            Text("settings.provider.getapikey".localized)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                } header: {
                    Text("\(providerManager.liveAIProvider.displayName) API Key")
                }
            }
            .navigationTitle("settings.liveai.provider".localized)
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

    private func liveAIProviderDescription(_ provider: LiveAIProvider) -> String {
        switch provider {
        case .alibaba:
            return "settings.liveai.alibaba.desc".localized
        case .google:
            return "settings.liveai.google.desc".localized
        }
    }
}

// MARK: - Google API Key Settings

struct GoogleAPIKeySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showSaveSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("settings.apikey.placeholder".localized, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Google Gemini API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.apikey.google.help".localized)
                        Link("settings.apikey.get".localized, destination: URL(string: "https://aistudio.google.com/apikey")!)
                            .font(.caption)
                    }
                }

                Section {
                    Button("save".localized) {
                        saveAPIKey()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    if APIKeyManager.shared.hasGoogleAPIKey() {
                        Button("settings.apikey.delete".localized, role: .destructive) {
                            deleteAPIKey()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("settings.apikey.manage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .alert("settings.apikey.saved".localized, isPresented: $showSaveSuccess) {
                Button("ok".localized) {
                    dismiss()
                }
            } message: {
                Text("settings.apikey.saved.message".localized)
            }
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let existingKey = APIKeyManager.shared.getGoogleAPIKey() {
                    apiKey = existingKey
                }
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "settings.apikey.empty".localized
            showError = true
            return
        }

        if APIKeyManager.shared.saveGoogleAPIKey(apiKey) {
            showSaveSuccess = true
        } else {
            errorMessage = "settings.apikey.savefailed".localized
            showError = true
        }
    }

    private func deleteAPIKey() {
        if APIKeyManager.shared.deleteGoogleAPIKey() {
            apiKey = ""
            dismiss()
        } else {
            errorMessage = "settings.apikey.deletefailed".localized
            showError = true
        }
    }
}
