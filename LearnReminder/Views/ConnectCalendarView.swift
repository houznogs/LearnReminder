import SwiftUI
import UIKit

struct ConnectCalendarView: View {
    @ObservedObject var vm: DeadlinesViewModel
    @State private var showAdvanced: Bool = false
    @State private var tempURL: String
    @EnvironmentObject private var localization: LocalizationManager

    init(vm: DeadlinesViewModel) {
        _vm = ObservedObject(wrappedValue: vm)
        _tempURL = State(initialValue: vm.calendarURLString)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localization.localized("connect.status_section")) {
                    HStack(spacing: 10) {
                        Image(systemName: statusIcon)
                            .foregroundStyle(statusColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusText)
                                .font(.subheadline.weight(.semibold))
                            Text(statusDetail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(localization.localized("connect.last_synced", lastSyncText))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vm.isLoading {
                            ProgressView()
                        }
                    }
                }

                Section(localization.localized("connect.actions_section")) {
                    Button {
                        Task { await vm.refresh() }
                    } label: {
                        Label(localization.localized("connect.refresh_now"), systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        disconnect()
                    } label: {
                        Label(localization.localized("connect.disconnect"), systemImage: "link.badge.minus")
                    }
                }

                Section(localization.localized("connect.advanced_section")) {
                    Button {
                        showAdvanced.toggle()
                    } label: {
                        HStack {
                            Text(showAdvanced ? localization.localized("connect.hide_advanced") : localization.localized("connect.show_advanced"))
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showAdvanced {
                        HStack {
                            TextField(localization.localized("connect.placeholder_url"), text: $tempURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            Button(localization.localized("connect.paste")) {
                                if let paste = UIPasteboard.general.string {
                                    tempURL = paste
                                }
                            }
                        }
                        Button {
                            saveLink()
                        } label: {
                            Label(localization.localized("connect.save_link"), systemImage: "link.badge.checkmark")
                        }
                        Text(localization.localized("connect.tip"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = vm.errorMessage, !error.isEmpty {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(localization.localized("connect.title"))
        }
    }

    private var statusText: String {
        if !vm.isCalendarLinkValid {
            return localization.localized("status.invalid_link")
        }
        return vm.isConnected ? localization.localized("status.connected") : localization.localized("status.not_connected")
    }

    private var statusIcon: String {
        if !vm.isCalendarLinkValid {
            return "xmark.octagon.fill"
        }
        return vm.isConnected ? "checkmark.seal.fill" : "link"
    }

    private var statusColor: Color {
        if !vm.isCalendarLinkValid { return .red }
        return vm.isConnected ? .green : .orange
    }

    private var statusDetail: String {
        if !vm.isCalendarLinkValid {
            return localization.localized("connect.status_invalid_detail")
        }
        if vm.isConnected {
            return localization.localized("connect.status_connected_detail")
        }
        return localization.localized("connect.status_not_connected_detail")
    }

    private var isValidLink: Bool {
        AppSettings.isValidHTTPURL(AppSettings.normalizedURLString(vm.calendarURLString))
    }

    private var lastSyncText: String {
        if let last = AppSettings.lastFetchDate() {
            return localization.relativeDateString(for: last, relativeTo: Date(), unitsStyle: .short)
        }
        return localization.localized("status.never")
    }

    private func saveLink() {
        vm.calendarURLString = tempURL
        vm.saveCalendarURL()
        Task { await vm.refresh() }
    }

    private func disconnect() {
        vm.calendarURLString = ""
        vm.saveCalendarURL()
        vm.deadlines = []
    }
}

#Preview {
    ConnectCalendarView(vm: DeadlinesViewModel())
        .environmentObject(LocalizationManager.shared)
}
