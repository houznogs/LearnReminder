import Foundation

struct AppSettings {
    private static let defaults = UserDefaults.standard
    private enum Key {
        static let calendarURL = "calendarURL"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let lastFetchDate = "lastFetchDate"
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

    // MARK: - Validation

    static func normalizedURLString(_ string: String) -> String {
        string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidHTTPURL(_ string: String) -> Bool {
        let trimmed = normalizedURLString(string)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }
}
