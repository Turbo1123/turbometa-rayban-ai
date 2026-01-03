/*
 * Settings View
 * 个人中心 - 设备管理和设置
 */

import SwiftUI
import MWDATCore

// MARK: - Custom Model Manager
/// 管理各服务提供商的自定义模型列表，支持增删改
class CustomModelManager: ObservableObject {
    static let shared = CustomModelManager()
    
    private let storageKey = "customModelsByProvider"
    
    /// 按提供商存储的自定义模型 [providerRawValue: [modelNames]]
    @Published var modelsByProvider: [String: [String]] = [:]
    
    private init() {
        loadModels()
    }
    
    private func loadModels() {
        if let data = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [String]] {
            modelsByProvider = data
        }
    }
    
    private func saveModels() {
        UserDefaults.standard.set(modelsByProvider, forKey: storageKey)
    }
    
    func models(for provider: VisionAPIConfig.ModelProvider) -> [String] {
        return modelsByProvider[provider.rawValue] ?? []
    }
    
    func addModel(_ model: String, for provider: VisionAPIConfig.ModelProvider) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var providerModels = modelsByProvider[provider.rawValue] ?? []
        if !providerModels.contains(trimmed) {
            providerModels.insert(trimmed, at: 0)
            modelsByProvider[provider.rawValue] = providerModels
            saveModels()
        }
    }
    
    func removeModel(_ model: String, for provider: VisionAPIConfig.ModelProvider) {
        var providerModels = modelsByProvider[provider.rawValue] ?? []
        providerModels.removeAll { $0 == model }
        modelsByProvider[provider.rawValue] = providerModels
        saveModels()
    }
}

struct SettingsView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    let apiKey: String

    @State private var showAPIKeySettings = false
    @State private var showModelSettings = false
    @State private var showEndpointSettings = false
    @State private var showRealtimeModelSettings = false
    @State private var showRealtimeEndpointSettings = false
    @State private var showImageGenModelSettings = false
    @State private var showImageGenEndpointSettings = false
    @State private var showLanguageSettings = false
    @AppStorage(VisionAPIConfig.modelKey) private var selectedModel = VisionAPIConfig.defaultModel
    @AppStorage(VisionAPIConfig.realtimeModelKey) private var selectedRealtimeModel = VisionAPIConfig.defaultRealtimeModel
    @AppStorage(VisionAPIConfig.imageGenModelKey) private var selectedImageGenModel = VisionAPIConfig.defaultImageGenModel
    @AppStorage(VisionAPIConfig.providerKey) private var preferredProviderRaw = VisionAPIConfig.ModelProvider.qwen.rawValue
    @AppStorage(VisionAPIConfig.realtimeInputLanguageKey) private var selectedLanguage = VisionAPIConfig.defaultRealtimeInputLanguage
    @State private var hasAPIKey = false // 改为 State 变量
    @State private var showModelEndpointAlert = false
    @State private var modelEndpointAlertMessage = ""

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self.apiKey = apiKey
    }

    // 刷新 API Key 状态
    private func refreshAPIKeyStatus() {
        hasAPIKey = APIKeyManager.shared.hasAPIKey(provider: activeProvider)
    }

    private var preferredProvider: VisionAPIConfig.ModelProvider {
        get {
            VisionAPIConfig.ModelProvider(rawValue: preferredProviderRaw) ?? .qwen
        }
        set {
            preferredProviderRaw = newValue.rawValue
        }
    }

    private var activeProvider: VisionAPIConfig.ModelProvider {
        VisionAPIConfig.provider(for: selectedModel) ?? preferredProvider
    }

    private var apiBaseURL: String {
        VisionAPIConfig.baseURL(for: activeProvider)
    }

    private var realtimeBaseURL: String {
        VisionAPIConfig.realtimeBaseURL(for: VisionAPIConfig.activeRealtimeProvider)
    }

    private var imageGenBaseURL: String {
        VisionAPIConfig.baseURL(for: VisionAPIConfig.activeImageGenProvider)
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
                            Text(streamViewModel.hasActiveDevice ? "已连接" : "未连接")
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
                        InfoRow(title: "设备状态", value: "在线")

                        if streamViewModel.isStreaming {
                            InfoRow(title: "视频流", value: "活跃")
                        } else {
                            InfoRow(title: "视频流", value: "未启动")
                        }

                        // TODO: 从 SDK 获取更多设备信息
                        // InfoRow(title: "电量", value: "85%")
                        // InfoRow(title: "固件版本", value: "v20.0")
                    }
                } header: {
                    Text("设备管理")
                }

                // AI 设置
                Section {
                    Button {
                        showModelSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(AppColors.accent)
                            Text("视觉/营养模型")
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
                        showRealtimeModelSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "waveform")
                                .foregroundColor(AppColors.liveAI)
                            Text("实时对话模型")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(selectedRealtimeModel)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showEndpointSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(AppColors.liveAI)
                            Text("视觉/营养服务地址")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(apiBaseURL)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showRealtimeEndpointSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                                .foregroundColor(AppColors.liveAI)
                            Text("实时对话服务地址")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(realtimeBaseURL)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }

                    Button {
                        showImageGenEndpointSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(AppColors.liveAI)
                            Text("图片生成服务地址")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(imageGenBaseURL)
                                .lineLimit(1)
                                .truncationMode(.middle)
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
                            Text("语音识别语言")
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
                            Text("API Key 管理")
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(hasAPIKey ? "已配置" : "未配置")
                                .font(AppTypography.caption)
                                .foregroundColor(hasAPIKey ? .green : .red)
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text("AI 设置")
                }

                // 网络设置
                Section {
                    Toggle(isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "bypassSystemProxy") },
                        set: { UserDefaults.standard.set($0, forKey: "bypassSystemProxy") }
                    )) {
                        HStack {
                            Image(systemName: "network.slash")
                                .foregroundColor(AppColors.liveAI)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("绕过系统代理")
                                    .foregroundColor(AppColors.textPrimary)
                                Text("WebSocket 连接直连，避免代理导致的连接问题")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("网络设置")
                }

                // 关于
                Section {
                    InfoRow(title: "版本", value: "1.0.0")
                    InfoRow(title: "SDK 版本", value: "0.3.0")
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showAPIKeySettings) {
                APIKeySettingsView(selectedProviderRaw: $preferredProviderRaw)
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
            .sheet(isPresented: $showRealtimeModelSettings) {
                OmniRealtimeModelSettingsView(selectedModel: $selectedRealtimeModel)
            }
            .sheet(isPresented: $showEndpointSettings) {
                APIEndpointSettingsView(selectedProviderRaw: $preferredProviderRaw)
            }
            .sheet(isPresented: $showRealtimeEndpointSettings) {
                RealtimeEndpointSettingsView(selectedProviderRaw: $preferredProviderRaw)
            }
            .sheet(isPresented: $showImageGenModelSettings) {
                ImageGenModelSettingsView(selectedModel: $selectedImageGenModel)
            }
            .sheet(isPresented: $showImageGenEndpointSettings) {
                APIEndpointSettingsView(selectedProviderRaw: $preferredProviderRaw)
            }
            .onChange(of: showEndpointSettings) { isShowing in
                if !isShowing {
                    refreshAPIKeyStatus()
                    validateModelEndpointPair()
                }
            }
            .onChange(of: showRealtimeEndpointSettings) { isShowing in
                if !isShowing {
                    refreshAPIKeyStatus()
                    validateRealtimeConfigPair()
                }
            }
            .sheet(isPresented: $showLanguageSettings) {
                LanguageSettingsView(selectedLanguage: $selectedLanguage)
            }
            .onChange(of: selectedModel) { _ in
                if let provider = VisionAPIConfig.provider(for: selectedModel) {
                    preferredProviderRaw = provider.rawValue
                }
                refreshAPIKeyStatus()
                validateModelEndpointPair()
            }
            .onChange(of: selectedRealtimeModel) { _ in
                if let provider = VisionAPIConfig.provider(for: selectedRealtimeModel) {
                    preferredProviderRaw = provider.rawValue
                }
                refreshAPIKeyStatus()
                validateRealtimeConfigPair()
            }
            .onChange(of: preferredProviderRaw) { _ in
                refreshAPIKeyStatus()
                validateModelEndpointPair()
                validateRealtimeConfigPair()
            }
            .onAppear {
                // 视图出现时刷新 API Key 状态
                refreshAPIKeyStatus()
                validateModelEndpointPair()
                validateRealtimeConfigPair()
            }
            .alert("模型与服务地址不匹配", isPresented: $showModelEndpointAlert) {
                Button("知道了") {}
            } message: {
                Text(modelEndpointAlertMessage)
            }
        }
    }

    // MARK: - Model / Endpoint Validation

    private func validateModelEndpointPair() {
        if apiBaseURL.isEmpty {
            modelEndpointAlertMessage = "当前服务地址为空，请先配置 API 服务地址。"
            showModelEndpointAlert = true
            return
        }

        if VisionAPIConfig.apiKey(for: activeProvider).isEmpty {
            modelEndpointAlertMessage = "当前服务未配置 API Key，请先在「API Key 管理」中设置。"
            showModelEndpointAlert = true
            return
        }

        let modelProvider = VisionAPIConfig.provider(for: selectedModel)
        let endpointProvider = VisionAPIConfig.provider(forBaseURL: apiBaseURL)

        if let modelProvider, let endpointProvider {
            if modelProvider != endpointProvider {
                modelEndpointAlertMessage = "当前模型与服务地址不匹配：模型为「\(modelProvider.displayName)」，服务地址为「\(endpointProvider.displayName)」。请调整其中一个。"
                showModelEndpointAlert = true
            }
            return
        }

        if modelProvider != nil && endpointProvider == nil {
            modelEndpointAlertMessage = "已识别模型提供方为「\(modelProvider!.displayName)」，但服务地址无法识别，请确认是否为对应厂商的 OpenAI 兼容地址。"
            showModelEndpointAlert = true
        } else if modelProvider == nil && endpointProvider != nil {
            modelEndpointAlertMessage = "已识别服务地址为「\(endpointProvider!.displayName)」，但模型名称无法识别，请确认模型是否属于该厂商。"
            showModelEndpointAlert = true
        } else if modelProvider == nil && endpointProvider == nil {
            modelEndpointAlertMessage = "模型与服务地址均无法识别，请确认是否为支持的服务，或使用自定义 OpenAI 兼容配置。"
            showModelEndpointAlert = true
        }
    }

    private func validateRealtimeConfigPair() {
        if realtimeBaseURL.isEmpty {
            modelEndpointAlertMessage = "当前实时对话服务地址为空，请先配置。"
            showModelEndpointAlert = true
            return
        }

        if VisionAPIConfig.apiKey(for: VisionAPIConfig.activeRealtimeProvider).isEmpty {
            modelEndpointAlertMessage = "当前服务未配置 API Key，请先在「API Key 管理」中设置。"
            showModelEndpointAlert = true
            return
        }

        let modelProvider = VisionAPIConfig.provider(for: selectedRealtimeModel)
        let endpointProvider = VisionAPIConfig.provider(forBaseURL: realtimeBaseURL)

        if let modelProvider, let endpointProvider {
            if modelProvider != endpointProvider {
                modelEndpointAlertMessage = "当前实时对话模型与服务地址不匹配：模型为「\(modelProvider.displayName)」，服务地址为「\(endpointProvider.displayName)」。请调整其中一个。"
                showModelEndpointAlert = true
            }
            return
        }

        if modelProvider != nil && endpointProvider == nil {
            modelEndpointAlertMessage = "已识别实时对话模型提供方为「\(modelProvider!.displayName)」，但服务地址无法识别。"
            showModelEndpointAlert = true
        } else if modelProvider == nil && endpointProvider != nil {
            modelEndpointAlertMessage = "已识别实时对话服务地址为「\(endpointProvider!.displayName)」，但模型名称无法识别。"
            showModelEndpointAlert = true
        } else if modelProvider == nil && endpointProvider == nil {
            modelEndpointAlertMessage = "实时对话模型与服务地址均无法识别，请确认是否为支持的服务。"
            showModelEndpointAlert = true
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
    @Binding var selectedProviderRaw: String
    @State private var selectedProvider: VisionAPIConfig.ModelProvider = .qwen

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("模型服务", selection: $selectedProvider) {
                        ForEach(VisionAPIConfig.ModelProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }

                    SecureField("请输入 API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("\(selectedProvider.displayName) API Key")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("请前往对应厂商控制台获取 API Key")
                    }
                }

                Section {
                    Button("保存") {
                        saveAPIKey()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(apiKey.isEmpty)

                    if APIKeyManager.shared.hasAPIKey(provider: selectedProvider) {
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
                // 加载当前服务的 API Key
                selectedProvider = VisionAPIConfig.ModelProvider(rawValue: selectedProviderRaw) ?? .qwen
                if let existingKey = APIKeyManager.shared.getAPIKey(provider: selectedProvider) {
                    apiKey = existingKey
                }
            }
            .onChange(of: selectedProvider) { provider in
                selectedProviderRaw = provider.rawValue
                apiKey = APIKeyManager.shared.getAPIKey(provider: provider) ?? ""
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else {
            errorMessage = "API Key 不能为空"
            showError = true
            return
        }

        if APIKeyManager.shared.saveAPIKey(apiKey, provider: selectedProvider) {
            showSaveSuccess = true
        } else {
            errorMessage = "保存失败，请重试"
            showError = true
        }
    }

    private func deleteAPIKey() {
        if APIKeyManager.shared.deleteAPIKey(provider: selectedProvider) {
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
    @StateObject private var modelManager = CustomModelManager.shared

    @State private var newModelName = ""
    @State private var addingForProvider: VisionAPIConfig.ModelProvider?

    let presetModels: [(provider: VisionAPIConfig.ModelProvider, models: [String])] = [
        (.qwen, ["qwen3-vl-plus", "qwen2.5-vl", "qwen-vl-plus"]),
        (.doubao, ["doubao-1-5-vision-pro", "doubao-1-5-vision-lite"]),
        (.stepfun, ["step-1.5v-turbo", "step-1.5v-mini"]),
        (.openai, []),
        (.gemini, ["gemini-2.0-flash-exp"]),
        (.geminiCompatible, [])
    ]

    var body: some View {
        NavigationView {
            List {
                // 当前模型
                Section {
                    HStack {
                        Text("当前选择")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedModel)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
                
                // 每个提供商一个 Section
                ForEach(presetModels, id: \.provider.rawValue) { item in
                    providerSection(provider: item.provider, presets: item.models)
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
            .alert("添加自定义模型", isPresented: Binding(
                get: { addingForProvider != nil },
                set: { if !$0 { addingForProvider = nil } }
            )) {
                TextField("模型名称", text: $newModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Button("取消", role: .cancel) {
                    newModelName = ""
                    addingForProvider = nil
                }
                Button("添加") {
                    if !newModelName.isEmpty, let provider = addingForProvider {
                        modelManager.addModel(newModelName, for: provider)
                        selectedModel = newModelName
                        newModelName = ""
                        addingForProvider = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func providerSection(provider: VisionAPIConfig.ModelProvider, presets: [String]) -> some View {
        Section {
            // 预设模型
            ForEach(presets, id: \.self) { model in
                modelRow(model)
            }
            
            // 自定义模型（可删除）
            ForEach(modelManager.models(for: provider), id: \.self) { model in
                modelRow(model)
            }
            .onDelete { indexSet in
                let customModels = modelManager.models(for: provider)
                for index in indexSet {
                    modelManager.removeModel(customModels[index], for: provider)
                }
            }
            
            // 添加按钮
            Button {
                addingForProvider = provider
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("添加模型")
                        .foregroundColor(.blue)
                }
            }
        } header: {
            Text(provider.displayName)
        } footer: {
            if !modelManager.models(for: provider).isEmpty {
                Text("左滑可删除自定义模型")
            }
        }
    }
    
    @ViewBuilder
    private func modelRow(_ model: String) -> some View {
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
}

struct OmniRealtimeModelSettingsView: View {
    @Binding var selectedModel: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelManager = CustomModelManager.shared

    @State private var newModelName = ""
    @State private var addingForProvider: VisionAPIConfig.ModelProvider?

    let presetModels: [(provider: VisionAPIConfig.ModelProvider, models: [String])] = [
        (.qwen, ["qwen3-omni-flash-realtime", "qwen3-omni-standard-realtime"]),
        (.doubao, ["doubao-1-5-voice-pro", "doubao-1-5-voice-lite"]),
        (.stepfun, ["step-1.5v-turbo", "step-1.5v-mini"]),
        (.openai, [])
    ]

    var body: some View {
        NavigationView {
            List {
                // 当前模型
                Section {
                    HStack {
                        Text("当前选择")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedModel)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
                
                // 每个提供商一个 Section
                ForEach(presetModels, id: \.provider.rawValue) { item in
                    providerSection(provider: item.provider, presets: item.models)
                }
            }
            .navigationTitle("实时对话模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("添加自定义模型", isPresented: Binding(
                get: { addingForProvider != nil },
                set: { if !$0 { addingForProvider = nil } }
            )) {
                TextField("模型名称", text: $newModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Button("取消", role: .cancel) {
                    newModelName = ""
                    addingForProvider = nil
                }
                Button("添加") {
                    if !newModelName.isEmpty, let provider = addingForProvider {
                        modelManager.addModel(newModelName, for: provider)
                        selectedModel = newModelName
                        newModelName = ""
                        addingForProvider = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func providerSection(provider: VisionAPIConfig.ModelProvider, presets: [String]) -> some View {
        Section {
            ForEach(presets, id: \.self) { model in
                modelRow(model)
            }
            
            ForEach(modelManager.models(for: provider), id: \.self) { model in
                modelRow(model)
            }
            .onDelete { indexSet in
                let customModels = modelManager.models(for: provider)
                for index in indexSet {
                    modelManager.removeModel(customModels[index], for: provider)
                }
            }
            
            Button {
                addingForProvider = provider
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("添加模型")
                        .foregroundColor(.blue)
                }
            }
        } header: {
            Text(provider.displayName)
        } footer: {
            if !modelManager.models(for: provider).isEmpty {
                Text("左滑可删除自定义模型")
            }
        }
    }
    
    @ViewBuilder
    private func modelRow(_ model: String) -> some View {
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
}

struct APIEndpointSettingsView: View {
    @Binding var selectedProviderRaw: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: VisionAPIConfig.ModelProvider = .qwen
    @State private var customBaseURL = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("模型服务", selection: $selectedProvider) {
                        ForEach(VisionAPIConfig.ModelProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                } header: {
                    Text("选择服务")
                }

                Section {
                    ForEach(providerEndpoints, id: \.name) { endpoint in
                        Button {
                            if !endpoint.url.isEmpty {
                                VisionAPIConfig.setBaseURL(endpoint.url, for: selectedProvider)
                                customBaseURL = ""
                                selectedProviderRaw = selectedProvider.rawValue
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(endpoint.name)
                                        .foregroundColor(.primary)
                                    if !endpoint.url.isEmpty {
                                        Text(endpoint.url)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                Spacer()
                                if !endpoint.url.isEmpty && VisionAPIConfig.baseURL(for: selectedProvider) == endpoint.url {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(endpoint.url.isEmpty)
                    }
                } header: {
                    Text("服务地址预设")
                }

                Section {
                    TextField("自定义 API Base URL", text: $customBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    Button("使用自定义地址") {
                        if !customBaseURL.isEmpty {
                            VisionAPIConfig.setBaseURL(customBaseURL, for: selectedProvider)
                            selectedProviderRaw = selectedProvider.rawValue
                        }
                    }
                    .disabled(customBaseURL.isEmpty)
                } header: {
                    Text("自定义")
                } footer: {
                    Text("当前使用: \(VisionAPIConfig.baseURL(for: selectedProvider))")
                }
            }
            .navigationTitle("API 服务地址")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedProvider = VisionAPIConfig.ModelProvider(rawValue: selectedProviderRaw) ?? .qwen
            customBaseURL = VisionAPIConfig.baseURL(for: selectedProvider)
        }
        .onChange(of: selectedProvider) { provider in
            selectedProviderRaw = provider.rawValue
            customBaseURL = VisionAPIConfig.baseURL(for: provider)
        }
    }

    private var providerEndpoints: [(name: String, url: String)] {
        switch selectedProvider {
        case .qwen:
            return [("通义千问（默认）", VisionAPIConfig.ModelProvider.qwen.defaultBaseURL)]
        case .doubao:
            return [("豆包（火山引擎 Ark）", VisionAPIConfig.ModelProvider.doubao.defaultBaseURL)]
        case .stepfun:
            return [("阶越星辰", VisionAPIConfig.ModelProvider.stepfun.defaultBaseURL)]
        case .openai:
            return [("OpenAI 兼容（自定义）", "")]
        case .gemini:
            return [("Gemini (Google/Vertex)", VisionAPIConfig.ModelProvider.gemini.defaultBaseURL)]
        case .geminiCompatible:
            return [("Gemini 兼容（自定义）", "")]
        }
    }
}

struct RealtimeEndpointSettingsView: View {
    @Binding var selectedProviderRaw: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProvider: VisionAPIConfig.ModelProvider = .qwen
    @State private var customBaseURL = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("模型服务", selection: $selectedProvider) {
                        ForEach(VisionAPIConfig.ModelProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                } header: {
                    Text("选择服务")
                }

                Section {
                    ForEach(providerEndpoints, id: \.name) { endpoint in
                        Button {
                            if !endpoint.url.isEmpty {
                                VisionAPIConfig.setRealtimeBaseURL(endpoint.url, for: selectedProvider)
                                customBaseURL = ""
                                selectedProviderRaw = selectedProvider.rawValue
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(endpoint.name)
                                        .foregroundColor(.primary)
                                    if !endpoint.url.isEmpty {
                                        Text(endpoint.url)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                Spacer()
                                if !endpoint.url.isEmpty && VisionAPIConfig.realtimeBaseURL(for: selectedProvider) == endpoint.url {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(endpoint.url.isEmpty)
                    }
                } header: {
                    Text("服务地址预设")
                }

                Section {
                    TextField("自定义实时对话 Base URL", text: $customBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    Button("使用自定义地址") {
                        if !customBaseURL.isEmpty {
                            VisionAPIConfig.setRealtimeBaseURL(customBaseURL, for: selectedProvider)
                            selectedProviderRaw = selectedProvider.rawValue
                        }
                    }
                    .disabled(customBaseURL.isEmpty)
                } header: {
                    Text("自定义")
                } footer: {
                    Text("当前使用: \(VisionAPIConfig.realtimeBaseURL(for: selectedProvider))")
                }
            }
            .navigationTitle("实时对话服务地址")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            selectedProvider = VisionAPIConfig.ModelProvider(rawValue: selectedProviderRaw) ?? .qwen
            customBaseURL = VisionAPIConfig.realtimeBaseURL(for: selectedProvider)
        }
        .onChange(of: selectedProvider) { provider in
            selectedProviderRaw = provider.rawValue
            customBaseURL = VisionAPIConfig.realtimeBaseURL(for: provider)
        }
    }

    private var providerEndpoints: [(name: String, url: String)] {
        switch selectedProvider {
        case .qwen:
            return [("通义千问（默认）", VisionAPIConfig.ModelProvider.qwen.defaultRealtimeBaseURL)]
        case .doubao:
            return [("豆包（火山引擎 Ark）", VisionAPIConfig.ModelProvider.doubao.defaultRealtimeBaseURL)]
        case .stepfun:
            return [("阶越星辰", VisionAPIConfig.ModelProvider.stepfun.defaultRealtimeBaseURL)]
        case .openai:
            return [("OpenAI 兼容（自定义）", "")]
        case .gemini:
            return [("Gemini (暂不支持实时)", "")]
        case .geminiCompatible:
            return [("Gemini 兼容 (暂不支持实时)", "")]
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

// MARK: - Image Gen Model Settings

struct ImageGenModelSettingsView: View {
    @Binding var selectedModel: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelManager = CustomModelManager.shared

    @State private var newModelName = ""
    @State private var addingForProvider: VisionAPIConfig.ModelProvider?

    let presetModels: [(provider: VisionAPIConfig.ModelProvider, models: [String])] = [
        (.gemini, ["gemini-3-pro-image-preview", "gemini-2.0-flash-exp"]),
        (.geminiCompatible, []),
        (.doubao, ["doubao-seedream-4-5-251128"])
    ]

    var body: some View {
        NavigationView {
            List {
                // 当前模型
                Section {
                    HStack {
                        Text("当前选择")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(selectedModel)
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }
                
                // 服务提供商选择
                Section {
                    Picker("模型服务", selection: Binding(
                        get: { VisionAPIConfig.preferredImageGenProvider },
                        set: { VisionAPIConfig.preferredImageGenProvider = $0 }
                    )) {
                        Text("Gemini").tag(VisionAPIConfig.ModelProvider.gemini)
                        Text("Gemini 兼容").tag(VisionAPIConfig.ModelProvider.geminiCompatible)
                        Text("豆包 (Seedream)").tag(VisionAPIConfig.ModelProvider.doubao)
                    }
                } header: {
                    Text("选择服务提供商")
                }
                
                // 每个提供商一个 Section
                ForEach(presetModels, id: \.provider.rawValue) { item in
                    providerSection(provider: item.provider, presets: item.models)
                }
            }
            .navigationTitle("图片生成模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("添加自定义模型", isPresented: Binding(
                get: { addingForProvider != nil },
                set: { if !$0 { addingForProvider = nil } }
            )) {
                TextField("模型名称", text: $newModelName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Button("取消", role: .cancel) {
                    newModelName = ""
                    addingForProvider = nil
                }
                Button("添加") {
                    if !newModelName.isEmpty, let provider = addingForProvider {
                        modelManager.addModel(newModelName, for: provider)
                        selectedModel = newModelName
                        newModelName = ""
                        addingForProvider = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func providerSection(provider: VisionAPIConfig.ModelProvider, presets: [String]) -> some View {
        Section {
            ForEach(presets, id: \.self) { model in
                modelRow(model)
            }
            
            ForEach(modelManager.models(for: provider), id: \.self) { model in
                modelRow(model)
            }
            .onDelete { indexSet in
                let customModels = modelManager.models(for: provider)
                for index in indexSet {
                    modelManager.removeModel(customModels[index], for: provider)
                }
            }
            
            Button {
                addingForProvider = provider
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("添加模型")
                        .foregroundColor(.blue)
                }
            }
        } header: {
            Text(provider.displayName)
        } footer: {
            if !modelManager.models(for: provider).isEmpty {
                Text("左滑可删除自定义模型")
            }
        }
    }
    
    @ViewBuilder
    private func modelRow(_ model: String) -> some View {
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
}
