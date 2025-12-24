import SwiftUI

struct RootView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @StateObject private var vm = DeadlinesViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(vm: vm)
            }
            .tabItem {
                Label(localization.localized("tab.home"), systemImage: "house.fill")
            }

            NavigationStack {
                ConnectCalendarView(vm: vm)
            }
            .tabItem {
                Label(localization.localized("tab.connect"), systemImage: "link")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(localization.localized("tab.settings"), systemImage: "gearshape")
            }
        }
        .task {
            if vm.isCalendarLinkValid && vm.deadlines.isEmpty {
                await vm.refresh()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(LocalizationManager.shared)
}
