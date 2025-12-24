import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var labelKey: String {
        switch self {
        case .english:
            return "language.english"
        case .chineseSimplified:
            return "language.chinese_simplified"
        }
    }
}

enum AppTone: String, CaseIterable, Identifiable {
    case neutral
    case cute

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .neutral:
            return "tone.neutral"
        case .cute:
            return "tone.cute"
        }
    }
}

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var language: AppLanguage {
        didSet { AppSettings.setAppLanguage(language) }
    }

    @Published var tone: AppTone {
        didSet { AppSettings.setAppTone(tone) }
    }

    var locale: Locale {
        language.locale
    }

    private init() {
        language = AppSettings.appLanguage()
        tone = AppSettings.appTone()
    }

    func localized(_ key: String, toneSensitive: Bool = true) -> String {
        let bundle = bundleForCurrentLanguage()

        if toneSensitive,
           language == .chineseSimplified,
           tone == .cute {
            let cuteKey = "\(key)_cute"
            let cuteValue = bundle.localizedString(forKey: cuteKey, value: nil, table: nil)
            if cuteValue != cuteKey {
                return cuteValue
            }
        }

        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        if value != key {
            return value
        }

        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    func localized(_ key: String, toneSensitive: Bool = true, _ arguments: CVarArg...) -> String {
        let format = localized(key, toneSensitive: toneSensitive)
        return String(format: format, locale: locale, arguments: arguments)
    }

    func relativeDateString(for date: Date, relativeTo reference: Date = Date(), unitsStyle: RelativeDateTimeFormatter.UnitsStyle = .full) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = unitsStyle
        formatter.locale = locale
        return formatter.localizedString(for: date, relativeTo: reference)
    }

    func shortDateTimeString(for date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    func timeString(for date: Date) -> String {
        date.formatted(Date.FormatStyle(time: .shortened).locale(locale))
    }

    private func bundleForCurrentLanguage() -> Bundle {
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }
}
