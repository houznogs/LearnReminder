import Foundation

struct AppSettings {
    private static let defaults = UserDefaults.standard
    private enum Key {
        static let calendarURL = "calendarURL"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let lastFetchDate = "lastFetchDate"
        static let languageCode = "languageCode"
        static let tone = "tone"
    }

    // MARK: - Calendar URL

    static func calendarURLString() -> String {
        defaults.string(forKey: Key.calendarURL) ?? ""
    }

    static func setCalendarURLString(_ value: String) {
        defaults.set(value, forKey: Key.calendarURL)
    }

    // MARK: - Reminder Time

    static func reminderHour() -> Int {
        let stored = defaults.integer(forKey: Key.reminderHour)
        return stored == 0 ? 20 : stored
    }

    static func setReminderHour(_ value: Int) {
        defaults.set(value, forKey: Key.reminderHour)
    }

    static func reminderMinute() -> Int {
        defaults.object(forKey: Key.reminderMinute) == nil ? 0 : defaults.integer(forKey: Key.reminderMinute)
    }

    static func setReminderMinute(_ value: Int) {
        defaults.set(value, forKey: Key.reminderMinute)
    }

    // MARK: - Last Fetch

    static func lastFetchDate() -> Date? {
        defaults.object(forKey: Key.lastFetchDate) as? Date
    }

    static func setLastFetchDate(_ value: Date?) {
        defaults.set(value, forKey: Key.lastFetchDate)
    }

    // MARK: - Language & Tone

    static func appLanguage() -> AppLanguage {
        if let stored = defaults.string(forKey: Key.languageCode),
           let language = AppLanguage(rawValue: stored) {
            return language
        }
        if let preferred = Locale.preferredLanguages.first?.lowercased(),
           preferred.contains("zh") {
            return .chineseSimplified
        }
        return .english
    }

    static func setAppLanguage(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: Key.languageCode)
    }

    static func appTone() -> AppTone {
        if let stored = defaults.string(forKey: Key.tone),
           let tone = AppTone(rawValue: stored) {
            return tone
        }
        return .neutral
    }

    static func setAppTone(_ tone: AppTone) {
        defaults.set(tone.rawValue, forKey: Key.tone)
    }

    // MARK: - Validation

    static func normalizedURLString(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidHTTPURL(_ string: String) -> Bool {
        let trimmed = normalizedURLString(string)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "file" else {
            return false
        }
        return true
    }
}
