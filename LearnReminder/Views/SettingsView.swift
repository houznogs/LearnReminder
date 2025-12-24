import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        Form {
            Section(localization.localized("settings.language_section")) {
                Picker("", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(localization.localized(language.labelKey, toneSensitive: false))
                            .tag(language)
                    }
                }
                .pickerStyle(.inline)
                Text(localization.localized("settings.language_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(localization.localized("settings.tone_section")) {
                Picker("", selection: toneBinding) {
                    ForEach(AppTone.allCases) { tone in
                        Text(localization.localized(tone.labelKey))
                            .tag(tone)
                    }
                }
                .pickerStyle(.segmented)
                Text(localization.localized("settings.tone_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(localization.localized("settings.title"))
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localization.language },
            set: { localization.language = $0 }
        )
    }

    private var toneBinding: Binding<AppTone> {
        Binding(
            get: { localization.tone },
            set: { localization.tone = $0 }
        )
    }
}

#Preview {
    SettingsView()
        .environmentObject(LocalizationManager.shared)
}
