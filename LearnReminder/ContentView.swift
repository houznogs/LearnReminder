import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject var vm = DeadlinesViewModel()
    @AppStorage("reminderEnabled") private var reminderEnabled = false

    @State private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: AppSettings.reminderHour(), minute: AppSettings.reminderMinute())) ?? Date()
    @State private var requestingPermission = false

    private let notificationManager = NotificationManager()

    var body: some View {
        NavigationStack {
            Form {
                Section("iCal URL") {
                    HStack {
                        TextField("https://learn.uwaterloo.ca/.../calendar.ics", text: $vm.calendarURLString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        Button("Paste") {
                            if let paste = UIPasteboard.general.string {
                                vm.calendarURLString = paste
                            }
                        }
                    }

                    HStack {
                        Button("Save") {
                            vm.saveCalendarURL()
                            Task { await vm.load() }
                        }
                        Button("Refresh") {
                            Task { await vm.refresh() }
                        }
                    }

                    if vm.isLoading {
                        ProgressView("Loading…")
                    }

                    if let error = vm.errorMessage, !error.isEmpty {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("Upcoming Deadlines") {
                    if vm.deadlines.isEmpty {
                        Text("No upcoming deadlines")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.deadlines) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.course)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.title)
                                    .font(.headline)
                                HStack {
                                    Text(item.dueDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if item.isOverdue {
                                        Text("Overdue")
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Daily Reminder") {
                    Toggle("Enable Daily Reminder", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { enabled in
                            Task { await handleReminderToggle(enabled: enabled) }
                        }

                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderTime) { _ in
                            saveReminderTime()
                            Task { await scheduleReminderIfEnabled() }
                        }
                        .disabled(!reminderEnabled)

                    if requestingPermission {
                        ProgressView("Requesting permission…")
                    }
                }
            }
            .navigationTitle("LearnReminder")
            .task {
                await vm.load()
                saveReminderTime() // sync defaults on first run
            }
        }
    }

    private func saveReminderTime() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        AppSettings.setReminderHour(comps.hour ?? 20)
        AppSettings.setReminderMinute(comps.minute ?? 0)
    }

    private func handleReminderToggle(enabled: Bool) async {
        if enabled {
            await scheduleReminderIfEnabled()
        } else {
            await notificationManager.cancelDailyReminder()
        }
    }

    private func scheduleReminderIfEnabled() async {
        guard reminderEnabled else { return }
        requestingPermission = true
        let granted = (try? await notificationManager.requestAuthorization()) ?? false
        requestingPermission = false
        guard granted else {
            reminderEnabled = false
            return
        }

        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        await notificationManager.scheduleDailyReminder(
            hour: comps.hour ?? 20,
            minute: comps.minute ?? 0,
            body: vm.nextDueSummary
        )
    }
}

#Preview {
    ContentView()
}
