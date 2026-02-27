/*
 * Performance Optimizer
 * 性能优化工具类 - 提供各种性能优化方法
 */

import Foundation
import SwiftUI

class PerformanceOptimizer {

    // MARK: - Caching

    /// 内存缓存，用于存储频繁访问的数据
    private static var cache = NSCache<NSString, CacheEntry>()

    /// 缓存条目
    private struct CacheEntry {
        let value: Any
        let expirationDate: Date

        var isExpired: Bool {
            return Date() > expirationDate
        }
    }

    /// 缓存数据
    static func cache(_ value: Any, forKey key: String, expiration: TimeInterval = 300) {
        let entry = CacheEntry(value: value, expirationDate: Date().addingTimeInterval(expiration))
        cache.setObject(entry as NSString, forKey: key as NSString)
    }

    /// 获取缓存数据
    static func getCached<T>(valueForKey key: String, as type: T.Type) -> T? {
        guard let entry = cache.object(forKey: key as NSString) as? CacheEntry,
              !entry.isExpired,
              let value = entry.value as? T else {
            return nil
        }
        return value
    }

    /// 清除过期缓存
    static func clearExpiredCache() {
        // NSCache会自动管理内存，这里主要是逻辑清除
        cache.removeAllObjects()
    }

    // MARK: - Debouncing & Throttling

    /// 防抖 - 延迟执行直到调用停止
    private static var debounceWorkItems = [String: DispatchWorkItem]()

    static func debounce(delay: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let id = UUID().uuidString
        return { [weak self] in
            // 取消之前的任务
            self?.debounceWorkItems[id]?.cancel()

            // 创建新任务
            let workItem = DispatchWorkItem { action() }
            debounceWorkItems[id] = workItem

            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }

    /// 节流 - 限制执行频率
    private static var throttleWorkItems = [String: DispatchWorkItem]()
    private static var throttleLastRun = [String: Date]()

    static func throttle(interval: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        let id = UUID().uuidString
        return { [weak self] in
            let now = Date()

            // 检查是否可以执行
            if let lastRun = self?.throttleLastRun[id],
               now.timeIntervalSince(lastRun) < interval {
                return
            }

            // 更新最后执行时间
            self?.throttleLastRun[id] = now

            // 执行动作
            action()
        }
    }

    // MARK: - Async Optimization

    /// 批量执行异步任务
    static func executeBatch<T>(_ tasks: [() async throws -> T]) async throws -> [T] {
        return try await withThrowingTaskGroup(of: T.self) { group in
            for task in tasks {
                group.addTask {
                    return try await task()
                }
            }

            var results = [T]()
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    /// 并发执行多个任务并等待第一个完成
    static func executeFirst<T>(_ tasks: [() async throws -> T]) async throws -> T? {
        return try await withThrowingTaskGroup(of: T.self) { group in
            for task in tasks {
                group.addTask {
                    return try await task()
                }
            }

            return try await group.first(where: { _ in true })
        }
    }

    // MARK: - Memory Management

    /// 释放内存
    static func releaseMemory() {
        // 清除缓存
        clearExpiredCache()

        // 强制垃圾回收（仅在必要时使用）
        autoreleasepool {
            // 执行需要清理的操作
        }
    }

    /// 检查内存压力
    static func checkMemoryPressure() -> Bool {
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
            let ratio = usedMB / totalMB

            // 如果使用超过80%的内存，认为有压力
            return ratio > 0.8
        }

        return false
    }
}

// MARK: - SwiftUI Extensions

extension View {
    /// 防抖修饰器
    func debouncedChange(forKey key: String, delay: TimeInterval = 0.3, action: @escaping () -> Void) -> some View {
        self.onChange(of: key) { _ in
            PerformanceOptimizer.debounce(delay: delay, action: action)()
        }
    }
}

// MARK: - Task Tracker

/// 任务跟踪器 - 用于避免重复任务
@MainActor
class TaskTracker {
    private var tasks = [String: Task<Void, Never>]()

    /// 追踪并执行任务（如果同名任务已存在则取消）
    func track(_ id: String, task: @escaping () async -> Void) {
        // 取消现有任务
        tasks[id]?.cancel()

        // 创建新任务
        let newTask = Task {
            await task()
            // 完成后移除
            tasks.removeValue(forKey: id)
        }

        tasks[id] = newTask
    }

    /// 取消特定任务
    func cancel(id: String) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
    }

    /// 取消所有任务
    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    deinit {
        cancelAll()
    }
}

// MARK: - Performance Monitor

/// 性能监控器
class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var measurements = [String: [TimeInterval]]()

    /// 开始测量
    func startMeasurement(_ id: String) -> Date {
        return Date()
    }

    /// 结束测量并记录
    func endMeasurement(_ id: String, start: Date) {
        let duration = Date().timeIntervalSince(start)

        if measurements[id] == nil {
            measurements[id] = []
        }

        measurements[id]?.append(duration)

        // 只保留最近100次测量
        if let count = measurements[id]?.count, count > 100 {
            measurements[id]?.removeFirst()
        }

        // 如果平均执行时间超过1秒，打印警告
        if let times = measurements[id], times.count >= 10 {
            let avg = times.reduce(0, +) / Double(times.count)
            if avg > 1.0 {
                print("⚠️ [Performance] \(id) average execution time: \(String(format: "%.3f", avg))s")
            }
        }
    }

    /// 获取平均执行时间
    func getAverageTime(for id: String) -> TimeInterval? {
        guard let times = measurements[id], !times.isEmpty else {
            return nil
        }
        return times.reduce(0, +) / Double(times.count)
    }

    /// 清除测量数据
    func clearMeasurements() {
        measurements.removeAll()
    }
}

// MARK: - Usage Examples

/*
 使用缓存：
 ```
 PerformanceOptimizer.cache(data, forKey: "myData")
 if let cached = PerformanceOptimizer.getCached(valueForKey: "myData", as: MyData.self) {
     print("使用缓存数据")
 }
 ```

 使用防抖：
 ```
 let debouncedSearch = PerformanceOptimizer.debounce(delay: 0.5) {
     performSearch()
 }
 debouncedSearch() // 每次调用都会重置计时器
 ```

 使用节流：
 ```
 let throttledUpdate = PerformanceOptimizer.throttle(interval: 1.0) {
     updateUI()
 }
 throttledUpdate() // 每秒最多执行一次
 ```

 使用任务跟踪：
 ```
 let taskTracker = TaskTracker()
 taskTracker.track("search") {
     await performSearch()
 }
 ```

 使用性能监控：
 ```
 let monitor = PerformanceMonitor.shared
 let start = monitor.startMeasurement("operation")
 // ... 执行操作 ...
 monitor.endMeasurement("operation", start: start)
 ```
 */
