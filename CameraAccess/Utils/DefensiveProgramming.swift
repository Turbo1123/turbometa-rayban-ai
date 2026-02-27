/*
 * Defensive Programming Utilities
 * 防御性编程工具集 - 提供安全的类型转换和边界检查
 */

import Foundation
import UIKit

// MARK: - Safe Converters

/// 安全的类型转换工具
struct SafeConverter {

    /// 安全地将字符串转换为Int
    static func toInt(_ string: String?) -> Int? {
        guard let string = string else { return nil }
        return Int(string)
    }

    /// 安全地将字符串转换为Double
    static func toDouble(_ string: String?) -> Double? {
        guard let string = string else { return nil }
        return Double(string)
    }

    /// 安全地将字符串转换为Bool
    static func toBool(_ string: String?) -> Bool? {
        guard let string = string else { return nil }
        let lowercased = string.lowercased()
        if lowercased == "true" || lowercased == "1" {
            return true
        }
        if lowercased == "false" || lowercased == "0" {
            return false
        }
        return nil
    }

    /// 安全地将Any转换为String
    static func toString(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        return value as? String
    }

    /// 安全地将Any转换为Int
    static func toInt(_ value: Any?) -> Int? {
        guard let value = value else { return nil }
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return toInt(stringValue)
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return nil
    }

    /// 安全地将Any转换为Double
    static func toDouble(_ value: Any?) -> Double? {
        guard let value = value else { return nil }
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let stringValue = value as? String {
            return toDouble(stringValue)
        }
        if let numberValue = value as? NSNumber {
            return numberValue.doubleValue
        }
        return nil
    }
}

// MARK: - Boundary Checker

/// 边界检查工具
struct BoundaryChecker {

    /// 检查索引是否在数组范围内
    static func isValidIndex<T>(_ index: Int, array: [T]) -> Bool {
        return index >= 0 && index < array.count
    }

    /// 安全地获取数组元素
    static func safeElement<T>(at index: Int, array: [T]) -> T? {
        guard isValidIndex(index, array: array) else {
            return nil
        }
        return array[index]
    }

    /// 限制值在指定范围内
    static func clamp<T: Comparable>(_ value: T, min: T, max: T) -> T {
        if value < min { return min }
        if value > max { return max }
        return value
    }

    /// 检查字符串是否为空或仅包含空白
    static func isBlank(_ string: String?) -> Bool {
        return string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    /// 检查数组是否为空
    static func isEmpty<T>(_ array: [T]?) -> Bool {
        return array?.isEmpty ?? true
    }
}

// MARK: - Validation Helper

/// 验证工具
struct ValidationHelper {

    /// 验证URL格式
    static func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    /// 验证邮箱格式
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// 验证字符串长度
    static func isValidLength(_ string: String?, min: Int = 0, max: Int = Int.max) -> Bool {
        guard let string = string else { return false }
        return string.count >= min && string.count <= max
    }

    /// 验证图片大小
    static func isValidImageSize(_ image: UIImage, maxSizeMB: Double = 10.0) -> Bool {
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            return false
        }
        let sizeMB = Double(imageData.count) / (1024.0 * 1024.0)
        return sizeMB <= maxSizeMB
    }
}

// MARK: - Safe Unwrapping

/// 安全解包工具
struct SafeUnwrap {

    /// 安全解包多个可选值
    static func all<T>(_ optionals: T?...) -> [T]? {
        let unwrapped = optionals.compactMap { $0 }
        guard unwrapped.count == optionals.count else {
            return nil
        }
        return unwrapped
    }

    /// 安全解包第一个非nil值
    static func first<T>(_ optionals: T?...) -> T? {
        for optional in optionals {
            if let value = optional {
                return value
            }
        }
        return nil
    }

    /// 安全解包或返回默认值
    static func or<T>(_ optional: T?, default: T) -> T {
        return optional ?? `default`
    }
}

// MARK: - Optional Extensions

extension Optional {

    /// 执行操作如果值存在
    func ifSome(_ action: (Wrapped) -> Void) {
        if let unwrapped = self {
            action(unwrapped)
        }
    }

    /// 转换可选值
    func map<U>(_ transform: (Wrapped) throws -> U) rethrows -> U? {
        guard let unwrapped = self else { return nil }
        return try transform(unwrapped)
    }

    /// 过滤可选值
    func filter(_ predicate: (Wrapped) throws -> Bool) rethrows -> Wrapped? {
        guard let unwrapped = self else { return nil }
        return try predicate(unwrapped) ? unwrapped : nil
    }
}

// MARK: - Array Extensions

extension Array {

    /// 安全获取元素
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

    /// 去重
    func distinct<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var uniqueKeys = Set<T>()
        return filter { element in
            uniqueKeys.insert(element[keyPath: keyPath])
            return true
        }
    }
}

// MARK: - String Extensions

extension String {

    /// 去除首尾空白
    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 是否为空
    var isBlank: Bool {
        return trimmed.isEmpty
    }

    /// 安全的子字符串
    func safeSubstring(from: Int, to: Int? = nil) -> String? {
        guard from >= 0 && from < count else { return nil }
        let endIndex = to ?? self.count
        guard endIndex >= from && endIndex <= count else { return nil }
        let indexFrom = index(startIndex, offsetBy: from)
        let indexTo = self.index(startIndex, offsetBy: endIndex)
        return String(self[indexFrom..<indexTo])
    }

    /// 截断字符串
    func truncated(limit: Int, trailing: String = "...") -> String {
        if count <= limit {
            return self
        }
        let index = self.index(startIndex, offsetBy: limit)
        return String(self[..<index]) + trailing
    }
}

// MARK: - Usage Examples

/*
 安全转换：
 ```
 let intValue = SafeConverter.toInt("123")  // 123
 let wrongValue = SafeConverter.toInt("abc") // nil
 let boolValue = SafeConverter.toBool("true") // true
 ```

 边界检查：
 ```
 let array = [1, 2, 3]
 let element = BoundaryChecker.safeElement(at: 5, array: array) // nil
 let clamped = BoundaryChecker.clamp(15, min: 0, max: 10) // 10
 ```

 验证：
 ```
 let valid = ValidationHelper.isValidURL("https://example.com") // true
 let emailValid = ValidationHelper.isValidEmail("test@example.com") // true
 ```

 可选值操作：
 ```
 let optional: String? = "hello"
 optional.ifSome { print($0) } // 打印 "hello"

 let value = SafeUnwrap.or(optional, default: "default") // "hello"
 ```

 数组安全访问：
 ```
 let array = [1, 2, 3]
 let element = array[safe: 5] // nil 而不是崩溃
 ```

 字符串操作：
 ```
 let text = "  hello  "
 text.isBlank // false
 text.trimmed // "hello"
 text.truncated(limit: 3) // "hel..."
 ```
 */
