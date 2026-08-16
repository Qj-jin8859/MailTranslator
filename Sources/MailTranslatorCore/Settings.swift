import Foundation

final class AppSettings {
    static let shared = AppSettings()
    static let supportedTargetLanguages: [(code: String, title: String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("pt", "Português"),
        ("it", "Italiano"),
        ("ru", "Русский"),
        ("ar", "العربية")
    ]

    private let defaults: UserDefaults

    private enum Key {
        static let autoTranslate = "autoTranslateEnabled"
        static let targetLanguage = "targetLanguage"
        static let autoTranslateLanguage = "autoTranslateLanguage"
        static let pollingInterval = "pollingInterval"
        static let showOriginal = "showOriginalText"
        static let deepSeekAPIKey = "deepSeekAPIKey"
        static let deepSeekModel = "deepSeekModel"
        static let offlineOnly = "offlineOnly"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let syncTargetLanguage = "syncTargetLanguage"
    }

    private init() {
        defaults = UserDefaults(suiteName: "local.codex.MailTranslator.settings") ?? .standard

        if defaults.object(forKey: Key.autoTranslate) == nil {
            defaults.set(true, forKey: Key.autoTranslate)
        }
        if defaults.object(forKey: Key.targetLanguage) == nil {
            defaults.set("zh-Hans", forKey: Key.targetLanguage)
        }
        if defaults.object(forKey: Key.autoTranslateLanguage) == nil {
            defaults.set("zh-Hans", forKey: Key.autoTranslateLanguage)
        }
        if defaults.object(forKey: Key.pollingInterval) == nil {
            defaults.set(0.75, forKey: Key.pollingInterval)
        }
        if defaults.object(forKey: Key.showOriginal) == nil {
            defaults.set(true, forKey: Key.showOriginal)
        }
        if defaults.object(forKey: Key.syncTargetLanguage) == nil {
            defaults.set(true, forKey: Key.syncTargetLanguage)
        }
        if defaults.object(forKey: Key.deepSeekModel) == nil {
            defaults.set("deepseek-chat", forKey: Key.deepSeekModel)
        }
        if defaults.object(forKey: Key.offlineOnly) == nil {
            defaults.set(false, forKey: Key.offlineOnly)
        }
    }

    var autoTranslateEnabled: Bool {
        get { defaults.bool(forKey: Key.autoTranslate) }
        set { defaults.set(newValue, forKey: Key.autoTranslate) }
    }

    var targetLanguage: String {
        get { defaults.string(forKey: Key.targetLanguage) ?? "zh-Hans" }
        set { defaults.set(newValue, forKey: Key.targetLanguage) }
    }

    var autoTranslateLanguage: String {
        get { defaults.string(forKey: Key.autoTranslateLanguage) ?? "zh-Hans" }
        set { defaults.set(newValue, forKey: Key.autoTranslateLanguage) }
    }

    var pollingInterval: TimeInterval {
        get {
            let value = defaults.double(forKey: Key.pollingInterval)
            return value > 0 ? value : 0.75
        }
        set { defaults.set(newValue, forKey: Key.pollingInterval) }
    }

    var showOriginalText: Bool {
        get { defaults.bool(forKey: Key.showOriginal) }
        set { defaults.set(newValue, forKey: Key.showOriginal) }
    }

    var deepSeekAPIKey: String {
        get { defaults.string(forKey: Key.deepSeekAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.deepSeekAPIKey) }
    }

    var deepSeekModel: String {
        get { defaults.string(forKey: Key.deepSeekModel) ?? "deepseek-chat" }
        set { defaults.set(newValue, forKey: Key.deepSeekModel) }
    }

    var offlineOnly: Bool {
        get { defaults.bool(forKey: Key.offlineOnly) }
        set { defaults.set(newValue, forKey: Key.offlineOnly) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var launchAtLoginEnabled: Bool {
        get { defaults.bool(forKey: Key.launchAtLoginEnabled) }
        set { defaults.set(newValue, forKey: Key.launchAtLoginEnabled) }
    }

    var syncTargetLanguage: Bool {
        get { defaults.bool(forKey: Key.syncTargetLanguage) }
        set { defaults.set(newValue, forKey: Key.syncTargetLanguage) }
    }
}
