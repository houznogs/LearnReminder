import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject var vm = DeadlinesViewModel()
    @StateObject private var todoStore = TodoStore()
    @AppStorage("reminderEnabled") private var reminderEnabled = false

    @State private var reminderTime: Date = Calendar.current.date(from: DateComponents(hour: AppSettings.reminderHour(), minute: AppSettings.reminderMinute())) ?? Date()
    @State private var requestingPermission = false
    @State private var newTodoTitle: String = ""
    @State private var selectedDeadline: DeadlineItem?
    @State private var noteText: String = ""
    @State private var searchText: String = ""
    @State private var selectedCourse: String?
    @State private var showingCalendarConnect = false

    private let notificationManager = NotificationManager()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    nextDueCard
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    filterRow
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    calendarStatusRow
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                Section("Due Today") {
                    if dueTodayDeadlines.isEmpty {
                        placeholderRow(text: vm.activeDeadlines.isEmpty ? "No deadlines yet. Connect your calendar to start tracking." : "Nothing due today. You're ahead!")
                    } else {
                        deadlineList(items: dueTodayDeadlines, completed: false)
                    }
                }

                Section("This Week") {
                    if thisWeekDeadlines.isEmpty {
                        placeholderRow(text: "No items due this week.")
                    } else {
                        deadlineList(items: thisWeekDeadlines, completed: false)
                    }
                }

                Section("Upcoming") {
                    if upcomingDeadlines.isEmpty {
                        placeholderRow(text: filteredActiveDeadlines.isEmpty ? "Nothing to show. Try another course filter or connect your calendar." : "All set for now.")
                    } else {
                        deadlineList(items: upcomingDeadlines, completed: false)
                    }
                }

                if !filteredCompletedDeadlines.isEmpty {
                    Section("Completed") {
                        deadlineList(items: filteredCompletedDeadlines, completed: true)
                    }
                }

                Section("To-Do") {
                    todoComposer

                    if todoStore.items.isEmpty {
                        placeholderRow(text: "No to-dos yet. Add quick reminders that stay local.")
                    } else {
                        ForEach(todoStore.items) { item in
                            HStack {
                                Button {
                                    todoStore.toggle(item)
                                } label: {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                                }
                                .buttonStyle(.plain)

                                Text(item.title)
                                    .strikethrough(item.isCompleted)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                                Spacer()
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    todoStore.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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

                if vm.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Syncing calendar…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = vm.errorMessage, !error.isEmpty {
                    Section {
                        errorRow(message: error)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search deadlines")
            .navigationTitle("LearnReminder")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    courseFilterMenu
                    Button {
                        showingCalendarConnect = true
                    } label: {
                        Label("Connect calendar", systemImage: "link.badge.plus")
                    }
                }
            }
            .task {
                await vm.load()
                saveReminderTime() // sync defaults on first run
            }
            .sheet(isPresented: $showingCalendarConnect) {
                CalendarConnectView(vm: vm)
            }
            .sheet(item: $selectedDeadline) { item in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.title)
                            .font(.headline)
                        TextEditor(text: $noteText)
                            .frame(minHeight: 180)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3))
                            )
                    }
                    .padding()
                    .navigationTitle("Notes")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                selectedDeadline = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                vm.updateNotes(for: item.id, notes: noteText)
                                selectedDeadline = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private var nextDueCard: some View {
        Group {
            if let next = nextDeadline {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Due")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(next.title)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(next.course)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label(next.dueDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar.badge.clock")
                            .font(.subheadline)
                        Text(next.relativeDueText)
                            .font(.footnote)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)))
                            .foregroundStyle(.white)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Color.blue.opacity(0.85), Color.indigo.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                )
                .foregroundStyle(.white)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Due")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("No upcoming deadlines.")
                        .font(.title3.weight(.semibold))
                    Text("Connect your calendar to populate the dashboard.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
    }

    private var filterRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Course Filter", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("All Courses") { selectedCourse = nil }
                    ForEach(availableCourses, id: \.self) { course in
                        Button {
                            selectedCourse = course
                        } label: {
                            Label(course, systemImage: selectedCourse == course ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedCourse ?? "All Courses")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }
            }
            Text(filterHintText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var calendarStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: vm.isLoading ? "arrow.triangle.2.circlepath" : (vm.calendarURLString.isEmpty ? "exclamationmark.triangle.fill" : "checkmark.seal.fill"))
                .foregroundStyle(vm.isLoading ? .blue : (vm.calendarURLString.isEmpty ? .orange : .green))
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.calendarURLString.isEmpty ? "Calendar not connected" : "Calendar connected")
                    .font(.subheadline.weight(.semibold))
                Text(vm.calendarURLString.isEmpty ? "Add your iCal URL to pull deadlines." : "Last synced \(lastFetchText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Refresh") {
                Task { await vm.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    private var courseFilterMenu: some View {
        Menu {
            Button("All Courses") { selectedCourse = nil }
            if availableCourses.isEmpty {
                Button("No courses available") {}.disabled(true)
            } else {
                ForEach(availableCourses, id: \.self) { course in
                    Button {
                        selectedCourse = course
                    } label: {
                        if selectedCourse == course {
                            Label(course, systemImage: "checkmark")
                        } else {
                            Text(course)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder
    private func deadlineList(items: [DeadlineItem], completed: Bool) -> some View {
        ForEach(items) { item in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.course)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.title)
                            .font(.headline)
                            .strikethrough(completed, color: .secondary)
                            .foregroundStyle(completed ? .secondary : .primary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(item.dueDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.relativeDueText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if item.isOverdue && !completed {
                        labelPill(text: "Overdue", color: .red.opacity(0.15), foreground: .red)
                    } else if Calendar.current.isDateInToday(item.dueDate) && !completed {
                        labelPill(text: "Due today", color: .orange.opacity(0.15), foreground: .orange)
                    }
                    if let notes = item.notes, !notes.isEmpty {
                        labelPill(text: "Has notes", color: .blue.opacity(0.12), foreground: .blue)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedDeadline = item
                noteText = item.notes ?? ""
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if !completed {
                    Button {
                        vm.toggleCompletion(for: item)
                    } label: {
                        Label("Complete", systemImage: "checkmark.circle")
                    }
                    .tint(.green)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if completed {
                    Button {
                        vm.toggleCompletion(for: item)
                    } label: {
                        Label("Mark Incomplete", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.orange)
                }
            }
        }
    }

    private var todoComposer: some View {
        HStack {
            TextField("New task", text: $newTodoTitle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            Button {
                addTodo()
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func placeholderRow(text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    private func labelPill(text: String, color: Color, foreground: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(color))
    }

    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sync issue", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.08))
        )
    }

    private func addTodo() {
        todoStore.add(title: newTodoTitle)
        newTodoTitle = ""
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

    private var filteredActiveDeadlines: [DeadlineItem] {
        vm.activeDeadlines
            .filter { matchesCourse($0) && matchesSearch($0) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var filteredCompletedDeadlines: [DeadlineItem] {
        vm.completedDeadlines
            .filter { matchesCourse($0) && matchesSearch($0) }
            .sorted { $0.dueDate > $1.dueDate }
    }

    private var dueTodayDeadlines: [DeadlineItem] {
        filteredActiveDeadlines.filter { Calendar.current.isDateInToday($0.dueDate) }
    }

    private var thisWeekDeadlines: [DeadlineItem] {
        filteredActiveDeadlines.filter { isThisWeek($0.dueDate) && !Calendar.current.isDateInToday($0.dueDate) }
    }

    private var upcomingDeadlines: [DeadlineItem] {
        let excluded = Set(dueTodayDeadlines.map(\.id) + thisWeekDeadlines.map(\.id))
        return filteredActiveDeadlines.filter { !excluded.contains($0.id) }
    }

    private var nextDeadline: DeadlineItem? {
        filteredActiveDeadlines.sorted { $0.dueDate < $1.dueDate }.first
    }

    private var availableCourses: [String] {
        Array(Set(vm.deadlines.map(\.course))).sorted()
    }

    private var lastFetchText: String {
        if let last = AppSettings.lastFetchDate() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: last, relativeTo: Date())
        }
        return "never"
    }

    private var filterHintText: String {
        if let course = selectedCourse {
            return "Filtering by \(course)."
        }
        if !searchText.isEmpty {
            return "Searching for \"\(searchText)\"."
        }
        return "Use search and course filters to focus the dashboard."
    }

    private func matchesCourse(_ item: DeadlineItem) -> Bool {
        guard let course = selectedCourse else { return true }
        return item.course == course
    }

    private func matchesSearch(_ item: DeadlineItem) -> Bool {
        guard !searchText.isEmpty else { return true }
        let haystack = "\(item.title) \(item.course) \(item.notes ?? "")".lowercased()
        return haystack.contains(searchText.lowercased())
    }

    private func isThisWeek(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

struct CalendarConnectView: View {
    @ObservedObject var vm: DeadlinesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var workingURL: String
    @State private var advancedText: String

    init(vm: DeadlinesViewModel) {
        _vm = ObservedObject(wrappedValue: vm)
        _workingURL = State(initialValue: vm.calendarURLString)
        _advancedText = State(initialValue: vm.calendarURLString)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Label(vm.calendarURLString.isEmpty ? "Not connected" : "Connected", systemImage: vm.calendarURLString.isEmpty ? "link" : "checkmark.seal.fill")
                    Text("Last fetched \(lastFetchText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Calendar URL") {
                    TextField("https://learn.uwaterloo.ca/.../calendar.ics", text: $workingURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button {
                        if let paste = UIPasteboard.general.string {
                            workingURL = paste
                            advancedText = paste
                        }
                    } label: {
                        Label("Paste from clipboard", systemImage: "doc.on.clipboard")
                    }
                }

                Section("Advanced paste") {
                    TextEditor(text: $advancedText)
                        .font(.callout.monospaced())
                        .frame(minHeight: 140)
                        .onChange(of: advancedText) { newValue in
                            workingURL = newValue
                        }
                    Text("Use this area for long URLs or to double-check raw ICS links.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        connect()
                    } label: {
                        Label("Save & Sync", systemImage: "link.badge.checkmark")
                    }
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Connect Calendar")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var lastFetchText: String {
        if let last = AppSettings.lastFetchDate() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: last, relativeTo: Date())
        }
        return "never"
    }

    private func connect() {
        let normalized = workingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        vm.calendarURLString = normalized
        vm.saveCalendarURL()
        Task {
            await vm.load()
            dismiss()
        }
    }
}

#Preview {
    ContentView()
}
