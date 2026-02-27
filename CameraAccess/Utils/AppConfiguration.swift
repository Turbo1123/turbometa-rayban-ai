/*
 * App Configuration Manager
 * 应用配置管理器 - 统一管理应用配置和启动优化
 */

import Foundation
import SwiftUI

/// 应用配置
class AppConfiguration {

    // MARK: - Shared Instance

    static let shared = AppConfiguration()

    // MARK: - Properties

    /// 应用版本
    let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

    /// 构建版本
    let buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

    /// 应用标识符
    let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "Unknown"

    /// 设备信息
    let deviceInfo: DeviceInfo

    /// 环境配置
    let environment: Environment

    // MARK: - Nested Types

    struct DeviceInfo {
        let model: String
        let systemName: String
        let systemVersion: String
        let name: String

        var isSimulator: Bool {
            return model.contains("Simulator")
        }
    }

    enum Environment: String {
        case development
        case production
        case testing

        var isProduction: Bool {
            return self == .production
        }

        var isDebug: Bool {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }

    // MARK: - Initialization

    private init() {
        // 获取设备信息
        let device = UIDevice.current
        self.deviceInfo = DeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            name: device.name
        )

        // 确定环境
        #if DEBUG
        self.environment = .development
        #else
        self.environment = .production
        #endif

        // 启动时初始化
        setup()
    }

    // MARK: - Setup

    private func setup() {
        print("🚀 [AppConfig] Starting \(bundleIdentifier) v\(appVersion) (Build \(buildNumber))")
        print("📱 [AppConfig] Device: \(deviceInfo.name) - \(deviceInfo.systemName) \(deviceInfo.systemVersion)")
        print("🔧 [AppConfig] Environment: \(environment.rawValue.uppercased())")

        // 根据环境配置日志
        if environment.isDebug {
            Logger.shared.setMinimumLevel(.debug)
            Logger.shared.setConsoleOutput(true)
        } else {
            Logger.shared.setMinimumLevel(.info)
            Logger.shared.setConsoleOutput(false)
        }

        logInfo("App initialized successfully", category: .general)
    }

    // MARK: - Configuration Keys

    enum ConfigKey: String {
        case firstLaunch = "app_first_launch"
        case lastVersion = "app_last_version"
        case analyticsEnabled = "analytics_enabled"
        case crashReportingEnabled = "crash_reporting_enabled"
        case cacheSize = "cache_size_limit"
        case autoCleanCache = "auto_clean_cache"
    }

    // MARK: - Configuration Getters/Setters

    var isFirstLaunch: Bool {
        get {
            return !UserDefaults.standard.bool(forKey: ConfigKey.firstLaunch.rawValue)
        }
        set {
            UserDefaults.standard.set(!newValue, forKey: ConfigKey.firstLaunch.rawValue)
        }
    }

    var lastVersion: String? {
        get {
            return UserDefaults.standard.string(forKey: ConfigKey.lastVersion.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ConfigKey.lastVersion.rawValue)
        }
    }

    var isAnalyticsEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: ConfigKey.analyticsEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ConfigKey.analyticsEnabled.rawValue)
        }
    }

    var isCrashReportingEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: ConfigKey.crashReportingEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ConfigKey.crashReportingEnabled.rawValue)
        }
    }

    // MARK: - Version Check

    func checkForVersionUpdate() -> Bool {
        guard let lastVersion = lastVersion else {
            // 首次安装
            self.lastVersion = appVersion
            return true
        }

        if lastVersion != appVersion {
            // 版本更新
            self.lastVersion = appVersion
            logInfo("App updated from \(lastVersion) to \(appVersion)", category: .general)
            return true
        }

        return false
    }

    // MARK: - Migration

    func performMigrationIfNeeded() {
        guard checkForVersionUpdate() else { return }

        // 执行版本迁移
        logInfo("Performing migration...", category: .general)

        // 清除旧缓存
        if isFirstLaunch {
            clearAllCaches()
        }

        // 标记已完成首次启动
        if isFirstLaunch {
            isFirstLaunch = false
        }
    }

    // MARK: - Cache Management

    private func clearAllCaches() {
        logInfo("Clearing all caches...", category: .general)

        // 清除URL缓存
        URLCache.shared.removeAllCachedResponses()

        // 清除图片缓存
        ImageCache.shared.clear()

        logInfo("All caches cleared", category: .general)
    }

    func clearCacheIfNeeded() -> Bool {
        // 检查缓存大小
        let cacheSize = getCacheSize()

        if cacheSize > 100 * 1024 * 1024 { // 100MB
            logWarning("Cache size exceeds 100MB, clearing...", category: .performance)
            clearAllCaches()
            return true
        }

        return false
    }

    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0

        // URL缓存大小
        totalSize += URLCache.shared.currentDiskUsage

        // 计算其他缓存大小（可根据需要添加）

        return totalSize
    }

    // MARK: - Performance Settings

    var recommendedMaxCacheSize: Int {
        // 根据设备内存返回推荐的缓存大小
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        if physicalMemory < 2_000_000_000 { // < 2GB
            return 50 * 1024 * 1024 // 50MB
        } else if physicalMemory < 4_000_000_000 { // < 4GB
            return 100 * 1024 * 1024 // 100MB
        } else {
            return 200 * 1024 * 1024 // 200MB
        }
    }
}

// MARK: - Image Cache

class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = AppConfiguration.shared.recommendedMaxCacheSize

        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func clearCache() {
        logWarning("Received memory warning, clearing image cache", category: .performance)
        cache.removeAllObjects()
    }

    func set(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Startup Optimizer

class StartupOptimizer {

    static let shared = StartupOptimizer()

    private init() {}

    // MARK: - Startup Tasks

    enum StartupTask {
        case essential
        case highPriority
        case normal
        case lowPriority

        var delay: TimeInterval {
            switch self {
            case .essential: return 0
            case .highPriority: return 0.1
            case .normal: return 0.5
            case .lowPriority: return 1.0
            }
        }
    }

    /// 执行启动优化
    func optimizeStartup() {
        logInfo("Starting startup optimization...", category: .performance)

        // 立即执行的任务
        executeTasks(priority: .essential)

        // 延迟执行的任务
        DispatchQueue.main.asyncAfter(deadline: .now() + StartupTask.highPriority.delay) {
            self.executeTasks(priority: .highPriority)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + StartupTask.normal.delay) {
            self.executeTasks(priority: .normal)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + StartupTask.lowPriority.delay) {
            self.executeTasks(priority: .lowPriority)
        }
    }

    private func executeTasks(priority: StartupTask) {
        switch priority {
        case .essential:
            logInfo("Executing essential startup tasks", category: .performance)
            // 必须立即执行的任务
            AppConfiguration.shared.performMigrationIfNeeded()

        case .highPriority:
            logInfo("Executing high priority startup tasks", category: .performance)
            // 高优先级任务
            Task {
                await APIProviderManager.shared.fetchOpenRouterModels()
            }

        case .normal:
            logInfo("Executing normal priority startup tasks", category: .performance)
            // 普通优先级任务
            AppConfiguration.shared.clearCacheIfNeeded()

        case .lowPriority:
            logInfo("Executing low priority startup tasks", category: .performance)
            // 低优先级任务
            PerformanceMonitor.shared.clearMeasurements()
        }
    }

    // MARK: - Preloading

    /// 预加载数据
    func preloadData() {
        logInfo("Preloading data...", category: .performance)

        Task {
            // 预加载用户设置
            _ = LanguageManager.shared.currentLanguage

            // 预加载API配置
            _ = APIProviderManager.shared.currentProvider

            logInfo("Data preloading completed", category: .performance)
        }
    }
}

// MARK: - Usage Examples

/*
 应用启动时的使用：

 在 AppDelegate 或 App 入口：

 ```
 struct TurboMetaApp: App {
     init() {
         // 1. 初始化配置
         _ = AppConfiguration.shared.setup()

         // 2. 启动优化
         StartupOptimizer.shared.optimizeStartup()

         // 3. 预加载数据
         StartupOptimizer.shared.preloadData()
     }

     var body: some Scene {
         // ...
     }
 }
 ```

 检查配置：

 ```
 let config = AppConfiguration.shared
 print("Version: \(config.appVersion)")
 print("Device: \(config.deviceInfo.model)")
 print("Environment: \(config.environment.rawValue)")
 ```

 迁移检查：

 ```
 AppConfiguration.shared.performMigrationIfNeeded()
 ```
 */
