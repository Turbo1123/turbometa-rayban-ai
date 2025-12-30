/*
 * Language Manager
 * App 语言管理器 - 支持中英文切换
 */

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"

    var displayName: String {
        switch self {
        case .system: return "跟随系统 / System"
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return Locale.current
        case .chinese: return Locale(identifier: "zh-Hans")
        case .english: return Locale(identifier: "en")
        }
    }
}

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let languageKey = "app_language"

    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }

    // Use nonisolated(unsafe) to allow access from any thread
    // This is safe because we only read after initialization
    nonisolated(unsafe) static var currentBundle: Bundle = .main

    private init() {
        let savedLanguage = UserDefaults.standard.string(forKey: languageKey) ?? "system"
        self.currentLanguage = AppLanguage(rawValue: savedLanguage) ?? .system
        updateBundle()
    }

    private func updateBundle() {
        let languageCode: String

        switch currentLanguage {
        case .system:
            // Use system language, prefer Chinese if available
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            if preferredLanguage.hasPrefix("zh") {
                languageCode = "zh-Hans"
            } else {
                languageCode = "en"
            }
        case .chinese:
            languageCode = "zh-Hans"
        case .english:
            languageCode = "en"
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            LanguageManager.currentBundle = bundle
        } else {
            LanguageManager.currentBundle = .main
        }
    }

    /// Get localized string
    func localizedString(_ key: String) -> String {
        return LanguageManager.currentBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Get localized string with format arguments
    func localizedString(_ key: String, _ args: CVarArg...) -> String {
        let format = LanguageManager.currentBundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, arguments: args)
    }

    /// Check if current language is Chinese
    var isChinese: Bool {
        switch currentLanguage {
        case .chinese:
            return true
        case .english:
            return false
        case .system:
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            return preferredLanguage.hasPrefix("zh")
        }
    }

    /// Get language code for API calls (TTS, etc.)
    var apiLanguageCode: String {
        return isChinese ? "Chinese" : "English"
    }

    /// Get TTS voice based on current language
    var ttsVoice: String {
        return isChinese ? "Cherry" : "Ethan"
    }

    // Static helpers for nonisolated access
    nonisolated static var staticIsChinese: Bool {
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "system"
        let language = AppLanguage(rawValue: savedLanguage) ?? .system
        switch language {
        case .chinese:
            return true
        case .english:
            return false
        case .system:
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            return preferredLanguage.hasPrefix("zh")
        }
    }

    nonisolated static var staticApiLanguageCode: String {
        return staticIsChinese ? "Chinese" : "English"
    }

    nonisolated static var staticTtsVoice: String {
        return staticIsChinese ? "Cherry" : "Ethan"
    }
}

// MARK: - String Extension for Localization

extension String {
    /// Localized string - can be called from any thread
    var localized: String {
        return LanguageManager.currentBundle.localizedString(forKey: self, value: nil, table: nil)
    }

    /// Localized string with format arguments - can be called from any thread
    func localized(_ args: CVarArg...) -> String {
        let format = LanguageManager.currentBundle.localizedString(forKey: self, value: nil, table: nil)
        return String(format: format, arguments: args)
    }
}
