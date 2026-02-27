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

    private struct LogEntry {
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
        error("Network Error: \(url) - \(error.localizedDescription)", category: .networking)
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
