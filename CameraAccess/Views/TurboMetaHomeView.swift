/*
 * TurboMeta Home View
 * 主页 - 功能入口
 */

import SwiftUI

struct TurboMetaHomeView: View {
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @ObservedObject var wearablesViewModel: WearablesViewModel
    let visionApiKey: String
    let realtimeApiKey: String

    @State private var showLiveAI = false
    @State private var showLiveStream = false
    @State private var showLeanEat = false
    @State private var showGeminiGen = false
    @State private var showQuickVision = false
    @State private var showLiveTranslate = false
    @State private var showAPIKeyMissingAlert = false
    @State private var apiKeyMissingMessage = "请先在\"我的\"→\"API Key 管理\"中完成配置"

    // 设备连接状态
    private var isDeviceConnected: Bool {
        streamViewModel.hasActiveDevice
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        AppColors.primary.opacity(0.1),
                        AppColors.secondary.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        VStack(spacing: AppSpacing.sm) {
                            Text(NSLocalizedString("app.name", comment: "App name"))
                                .font(AppTypography.largeTitle)
                                .foregroundColor(AppColors.textPrimary)

                            Text(NSLocalizedString("app.subtitle", comment: "App subtitle"))
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.textSecondary)

                            // 设备连接状态指示器
                            HStack(spacing: AppSpacing.xs) {
                                Circle()
                                    .fill(isDeviceConnected ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(isDeviceConnected ? "眼镜已连接" : "眼镜未连接")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                        .padding(.top, AppSpacing.xl)

                        // Feature Grid
                        VStack(spacing: AppSpacing.md) {
                            // Row 1
                            HStack(spacing: AppSpacing.md) {
                                FeatureCard(
                                    title: NSLocalizedString("home.liveai.title", comment: "Live AI title"),
                                    subtitle: NSLocalizedString("home.liveai.subtitle", comment: "Live AI subtitle"),
                                    icon: "brain.head.profile",
                                    gradient: [AppColors.liveAI, AppColors.liveAI.opacity(0.7)]
                                ) {
                                    if realtimeApiKey.isEmpty {
                                        apiKeyMissingMessage = "需要先配置实时对话 API Key 才能使用此功能。\n\n前往\"我的\" → \"API Key 管理\"进行配置。"
                                        showAPIKeyMissingAlert = true
                                    } else if !isDeviceConnected {
                                        apiKeyMissingMessage = "请先在 Meta View 应用中配对并连接您的 Ray-Ban Meta 眼镜。"
                                        showAPIKeyMissingAlert = true
                                    } else {
                                        showLiveAI = true
                                    }
                                }

                                FeatureCard(
                                    title: "AI 创意生成",
                                    subtitle: "照片风格化与生成",
                                    icon: "paintpalette.fill",
                                    gradient: [AppColors.secondary, AppColors.secondary.opacity(0.7)]
                                ) {
                                    if VisionAPIConfig.apiKey(for: VisionAPIConfig.activeImageGenProvider).isEmpty {
                                        apiKeyMissingMessage = "需要先配置 Gemini API Key 才能使用此功能。\n\n前往\"我的\" → \"API Key 管理\"进行配置。"
                                        showAPIKeyMissingAlert = true
                                    } else {
                                        showGeminiGen = true
                                    }
                                }
                            }

                            // Row 2
                            HStack(spacing: AppSpacing.md) {
                                FeatureCard(
                                    title: NSLocalizedString("home.quickvision.title", comment: "Quick Vision title"),
                                    subtitle: NSLocalizedString("home.quickvision.subtitle", comment: "Quick Vision subtitle"),
                                    icon: "eye.fill",
                                    gradient: [AppColors.primary, AppColors.primary.opacity(0.7)]
                                ) {
                                    if visionApiKey.isEmpty {
                                        apiKeyMissingMessage = "需要先配置视觉服务 API Key 才能使用此功能。\n\n前往\"我的\" → \"API Key 管理\"进行配置。"
                                        showAPIKeyMissingAlert = true
                                    } else if !isDeviceConnected {
                                        apiKeyMissingMessage = "请先在 Meta View 应用中配对并连接您的 Ray-Ban Meta 眼镜。"
                                        showAPIKeyMissingAlert = true
                                    } else {
                                        showQuickVision = true
                                    }
                                }

                                FeatureCard(
                                    title: NSLocalizedString("home.livetranslate.title", comment: "Live Translate title"),
                                    subtitle: NSLocalizedString("home.livetranslate.subtitle", comment: "Live Translate subtitle"),
                                    icon: "text.bubble.fill",
                                    gradient: [AppColors.accent, AppColors.accent.opacity(0.7)]
                                ) {
                                    if realtimeApiKey.isEmpty {
                                        apiKeyMissingMessage = "需要先配置实时对话 API Key 才能使用此功能。\n\n前往\"我的\" → \"API Key 管理\"进行配置。"
                                        showAPIKeyMissingAlert = true
                                    } else if !isDeviceConnected {
                                        apiKeyMissingMessage = "请先在 Meta View 应用中配对并连接您的 Ray-Ban Meta 眼镜。"
                                        showAPIKeyMissingAlert = true
                                    } else {
                                        showLiveTranslate = true
                                    }
                                }
                            }

                            // Row 3
                            HStack(spacing: AppSpacing.md) {
                                FeatureCard(
                                    title: NSLocalizedString("home.leaneat.title", comment: "LeanEat title"),
                                    subtitle: NSLocalizedString("home.leaneat.subtitle", comment: "LeanEat subtitle"),
                                    icon: "chart.bar.fill",
                                    gradient: [AppColors.leanEat, AppColors.leanEat.opacity(0.7)]
                                ) {
                                    if visionApiKey.isEmpty {
                                        apiKeyMissingMessage = "需要先配置视觉服务 API Key 才能使用此功能。\n\n前往\"我的\" → \"API Key 管理\"进行配置。"
                                        showAPIKeyMissingAlert = true
                                    } else if !isDeviceConnected {
                                        apiKeyMissingMessage = "请先在 Meta View 应用中配对并连接您的 Ray-Ban Meta 眼镜。"
                                        showAPIKeyMissingAlert = true
                                    } else {
                                        showLeanEat = true
                                    }
                                }

                                FeatureCard(
                                    title: NSLocalizedString("home.wordlearn.title", comment: "WordLearn title"),
                                    subtitle: NSLocalizedString("home.wordlearn.subtitle", comment: "WordLearn subtitle"),
                                    icon: "book.closed.fill",
                                    gradient: [AppColors.wordLearn, AppColors.wordLearn.opacity(0.7)],
                                    isPlaceholder: true
                                ) {
                                    // Placeholder
                                }
                            }

                            // Row 4 - Full width
                            FeatureCardWide(
                                title: NSLocalizedString("home.livestream.title", comment: "Live Stream title"),
                                subtitle: NSLocalizedString("home.livestream.subtitle", comment: "Live Stream subtitle"),
                                icon: "video.fill",
                                gradient: [AppColors.liveStream, AppColors.liveStream.opacity(0.7)]
                            ) {
                                showLiveStream = true
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showLiveAI) {
                LiveAIView(streamViewModel: streamViewModel, apiKey: realtimeApiKey)
            }
            .fullScreenCover(isPresented: $showLiveStream) {
                SimpleLiveStreamView(streamViewModel: streamViewModel)
            }
            .fullScreenCover(isPresented: $showLeanEat) {
                StreamView(viewModel: streamViewModel, wearablesVM: wearablesViewModel)
            }
            .fullScreenCover(isPresented: $showGeminiGen) {
                GeminiGenView(streamViewModel: streamViewModel, apiKey: VisionAPIConfig.apiKey(for: VisionAPIConfig.activeImageGenProvider))
            }
            .fullScreenCover(isPresented: $showQuickVision) {
                QuickVisionView(streamViewModel: streamViewModel, apiKey: visionApiKey)
            }
            .fullScreenCover(isPresented: $showLiveTranslate) {
                LiveTranslateView(streamViewModel: streamViewModel)
            }
            .alert("提示", isPresented: $showAPIKeyMissingAlert) {
                Button("知道了") {}
            } message: {
                Text(apiKeyMissingMessage)
            }
        }
    }
}

// MARK: - Feature Card

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    var isPlaceholder: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.md) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text
                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                if isPlaceholder {
                    Text(NSLocalizedString("home.comingsoon", comment: "Coming soon"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(.white.opacity(0.2))
                        .cornerRadius(AppCornerRadius.sm)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
        }
        .disabled(isPlaceholder)
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Feature Card Wide

struct FeatureCardWide: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }

                // Text
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(AppSpacing.lg)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppCornerRadius.lg)
            .shadow(color: AppShadow.medium(), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// --- INJECTED CODE START ---
/*
 * Logging System
 * 统一的日志管理系统 - 提供结构化的日志记录和调试功能
 */

import Foundation
import os.log

/// 日志级别
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case critical = 4

    var icon: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    var prefix: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    var color: String {
        switch self {
        case .debug: return "\u{001B}[36m" // Cyan
        case .info: return "\u{001B}[34m"  // Blue
        case .warning: return "\u{001B}[33m" // Yellow
        case .error: return "\u{001B}[31m"   // Red
        case .critical: return "\u{001B}[35m" // Magenta
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// 日志类别
enum LogCategory: String {
    case general = "General"
    case networking = "Network"
    case database = "Database"
    case ui = "UI"
    case performance = "Performance"
    case security = "Security"
    case media = "Media"
    case ai = "AI"
    case bluetooth = "Bluetooth"
    case camera = "Camera"

    var shortCode: String {
        switch self {
        case .general: return "GEN"
        case .networking: return "NET"
        case .database: return "DB"
        case .ui: return "UI"
        case .performance: return "PERF"
        case .security: return "SEC"
        case .media: return "MEDIA"
        case .ai: return "AI"
        case .bluetooth: return "BLE"
        case .camera: return "CAM"
        }
    }
}

/// 日志管理器
class Logger {

    // MARK: - Shared Instance

    static let shared = Logger()

    // MARK: - Properties

    private var minimumLogLevel: LogLevel = .debug
    private var enableConsoleOutput: Bool = true
    private var enableFileLogging: Bool = false
    private var logToFileURL: URL?

    // 格式化选项
    var showTimestamp: Bool = true
    var showCategory: Bool = true
    var showColors: Bool = true

    // 日志历史（用于调试）
    private var logHistory: [LogEntry] = []
    private let maxHistorySize = 1000

    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
        let file: String
        let function: String
        let line: Int
    }

    // MARK: - Initialization

    private init() {
        #if DEBUG
        minimumLogLevel = .debug
        #else
        minimumLogLevel = .info
        #endif

        setupFileLogging()
    }

    // MARK: - Configuration

    func setMinimumLevel(_ level: LogLevel) {
        minimumLogLevel = level
    }

    func setConsoleOutput(_ enabled: Bool) {
        enableConsoleOutput = enabled
    }

    func setFileLogging(_ enabled: Bool) {
        enableFileLogging = enabled
    }

    // MARK: - Logging Methods

    /// 记录调试日志
    func debug(_ message: String,
               category: LogCategory = .general,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    /// 记录信息日志
    func info(_ message: String,
              category: LogCategory = .general,
              file: String = #file,
              function: String = #function,
              line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    /// 记录警告日志
    func warning(_ message: String,
                 category: LogCategory = .general,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    /// 记录错误日志
    func error(_ message: String,
               category: LogCategory = .general,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    /// 记录严重错误日志
    func critical(_ message: String,
                  category: LogCategory = .general,
                  file: String = #file,
                  function: String = #function,
                  line: Int = #line) {
        log(level: .critical, message: message, category: category, file: file, function: function, line: line)
    }

    // MARK: - Private Methods

    private func log(level: LogLevel,
                    message: String,
                    category: LogCategory,
                    file: String,
                    function: String,
                    line: Int) {
        // 检查日志级别
        guard level >= minimumLogLevel else { return }

        // 创建日志条目
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line
        )

        // 添加到历史
        addToHistory(entry)

        // 格式化日志
        let formattedMessage = formatLog(entry)

        // 输出到控制台
        if enableConsoleOutput {
            print(formattedMessage)
        }

        // 写入文件
        if enableFileLogging {
            writeToFile(formattedMessage)
        }
    }

    private func formatLog(_ entry: LogEntry) -> String {
        var components: [String] = []

        // 时间戳
        if showTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            components.append("[\(formatter.string(from: entry.timestamp))]")
        }

        // 日志级别
        if showColors {
            components.append("\(entry.level.color)[\(entry.level.prefix)]\u{001B}[0m")
        } else {
            components.append("[\(entry.level.prefix)]")
        }

        // 图标
        components.append("\(entry.level.icon)")

        // 类别
        if showCategory {
            components.append("[\(entry.category.shortCode)]")
        }

        // 消息
        components.append(entry.message)

        // 文件信息（仅在DEBUG模式）
        #if DEBUG
        let fileName = URL(fileURLWithPath: entry.file).lastPathComponent
        components.append("(\(fileName):\(entry.line))")
        #endif

        return components.joined(separator: " ")
    }

    private func addToHistory(_ entry: LogEntry) {
        logHistory.append(entry)

        // 限制历史大小
        if logHistory.count > maxHistorySize {
            logHistory.removeFirst(logHistory.count - maxHistorySize)
        }
    }

    // MARK: - File Logging

    private func setupFileLogging() {
        do {
            let logsDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Logs")

            try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())

            logToFileURL = logsDirectory.appendingPathComponent("app_\(dateString).log")
        } catch {
            print("Failed to setup file logging: \(error)")
        }
    }

    private func writeToFile(_ message: String) {
        guard let fileURL = logToFileURL else { return }

        do {
            let data = (message + "\n").data(using: .utf8) ?? Data()

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } else {
                try data.write(to: fileURL)
            }
        } catch {
            print("Failed to write log to file: \(error)")
        }
    }

    // MARK: - Log History

    func getLogHistory(level: LogLevel? = nil, category: LogCategory? = nil) -> [LogEntry] {
        var filtered = logHistory

        if let level = level {
            filtered = filtered.filter { $0.level == level }
        }

        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        return filtered
    }

    func clearLogHistory() {
        logHistory.removeAll()
    }

    func exportLogHistory() -> String {
        return logHistory.map { formatLog($0) }.joined(separator: "\n")
    }
}

// MARK: - Convenience Extensions

extension Logger {

    /// 记录网络请求
    func logNetworkRequest(_ url: String, method: String = "GET") {
        info("Network Request: \(method) \(url)", category: .networking)
    }

    /// 记录网络响应
    func logNetworkResponse(_ url: String, statusCode: Int, responseTime: TimeInterval) {
        let responseTimeMs = String(format: "%.0f", responseTime * 1000)
        if statusCode >= 200 && statusCode < 300 {
            info("Response: \(statusCode) OK (\(responseTimeMs)ms)", category: .networking)
        } else {
            warning("Response: \(statusCode) (\(responseTimeMs)ms)", category: .networking)
        }
    }

    /// 记录网络错误
    func logNetworkError(_ url: String, error: Error) {
        self.error("Network Error: \(url) - \(error.localizedDescription)", category: .networking)
    }

    /// 记录性能指标
    func logPerformance(_ operation: String, duration: TimeInterval) {
        let durationMs = String(format: "%.2f", duration * 1000)
        info("\(operation) took \(durationMs)ms", category: .performance)
    }

    /// 记录内存使用情况
    func logMemoryUsage() {
        let memory = getMemoryUsage()
        info("Memory: \(memory.usedMB)MB used / \(memory.totalMB)MB total (\(memory.percentage)%)", category: .performance)
    }

    private func getMemoryUsage() -> (usedMB: Double, totalMB: Double, percentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            let percentage = (usedMB / totalMB) * 100
            return (usedMB, totalMB, percentage)
        }

        return (0, 0, 0)
    }
}

// MARK: - Global Log Functions

/// 全局调试日志
func logDebug(_ message: String,
              category: LogCategory = .general,
              file: String = #file,
              function: String = #function,
              line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

/// 全局信息日志
func logInfo(_ message: String,
             category: LogCategory = .general,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

/// 全局警告日志
func logWarning(_ message: String,
                category: LogCategory = .general,
                file: String = #file,
                function: String = #function,
                line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

/// 全局错误日志
func logError(_ message: String,
              category: LogCategory = .general,
              file: String = #file,
              function: String = #function,
              line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}

/// 全局严重错误日志
func logCritical(_ message: String,
                 category: LogCategory = .general,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
    Logger.shared.critical(message, category: category, file: file, function: function, line: line)
}

// MARK: - Usage Examples

/*
 基本使用：
 ```
 logDebug("This is a debug message")
 logInfo("Application started")
 logWarning("This is a warning")
 logError("An error occurred")
 logCritical("Critical failure!")
 ```

 带类别：
 ```
 logInfo("User logged in", category: .security)
 logError("Network timeout", category: .networking)
 ```

 直接使用Logger：
 ```
 Logger.shared.logPerformance("Image Processing", duration: 0.234)
 Logger.shared.logMemoryUsage()
 Logger.shared.logNetworkRequest("https://api.example.com", method: "POST")
 ```

 导出日志：
 ```
 let logText = Logger.shared.exportLogHistory()
 // 可以保存到文件或发送到服务器
 ```
 */


/*
 * Network Error Handler
 * 网络请求错误处理工具 - 统一的错误处理和重试机制
 */

import Foundation

class NetworkErrorHandler {

    // MARK: - Error Types

    enum NetworkError: LocalizedError {
        case invalidURL
        case noConnection
        case timeout
        case serverError(statusCode: Int, message: String?)
        case unauthorized
        case rateLimited
        case invalidResponse
        case decodingError
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的请求地址"
            case .noConnection:
                return "网络连接不可用，请检查网络设置"
            case .timeout:
                return "请求超时，请稍后重试"
            case .serverError(let code, let message):
                return message ?? "服务器错误 (\(code))"
            case .unauthorized:
                return "API Key 无效或已过期，请检查设置"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            case .invalidResponse:
                return "服务器返回格式错误"
            case .decodingError:
                return "数据解析失败"
            case .unknown(let error):
                return error.localizedDescription
            }
        }

        var isRetryable: Bool {
            switch self {
            case .noConnection, .timeout, .rateLimited, .serverError:
                return true
            case .invalidURL, .unauthorized, .invalidResponse, .decodingError, .unknown:
                return false
            }
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let defaultRetryCount = 3
        static let baseRetryDelay: TimeInterval = 1.0
        static let maxRetryDelay: TimeInterval = 10.0
    }

    // MARK: - Public Methods

    /// 执行带重试的网络请求
    /// - Parameters:
    ///   - request: URLRequest
    ///   - retryCount: 重试次数
    /// - Returns: 返回的数据
    static func executeWithRetry(
        _ request: URLRequest,
        retryCount: Int = Constants.defaultRetryCount
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0..<retryCount {
            do {
                let result = try await URLSession.shared.data(for: request)
                return result
            } catch {
                lastError = error

                // 如果是最后一次尝试，不再等待
                if attempt < retryCount - 1 {
                    let networkError = self.classifyError(error)
                    if networkError.isRetryable {
                        let delay = self.calculateRetryDelay(attempt: attempt)
                        print("⚠️ [Network] Request failed (attempt \(attempt + 1)), retrying in \(delay)s...")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
            }
        }

        throw lastError ?? NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
    }

    /// 分类错误类型
    private static func classifyError(_ error: Error) -> NetworkError {
        let nsError = error as NSError

        // 检查是否是网络连接错误
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost:
                return .noConnection
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorUserCancelledAuthentication,
                 NSURLErrorUserAuthenticationRequired:
                return .unauthorized
            default:
                return .unknown(error)
            }
        }

        // 检查是否是HTTP错误
        if let httpResponse = nsError.userInfo["HTTPURLResponse"] as? HTTPURLResponse {
            return classifyHTTPError(httpResponse)
        }

        return .unknown(error)
    }

    /// 分类HTTP错误
    static func classifyHTTPError(_ response: HTTPURLResponse) -> NetworkError {
        switch response.statusCode {
        case 401, 403:
            return .unauthorized
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(statusCode: response.statusCode, message: nil)
        case 400, 404, 422:
            return .invalidResponse
        default:
            return .serverError(statusCode: response.statusCode, message: nil)
        }
    }

    /// 从HTTP响应中提取错误信息
    static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // 尝试不同的错误字段
        if let error = json["error"] as? [String: Any] {
            return error["message"] as? String
        }

        if let message = json["message"] as? String {
            return message
        }

        if let error = json["error"] as? String {
            return error
        }

        return nil
    }

    // MARK: - Private Helpers

    /// 计算重试延迟（指数退避）
    private static func calculateRetryDelay(attempt: Int) -> TimeInterval {
        let delay = Constants.baseRetryDelay * pow(2.0, Double(attempt))
        return min(delay, Constants.maxRetryDelay)
    }
}

// MARK: - URLRequest Extension

extension URLRequest {

    /// 创建带有默认配置的URLRequest
    /// - Parameters:
    ///   - url: URL
    ///   - method: HTTP方法
    ///   - apiKey: API Key
    /// - timeout: 超时时间
    /// - Returns: URLRequest
    static func create(
        url: URL,
        method: String = "GET",
        apiKey: String? = nil,
        timeout: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout

        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }
}

// MARK: - URLSession Extension

extension URLSession {

    /// 带重试的data请求
    func dataWithRetry(for request: URLRequest, retryCount: Int = 3) async throws -> (Data, URLResponse) {
        return try await NetworkErrorHandler.executeWithRetry(request, retryCount: retryCount)
    }
}


/*
 * Image Processor
 * 图片处理工具类 - 提供图片压缩、格式转换等功能
 */

import UIKit
import Accelerate

class ImageProcessor {

    // MARK: - Constants

    private enum Constants {
        static let maxImageSize: CGFloat = 4096 // 最大图片尺寸
        static let jpegCompressionQuality: CGFloat = 0.85
        static let thumbnailSize: CGFloat = 200
    }

    // MARK: - Image Compression

    /// 压缩图片到指定大小以下
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxFileSizeKB: 最大文件大小（KB）
    /// - Returns: 压缩后的图片数据
    static func compressImage(_ image: UIImage, maxFileSizeKB: Int = 500) -> Data? {
        var compression: CGFloat = Constants.jpegCompressionQuality
        var imageData = image.jpegData(compressionQuality: compression)

        // 如果图片已经足够小，直接返回
        if let data = imageData, data.count / 1024 <= maxFileSizeKB {
            return data
        }

        // 二分法寻找最佳压缩质量
        var minQuality: CGFloat = 0.1
        var maxQuality: CGFloat = Constants.jpegCompressionQuality

        while maxQuality - minQuality > 0.05 {
            let midQuality = (minQuality + maxQuality) / 2
            guard let data = image.jpegData(compressionQuality: midQuality) else {
                break
            }

            if data.count / 1024 <= maxFileSizeKB {
                imageData = data
                minQuality = midQuality
            } else {
                maxQuality = midQuality
            }
        }

        return imageData
    }

    /// 将图片缩放到指定尺寸
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxWidth: 最大宽度
    ///   - maxHeight: 最大高度
    /// - Returns: 缩放后的图片
    static func scaleImage(_ image: UIImage, maxWidth: CGFloat = Constants.maxImageSize, maxHeight: CGFloat = Constants.maxImageSize) -> UIImage {
        let size = calculateScaledSize(for: image.size, maxWidth: maxWidth, maxHeight: maxHeight)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()

        return scaledImage
    }

    /// 创建缩略图
    /// - Parameter image: 原始图片
    /// - Returns: 缩略图
    static func createThumbnail(_ image: UIImage) -> UIImage? {
        let size = calculateScaledSize(for: image.size, maxWidth: Constants.thumbnailSize, maxHeight: Constants.thumbnailSize)

        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail
    }

    // MARK: - Image Format Conversion

    /// 将图片转换为 Base64 编码
    /// - Parameter image: 图片
    /// - Returns: Base64 字符串
    static func toBase64(_ image: UIImage, compressionQuality: CGFloat = Constants.jpegCompressionQuality) -> String? {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return imageData.base64EncodedString()
    }

    /// 从 Base64 字符串创建图片
    /// - Parameter base64String: Base64 字符串
    /// - Returns: 图片
    static func fromBase64(_ base64String: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - Image Validation

    /// 验证图片是否有效
    /// - Parameter image: 图片
    /// - Returns: 是否有效
    static func isValidImage(_ image: UIImage) -> Bool {
        // 检查尺寸
        guard image.size.width > 0 && image.size.height > 0 else {
            return false
        }

        // 检查CGImage
        guard image.cgImage != nil else {
            return false
        }

        return true
    }

    /// 获取图片大小（MB）
    /// - Parameter image: 图片
    /// - Returns: 图片大小
    static func getImageSizeMB(_ image: UIImage) -> Double {
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return 0
        }
        return Double(data.count) / (1024.0 * 1024.0)
    }

    // MARK: - Private Helpers

    /// 计算缩放后的尺寸
    private static func calculateScaledSize(for originalSize: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        var width = originalSize.width
        var height = originalSize.height

        // 如果图片尺寸已经小于限制，直接返回
        if width <= maxWidth && height <= maxHeight {
            return originalSize
        }

        // 计算缩放比例
        let widthRatio = maxWidth / width
        let heightRatio = maxHeight / height
        let ratio = min(widthRatio, heightRatio)

        width *= ratio
        height *= ratio

        return CGSize(width: width, height: height)
    }
}

// MARK: - UIImage Extension

extension UIImage {

    /// 压缩图片
    func compressed(maxFileSizeKB: Int = 500) -> Data? {
        return ImageProcessor.compressImage(self, maxFileSizeKB: maxFileSizeKB)
    }

    /// 缩放图片
    func scaled(maxWidth: CGFloat = 4096, maxHeight: CGFloat = 4096) -> UIImage {
        return ImageProcessor.scaleImage(self, maxWidth: maxWidth, maxHeight: maxHeight)
    }

    /// 创建缩略图
    var thumbnail: UIImage? {
        return ImageProcessor.createThumbnail(self)
    }

    /// 转换为 Base64
    func toBase64(compressionQuality: CGFloat = 0.85) -> String? {
        return ImageProcessor.toBase64(self, compressionQuality: compressionQuality)
    }

    /// 验证图片是否有效
    var isValid: Bool {
        return ImageProcessor.isValidImage(self)
    }

    /// 获取图片大小（MB）
    var sizeInMB: Double {
        return ImageProcessor.getImageSizeMB(self)
    }
}

// FIX FOR OVERLOAD
extension URLSession {
    func dataWithRetry(from url: URL, retryCount: Int = 3) async throws -> (Data, URLResponse) {
        return try await dataWithRetry(for: URLRequest(url: url), retryCount: retryCount)
    }
}

