import SwiftUI

@main
struct LearnReminderApp: App {
    @StateObject private var localization = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
        }
    }
}
